function summary = run_exp02_k_sensitivity(image_file, K_values, num_rounds, runtime_repeats)
%RUN_EXP02_K_SENSITIVITY Sensitivity of reconstruction quality and crypto cost to K.
%
% Scientific purpose
% ------------------
% K is treated as a CLSA-KPD representation-budget variable, not as an
% encryption hyperparameter. The same ordered KPD sequence is reused for
% all operating points. Encryption rounds are fixed to the value selected
% by Exp01 so that K is the only experimental variable.
%
% Default protocol
% ----------------
% image           : 5.1.09.tiff (256x256 grayscale)
% K values        : [25 50 75 100 125 150 200 250 300]
% encryption R    : 3 (selected from Exp01)
% runtime repeats : 5
%
% Main outputs
% ------------
% results/tables/exp02_k_sensitivity_summary.csv
% results/tables/exp02_k_sensitivity_runtime_fit.csv
% results/raw/exp02_k_sensitivity/exp02_k_sensitivity.mat
% results/figures/exp02_k_sensitivity.pdf/.png
% results/images/exp02_k_sensitivity/<image>_K*.png

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
if nargin < 2 || isempty(K_values)
    K_values = cfg.exp02.K_values;
end
if nargin < 3 || isempty(num_rounds)
    num_rounds = cfg.exp02.num_rounds;
end
if nargin < 4 || isempty(runtime_repeats)
    runtime_repeats = cfg.exp02.runtime_repeats;
end

