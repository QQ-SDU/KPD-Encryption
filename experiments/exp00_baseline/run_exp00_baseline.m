function summary = run_exp00_baseline(image_file, K_override)
%RUN_EXP00_BASELINE Clean end-to-end baseline for the revised codebase.
%
% Pipeline:
% image -> CLSA-KPD -> group serialization -> group encryption ->
% group decryption -> factor recovery -> KPD reconstruction.
%
% This experiment is an integrity baseline, not a final paper experiment.

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
if nargin < 2 || isempty(K_override)
    K_override = cfg.baseline.K;
end

[I, meta] = load_image_record(image_file);
n = get_partition_for_image(size(I), cfg);

rep_cfg = cfg.representation;
rep_cfg.K_max = K_override;

fprintf('=== exp00 baseline ===\n');
fprintf('Image: %s (%dx%d, %d channel(s))\n', meta.filename, meta.height, meta.width, meta.channels);
fprintf('Partition: [%s]\n', num2str(n));
fprintf('K requested: %d\n', K_override);

rep = clsa_decompose_image(I, n, rep_cfg, cfg.seed, meta);
I_kpd = reconstruct_representation(rep);

rng(cfg.seed + 100000, 'twister');
dec_rep = rep;
secure = struct();
secure.channel = cell(rep.channels, 1);
all_exact = true;

for ch = 1:rep.channels
    K_ch = rep.channel{ch}.K;
    secure.channel{ch}.cipher = cell(K_ch, 1);
    secure.channel{ch}.key = cell(K_ch, 1);

    for k = 1:K_ch
        factors = rep.channel{ch}.groups{k};
        param_vec = concat_factors(factors);

        key = make_group_key(cfg.encryption.num_rounds, cfg.encryption.a_max);
        [cipher, key] = encrypt_group(param_vec, cfg.encryption, key);
        recovered = decrypt_group(cipher, key, cfg.encryption);

        exact = isequal(param_vec, recovered);
        all_exact = all_exact && exact;
        if ~exact
            error('exp00:ParameterMismatch', 'Bit-exact recovery failed at channel %d, group %d.', ch, k);
        end

        dec_rep.channel{ch}.groups{k} = split_factors(recovered, n);
        secure.channel{ch}.cipher{k} = cipher;
        secure.channel{ch}.key{k} = key;
    end
end

I_dec = reconstruct_representation(dec_rep);
recon_equal = isequal(I_kpd, I_dec);
if ~recon_equal
    error('exp00:ReconstructionMismatch', 'Decrypted reconstruction differs from direct KPD reconstruction.');
end

I_u8 = uint8(I);
I_kpd_u8 = clip_image_uint8(I_kpd);
I_dec_u8 = clip_image_uint8(I_dec);

psnr_kpd = image_psnr(I_u8, I_kpd_u8);
ssim_kpd = image_ssim(I_u8, I_kpd_u8);
psnr_dec = image_psnr(I_u8, I_dec_u8);
ssim_dec = image_ssim(I_u8, I_dec_u8);

out_dir = fullfile(cfg.results.raw, 'exp00_baseline');
if exist(out_dir, 'dir') ~= 7
    mkdir(out_dir);
end
[~, base, ~] = fileparts(meta.filename);

imwrite(I_u8, fullfile(out_dir, [base, '_original.png']));
imwrite(I_kpd_u8, fullfile(out_dir, [base, '_kpd.png']));
imwrite(I_dec_u8, fullfile(out_dir, [base, '_decrypted.png']));

cache_name = sprintf('%s_K%d_representation.mat', base, rep.channel{1}.K);
cache_file = save_representation_cache(rep, cfg.representation.cache_dir, cache_name);

artifact_file = fullfile(out_dir, sprintf('%s_K%d_baseline.mat', base, rep.channel{1}.K));
save(artifact_file, 'rep', 'secure', 'dec_rep', 'meta', 'cfg', '-v7.3');

summary = table(string(meta.filename), meta.height, meta.width, meta.channels, ...
    string(mat2str(n)), K_override, rep.channel{1}.K, all_exact, recon_equal, ...
    psnr_kpd, ssim_kpd, psnr_dec, ssim_dec, string(cache_file), ...
    'VariableNames', {'Image','Height','Width','Channels','Partition', ...
    'KRequested','KReal','AllParametersBitExact','ReconstructionExactlyEqual', ...
    'PSNR_KPD','SSIM_KPD','PSNR_Decrypted','SSIM_Decrypted','RepresentationCache'});

summary_file = fullfile(cfg.results.tables, 'exp00_baseline_summary.csv');
if exist(cfg.results.tables, 'dir') ~= 7
    mkdir(cfg.results.tables);
end
writetable(summary, summary_file);

fprintf('Bit-exact parameter recovery: %d\n', all_exact);
fprintf('KPD/decrypted reconstruction identical: %d\n', recon_equal);
fprintf('PSNR: %.4f dB | SSIM: %.6f\n', psnr_dec, ssim_dec);
fprintf('Summary: %s\n', summary_file);
end
