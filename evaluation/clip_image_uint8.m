function U = clip_image_uint8(A)
%CLIP_IMAGE_UINT8 Clip a reconstructed image to [0,255] and convert to uint8.

A = double(A);
A(~isfinite(A)) = 0;
A = min(max(A, 0), 255);
U = uint8(round(A));
end
