function P = inverse_permute_2d(T, S)
%INVERSE_PERMUTE_2D Exact inverse of permute_2d.

T = uint8(T);
[M, N] = size(T);
if ~isequal(size(S), [M, N])
    error('inverse_permute_2d:Size', 'T and S must have identical sizes.');
end

[~, O] = sort(S, 1);
P = zeros(M, N, 'uint8');
for i = 1:M
    pos = sub2ind([M, N], O(i,:), 1:N);
    t_vals = T(pos);
    s_vals = S(pos);
    [~, v] = sort(s_vals);
    inv_v = zeros(size(v));
    inv_v(v) = 1:numel(v);
    P(pos) = t_vals(inv_v);
end
end
