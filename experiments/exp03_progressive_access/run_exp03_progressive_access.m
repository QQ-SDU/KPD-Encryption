function summary = run_exp03_progressive_access(image_file, K_total, q_values, num_rounds, random_trials)
%RUN_EXP03_PROGRESSIVE_ACCESS Progressive key-based access to encrypted KPD groups.
%
% Scientific question
% -------------------
% Why is the ordered CLSA-KPD representation useful for encryption at all?
%
% Protocol
% --------
% 1) Build one ordered K_total-term CLSA-KPD representation.
% 2) Encrypt ALL K_total parameter groups independently using R rounds.
% 3) Simulate authorization by releasing only q group keys.
% 4) Compare three key-release policies at the same q:
%       Prefix : keys 1:q (importance-ordered progressive authorization)
%       Random : q uniformly sampled group keys (mean/std over trials)
%       Tail   : keys K_total-q+1:K_total
%
% The ciphertext set is identical in all cases; only the released key set
% changes. Unreleased groups are not replaced by wrong-key floating-point
% values; they are simply unavailable to the authorized reconstruction.
%
% Default protocol
% ----------------
% image          : 5.1.09.tiff (256x256 grayscale)
% K_total        : 300
% q values       : [25 50 75 100 150 200 250 300]
% encryption R   : 3 (selected by Exp01)
% random trials  : 30
%
% Outputs
% -------
% results/tables/exp03_progressive_access_summary.csv
% results/tables/exp03_progressive_access_random_trials.csv
% results/raw/exp03_progressive_access/exp03_progressive_access.mat
% results/figures/exp03_progressive_access_quality.pdf/.png
% results/figures/exp03_progressive_access_visual.pdf/.png
% results/images/exp03_progressive_access/*.png

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
if nargin < 2 || isempty(K_total)
    K_total = cfg.exp03.K_total;
end
if nargin < 3 || isempty(q_values)
    q_values = cfg.exp03.q_values;
end
if nargin < 4 || isempty(num_rounds)
    num_rounds = cfg.exp03.num_rounds;
end
if nargin < 5 || isempty(random_trials)
    random_trials = cfg.exp03.random_trials;
end

validateattributes(K_total, {'numeric'}, {'scalar','integer','positive'});
q_values = unique(double(q_values(:).'), 'stable');
validateattributes(q_values, {'numeric'}, {'vector','integer','positive','<=',K_total});
validateattributes(num_rounds, {'numeric'}, {'scalar','integer','positive'});
validateattributes(random_trials, {'numeric'}, {'scalar','integer','positive'});

[I, meta] = load_image_record(image_file);
if meta.channels ~= 1
    error('exp03:GrayscaleOnly', ...
        ['Exp03 isolates the access-control mechanism on one grayscale image. ', ...
         'Color/dataset generalization is handled in Exp05.']);
end
n = get_partition_for_image(size(I), cfg);

fprintf('=== exp03 progressive authorized reconstruction ===\n');
fprintf('Image: %s (%dx%d, %d channel)\n', meta.filename, meta.height, meta.width, meta.channels);
fprintf('Partition: [%s]\n', num2str(n));
fprintf('Fully encrypted representation: K_total = %d groups\n', K_total);
fprintf('Authorized q values: [%s]\n', num2str(q_values));
fprintf('Encryption rounds fixed at R = %d\n', num_rounds);
fprintf('Random-subset trials per q: %d\n', random_trials);

%% 1. Reuse the same K_total-term representation already created by Exp02.
[rep, cache_file, cache_created] = get_or_create_representation_cache( ...
    I, meta, n, K_total, cfg);
if rep.channel{1}.K < K_total
    error('exp03:InsufficientK', ...
        'Representation contains K=%d but K_total=%d is required.', ...
        rep.channel{1}.K, K_total);
end
if cache_created
    fprintf('Created representation cache: %s\n', cache_file);
else
    fprintf('Loaded representation cache: %s\n', cache_file);
end

%% 2. Encrypt the complete representation once, with independent group keys.
enc_cfg = cfg.encryption;
enc_cfg.num_rounds = num_rounds;

rng(cfg.seed + 300000, 'twister');
master_keys = cell(K_total,1);
cipher_groups = cell(K_total,1);
decrypted_groups = cell(K_total,1);
all_exact = true;

for k = 1:K_total
    param_vec = concat_factors(rep.channel{1}.groups{k});
    master_keys{k} = make_group_key(num_rounds, cfg.encryption.a_max);
    [cipher_groups{k}, master_keys{k}] = encrypt_group(param_vec, enc_cfg, master_keys{k});
    recovered = decrypt_group(cipher_groups{k}, master_keys{k}, enc_cfg);

    exact = isequal(recovered, param_vec);
    all_exact = all_exact && exact;
    if ~exact
        error('exp03:DecryptMismatch', 'Bit-exact recovery failed at group %d.', k);
    end
    decrypted_groups{k} = split_factors(recovered, n);
end
fprintf('Bit-exact recovery for all %d encrypted groups: %d\n', K_total, all_exact);

I_full_direct = reconstruct_representation(rep, K_total);
I_full_dec = reconstruct_group_subset(decrypted_groups, rep.image_size, 1:K_total);
full_equivalent = isequal(I_full_direct, I_full_dec);
if ~full_equivalent
    error('exp03:FullReconstructionMismatch', ...
        'Full decrypted reconstruction differs from the direct KPD reconstruction.');
end

%% 3. Evaluate three authorization policies for the same number q of released keys.
num_q = numel(q_values);
I_ref = uint8(I);
params_per_group = sum(n);
values_per_channel = meta.height * meta.width;

KeyAuthorizationPct = q_values(:) / K_total * 100;
AuthorizedParameterRatePct = q_values(:) * params_per_group / values_per_channel * 100;

PSNR_Prefix = zeros(num_q,1);
SSIM_Prefix = zeros(num_q,1);
PSNR_Tail = zeros(num_q,1);
SSIM_Tail = zeros(num_q,1);
PrefixMatchesDirectKPD = false(num_q,1);

PSNR_RandomMean = zeros(num_q,1);
PSNR_RandomStd = zeros(num_q,1);
PSNR_RandomMin = zeros(num_q,1);
PSNR_RandomMax = zeros(num_q,1);
SSIM_RandomMean = zeros(num_q,1);
SSIM_RandomStd = zeros(num_q,1);
SSIM_RandomMin = zeros(num_q,1);
SSIM_RandomMax = zeros(num_q,1);

trial_q = zeros(num_q*random_trials,1);
trial_id = zeros(num_q*random_trials,1);
trial_psnr = zeros(num_q*random_trials,1);
trial_ssim = zeros(num_q*random_trials,1);
trial_indices = strings(num_q*random_trials,1);
trial_ptr = 0;

image_out_dir = fullfile(cfg.results.images, 'exp03_progressive_access');
if exist(image_out_dir, 'dir') ~= 7, mkdir(image_out_dir); end
[~, base, ~] = fileparts(meta.filename);

prefix_images = cell(num_q,1);

for i = 1:num_q
    q = q_values(i);

    idx_prefix = 1:q;
    I_prefix = reconstruct_group_subset(decrypted_groups, rep.image_size, idx_prefix);
    I_prefix_u8 = clip_image_uint8(I_prefix);
    prefix_images{i} = I_prefix_u8;
    PSNR_Prefix(i) = image_psnr(I_ref, I_prefix_u8);
    SSIM_Prefix(i) = image_ssim(I_ref, I_prefix_u8);

    I_direct_q = reconstruct_representation(rep, q);
    PrefixMatchesDirectKPD(i) = isequal(I_prefix, I_direct_q);
    if ~PrefixMatchesDirectKPD(i)
        error('exp03:PrefixMismatch', ...
            'Authorized prefix reconstruction differs from direct KPD at q=%d.', q);
    end

    idx_tail = (K_total-q+1):K_total;
    I_tail = reconstruct_group_subset(decrypted_groups, rep.image_size, idx_tail);
    I_tail_u8 = clip_image_uint8(I_tail);
    PSNR_Tail(i) = image_psnr(I_ref, I_tail_u8);
    SSIM_Tail(i) = image_ssim(I_ref, I_tail_u8);

    psnr_trials = zeros(random_trials,1);
    ssim_trials = zeros(random_trials,1);
    rng(cfg.seed + 300100 + q, 'twister');
    for t = 1:random_trials
        idx_random = sort(randperm(K_total, q));
        I_random = reconstruct_group_subset(decrypted_groups, rep.image_size, idx_random);
        I_random_u8 = clip_image_uint8(I_random);
        psnr_trials(t) = image_psnr(I_ref, I_random_u8);
        ssim_trials(t) = image_ssim(I_ref, I_random_u8);

        trial_ptr = trial_ptr + 1;
        trial_q(trial_ptr) = q;
        trial_id(trial_ptr) = t;
        trial_psnr(trial_ptr) = psnr_trials(t);
        trial_ssim(trial_ptr) = ssim_trials(t);
        trial_indices(trial_ptr) = string(sprintf('%d ', idx_random));
    end

    PSNR_RandomMean(i) = mean(psnr_trials);
    PSNR_RandomStd(i) = std(psnr_trials,0);
    PSNR_RandomMin(i) = min(psnr_trials);
    PSNR_RandomMax(i) = max(psnr_trials);
    SSIM_RandomMean(i) = mean(ssim_trials);
    SSIM_RandomStd(i) = std(ssim_trials,0);
    SSIM_RandomMin(i) = min(ssim_trials);
    SSIM_RandomMax(i) = max(ssim_trials);

    imwrite(I_prefix_u8, fullfile(image_out_dir, sprintf('%s_prefix_q%03d.png', base, q)));

    fprintf(['q=%3d (%6.2f%% keys) | Prefix: %.4f dB / %.5f | ', ...
             'Random: %.4f+/-%.4f dB / %.5f+/-%.5f | Tail: %.4f dB / %.5f\n'], ...
        q, KeyAuthorizationPct(i), PSNR_Prefix(i), SSIM_Prefix(i), ...
        PSNR_RandomMean(i), PSNR_RandomStd(i), SSIM_RandomMean(i), SSIM_RandomStd(i), ...
        PSNR_Tail(i), SSIM_Tail(i));
end

random_trials_table = table(trial_q, trial_id, trial_psnr, trial_ssim, trial_indices, ...
    'VariableNames', {'QAuthorized','Trial','PSNR','SSIM','AuthorizedGroupIndices'});

%% 4. Quantify the benefit of ordered key release.
PrefixPSNRGainOverRandomMean_dB = PSNR_Prefix - PSNR_RandomMean;
PrefixSSIMGainOverRandomMean = SSIM_Prefix - SSIM_RandomMean;
PrefixPSNRGainOverTail_dB = PSNR_Prefix - PSNR_Tail;
PrefixSSIMGainOverTail = SSIM_Prefix - SSIM_Tail;

summary = table( ...
    q_values(:), repmat(K_total,num_q,1), KeyAuthorizationPct, AuthorizedParameterRatePct, ...
    PSNR_Prefix, SSIM_Prefix, ...
    PSNR_RandomMean, PSNR_RandomStd, PSNR_RandomMin, PSNR_RandomMax, ...
    SSIM_RandomMean, SSIM_RandomStd, SSIM_RandomMin, SSIM_RandomMax, ...
    PSNR_Tail, SSIM_Tail, ...
    PrefixPSNRGainOverRandomMean_dB, PrefixSSIMGainOverRandomMean, ...
    PrefixPSNRGainOverTail_dB, PrefixSSIMGainOverTail, ...
    PrefixMatchesDirectKPD, repmat(all_exact,num_q,1), repmat(full_equivalent,num_q,1), ...
    'VariableNames', {'QAuthorized','KTotalEncrypted','KeyAuthorizationPct', ...
    'AuthorizedParameterRatePct','PSNR_Prefix','SSIM_Prefix', ...
    'PSNR_RandomMean','PSNR_RandomStd','PSNR_RandomMin','PSNR_RandomMax', ...
    'SSIM_RandomMean','SSIM_RandomStd','SSIM_RandomMin','SSIM_RandomMax', ...
    'PSNR_Tail','SSIM_Tail', ...
    'PrefixPSNRGainOverRandomMean_dB','PrefixSSIMGainOverRandomMean', ...
    'PrefixPSNRGainOverTail_dB','PrefixSSIMGainOverTail', ...
    'PrefixMatchesDirectKPD','AllParametersBitExact','FullReconstructionEquivalent'});

%% 5. Save numerical results and reproducibility metadata.
if exist(cfg.results.tables, 'dir') ~= 7, mkdir(cfg.results.tables); end
summary_file = fullfile(cfg.results.tables, 'exp03_progressive_access_summary.csv');
trial_file = fullfile(cfg.results.tables, 'exp03_progressive_access_random_trials.csv');
writetable(summary, summary_file);
writetable(random_trials_table, trial_file);

raw_dir = fullfile(cfg.results.raw, 'exp03_progressive_access');
if exist(raw_dir, 'dir') ~= 7, mkdir(raw_dir); end
artifact_file = fullfile(raw_dir, 'exp03_progressive_access.mat');
save(artifact_file, 'summary', 'random_trials_table', 'meta', 'n', 'K_total', ...
    'q_values', 'num_rounds', 'random_trials', 'cache_file', 'cfg', ...
    'all_exact', 'full_equivalent', '-v7.3');

%% 6. Quality figure: ordered prefix versus random/tail key release.
if exist(cfg.results.figures, 'dir') ~= 7, mkdir(cfg.results.figures); end
fig1 = figure('Color','w','Units','pixels','Position',[100 100 1120 480]);
tiledlayout(fig1,1,2,'TileSpacing','compact','Padding','compact');

nexttile;
plot(q_values, PSNR_Prefix, '-o', 'LineWidth',1.8,'MarkerSize',6); hold on;
errorbar(q_values, PSNR_RandomMean, PSNR_RandomStd, '--s', 'LineWidth',1.4,'MarkerSize',6);
plot(q_values, PSNR_Tail, ':^', 'LineWidth',1.6,'MarkerSize',6);
xline(100, '--', 'q=100', 'LabelVerticalAlignment','bottom');
grid on; box on;
xlabel('Number of released group keys, q'); ylabel('PSNR (dB)');
title('(a) Reconstruction quality under key release');
legend({'Ordered prefix','Random subset','Tail subset'}, 'Location','southeast');

nexttile;
plot(q_values, SSIM_Prefix, '-o', 'LineWidth',1.8,'MarkerSize',6); hold on;
errorbar(q_values, SSIM_RandomMean, SSIM_RandomStd, '--s', 'LineWidth',1.4,'MarkerSize',6);
plot(q_values, SSIM_Tail, ':^', 'LineWidth',1.6,'MarkerSize',6);
xline(100, '--', 'q=100', 'LabelVerticalAlignment','bottom');
grid on; box on;
xlabel('Number of released group keys, q'); ylabel('SSIM');
title('(b) Structural similarity under key release');
legend({'Ordered prefix','Random subset','Tail subset'}, 'Location','southeast');

set(findall(fig1,'-property','FontName'),'FontName','Times New Roman');
set(findall(fig1,'-property','FontSize'),'FontSize',12);
fig1_pdf = fullfile(cfg.results.figures, 'exp03_progressive_access_quality.pdf');
fig1_png = fullfile(cfg.results.figures, 'exp03_progressive_access_quality.png');
save_figure_compat(fig1, fig1_pdf, fig1_png);

%% 7. Visual figure for representative progressive authorization levels.
visual_q = choose_visual_q(q_values);
fig2 = figure('Color','w','Units','pixels','Position',[80 80 1450 520]);
tiledlayout(fig2,1,numel(visual_q)+1,'TileSpacing','compact','Padding','compact');
nexttile;
imshow(I_ref);
title('Original');
for j = 1:numel(visual_q)
    q = visual_q(j);
    ii = find(q_values == q, 1);
    nexttile;
    imshow(prefix_images{ii});
    title(sprintf('q=%d\n%.2f dB, %.3f', q, PSNR_Prefix(ii), SSIM_Prefix(ii)));
end
set(findall(fig2,'-property','FontName'),'FontName','Times New Roman');
set(findall(fig2,'-property','FontSize'),'FontSize',12);
fig2_pdf = fullfile(cfg.results.figures, 'exp03_progressive_access_visual.pdf');
fig2_png = fullfile(cfg.results.figures, 'exp03_progressive_access_visual.png');
save_figure_compat(fig2, fig2_pdf, fig2_png);

%% 8. Optional cross-check against Exp02 if its summary is present.
exp02_file = fullfile(cfg.results.tables, 'exp02_k_sensitivity_summary.csv');
if exist(exp02_file, 'file') == 2
    E2 = readtable(exp02_file);
    common_q = intersect(q_values(:), E2.K(:));
    max_psnr_diff = 0;
    max_ssim_diff = 0;
    for j = 1:numel(common_q)
        q = common_q(j);
        a = find(q_values == q,1);
        b = find(E2.K == q,1);
        max_psnr_diff = max(max_psnr_diff, abs(PSNR_Prefix(a)-E2.PSNR_KPD(b)));
        max_ssim_diff = max(max_ssim_diff, abs(SSIM_Prefix(a)-E2.SSIM_KPD(b)));
    end
    fprintf('Cross-check with Exp02: max |Delta PSNR| = %.12g dB, max |Delta SSIM| = %.12g\n', ...
        max_psnr_diff, max_ssim_diff);
end

fprintf('\n=== exp03 complete ===\n');
fprintf('Summary table : %s\n', summary_file);
fprintf('Random trials : %s\n', trial_file);
fprintf('Raw artifact  : %s\n', artifact_file);
fprintf('Quality figure: %s\n', fig1_png);
fprintf('Visual figure : %s\n', fig2_png);
end

function visual_q = choose_visual_q(q_values)
preferred = [25 50 100 200 300];
visual_q = preferred(ismember(preferred, q_values));
if isempty(visual_q)
    idx = unique(round(linspace(1,numel(q_values),min(5,numel(q_values)))));
    visual_q = q_values(idx);
end
end

function save_figure_compat(fig, pdf_file, png_file)
try
    exportgraphics(fig, pdf_file, 'ContentType','vector');
    exportgraphics(fig, png_file, 'Resolution',600);
catch
    print(fig, pdf_file, '-dpdf', '-bestfit');
    print(fig, png_file, '-dpng', '-r600');
end
end
