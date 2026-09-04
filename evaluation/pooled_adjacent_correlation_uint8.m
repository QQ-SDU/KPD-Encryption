function metrics = pooled_adjacent_correlation_uint8(blocks)
%POOLED_ADJACENT_CORRELATION_UINT8 Aggregate adjacent-byte correlations.
%
% blocks may be a cell array of uint8 matrices or one uint8 matrix.
% Neighbor pairs are formed only within each block; no artificial pair is
% created across two independently encrypted KPD groups.

if ~iscell(blocks)
    blocks = {blocks};
end

h1 = []; h2 = [];
v1 = []; v2 = [];
d1 = []; d2 = [];

for k = 1:numel(blocks)
    A = double(uint8(blocks{k}));
    [M, N] = size(A);

    if N > 1
        X = A(:,1:end-1); Y = A(:,2:end);
        h1 = [h1; X(:)]; %#ok<AGROW>
        h2 = [h2; Y(:)]; %#ok<AGROW>
    end
    if M > 1
        X = A(1:end-1,:); Y = A(2:end,:);
        v1 = [v1; X(:)]; %#ok<AGROW>
        v2 = [v2; Y(:)]; %#ok<AGROW>
    end
    if M > 1 && N > 1
        X = A(1:end-1,1:end-1); Y = A(2:end,2:end);
        d1 = [d1; X(:)]; %#ok<AGROW>
        d2 = [d2; Y(:)]; %#ok<AGROW>
    end
end

metrics.horizontal = corr_pair(h1, h2);
metrics.vertical   = corr_pair(v1, v2);
metrics.diagonal   = corr_pair(d1, d2);
end

function r = corr_pair(a, b)
a = double(a(:));
b = double(b(:));
if numel(a) < 2 || numel(a) ~= numel(b)
    r = NaN;
    return;
end

a = a - mean(a);
b = b - mean(b);
den = sqrt(sum(a.^2) * sum(b.^2));
if den == 0
    r = NaN;
else
    r = sum(a .* b) / den;
end
end
