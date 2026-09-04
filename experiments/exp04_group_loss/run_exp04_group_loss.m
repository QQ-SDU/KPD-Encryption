function summary = run_exp04_group_loss(image_file, K_total, loss_rates, num_rounds, random_trials)
%RUN_EXP04_GROUP_LOSS Exp04: robustness to encrypted KPD-group loss/erasure.
%
% Implementation for Exp04. Use the project-root wrapper `run_group_loss`.
%
% Scientific question
% -------------------
% How robust is the independently encrypted CLSA-KPD representation when
% some encrypted parameter groups are unavailable during transmission or
% storage?
%
% Important interpretation
% ------------------------
% This experiment studies GROUP ERASURE/LOSS, not undetected ciphertext
% corruption. A missing group is simply unavailable and is omitted from
% reconstruction. This avoids interpreting corrupted bytes as arbitrary
% IEEE-754 doubles.
%
% Three loss policies are compared at the same loss rate:
%   1) Random loss  : uniformly random missing groups (mean/std over trials)
%   2) Early loss   : lose groups 1:m (worst case: high-importance groups)
%   3) Late loss    : lose groups K-m+1:K (low-importance groups)
%
% Defaults
% --------
% image         : 5.1.09.tiff
% K_total       : 300
% loss rates    : [0 1 5 10 20 30] %
% rounds        : R = 3
% random trials : 100 per nonzero loss rate

project_root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(project_root);
setup_paths();
cfg = default_config(project_root);

if nargin < 1 || isempty(image_file)
    image_file = cfg.baseline.default_image;
elseif exist(image_file, 'file') ~= 2
    candidate = fullfile(project_root, image_file);
    if exist(candidate, 'file') == 2
        image_file = candidate;
    end
end
if nargin < 2 || isempty(K_total), K_total = 300; end
if nargin < 3 || isempty(loss_rates), loss_rates = [0 1 5 10 20 30]; end
if nargin < 4 || isempty(num_rounds), num_rounds = 3; end
if nargin < 5 || isempty(random_trials), random_trials = 100; end