K_values = unique(double(K_values(:).'), 'stable');
validateattributes(K_values, {'numeric'}, {'vector','integer','positive'});
validateattributes(num_rounds, {'numeric'}, {'scalar','integer','positive'});
validateattributes(runtime_repeats, {'numeric'}, {'scalar','integer','positive'});

[I, meta] = load_image_record(image_file);
if meta.channels ~= 1
    error('exp02:GrayscaleOnly', ...
        ['Exp02 isolates the effect of K on one grayscale 256x256 image. ', ...
         'Dataset/color generalization is handled later in Exp05.']);
end
n = get_partition_for_image(size(I), cfg);
K_max = max(K_values);

fprintf('=== exp02 K sensitivity ===\n');
fprintf('Image: %s (%dx%d, %d channel)\n', meta.filename, meta.height, meta.width, meta.channels);
fprintf('Partition: [%s]\n', num2str(n));
fprintf('K values: [%s]\n', num2str(K_values));
fprintf('K max: %d\n', K_max);
fprintf('Encryption rounds fixed at R = %d\n', num_rounds);
fprintf('Runtime repeats: %d\n', runtime_repeats);

%% 1. Load or create one fixed representation containing at least K_max groups.
[rep, cache_file, cache_created] = load_or_create_representation( ...
    I, meta, n, K_max, cfg);

if rep.channel{1}.K < K_max
    error('exp02:InsufficientK', ...
        'Representation contains only K=%d groups, but K_max=%d is required.', ...
        rep.channel{1}.K, K_max);
end

if cache_created
    fprintf('Created representation cache: %s\n', cache_file);
else
    fprintf('Loaded representation cache: %s\n', cache_file);
end

%% 2. Fixed representation-budget mapping.
params_per_group = sum(n);
original_values_per_channel = meta.height * meta.width;
parameter_rate_pct = K_values(:) * params_per_group / original_values_per_channel * 100;

first_param = concat_factors(rep.channel{1}.groups{1});
[first_block, ~] = serialize_group(first_param);
bytes_per_group = numel(first_block);
serialized_bytes = K_values(:) * bytes_per_group;
serialized_kib = serialized_bytes / 1024;

%% 3. Reconstruction quality for prefixes of the same ordered KPD sequence.
num_K = numel(K_values);
PSNR_KPD = zeros(num_K,1);
SSIM_KPD = zeros(num_K,1);
ResidualRatio = zeros(num_K,1);

I_ref = uint8(I);
accum = zeros(meta.height * meta.width, 1);
idx_map = containers.Map('KeyType','double','ValueType','double');
for i = 1:num_K
    idx_map(K_values(i)) = i;
end

image_out_dir = fullfile(cfg.results.images, 'exp02_k_sensitivity');
if exist(image_out_dir, 'dir') ~= 7, mkdir(image_out_dir); end
[~, base, ~] = fileparts(meta.filename);

for k = 1:K_max
    factors = rep.channel{1}.groups{k};
    term = kron_product(factors{:});
    accum = accum + term(:);

    if isKey(idx_map, k)
        ii = idx_map(k);
        I_k = reshape(accum, meta.height, meta.width);
        I_k_u8 = clip_image_uint8(I_k);
        PSNR_KPD(ii) = image_psnr(I_ref, I_k_u8);
        SSIM_KPD(ii) = image_ssim(I_ref, I_k_u8);
        ResidualRatio(ii) = rep.channel{1}.residual_ratio(k);
        imwrite(I_k_u8, fullfile(image_out_dir, sprintf('%s_K%d.png', base, k)));
    end
end

%% 4. Build one fixed set of keys/ciphertexts for all K_max groups.
enc_cfg = cfg.encryption;
enc_cfg.num_rounds = num_rounds;

rng(cfg.seed + 200000, 'twister');
master_keys = cell(K_max,1);
param_groups = cell(K_max,1);
cipher_groups = cell(K_max,1);
all_exact = true;

for k = 1:K_max
    param_groups{k} = concat_factors(rep.channel{1}.groups{k});
    master_keys{k} = make_group_key(num_rounds, cfg.encryption.a_max);
    [cipher_groups{k}, ~] = encrypt_group(param_groups{k}, enc_cfg, master_keys{k});
    recovered = decrypt_group(cipher_groups{k}, master_keys{k}, enc_cfg);
    exact = isequal(recovered, param_groups{k});
    all_exact = all_exact && exact;
    if ~exact
        error('exp02:DecryptMismatch', ...
            'Bit-exact recovery failed at group %d.', k);
    end
end

fprintf('Bit-exact recovery for all %d groups: %d\n', K_max, all_exact);

%% 5. Encryption/decryption runtime versus K.
EncTotalMean_ms = zeros(num_K,1);
EncTotalStd_ms = zeros(num_K,1);
DecTotalMean_ms = zeros(num_K,1);
DecTotalStd_ms = zeros(num_K,1);
EncPerGroupMean_ms = zeros(num_K,1);
DecPerGroupMean_ms = zeros(num_K,1);
EncThroughput_MBps = zeros(num_K,1);
DecThroughput_MBps = zeros(num_K,1);

[warm_cipher, ~] = encrypt_group(param_groups{1}, enc_cfg, master_keys{1});
warm_rec = decrypt_group(warm_cipher, master_keys{1}, enc_cfg); %#ok<NASGU>

for i = 1:num_K
    K = K_values(i);
    enc_times = zeros(runtime_repeats,1);
    dec_times = zeros(runtime_repeats,1);

    for t = 1:runtime_repeats
        tic;
        for k = 1:K
            encrypt_group(param_groups{k}, enc_cfg, master_keys{k});
        end
        enc_times(t) = toc;

        tic;
        for k = 1:K
            decrypt_group(cipher_groups{k}, master_keys{k}, enc_cfg);
        end
        dec_times(t) = toc;
    end

    EncTotalMean_ms(i) = 1000 * mean(enc_times);
    EncTotalStd_ms(i) = 1000 * std(enc_times,0);
    DecTotalMean_ms(i) = 1000 * mean(dec_times);
    DecTotalStd_ms(i) = 1000 * std(dec_times,0);
    EncPerGroupMean_ms(i) = EncTotalMean_ms(i) / K;
    DecPerGroupMean_ms(i) = DecTotalMean_ms(i) / K;

    total_MB = serialized_bytes(i) / 1e6;
    EncThroughput_MBps(i) = total_MB / (EncTotalMean_ms(i)/1000);
    DecThroughput_MBps(i) = total_MB / (DecTotalMean_ms(i)/1000);

    fprintf('K=%3d | rate=%6.2f%% | PSNR=%8.4f dB | SSIM=%.6f | Enc=%8.3f ms | Dec=%8.3f ms\n', ...
        K, parameter_rate_pct(i), PSNR_KPD(i), SSIM_KPD(i), ...
        EncTotalMean_ms(i), DecTotalMean_ms(i));
end

%% 6. Marginal quality gains and runtime linearity.
DeltaPSNR_dB = [NaN; diff(PSNR_KPD)];
DeltaSSIM = [NaN; diff(SSIM_KPD)];
DeltaK = [NaN; diff(K_values(:))];
PSNRGainPer25Terms_dB = DeltaPSNR_dB ./ DeltaK * 25;
SSIMGainPer25Terms = DeltaSSIM ./ DeltaK * 25;

[p_enc, enc_r2] = linear_fit(K_values(:), EncTotalMean_ms);
[p_dec, dec_r2] = linear_fit(K_values(:), DecTotalMean_ms);
fit_table = table( ...
    ["Encryption"; "Decryption"], ...
    [p_enc(1); p_dec(1)], [p_enc(2); p_dec(2)], [enc_r2; dec_r2], ...
    'VariableNames', {'Process','Slope_ms_per_group','Intercept_ms','R_squared'});

%% 7. Save paper-ready summary.
summary = table( ...
    K_values(:), parameter_rate_pct, repmat(params_per_group,num_K,1), ...
    repmat(bytes_per_group,num_K,1), serialized_bytes, serialized_kib, ...
    PSNR_KPD, SSIM_KPD, ResidualRatio, ...
    DeltaPSNR_dB, DeltaSSIM, PSNRGainPer25Terms_dB, SSIMGainPer25Terms, ...
    EncTotalMean_ms, EncTotalStd_ms, DecTotalMean_ms, DecTotalStd_ms, ...
    EncPerGroupMean_ms, DecPerGroupMean_ms, EncThroughput_MBps, DecThroughput_MBps, ...
    repmat(all_exact,num_K,1), ...
    'VariableNames', {'K','ParameterRatePct','ParametersPerGroup', ...
    'BytesPerGroup','SerializedBytes','SerializedKiB', ...
    'PSNR_KPD','SSIM_KPD','ResidualRatio', ...
    'DeltaPSNR_dB','DeltaSSIM','PSNRGainPer25Terms_dB','SSIMGainPer25Terms', ...
    'EncTotalMean_ms','EncTotalStd_ms','DecTotalMean_ms','DecTotalStd_ms', ...
    'EncPerGroupMean_ms','DecPerGroupMean_ms','EncThroughput_MBps','DecThroughput_MBps', ...
    'AllParametersBitExact'});

if exist(cfg.results.tables, 'dir') ~= 7, mkdir(cfg.results.tables); end
summary_file = fullfile(cfg.results.tables, 'exp02_k_sensitivity_summary.csv');
fit_file = fullfile(cfg.results.tables, 'exp02_k_sensitivity_runtime_fit.csv');
writetable(summary, summary_file);
writetable(fit_table, fit_file);

%% 8. Save reproducibility artifact.
raw_dir = fullfile(cfg.results.raw, 'exp02_k_sensitivity');
if exist(raw_dir, 'dir') ~= 7, mkdir(raw_dir); end
artifact_file = fullfile(raw_dir, 'exp02_k_sensitivity.mat');
save(artifact_file, 'summary', 'fit_table', 'K_values', 'num_rounds', ...
    'runtime_repeats', 'meta', 'n', 'cache_file', 'cfg', 'all_exact', '-v7.3');

%% 9. Publication-oriented diagnostic figure.
if exist(cfg.results.figures, 'dir') ~= 7, mkdir(cfg.results.figures); end
fig = figure('Color','w','Units','pixels','Position',[100 100 1450 470]);
tiledlayout(fig,1,3,'TileSpacing','compact','Padding','compact');

nexttile;
plot(K_values, PSNR_KPD, '-o', 'LineWidth', 1.6, 'MarkerSize', 6);
hold on; xline(100, '--', 'K=100', 'LabelVerticalAlignment','bottom');
grid on; box on;
xlabel('Number of KPD terms, K'); ylabel('PSNR (dB)');
title('(a) Reconstruction quality: PSNR');

nexttile;
plot(K_values, SSIM_KPD, '-o', 'LineWidth', 1.6, 'MarkerSize', 6);
hold on; xline(100, '--', 'K=100', 'LabelVerticalAlignment','bottom');
grid on; box on;
xlabel('Number of KPD terms, K'); ylabel('SSIM');
title('(b) Reconstruction quality: SSIM');

nexttile;
errorbar(K_values, EncTotalMean_ms, EncTotalStd_ms, '-o', ...
    'LineWidth', 1.4, 'MarkerSize', 6);
hold on;
errorbar(K_values, DecTotalMean_ms, DecTotalStd_ms, '--s', ...
    'LineWidth', 1.4, 'MarkerSize', 6);
xline(100, '--', 'K=100', 'LabelVerticalAlignment','bottom');
grid on; box on;
xlabel('Number of KPD terms, K'); ylabel('Total time (ms)');
title(sprintf('(c) Encryption/decryption cost (R=%d)', num_rounds));
legend({'Encryption','Decryption'}, 'Location','northwest');

set(findall(fig,'-property','FontName'),'FontName','Times New Roman');
set(findall(fig,'-property','FontSize'),'FontSize',11);
fig_pdf = fullfile(cfg.results.figures, 'exp02_k_sensitivity.pdf');
fig_png = fullfile(cfg.results.figures, 'exp02_k_sensitivity.png');
save_figure_compat(fig, fig_pdf, fig_png);

fprintf('\n=== exp02 complete ===\n');
fprintf('Summary table : %s\n', summary_file);
fprintf('Runtime fit   : %s\n', fit_file);
fprintf('Raw artifact  : %s\n', artifact_file);
fprintf('Figure        : %s\n', fig_png);
fprintf('Runtime linear fit: encryption slope %.4f ms/group (R^2=%.6f); decryption slope %.4f ms/group (R^2=%.6f).\n', ...
    p_enc(1), enc_r2, p_dec(1), dec_r2);
end

function [rep, cache_file, created] = load_or_create_representation(I, meta, n, K_required, cfg)
[~, base, ~] = fileparts(meta.filename);
pattern = fullfile(cfg.representation.cache_dir, sprintf('%s_K*_representation.mat', base));
files = dir(pattern);

best_file = '';
best_K = inf;
for i = 1:numel(files)
    candidate = fullfile(files(i).folder, files(i).name);
    tok = regexp(files(i).name, '_K(\d+)_representation\.mat$', 'tokens', 'once');
    if isempty(tok), continue; end
    K_file = str2double(tok{1});
    if K_file < K_required || K_file >= best_K, continue; end

    try
        D = load(candidate, 'rep');
        validate_representation(D.rep, meta, n, K_required);
        best_file = candidate;
        best_K = K_file;
    catch
    end
end

if ~isempty(best_file)
    D = load(best_file, 'rep');
    rep = D.rep;
    cache_file = best_file;
    created = false;
    return;
end

rep_cfg = cfg.representation;
rep_cfg.K_max = K_required;
rep = clsa_decompose_image(I, n, rep_cfg, cfg.seed, meta);
if rep.channel{1}.K < K_required
    warning('exp02:EarlyStop', ...
        'CLSA stopped at K=%d before requested K=%d.', rep.channel{1}.K, K_required);
end
cache_name = sprintf('%s_K%d_representation.mat', base, rep.channel{1}.K);
cache_file = save_representation_cache(rep, cfg.representation.cache_dir, cache_name);
created = true;
end

function validate_representation(rep, meta, n, K_required)
if ~isfield(rep,'channels') || rep.channels ~= 1
    error('exp02:CacheChannels', 'Cached representation must be grayscale.');
end
if ~isequal(double(rep.image_size(:).'), [meta.height meta.width])
    error('exp02:CacheImageSize', 'Cached representation image size mismatch.');
end
if ~isequal(double(rep.partition(:).'), double(n(:).'))
    error('exp02:CachePartition', 'Cached representation partition mismatch.');
end
if rep.channel{1}.K < K_required
    error('exp02:CacheK', 'Cached representation does not contain enough groups.');
end
end

function [p, r2] = linear_fit(x, y)
x = double(x(:));
y = double(y(:));
p = polyfit(x, y, 1);
yhat = polyval(p, x);
ss_res = sum((y-yhat).^2);
ss_tot = sum((y-mean(y)).^2);
if ss_tot == 0
    r2 = 1;
else
    r2 = 1 - ss_res/ss_tot;
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
