function I_rec = reconstruct_group_subset(groups, image_size, indices)
%RECONSTRUCT_GROUP_SUBSET Reconstruct one image channel from selected KPD groups.

if nargin < 3 || isempty(indices)
    indices = [];
end

h = image_size(1);
w = image_size(2);
accum = zeros(h*w, 1);

indices = unique(double(indices(:).'), 'sorted');
if any(indices < 1) || any(indices > numel(groups)) || any(indices ~= floor(indices))
    error('reconstruct_group_subset:Indices', 'Group indices are invalid.');
end

for k = indices
    factors = groups{k};
    term = kron_product(factors{:});
    accum = accum + term(:);
end

I_rec = reshape(accum, h, w);
end
