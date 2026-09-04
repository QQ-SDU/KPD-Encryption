function cache_file = save_representation_cache(rep, cache_dir, cache_name)
%SAVE_REPRESENTATION_CACHE Save factors/metadata only; do not save full residual vectors.

if exist(cache_dir, 'dir') ~= 7
    mkdir(cache_dir);
end
if nargin < 3 || isempty(cache_name)
    if isfield(rep, 'source') && isfield(rep.source, 'filename')
        [~, base, ~] = fileparts(rep.source.filename);
    else
        base = 'representation';
    end
    cache_name = sprintf('%s_K%d.mat', base, rep.channel{1}.K);
end

cache_file = fullfile(cache_dir, cache_name);
save(cache_file, 'rep', '-v7.3');
end
