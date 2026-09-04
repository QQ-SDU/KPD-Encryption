function factors = split_factors(param_vec, n)
%SPLIT_FACTORS Split a concatenated parameter vector by KPD dimensions.

param_vec = double(param_vec(:));
n = double(n(:).');

if numel(param_vec) ~= sum(n)
    error('split_factors:Length', 'Parameter length must equal sum(n).');
end

factors = cell(1, numel(n));
ptr = 1;
for i = 1:numel(n)
    factors{i} = param_vec(ptr:ptr+n(i)-1);
    ptr = ptr + n(i);
end
end
