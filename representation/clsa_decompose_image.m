function rep = clsa_decompose_image(I, n, rep_cfg, seed, source_meta)
%CLSA_DECOMPOSE_IMAGE Apply CLSA-KPD independently to every image channel.

if nargin < 4 || isempty(seed)
    seed = 1;
end
if nargin < 5
    source_meta = struct();
end

[h, w, c] = size(I);
if ismatrix(I)
    c = 1;
end
if prod(n) ~= h * w
    error('clsa_decompose_image:Partition', 'prod(n) must equal height*width.');
end

rep.version = 'paper-v1';
rep.source = source_meta;
rep.image_size = [h, w];
rep.channels = c;
rep.partition = n;
rep.seed = seed;
rep.settings = rep_cfg;
rep.channel = cell(c, 1);

opts.K_max = rep_cfg.K_max;
opts.init_scale = rep_cfg.init_scale;
opts.inner_tol = rep_cfg.inner_tol;
opts.inner_max_iter = rep_cfg.inner_max_iter;
opts.residual_abs_tol = rep_cfg.residual_abs_tol;

for ch = 1:c
    rng(seed + ch - 1, 'twister');
    channel_data = double(I(:,:,ch));
    rep.channel{ch} = clsa_decompose_vector(channel_data(:), n, opts);
end
end
