function p = image_psnr(A, B)
%IMAGE_PSNR PSNR for image arrays on the 0-255 scale.

A = double(A);
B = double(B);
if ~isequal(size(A), size(B))
    error('image_psnr:Size', 'Images must have identical sizes.');
end
mse = mean((A(:) - B(:)).^2);
if mse == 0
    p = Inf;
else
    p = 10 * log10(255^2 / mse);
end
end
