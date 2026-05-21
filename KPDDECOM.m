%% run_kpd_encrypt_psnr_cr_compare.m
% KPD decomposition + parameter encryption/decryption + PSNR comparison
% for CR = 0.25, 0.5, 0.75.
%
% Put this script in the same folder as:
% encrypt_params.m, decrypt_params.m, permute_2D.m, inverse_permute_2D.m,
% diffuse_2D.m, inverse_diffuse_2D.m, lscm_generate_matrices.m
%
% Put the test image in the same folder and set img_path below.

clear; clc; close all;

%% ===================== User settings =====================
img_path = 'image1.bmp';     % Change this to your image name
target_size = [256, 256];        % Image size used in the paper
n = [64, 32, 32];                % KPD dimension partition
CR_list = [0.25, 0.50, 0.75];

rounds = 4;                      % 2D-LSCM encryption rounds
byte_img_size = [32, 32];        % 128 double values x 8 bytes = 1024 bytes
max_als_iter = 50;               % CLSA inner iteration number
als_tol = 1e-5;                  % CLSA stopping tolerance

rng(2026);                       % For reproducibility

%% ===================== Read image =====================
img = imread(img_path);

if size(img, 3) == 3
    img = rgb2gray(img);
end

img = imresize(img, target_size);
img = uint8(img);
V = double(img(:));

N_img = numel(V);
N_param_per_term = sum(n);

fprintf('Image: %s\n', img_path);
fprintf('Image size: %d x %d\n', target_size(1), target_size(2));
fprintf('KPD partition: [%d, %d, %d]\n', n(1), n(2), n(3));
fprintf('Parameters per KPD term: %d\n\n', N_param_per_term);

%% ===================== Main loop =====================
num_cr = numel(CR_list);

K_list = zeros(num_cr, 1);
actual_CR = zeros(num_cr, 1);
psnr_kpd = zeros(num_cr, 1);
ssim_kpd = zeros(num_cr, 1);
psnr_dec = zeros(num_cr, 1);
ssim_dec = zeros(num_cr, 1);
enc_time = zeros(num_cr, 1);
dec_time = zeros(num_cr, 1);

recon_imgs = cell(num_cr, 1);

