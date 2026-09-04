function s = image_ssim(A, B)
%IMAGE_SSIM SSIM with a toolbox implementation when available, otherwise fallback.

A = clip_uint8(A);
B = clip_uint8(B);

if exist('ssim', 'file') == 2
    try
        s = ssim(B, A);
        return;
    catch
    end
end

if ndims(A) == 3
    vals = zeros(size(A,3), 1);
    for c = 1:size(A,3)
        vals(c) = global_ssim(double(A(:,:,c)), double(B(:,:,c)));
    end
    s = mean(vals);
else
    s = global_ssim(double(A), double(B));
end
end

function U = clip_uint8(A)
A = double(A);
A(~isfinite(A)) = 0;
A = min(max(A, 0), 255);
U = uint8(round(A));
end

function s = global_ssim(A, B)
a = A(:); b = B(:);
mu_a = mean(a); mu_b = mean(b);
var_a = mean((a-mu_a).^2); var_b = mean((b-mu_b).^2);
cov_ab = mean((a-mu_a).*(b-mu_b));
C1 = (0.01*255)^2; C2 = (0.03*255)^2;
s = ((2*mu_a*mu_b + C1) * (2*cov_ab + C2)) / ...
    ((mu_a^2 + mu_b^2 + C1) * (var_a + var_b + C2));
end
