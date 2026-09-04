function z = clsa_update_factor(n, s, V, X)
%CLSA_UPDATE_FACTOR Efficient ALS/CLSA update for an arbitrary KPD order.
%
% Solves the least-squares update of x_s in
%   V \approx x_1 \otimes ... \otimes x_s \otimes ... \otimes x_d
% without explicitly constructing the large Kronecker design matrix.
%
% This is algebraically equivalent to the original opt.mlx update
%   z = (N' * V) / M,
% where N contains an identity matrix in mode s and M is the product of
% squared norms of the remaining factors.

n = double(n(:).');
d = numel(n);
V = double(V(:));

if numel(X) ~= d
    error('clsa_update_factor:FactorCount', 'numel(X) must equal numel(n).');
end
if s < 1 || s > d || s ~= floor(s)
    error('clsa_update_factor:Mode', 's must be an integer from 1 to numel(n).');
end
if numel(V) ~= prod(n)
    error('clsa_update_factor:Size', 'numel(V) must equal prod(n).');
end

for i = 1:d
    X{i} = double(X{i}(:));
    if numel(X{i}) ~= n(i)
        error('clsa_update_factor:FactorSize', 'Factor %d has the wrong length.', i);
    end
end

denom = 1;
for i = 1:d
    if i ~= s
        denom = denom * (X{i}' * X{i});
    end
end

if ~isfinite(denom) || denom <= eps
    error('clsa_update_factor:ZeroNorm', 'The ALS denominator is too small or non-finite.');
end

if s < d
    q_after = X{s+1};
    for i = s+2:d
        q_after = kron(q_after, X{i});
    end
else
    q_after = 1;
end

if s > 1
    q_before = X{1};
    for i = 2:s-1
        q_before = kron(q_before, X{i});
    end
else
    q_before = 1;
end

after_len = prod(n(s+1:end));
if isempty(after_len), after_len = 1; end
before_len = prod(n(1:s-1));
if isempty(before_len), before_len = 1; end

T = reshape(V, after_len, n(s), before_len);
A = reshape(permute(T, [1, 3, 2]), after_len * before_len, n(s));
q = kron(q_before, q_after);

z = (A' * q(:)) / denom;
z = z(:);
end