for idx = 1:num_cr

    CR = CR_list(idx);

    % Number of KPD terms under the target compression ratio.
    K = round(CR * N_img / N_param_per_term);
    K_list(idx) = K;
    actual_CR(idx) = K * N_param_per_term / N_img;

    fprintf('====================================================\n');
    fprintf('Target CR = %.2f, K = %d, Actual CR = %.4f\n', ...
        CR, K, actual_CR(idx));
    fprintf('====================================================\n');

    residual = V;
    BigArray = cell(K, 1);

    cipher_data = cell(K, 1);
    key_data = cell(K, 1);

    %% ========== KPD decomposition and encryption ==========
    t_enc_all = tic;

    for k = 1:K

        % CLSA-based rank-one Kronecker approximation of current residual.
        [x1, x2, x3] = clsa_one_term(residual, n, max_als_iter, als_tol);

        BigArray{k} = {x1, x2, x3};

        current_term = kron3(x1, x2, x3);
        residual = residual - current_term;

        % Parameter vector of one KPD group.
        param_vec = [x1; x2; x3];

        % Generate independent group key.
        key.x0 = rand();
        key.y0 = rand();
        key.theta = rand();

        key.rounds = rounds;
        key.P = rounds;
        key.D = rounds;
        key.a = uint32(randi([1, 2^25 - 1], 1, rounds));

        key.param_len = numel(param_vec);
        key.byte_len = numel(typecast(param_vec(:)', 'uint8'));

        % Encrypt one KPD parameter group.
        cipher_data{k} = encrypt_params(param_vec, key, byte_img_size);
        key_data{k} = key;

        if mod(k, 20) == 0 || k == 1 || k == K
            fprintf('CR %.2f: term %d / %d completed\n', CR, k, K);
        end
    end

    enc_time(idx) = toc(t_enc_all);

    %% ========== Direct KPD reconstruction before encryption ==========
    V_kpd = zeros(N_img, 1);

    for k = 1:K
        x1 = BigArray{k}{1};
        x2 = BigArray{k}{2};
        x3 = BigArray{k}{3};
        V_kpd = V_kpd + kron3(x1, x2, x3);
    end

    img_kpd = vector_to_uint8_image(V_kpd, target_size);

    psnr_kpd(idx) = calc_psnr(img_kpd, img);
    ssim_kpd(idx) = ssim(img_kpd, img);

    %% ========== Decryption and reconstruction ==========
    t_dec_all = tic;

    V_dec = zeros(N_img, 1);

    for k = 1:K
        key = key_data{k};

        param_dec = decrypt_params(cipher_data{k}, key, byte_img_size);

        x1 = param_dec(1:n(1));
        x2 = param_dec(n(1)+1 : n(1)+n(2));
        x3 = param_dec(n(1)+n(2)+1 : n(1)+n(2)+n(3));

        V_dec = V_dec + kron3(x1, x2, x3);
    end

    dec_time(idx) = toc(t_dec_all);

    img_dec = vector_to_uint8_image(V_dec, target_size);
    recon_imgs{idx} = img_dec;

    psnr_dec(idx) = calc_psnr(img_dec, img);
    ssim_dec(idx) = ssim(img_dec, img);

    fprintf('CR %.2f finished:\n', CR);
    fprintf('  KPD reconstruction:       PSNR = %.4f dB, SSIM = %.4f\n', ...
        psnr_kpd(idx), ssim_kpd(idx));
    fprintf('  After encrypt/decrypt:    PSNR = %.4f dB, SSIM = %.4f\n', ...
        psnr_dec(idx), ssim_dec(idx));
    fprintf('  Encryption time: %.4f s, Decryption time: %.4f s\n\n', ...
        enc_time(idx), dec_time(idx));
end

%% ===================== Show result table =====================
result_table = table( ...
    CR_list(:), K_list, actual_CR, ...
    psnr_kpd, ssim_kpd, psnr_dec, ssim_dec, enc_time, dec_time, ...
    'VariableNames', { ...
    'Target_CR', 'K_terms', 'Actual_CR', ...
    'PSNR_KPD', 'SSIM_KPD', 'PSNR_After_Dec', 'SSIM_After_Dec', ...
    'Encryption_Time_s', 'Decryption_Time_s'});

disp(result_table);

writetable(result_table, 'kpd_encrypt_decrypt_psnr_cr_results.csv');

%% ===================== Print LaTeX row =====================
fprintf('\nLaTeX table row for Proposed method:\n');
fprintf('Proposed & %.4f & %.4f & %.4f \\\\\n', ...
    psnr_dec(1), psnr_dec(2), psnr_dec(3));

%% ===================== Visualization =====================
figure('Color', 'w', 'Position', [100, 100, 1000, 300]);

subplot(1, 4, 1);
imshow(img);
title('Original');

for idx = 1:num_cr
    subplot(1, 4, idx + 1);
    imshow(recon_imgs{idx});
    title(sprintf('CR=%.2f, PSNR=%.2f dB', ...
        CR_list(idx), psnr_dec(idx)));
end

exportgraphics(gcf, 'kpd_encrypt_decrypt_cr_comparison.png', 'Resolution', 300);

fprintf('\nResults saved:\n');
fprintf('  kpd_encrypt_decrypt_psnr_cr_results.csv\n');
fprintf('  kpd_encrypt_decrypt_cr_comparison.png\n');

%% ========================================================================
%% Local functions
%% ========================================================================

function [x1, x2, x3] = clsa_one_term(R, n, max_iter, tol)
%CLSA_ONE_TERM One rank-one Kronecker approximation:
% R ≈ x1 \otimes x2 \otimes x3.
%
% The vector order is consistent with kron(x1, kron(x2, x3)).

    n1 = n(1);
    n2 = n(2);
    n3 = n(3);

    % Random initialization.
    x1 = rand(n1, 1);
    x2 = rand(n2, 1);
    x3 = rand(n3, 1);

    % Avoid too small initial scale.
    x1 = x1 / norm(x1);
    x2 = x2 / norm(x2);
    x3 = x3 / norm(x3);

    prev_term = zeros(numel(R), 1);

    Rt = reshape(R, [n3, n2, n1]);

    for iter = 1:max_iter

        % Update x1.
        denom = (norm(x2)^2) * (norm(x3)^2) + eps;
        tmp = Rt .* reshape(x3, [n3, 1, 1]) .* reshape(x2, [1, n2, 1]);
        x1 = squeeze(sum(sum(tmp, 1), 2)) / denom;
        x1 = x1(:);

        % Update x2.
        denom = (norm(x1)^2) * (norm(x3)^2) + eps;
        tmp = Rt .* reshape(x3, [n3, 1, 1]) .* reshape(x1, [1, 1, n1]);
        x2 = squeeze(sum(sum(tmp, 1), 3)) / denom;
        x2 = x2(:);

        % Update x3.
        denom = (norm(x1)^2) * (norm(x2)^2) + eps;
        tmp = Rt .* reshape(x2, [1, n2, 1]) .* reshape(x1, [1, 1, n1]);
        x3 = squeeze(sum(sum(tmp, 2), 3)) / denom;
        x3 = x3(:);

        current_term = kron3(x1, x2, x3);

        rel_change = norm(current_term - prev_term) / (norm(prev_term) + eps);

        if rel_change < tol
            break;
        end

        prev_term = current_term;
    end
end

function y = kron3(x1, x2, x3)
%KRON3 Compute x1 \otimes x2 \otimes x3.
    y = kron(x1, kron(x2, x3));
    y = y(:);
end

function img_uint8 = vector_to_uint8_image(v, img_size)
%VECTOR_TO_UINT8_IMAGE Reshape vector and clip to [0,255].
    img_rec = reshape(v, img_size);
    img_rec(img_rec < 0) = 0;
    img_rec(img_rec > 255) = 255;
    img_uint8 = uint8(round(img_rec));
end

function val = calc_psnr(A, B)
%CALC_PSNR Compute PSNR for uint8 images.
    A = double(A);
    B = double(B);
    mse = mean((A(:) - B(:)).^2);
    if mse == 0
        val = Inf;
    else
        val = 10 * log10(255^2 / mse);
    end
end