%% decrypt_reconstruct.m
clear; clc;

load('encrypted_params.mat', 'cipher_data', 'key_data', 'n', 'v', 'img_size', 'P_rounds', 'D_rounds');
original_img = reshape(v{1}, 256, 256);

fprintf('开始解密并重建...\n');
p_accum = zeros(256*256, 1);

for i = 1:length(key_data)
    key = key_data{i};
    % 解密
    param_vec = decrypt_params(cipher_data{i}, key, img_size);
    
    % 拆分
    x1 = param_vec(1:n(1));
    x2 = param_vec(n(1)+1 : n(1)+n(2));
    x3 = param_vec(n(1)+n(2)+1 : end);
    
    term = kronn(x1, x2, x3);
    p_accum = p_accum + term;
end

img_recon = reshape(p_accum, 256, 256);
img_recon(img_recon<0) = 0;
img_recon(img_recon>255) = 255;
img_recon_uint8 = uint8(img_recon);

psnr_val = psnr(img_recon_uint8, uint8(original_img));
ssim_val = ssim(img_recon_uint8, uint8(original_img));
fprintf('重建完成：PSNR = %.2f dB, SSIM = %.4f\n', psnr_val, ssim_val);

figure;
subplot(1,2,1); imshow(uint8(original_img)); title('原始图像');
subplot(1,2,2); imshow(img_recon_uint8); title(sprintf('解密重建 (PSNR %.2f dB)', psnr_val));