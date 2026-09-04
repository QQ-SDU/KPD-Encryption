function P_perm = permute_2d(P, S)
%PERMUTE_2D Permutation used in the submitted parameter-domain cipher.

P = uint8(P);
[M, N] = size(P);
if ~isequal(size(S), [M, N])
    error('permute_2d:Size', 'P and S must have identical sizes.');
end

[~, O] = sort(S, 1);
T = zeros(M, N, 'uint8');
for i = 1:M
    pos = sub2ind([M, N], O(i,:), 1:N);
    vals = P(pos);
    s_vals = S(pos);
    [~, v] = sort(s_vals);
    T(pos) = vals(v);
end
P_perm = T;
end
