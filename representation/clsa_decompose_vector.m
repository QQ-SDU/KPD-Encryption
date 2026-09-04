function channel_rep = clsa_decompose_vector(V, n, opts)
%CLSA_DECOMPOSE_VECTOR Sequential CLSA-KPD decomposition of one image channel.

if nargin < 3
    opts = struct();
end
opts = apply_defaults(opts);

V = double(V(:));
n = double(n(:).');
if prod(n) ~= numel(V)
    error('clsa_decompose_vector:Partition', 'prod(n) must equal numel(V).');
end

residual = V;
V_norm = norm(V);
if V_norm == 0
    V_norm = 1;
end

K_max = opts.K_max;
groups = cell(K_max, 1);
residual_norm = zeros(K_max, 1);
residual_ratio = zeros(K_max, 1);
inner_iterations = zeros(K_max, 1);

K_real = K_max;
for k = 1:K_max
    factors = cell(1, numel(n));
    for j = 1:numel(n)
        factors{j} = opts.init_scale * rand(n(j), 1);
    end

    for inner = 1:opts.inner_max_iter
        prev_term = kron_product(factors{:});
        prev_term = prev_term(:);

        for j = 1:numel(n)
            factors{j} = clsa_update_factor(n, j, residual, factors);
        end

        new_term = kron_product(factors{:});
        new_term = new_term(:);

        if norm(prev_term - new_term) < opts.inner_tol
            break;
        end
    end

    current_term = kron_product(factors{:});
    current_term = current_term(:);
    residual = residual - current_term;

    groups{k} = factors;
    residual_norm(k) = norm(residual);
    residual_ratio(k) = residual_norm(k) / V_norm;
    inner_iterations(k) = inner;

    if residual_norm(k) < opts.residual_abs_tol
        K_real = k;
        break;
    end
end

channel_rep.groups = groups(1:K_real);
channel_rep.K = K_real;
channel_rep.partition = n;
channel_rep.residual_norm = residual_norm(1:K_real);
channel_rep.residual_ratio = residual_ratio(1:K_real);
channel_rep.inner_iterations = inner_iterations(1:K_real);
end

function opts = apply_defaults(opts)
defaults.K_max = 100;
defaults.init_scale = 6;
defaults.inner_tol = 0.1;
defaults.inner_max_iter = 200;
defaults.residual_abs_tol = 1e-4;
fields = fieldnames(defaults);
for i = 1:numel(fields)
    f = fields{i};
    if ~isfield(opts, f) || isempty(opts.(f))
        opts.(f) = defaults.(f);
    end
end
end