validateattributes(K_total, {'numeric'}, {'scalar','integer','positive'});
loss_rates = unique(double(loss_rates(:).'), 'stable');
if any(loss_rates < 0) || any(loss_rates >= 100)
    error('run_group_loss:LossRate', 'loss_rates must satisfy 0 <= rate < 100.');
end
validateattributes(num_rounds, {'numeric'}, {'scalar','integer','positive'});
validateattributes(random_trials, {'numeric'}, {'scalar','integer','positive'});

[I, meta] = load_image_record(image_file);
if meta.channels ~= 1
    error('run_group_loss:GrayscaleOnly', 'Exp04 currently isolates robustness on one grayscale image.');
end
n = get_partition_for_image(size(I), cfg);

fprintf('=== exp04 encrypted-group loss robustness ===\n');
fprintf('Image: %s (%dx%d)\n', meta.filename, meta.height, meta.width);
fprintf('Partition: [%s]\n', num2str(n));
fprintf('K_total = %d, R = %d\n', K_total, num_rounds);
fprintf('Loss rates (%%): [%s]\n', num2str(loss_rates));
fprintf('Random trials per nonzero rate: %d\n', random_trials);

[rep, cache_file, cache_created] = get_or_create_representation_cache(I, meta, n, K_total, cfg);
if rep.channel{1}.K < K_total
    error('run_group_loss:InsufficientK', 'Representation has only K=%d groups; K_total=%d required.', rep.channel{1}.K, K_total);
end
if cache_created
    fprintf('Created representation cache: %s\n', cache_file);
else
    fprintf('Loaded representation cache: %s\n', cache_file);
end

enc_cfg = cfg.encryption;
enc_cfg.num_rounds = num_rounds;
rng(cfg.seed + 400000, 'twister');

cipher_groups = cell(K_total,1);
keys = cell(K_total,1);
decrypted_groups = cell(K_total,1);
all_exact = true;
for k = 1:K_total
    param_vec = concat_factors(rep.channel{1}.groups{k});
    keys{k} = make_group_key(num_rounds, cfg.encryption.a_max);
    [cipher_groups{k}, keys{k}] = encrypt_group(param_vec, enc_cfg, keys{k});
    recovered = decrypt_group(cipher_groups{k}, keys{k}, enc_cfg);
    exact = isequal(recovered, param_vec);
    all_exact = all_exact && exact;
    if ~exact
        error('run_group_loss:DecryptMismatch', 'Bit-exact recovery failed at group %d.', k);
    end
    decrypted_groups{k} = split_factors(recovered, n);
end
fprintf('Bit-exact recovery for all groups: %d\n', all_exact);

I_ref = uint8(I);
I_full = reconstruct_group_subset(decrypted_groups, rep.image_size, 1:K_total);
I_full_u8 = clip_image_uint8(I_full);
full_psnr = image_psnr(I_ref, I_full_u8);
full_ssim = image_ssim(I_ref, I_full_u8);
I_direct = reconstruct_representation(rep, K_total);
full_equivalent = isequal(I_full, I_direct);
if ~full_equivalent
    error('run_group_loss:FullMismatch', 'Full decrypted reconstruction does not match direct KPD reconstruction.');
end
fprintf('No-loss KPD quality: %.4f dB / %.5f\n', full_psnr, full_ssim);

num_rates = numel(loss_rates);
LostGroups = zeros(num_rates,1); RetainedGroups = zeros(num_rates,1); RetainedGroupPct = zeros(num_rates,1);
PSNR_RandomMean = zeros(num_rates,1); PSNR_RandomStd = zeros(num_rates,1); PSNR_RandomMin = zeros(num_rates,1); PSNR_RandomMax = zeros(num_rates,1);
SSIM_RandomMean = zeros(num_rates,1); SSIM_RandomStd = zeros(num_rates,1); SSIM_RandomMin = zeros(num_rates,1); SSIM_RandomMax = zeros(num_rates,1);
PSNR_EarlyLoss = zeros(num_rates,1); SSIM_EarlyLoss = zeros(num_rates,1);
PSNR_LateLoss = zeros(num_rates,1); SSIM_LateLoss = zeros(num_rates,1);

trial_rows = sum(arrayfun(@(r) trial_count_for_rate(r, random_trials), loss_rates));
TrialLossRatePct = zeros(trial_rows,1); Trial = zeros(trial_rows,1); TrialLostGroups = zeros(trial_rows,1);
TrialPSNR = zeros(trial_rows,1); TrialSSIM = zeros(trial_rows,1); EarliestLostGroup = zeros(trial_rows,1);
IncludesGroup1 = false(trial_rows,1); LostGroupIndices = strings(trial_rows,1); ptr = 0;

image_out_dir = fullfile(cfg.results.images, 'exp04_group_loss');
if exist(image_out_dir, 'dir') ~= 7, mkdir(image_out_dir); end
[~, base, ~] = fileparts(meta.filename);

for i = 1:num_rates
    rate = loss_rates(i);
    if rate == 0, m = 0; else, m = max(1, round(K_total * rate / 100)); end
    m = min(m, K_total - 1);
    LostGroups(i) = m;
    RetainedGroups(i) = K_total - m;
    RetainedGroupPct(i) = RetainedGroups(i) / K_total * 100;

    if m == 0, keep_early_loss = 1:K_total; else, keep_early_loss = (m+1):K_total; end
    I_early = reconstruct_group_subset(decrypted_groups, rep.image_size, keep_early_loss);
    I_early_u8 = clip_image_uint8(I_early);
    PSNR_EarlyLoss(i) = image_psnr(I_ref, I_early_u8);
    SSIM_EarlyLoss(i) = image_ssim(I_ref, I_early_u8);

    if m == 0, keep_late_loss = 1:K_total; else, keep_late_loss = 1:(K_total-m); end
    I_late = reconstruct_group_subset(decrypted_groups, rep.image_size, keep_late_loss);
    I_late_u8 = clip_image_uint8(I_late);
    PSNR_LateLoss(i) = image_psnr(I_ref, I_late_u8);
    SSIM_LateLoss(i) = image_ssim(I_ref, I_late_u8);

    n_trials_here = trial_count_for_rate(rate, random_trials);
    psnr_trials = zeros(n_trials_here,1); ssim_trials = zeros(n_trials_here,1);
    rng(cfg.seed + 400100 + round(rate*100), 'twister');
    for t = 1:n_trials_here
        if m == 0, lost_idx = []; else, lost_idx = sort(randperm(K_total, m)); end
        keep_idx = setdiff(1:K_total, lost_idx, 'stable');
        I_random = reconstruct_group_subset(decrypted_groups, rep.image_size, keep_idx);
        I_random_u8 = clip_image_uint8(I_random);
        psnr_trials(t) = image_psnr(I_ref, I_random_u8);
        ssim_trials(t) = image_ssim(I_ref, I_random_u8);

        ptr = ptr + 1;
        TrialLossRatePct(ptr) = rate; Trial(ptr) = t; TrialLostGroups(ptr) = m;
        TrialPSNR(ptr) = psnr_trials(t); TrialSSIM(ptr) = ssim_trials(t);
        if isempty(lost_idx)
            EarliestLostGroup(ptr) = 0; IncludesGroup1(ptr) = false; LostGroupIndices(ptr) = "";
        else
            EarliestLostGroup(ptr) = min(lost_idx); IncludesGroup1(ptr) = any(lost_idx == 1);
            LostGroupIndices(ptr) = strtrim(string(sprintf('%d ', lost_idx)));
        end
    end

    PSNR_RandomMean(i) = mean(psnr_trials); PSNR_RandomStd(i) = std(psnr_trials,0);
    PSNR_RandomMin(i) = min(psnr_trials); PSNR_RandomMax(i) = max(psnr_trials);
    SSIM_RandomMean(i) = mean(ssim_trials); SSIM_RandomStd(i) = std(ssim_trials,0);
    SSIM_RandomMin(i) = min(ssim_trials); SSIM_RandomMax(i) = max(ssim_trials);

    if any(abs(rate - [10 20]) < 1e-12)
        imwrite(I_early_u8, fullfile(image_out_dir, sprintf('%s_early_loss_%g_pct.png', base, rate)));
        imwrite(I_late_u8, fullfile(image_out_dir, sprintf('%s_late_loss_%g_pct.png', base, rate)));
    end
end

PSNRDrop_RandomMean_dB = full_psnr - PSNR_RandomMean; SSIMDrop_RandomMean = full_ssim - SSIM_RandomMean;
PSNRDrop_EarlyLoss_dB = full_psnr - PSNR_EarlyLoss; SSIMDrop_EarlyLoss = full_ssim - SSIM_EarlyLoss;
PSNRDrop_LateLoss_dB = full_psnr - PSNR_LateLoss; SSIMDrop_LateLoss = full_ssim - SSIM_LateLoss;

summary = table(loss_rates(:), LostGroups, RetainedGroups, RetainedGroupPct, repmat(full_psnr,num_rates,1), repmat(full_ssim,num_rates,1), PSNR_RandomMean, PSNR_RandomStd, PSNR_RandomMin, PSNR_RandomMax, SSIM_RandomMean, SSIM_RandomStd, SSIM_RandomMin, SSIM_RandomMax, PSNR_EarlyLoss, SSIM_EarlyLoss, PSNR_LateLoss, SSIM_LateLoss, PSNRDrop_RandomMean_dB, SSIMDrop_RandomMean, PSNRDrop_EarlyLoss_dB, SSIMDrop_EarlyLoss, PSNRDrop_LateLoss_dB, SSIMDrop_LateLoss, repmat(all_exact,num_rates,1), repmat(full_equivalent,num_rates,1), 'VariableNames', {'LossRatePct','LostGroups','RetainedGroups','RetainedGroupPct','NoLossPSNR','NoLossSSIM','PSNR_RandomMean','PSNR_RandomStd','PSNR_RandomMin','PSNR_RandomMax','SSIM_RandomMean','SSIM_RandomStd','SSIM_RandomMin','SSIM_RandomMax','PSNR_EarlyLoss','SSIM_EarlyLoss','PSNR_LateLoss','SSIM_LateLoss','PSNRDrop_RandomMean_dB','SSIMDrop_RandomMean','PSNRDrop_EarlyLoss_dB','SSIMDrop_EarlyLoss','PSNRDrop_LateLoss_dB','SSIMDrop_LateLoss','AllParametersBitExact','FullReconstructionEquivalent'});

random_trials_table = table(TrialLossRatePct(1:ptr), Trial(1:ptr), TrialLostGroups(1:ptr), TrialPSNR(1:ptr), TrialSSIM(1:ptr), EarliestLostGroup(1:ptr), IncludesGroup1(1:ptr), LostGroupIndices(1:ptr), 'VariableNames', {'LossRatePct','Trial','LostGroups','PSNR','SSIM','EarliestLostGroup','IncludesGroup1','LostGroupIndices'});

if exist(cfg.results.tables, 'dir') ~= 7, mkdir(cfg.results.tables); end
summary_file = fullfile(cfg.results.tables, 'exp04_group_loss_summary.csv');
trials_file = fullfile(cfg.results.tables, 'exp04_group_loss_random_trials.csv');
writetable(summary, summary_file); writetable(random_trials_table, trials_file);

raw_dir = fullfile(cfg.results.raw, 'exp04_group_loss');
if exist(raw_dir, 'dir') ~= 7, mkdir(raw_dir); end
artifact_file = fullfile(raw_dir, 'exp04_group_loss.mat');
save(artifact_file, 'summary', 'random_trials_table', 'meta', 'n', 'K_total', 'loss_rates', 'num_rounds', 'random_trials', 'cache_file', 'full_psnr', 'full_ssim', 'cfg', '-v7.3');

if exist(cfg.results.figures, 'dir') ~= 7, mkdir(cfg.results.figures); end
fig = figure('Color','w','Units','pixels','Position',[100 100 1120 480]);
tiledlayout(fig,1,2,'TileSpacing','compact','Padding','compact');
nexttile;
errorbar(loss_rates, PSNR_RandomMean, PSNR_RandomStd, '-o','LineWidth',1.5,'MarkerSize',6); hold on;
plot(loss_rates, PSNR_EarlyLoss, '--s','LineWidth',1.6,'MarkerSize',6);
plot(loss_rates, PSNR_LateLoss, ':^','LineWidth',1.8,'MarkerSize',6);
grid on; box on; xlabel('Encrypted-group loss rate (%)'); ylabel('PSNR (dB)'); title('(a) Reconstruction quality under group loss');
legend({'Random loss','Early-group loss','Late-group loss'}, 'Location','best');
nexttile;
errorbar(loss_rates, SSIM_RandomMean, SSIM_RandomStd, '-o','LineWidth',1.5,'MarkerSize',6); hold on;
plot(loss_rates, SSIM_EarlyLoss, '--s','LineWidth',1.6,'MarkerSize',6);
plot(loss_rates, SSIM_LateLoss, ':^','LineWidth',1.8,'MarkerSize',6);
grid on; box on; xlabel('Encrypted-group loss rate (%)'); ylabel('SSIM'); title('(b) Structural similarity under group loss');
legend({'Random loss','Early-group loss','Late-group loss'}, 'Location','best');
set(findall(fig,'-property','FontName'),'FontName','Times New Roman');
set(findall(fig,'-property','FontSize'),'FontSize',12);
fig_pdf = fullfile(cfg.results.figures, 'exp04_group_loss_quality.pdf');
fig_png = fullfile(cfg.results.figures, 'exp04_group_loss_quality.png');
save_figure_compat(fig, fig_pdf, fig_png);

fprintf('\n=== exp04 complete ===\n');
fprintf('Summary table : %s\n', summary_file);
fprintf('Random trials : %s\n', trials_file);
fprintf('Raw artifact  : %s\n', artifact_file);
fprintf('Figure        : %s\n', fig_png);
end

function n = trial_count_for_rate(rate, random_trials)
if rate == 0, n = 1; else, n = random_trials; end
end

function save_figure_compat(fig, pdf_file, png_file)
try
    exportgraphics(fig, pdf_file, 'ContentType','vector');
    exportgraphics(fig, png_file, 'Resolution',600);
catch
    print(fig, pdf_file, '-dpdf','-bestfit');
    print(fig, png_file, '-dpng','-r600');
end
end
