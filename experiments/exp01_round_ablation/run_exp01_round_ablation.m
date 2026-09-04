function summary = run_exp01_round_ablation(image_file, K, rounds_list, runtime_repeats)
%RUN_EXP01_ROUND_ABLATION Encryption-round ablation for the paper experiments.
%
% The CLSA-KPD representation and master keys are held fixed. The only
% experimental variable is the number of encryption rounds R.

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
if nargin < 2 || isempty(K), K = 100; end
if nargin < 3 || isempty(rounds_list), rounds_list = 1:5; end
if nargin < 4 || isempty(runtime_repeats), runtime_repeats = 5; end

rounds_list = unique(double(rounds_list(:).'), 'stable');
validateattributes(K, {'numeric'}, {'scalar','integer','positive'});
validateattributes(rounds_list, {'numeric'}, {'vector','integer','positive'});
validateattributes(runtime_repeats, {'numeric'}, {'scalar','integer','positive'});

[I, meta] = load_image_record(image_file);
if meta.channels ~= 1
    error('exp01:GrayscaleOnly', 'Exp01 is fixed to one grayscale image so that the round-count effect is isolated.');
end
n = get_partition_for_image(size(I), cfg);

fprintf('=== exp01 round ablation ===\n');
fprintf('Image: %s (%dx%d, %d channel)\n', meta.filename, meta.height, meta.width, meta.channels);
fprintf('Partition: [%s]\n', num2str(n));
fprintf('K: %d\n', K);
fprintf('Rounds: [%s]\n', num2str(rounds_list));
fprintf('Runtime repeats: %d\n', runtime_repeats);

[~, base, ~] = fileparts(meta.filename);
cache_name = sprintf('%s_K%d_representation.mat', base, K);
cache_file = fullfile(cfg.representation.cache_dir, cache_name);

if exist(cache_file, 'file') == 2
    D = load(cache_file, 'rep');
    rep = D.rep;
    fprintf('Representation cache: loaded %s\n', cache_file);
else
    fprintf('Representation cache not found; computing it once...\n');
    rep_cfg = cfg.representation;
    rep_cfg.K_max = K;
    rep = clsa_decompose_image(I, n, rep_cfg, cfg.seed, meta);
    cache_file = save_representation_cache(rep, cfg.representation.cache_dir, cache_name);
    fprintf('Representation cache: created %s\n', cache_file);
end

validate_representation(rep, meta, n, K);
K_real = rep.channel{1}.K;
if K_real < K
    warning('exp01:EarlyStop', 'Representation stopped at K=%d; using all available groups.', K_real);
    K = K_real;
end

param_groups = cell(K, 1);
plain_blocks = cell(K, 1);
for k = 1:K
    param_groups{k} = concat_factors(rep.channel{1}.groups{k});
    [plain_blocks{k}, ~] = serialize_group(param_groups{k});
end
block_shape = size(plain_blocks{1});
block_bytes = numel(plain_blocks{1});
for k = 2:K
    if ~isequal(size(plain_blocks{k}), block_shape)
        error('exp01:BlockShape', 'All groups must have the same serialized block shape.');
    end
end

max_rounds = max(rounds_list);
rng(cfg.seed + 200000, 'twister');
master_keys = cell(K, 1);
for k = 1:K
    master_keys{k} = make_group_key(max_rounds, cfg.encryption.a_max);
end

num_R = numel(rounds_list);
EntropyPooled = zeros(num_R,1);
CorrH = zeros(num_R,1); CorrV = zeros(num_R,1); CorrD = zeros(num_R,1);
NPCRMean = zeros(num_R,1); NPCRStd = zeros(num_R,1); NPCRMin = zeros(num_R,1); NPCRMax = zeros(num_R,1);
UACIMean = zeros(num_R,1); UACIStd = zeros(num_R,1); UACIMin = zeros(num_R,1); UACIMax = zeros(num_R,1);
EncTotalMean_ms = zeros(num_R,1); EncTotalStd_ms = zeros(num_R,1);
DecTotalMean_ms = zeros(num_R,1); DecTotalStd_ms = zeros(num_R,1);
EncPerGroupMean_ms = zeros(num_R,1); DecPerGroupMean_ms = zeros(num_R,1);
all_group_tables = cell(num_R,1);

[NPCRCritical, UACILow, UACIHigh] = random_cipher_thresholds(block_bytes, 0.05);

for ir = 1:num_R
    Rounds = rounds_list(ir);
    fprintf('\n--- R = %d ---\n', Rounds);
    enc_cfg = cfg.encryption;
    enc_cfg.num_rounds = Rounds;

    cipher_groups = cell(K,1);
    npcr_vals = zeros(K,1); uaci_vals = zeros(K,1); entropy_group = zeros(K,1);

    for k = 1:K
        key = key_for_rounds(master_keys{k}, Rounds);
        [cipher, ~] = encrypt_group(param_groups{k}, enc_cfg, key);
        cipher_groups{k} = cipher;
        entropy_group(k) = entropy_uint8(cipher.bytes);

        perturbed_block = plain_blocks{k};
        perturbed_block(1) = bitxor(perturbed_block(1), uint8(1));
        [~, serialization] = serialize_group(param_groups{k});
        perturbed_param = deserialize_group(perturbed_block, serialization);
        [cipher_perturbed, ~] = encrypt_group(perturbed_param, enc_cfg, key);
        [npcr_vals(k), uaci_vals(k)] = npcr_uaci(cipher.bytes, cipher_perturbed.bytes);

        recovered = decrypt_group(cipher, key, enc_cfg);
        if ~isequal(recovered, param_groups{k})
            error('exp01:DecryptMismatch', 'Bit-exact recovery failed for R=%d, group=%d.', Rounds, k);
        end
    end

    pool = zeros(K * block_bytes, 1, 'uint8');
    ptr = 1; cipher_blocks = cell(K,1);
    for k = 1:K
        b = uint8(cipher_groups{k}.bytes);
        cipher_blocks{k} = b;
        pool(ptr:ptr+numel(b)-1) = b(:);
        ptr = ptr + numel(b);
    end
    EntropyPooled(ir) = entropy_uint8(pool);
    c = pooled_adjacent_correlation_uint8(cipher_blocks);
    CorrH(ir) = c.horizontal; CorrV(ir) = c.vertical; CorrD(ir) = c.diagonal;

    NPCRMean(ir) = mean(npcr_vals); NPCRStd(ir) = std(npcr_vals,0); NPCRMin(ir) = min(npcr_vals); NPCRMax(ir) = max(npcr_vals);
    UACIMean(ir) = mean(uaci_vals); UACIStd(ir) = std(uaci_vals,0); UACIMin(ir) = min(uaci_vals); UACIMax(ir) = max(uaci_vals);

    key1 = key_for_rounds(master_keys{1}, Rounds);
    [warm_cipher, ~] = encrypt_group(param_groups{1}, enc_cfg, key1);
    decrypt_group(warm_cipher, key1, enc_cfg);

    enc_times = zeros(runtime_repeats,1); dec_times = zeros(runtime_repeats,1);
    for t = 1:runtime_repeats
        tic;
        for k = 1:K
            key = key_for_rounds(master_keys{k}, Rounds);
            encrypt_group(param_groups{k}, enc_cfg, key);
        end
        enc_times(t) = toc;

        tic;
        for k = 1:K
            key = key_for_rounds(master_keys{k}, Rounds);
            decrypt_group(cipher_groups{k}, key, enc_cfg);
        end
        dec_times(t) = toc;
    end

    EncTotalMean_ms(ir) = 1000*mean(enc_times); EncTotalStd_ms(ir) = 1000*std(enc_times,0);
    DecTotalMean_ms(ir) = 1000*mean(dec_times); DecTotalStd_ms(ir) = 1000*std(dec_times,0);
    EncPerGroupMean_ms(ir) = EncTotalMean_ms(ir)/K; DecPerGroupMean_ms(ir) = DecTotalMean_ms(ir)/K;

    group_id=(1:K).'; round_col=repmat(Rounds,K,1);
    all_group_tables{ir}=table(round_col,group_id,entropy_group,npcr_vals,uaci_vals,'VariableNames',{'Round','Group','EntropyPerGroup','NPCR','UACI'});
end

summary = table(rounds_list(:), EntropyPooled, NPCRMean, NPCRStd, NPCRMin, NPCRMax, UACIMean, UACIStd, UACIMin, UACIMax, CorrH, CorrV, CorrD, EncTotalMean_ms, EncTotalStd_ms, DecTotalMean_ms, DecTotalStd_ms, EncPerGroupMean_ms, DecPerGroupMean_ms, repmat(NPCRCritical,num_R,1), repmat(UACILow,num_R,1), repmat(UACIHigh,num_R,1), 'VariableNames', {'Round','EntropyPooled','NPCRMean','NPCRStd','NPCRMin','NPCRMax','UACIMean','UACIStd','UACIMin','UACIMax','CorrH','CorrV','CorrD','EncTotalMean_ms','EncTotalStd_ms','DecTotalMean_ms','DecTotalStd_ms','EncPerGroupMean_ms','DecPerGroupMean_ms','NPCRCritical','UACILow','UACIHigh'});
group_table=vertcat(all_group_tables{:});
if exist(cfg.results.tables,'dir')~=7, mkdir(cfg.results.tables); end
writetable(summary,fullfile(cfg.results.tables,'exp01_round_ablation_summary.csv'));
writetable(group_table,fullfile(cfg.results.tables,'exp01_round_ablation_group_metrics.csv'));
end

function key = key_for_rounds(master_key, rounds)
key=master_key; key.num_rounds=double(rounds);
end

function validate_representation(rep, meta, n, K)
if ~isfield(rep,'channels') || rep.channels~=1, error('exp01:CacheChannels','Cached representation must be grayscale.'); end
if ~isequal(double(rep.image_size(:).'),[meta.height meta.width]), error('exp01:CacheImageSize','Cached representation image size does not match input.'); end
if ~isequal(double(rep.partition(:).'),double(n(:).')), error('exp01:CachePartition','Cached representation partition does not match current configuration.'); end
if rep.channel{1}.K<K, error('exp01:CacheK','Cached representation has only K=%d groups, requested K=%d.',rep.channel{1}.K,K); end
end

function [npcr_crit,uaci_low,uaci_high]=random_cipher_thresholds(H,alpha)
Q=255; z_npcr=-sqrt(2)*erfcinv(2*(1-alpha)); z_uaci=-sqrt(2)*erfcinv(2*(1-alpha/2));
npcr_crit=(Q-z_npcr*sqrt(Q/H))/(Q+1)*100;
mu_u=(Q+2)/(3*Q+3); sigma_u2=(Q+2)*(Q^2+2*Q+3)/(18*(Q+1)^2*Q*H);
uaci_low=(mu_u-z_uaci*sqrt(sigma_u2))*100; uaci_high=(mu_u+z_uaci*sqrt(sigma_u2))*100;
end
