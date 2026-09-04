function I_rec = reconstruct_representation(rep, K)
%RECONSTRUCT_REPRESENTATION Reconstruct an image from the first K KPD groups.

if nargin < 2 || isempty(K)
    K = inf;
end

h = rep.image_size(1);
w = rep.image_size(2);
c = rep.channels;
I_rec = zeros(h, w, c);

for ch = 1:c
    K_use = min(K, rep.channel{ch}.K);
    accum = zeros(h*w, 1);
    for k = 1:K_use
        factors = rep.channel{ch}.groups{k};
        term = kron_product(factors{:});
        accum = accum + term(:);
    end
    I_rec(:,:,ch) = reshape(accum, h, w);
end

if c == 1
    I_rec = I_rec(:,:,1);
end
end
