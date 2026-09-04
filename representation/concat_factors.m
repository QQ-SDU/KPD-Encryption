function param_vec = concat_factors(factors)
%CONCAT_FACTORS Concatenate one KPD term's factor vectors.

param_vec = [];
for i = 1:numel(factors)
    param_vec = [param_vec; double(factors{i}(:))]; %#ok<AGROW>
end
end
