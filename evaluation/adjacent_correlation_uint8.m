function metrics = adjacent_correlation_uint8(A)
%ADJACENT_CORRELATION_UINT8 Horizontal/vertical/diagonal byte correlations.

A = double(uint8(A));
metrics.horizontal = corr_pair(A(:,1:end-1), A(:,2:end));
metrics.vertical = corr_pair(A(1:end-1,:), A(2:end,:));
metrics.diagonal = corr_pair(A(1:end-1,1:end-1), A(2:end,2:end));
end

function r = corr_pair(A, B)
a = A(:) - mean(A(:));
b = B(:) - mean(B(:));
den = sqrt(sum(a.^2) * sum(b.^2));
if den == 0
    r = NaN;
else
    r = sum(a .* b) / den;
end
end
