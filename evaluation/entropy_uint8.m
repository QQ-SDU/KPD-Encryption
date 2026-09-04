function H = entropy_uint8(A)
%ENTROPY_UINT8 Shannon entropy of one uint8 byte pool.

A = uint8(A);
counts = accumarray(double(A(:)) + 1, 1, [256, 1]);
p = double(counts) / sum(counts);
p = p(p > 0);
H = -sum(p .* log2(p));
end
