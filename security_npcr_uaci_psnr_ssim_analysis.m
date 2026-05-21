%% security_npcr_uaci_psnr_ssim_analysis.m
% Compute NPCR/UACI and PSNR/SSIM for encrypted KPD parameter byte matrices.
% Put this file in the same folder as encrypted_params.mat and the encryption/decryption functions.

clear; clc; close all;

load('encrypted_params.mat', 'cipher_data', 'key_data', 'img_size');

% The paper reports the main security experiment with K = 100 KPD terms.
% If you want to evaluate all saved groups, set K_eval = numel(cipher_data).
K_eval = min(100, numel(cipher_data));
M = double(img_size(1));
N = double(img_size(2));
L = M * N;

npcr_val      = zeros(K_eval, 1);
uaci_val      = zeros(K_eval, 1);
psnr_pc_val   = zeros(K_eval, 1);   % plaintext parameter block B_k vs ciphertext C_k
ssim_pc_val   = zeros(K_eval, 1);
psnr_diff_val = zeros(K_eval, 1);   % ciphertext C_k vs ciphertext C'_k after one-byte change
ssim_diff_val = zeros(K_eval, 1);

for k = 1:K_eval
    key = key_data{k};

    % Ciphertext byte matrix C_k.
    C = reshape(uint8(cipher_data{k}), img_size);

    % Recover the plaintext parameter byte matrix B_k by correct decryption.
    % This avoids requiring the original BigArray variables to be saved.
    param_vec = decrypt_params(cipher_data{k}, key, img_size);
    plain_bytes = typecast(param_vec(:)', 'uint8');
    if isfield(key, 'byte_len')
        plain_bytes = plain_bytes(1:key.byte_len);
    end
    B = reshape(plain_bytes, img_size);

    % Plaintext-ciphertext similarity. A secure block should have low PSNR
    % and SSIM close to 0 between B_k and C_k.
    psnr_pc_val(k) = local_psnr(B, C);
    ssim_pc_val(k) = local_ssim(B, C);

    % Differential test: change only one byte in the plaintext parameter block.
    B2 = B;
    pos = mod((k-1) * 37, L) + 1;       % deterministic and evenly varied position
    B2(pos) = uint8(mod(double(B2(pos)) + 1, 256));

    % Encrypt the modified plaintext byte matrix with the same group key.
    C2 = encrypt_byte_matrix(B2, key);

    % NPCR and UACI between C_k and C'_k.
    npcr_val(k) = sum(C(:) ~= C2(:)) / L * 100;
    uaci_val(k) = mean(abs(double(C(:)) - double(C2(:))) / 255) * 100;

    % Optional ciphertext-ciphertext similarity after one-byte perturbation.
    psnr_diff_val(k) = local_psnr(C, C2);
    ssim_diff_val(k) = local_ssim(C, C2);
end

% Theoretical expectations for two independent 8-bit random matrices.
ideal_npcr = (1 - 1/256) * 100;
ideal_uaci = (257 / (3 * 256)) * 100;     % 33.4635%

% Approximate 95% reference interval for 32x32 blocks. This is useful because
% KPD parameter blocks are much smaller than normal 256x256 test images.
z = 1.96;
p_npcr = 255 / 256;
npcr_lower_95 = (p_npcr - z * sqrt(p_npcr * (1 - p_npcr) / L)) * 100;

mu_uaci = 257 / (3 * 256);
E2_uaci = (256^2 - 1) / (6 * 255^2);
var_uaci = E2_uaci - mu_uaci^2;
uaci_lower_95 = (mu_uaci - z * sqrt(var_uaci / L)) * 100;
uaci_upper_95 = (mu_uaci + z * sqrt(var_uaci / L)) * 100;

metric_name = [
    "NPCR (%)";
    "UACI (%)";
    "PSNR(B_k,C_k) (dB)";
    "SSIM(B_k,C_k)";
    "PSNR(C_k,C'_k) (dB)";
    "SSIM(C_k,C'_k)" ];

mean_val = [mean(npcr_val); mean(uaci_val); mean(psnr_pc_val); mean(ssim_pc_val); mean(psnr_diff_val); mean(ssim_diff_val)];
std_val  = [std(npcr_val);  std(uaci_val);  std(psnr_pc_val);  std(ssim_pc_val);  std(psnr_diff_val);  std(ssim_diff_val)];
min_val  = [min(npcr_val);  min(uaci_val);  min(psnr_pc_val);  min(ssim_pc_val);  min(psnr_diff_val);  min(ssim_diff_val)];
max_val  = [max(npcr_val);  max(uaci_val);  max(psnr_pc_val);  max(ssim_pc_val);  max(psnr_diff_val);  max(ssim_diff_val)];

summary_table = table(metric_name, mean_val, std_val, min_val, max_val, ...
    'VariableNames', {'Metric', 'Mean', 'Std', 'Min', 'Max'});

disp(summary_table);

per_block_table = table((1:K_eval)', npcr_val, uaci_val, psnr_pc_val, ssim_pc_val, ...
    psnr_diff_val, ssim_diff_val, ...
    'VariableNames', {'Block', 'NPCR', 'UACI', 'PSNR_plain_cipher', ...
    'SSIM_plain_cipher', 'PSNR_cipher_diff', 'SSIM_cipher_diff'});

writetable(summary_table, 'security_metrics_summary.csv');
writetable(per_block_table, 'security_metrics_per_block.csv');

% Export a LaTeX-ready table body.
fid = fopen('security_metrics_table_latex.txt', 'w');
fprintf(fid, 'Metric & Mean & Std. & Min & Max \\\\ \n');
fprintf(fid, '\\midrule\n');
for i = 1:height(summary_table)
    fprintf(fid, '%s & %.4f & %.4f & %.4f & %.4f \\\\ \n', ...
        summary_table.Metric(i), summary_table.Mean(i), summary_table.Std(i), ...
        summary_table.Min(i), summary_table.Max(i));
end
fclose(fid);

% Visualization for the paper: one table + this 2x2 figure is enough.
fig = figure('Color', 'w', 'Position', [100, 100, 1050, 760]);
tiledlayout(2, 2, 'Padding', 'compact', 'TileSpacing', 'compact');

nexttile;
plot(1:K_eval, npcr_val, 'o-', 'LineWidth', 1.0, 'MarkerSize', 3); hold on;
yline(ideal_npcr, '--', 'Ideal 99.6094%', 'LabelHorizontalAlignment', 'left');
yline(npcr_lower_95, ':', '95% lower bound', 'LabelHorizontalAlignment', 'left');
grid on; xlabel('KPD parameter block index'); ylabel('NPCR (%)');
title('(a) NPCR after one-byte plaintext change');

nexttile;
plot(1:K_eval, uaci_val, 'o-', 'LineWidth', 1.0, 'MarkerSize', 3); hold on;
yline(ideal_uaci, '--', 'Ideal 33.4635%', 'LabelHorizontalAlignment', 'left');
yline(uaci_lower_95, ':', '95% lower bound', 'LabelHorizontalAlignment', 'left');
yline(uaci_upper_95, ':', '95% upper bound', 'LabelHorizontalAlignment', 'left');
grid on; xlabel('KPD parameter block index'); ylabel('UACI (%)');
title('(b) UACI after one-byte plaintext change');

nexttile;
plot(1:K_eval, psnr_pc_val, 'o-', 'LineWidth', 1.0, 'MarkerSize', 3); hold on;
plot(1:K_eval, psnr_diff_val, 's-', 'LineWidth', 1.0, 'MarkerSize', 3);
grid on; xlabel('KPD parameter block index'); ylabel('PSNR (dB)');
legend('$B_k$ vs. $C_k$', '$C_k$ vs. $C_k''$', 'Interpreter', 'latex', 'Location', 'best');
title('(c) Low PSNR indicates strong dissimilarity');

nexttile;
plot(1:K_eval, ssim_pc_val, 'o-', 'LineWidth', 1.0, 'MarkerSize', 3); hold on;
plot(1:K_eval, ssim_diff_val, 's-', 'LineWidth', 1.0, 'MarkerSize', 3);
yline(0, '--');
grid on; xlabel('KPD parameter block index'); ylabel('SSIM');
legend('$B_k$ vs. $C_k$', '$C_k$ vs. $C_k''$', 'Interpreter', 'latex', 'Location', 'best');
title('(d) Near-zero SSIM indicates weak structural similarity');

exportgraphics(fig, 'Fig_NPCR_UACI_PSNR_SSIM.png', 'Resolution', 600);
savefig(fig, 'Fig_NPCR_UACI_PSNR_SSIM.fig');

fprintf('\nTheoretical reference for %d x %d byte blocks:\n', M, N);
fprintf('Ideal NPCR = %.4f%%, 95%% lower bound = %.4f%%\n', ideal_npcr, npcr_lower_95);
fprintf('Ideal UACI = %.4f%%, 95%% interval = [%.4f%%, %.4f%%]\n', ...
    ideal_uaci, uaci_lower_95, uaci_upper_95);
fprintf('Results saved to security_metrics_summary.csv, security_metrics_per_block.csv, and Fig_NPCR_UACI_PSNR_SSIM.png.\n');

%% Local functions
function C = encrypt_byte_matrix(B, key)
    P = uint8(B);
    [M, N] = size(P);

    x = key.x0;
    y = key.y0;
    theta0 = key.theta;

    if isfield(key, 'rounds')
        rounds = key.rounds;
    elseif isfield(key, 'P')
        rounds = key.P;
    else
        rounds = 4;
    end

    if isfield(key, 'a')
        a = double(key.a(:)');
    else
        a = ones(1, rounds);
    end

    for r = 1:rounds
        theta_r = mod(theta0 * a(r), 1);
        if theta_r <= 0
            theta_r = 2^-52;
        elseif theta_r >= 1
            theta_r = 1 - 2^-52;
        end

        [S, R, x, y] = lscm_generate_matrices(x, y, theta_r, M, N);
        P = permute_2D(P, S);
        P = diffuse_2D(P, R);
    end

    C = P;
end

function val = local_psnr(A, B)
    A = double(A);
    B = double(B);
    mse = mean((A(:) - B(:)).^2);
    if mse == 0
        val = Inf;
    else
        val = 10 * log10(255^2 / mse);
    end
end

function val = local_ssim(A, B)
    % Prefer MATLAB Image Processing Toolbox SSIM. If unavailable, use a
    % global SSIM fallback to keep the script executable.
    try
        val = ssim(uint8(A), uint8(B));
    catch
        A = double(A);
        B = double(B);
        L = 255;
        C1 = (0.01 * L)^2;
        C2 = (0.03 * L)^2;
        mux = mean(A(:));
        muy = mean(B(:));
        vx = var(A(:));
        vy = var(B(:));
        covxy = mean((A(:) - mux) .* (B(:) - muy));
        val = ((2 * mux * muy + C1) * (2 * covxy + C2)) / ...
              ((mux^2 + muy^2 + C1) * (vx + vy + C2));
    end
end
