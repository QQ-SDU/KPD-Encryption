function [rep, cache_file, created] = get_or_create_representation_cache(I, meta, n, K_required, cfg)
%GET_OR_CREATE_REPRESENTATION_CACHE Reuse the smallest compatible KPD cache.
%
% This helper centralizes representation-cache reuse across experiments
% experiments. A cache is compatible only when image size, channel count,
% partition, and available number of ordered KPD groups all match.

validateattributes(K_required, {'numeric'}, {'scalar','integer','positive'});

[~, base, ~] = fileparts(meta.filename);
pattern = fullfile(cfg.representation.cache_dir, sprintf('%s_K*_representation.mat', base));
files = dir(pattern);

best_file = '';
best_K = inf;
for i = 1:numel(files)
    candidate = fullfile(files(i).folder, files(i).name);
    tok = regexp(files(i).name, '_K(\d+)_representation\.mat$', 'tokens', 'once');
    if isempty(tok)
        continue;
    end

    K_file = str2double(tok{1});
    if K_file < K_required || K_file >= best_K
        continue;
    end

    try
        D = load(candidate, 'rep');
        validate_cache(D.rep, meta, n, K_required);
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

K_available = min(cellfun(@(c) c.K, rep.channel));
if K_available < K_required
    warning('representation:EarlyStop', ...
        'CLSA stopped at K=%d before requested K=%d.', K_available, K_required);
end

cache_name = sprintf('%s_K%d_representation.mat', base, K_available);
cache_file = save_representation_cache(rep, cfg.representation.cache_dir, cache_name);
created = true;
end

function validate_cache(rep, meta, n, K_required)
if ~isfield(rep, 'channels') || rep.channels ~= meta.channels
    error('representation:CacheChannels', 'Cached channel count mismatch.');
end
if ~isequal(double(rep.image_size(:).'), [meta.height meta.width])
    error('representation:CacheImageSize', 'Cached image size mismatch.');
end
if ~isequal(double(rep.partition(:).'), double(n(:).'))
    error('representation:CachePartition', 'Cached partition mismatch.');
end
for ch = 1:rep.channels
    if rep.channel{ch}.K < K_required
        error('representation:CacheK', 'Cached representation does not contain enough groups.');
    end
end
end
