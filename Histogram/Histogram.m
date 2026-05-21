%% histogram_three_stage_analysis.m
% Histogram analysis for three stages:
% 1) Original image
% 2) Plain KPD parameter byte matrices
% 3) Encrypted KPD parameter matrices

clear; clc; close all;

%% ================= Load data =================
load('encrypted_params.mat', ...
    'cipher_data', 'key_data', 'v', 'img_size');

K = numel(cipher_data);
fprintf('Loaded %d KPD parameter groups.\n', K);

%% ================= Stage 1: Original image =================
% v{1} is assumed to be the original vectorized image.
if iscell(v)
    ori_vec = v{1};
else
    ori_vec = v;
end

ori_img = reshape(ori_vec, 256, 256);
ori_img = uint8(min(max(round(ori_img), 0), 255));

%% ================= Stage 2 and Stage 3 =================
total_bytes = prod(double(img_size)) * K;

plain_values  = zeros(total_bytes, 1, 'uint8');
cipher_values = zeros(total_bytes, 1, 'uint8');

plain_blocks  = cell(K, 1);
cipher_blocks = cell(K, 1);

pos = 1;

for k = 1:K
    fprintf('Processing KPD block %d / %d\n', k, K);

    key = key_data{k};

    % Recover original KPD parameter vector.
    % This is only used to obtain the plaintext KPD parameter byte matrix.
    param_vec = decrypt_params(cipher_data{k}, key, img_size);

    % Plain KPD parameter byte matrix
    B_plain = param_to_byte_block(param_vec, key, img_size);

    % Encrypted KPD parameter byte matrix
    B_cipher = reshape(uint8(cipher_data{k}), double(img_size));

    plain_blocks{k}  = B_plain;
    cipher_blocks{k} = B_cipher;

    len = numel(B_plain);

    plain_values(pos:pos+len-1)  = B_plain(:);
    cipher_values(pos:pos+len-1) = B_cipher(:);

    pos = pos + len;
end

ori_values = ori_img(:);

%% ================= Histogram calculation =================
gray_levels = 0:255;
edges = 0:256;

[count_ori, ~]    = histcounts(double(ori_values), edges);
[count_plain, ~]  = histcounts(double(plain_values), edges);
[count_cipher, ~] = histcounts(double(cipher_values), edges);

prob_ori    = count_ori    / sum(count_ori);
prob_plain  = count_plain  / sum(count_plain);
prob_cipher = count_cipher / sum(count_cipher);

%% ================= Metrics =================
entropy_ori    = entropy_from_prob(prob_ori);
entropy_plain  = entropy_from_prob(prob_plain);
entropy_cipher = entropy_from_prob(prob_cipher);

hist_var_ori    = var(prob_ori, 1);
hist_var_plain  = var(prob_plain, 1);
hist_var_cipher = var(prob_cipher, 1);

T_metrics = table( ...
    [entropy_ori; entropy_plain; entropy_cipher], ...
    [hist_var_ori; hist_var_plain; hist_var_cipher], ...
    'VariableNames', {'Entropy', 'NormalizedHistogramVariance'}, ...
    'RowNames', {'Original image', 'KPD parameter matrices', 'Encrypted parameter matrices'} ...
);

disp('===== Histogram analysis metrics =====');
disp(T_metrics);

writetable(T_metrics, 'Histogram_ThreeStage_Metrics.csv', ...
    'WriteRowNames', true);

T_hist = table( ...
    gray_levels(:), ...
    prob_ori(:), ...
    prob_plain(:), ...
    prob_cipher(:), ...
    'VariableNames', {'GrayLevel', 'Original', 'KPD_Params', 'Encrypted'} ...
);

writetable(T_hist, 'Histogram_ThreeStage_Probabilities.csv');

%% ================= Build mosaics for visualization =================
plain_mosaic  = make_block_mosaic(plain_blocks, img_size);
cipher_mosaic = make_block_mosaic(cipher_blocks, img_size);

%% ================= Figure 1: Visual comparison =================
figure('Color','w','Position',[100 100 1200 360]);

subplot(1,3,1);
imshow(ori_img);
title('Original image', ...
    'FontName','Times New Roman', 'FontSize', 13);

subplot(1,3,2);
imshow(plain_mosaic);
title('KPD parameter byte matrices', ...
    'FontName','Times New Roman', 'FontSize', 13);

subplot(1,3,3);
imshow(cipher_mosaic);
title('Encrypted parameter matrices', ...
    'FontName','Times New Roman', 'FontSize', 13);

exportgraphics(gcf, 'Fig_Histogram_ThreeStage_Visual.png', ...
    'Resolution', 300);
exportgraphics(gcf, 'Fig_Histogram_ThreeStage_Visual.pdf', ...
    'ContentType', 'image', 'Resolution', 300);

%% ================= Figure 2: Histogram comparison =================
figure('Color','w','Position',[100 100 1200 420]);

max_y = max([prob_ori(:); prob_plain(:); prob_cipher(:)]) * 1.08;

subplot(1,3,1);
bar(gray_levels, prob_ori, 1);
xlim([0 255]);
ylim([0 max_y]);
grid on;
xlabel('Gray/byte value', 'FontName','Times New Roman');
ylabel('Probability', 'FontName','Times New Roman');
title(sprintf('Original image\nEntropy = %.4f', entropy_ori), ...
    'FontName','Times New Roman', 'FontSize', 12);
set(gca, 'FontName','Times New Roman', 'FontSize', 11);

subplot(1,3,2);
bar(gray_levels, prob_plain, 1);
xlim([0 255]);
ylim([0 max_y]);
grid on;
xlabel('Byte value', 'FontName','Times New Roman');
ylabel('Probability', 'FontName','Times New Roman');
title(sprintf('KPD parameter matrices\nEntropy = %.4f', entropy_plain), ...
    'FontName','Times New Roman', 'FontSize', 12);
set(gca, 'FontName','Times New Roman', 'FontSize', 11);

subplot(1,3,3);
bar(gray_levels, prob_cipher, 1);
xlim([0 255]);
ylim([0 max_y]);
grid on;
xlabel('Byte value', 'FontName','Times New Roman');
ylabel('Probability', 'FontName','Times New Roman');
title(sprintf('Encrypted matrices\nEntropy = %.4f', entropy_cipher), ...
    'FontName','Times New Roman', 'FontSize', 12);
set(gca, 'FontName','Times New Roman', 'FontSize', 11);

sgtitle('Histogram comparison of three stages', ...
    'FontName','Times New Roman', 'FontSize', 15);

exportgraphics(gcf, 'Fig_Histogram_ThreeStage.png', ...
    'Resolution', 300);
exportgraphics(gcf, 'Fig_Histogram_ThreeStage.pdf', ...
    'ContentType', 'image', 'Resolution', 300);

%% ================= Figure 3: Overlay histogram =================
figure('Color','w','Position',[100 100 850 500]);

plot(gray_levels, prob_ori, 'LineWidth', 1.4); hold on;
plot(gray_levels, prob_plain, 'LineWidth', 1.4);
plot(gray_levels, prob_cipher, 'LineWidth', 1.4);

grid on;
xlim([0 255]);

xlabel('Gray/byte value', ...
    'FontName','Times New Roman', 'FontSize', 13);
ylabel('Probability', ...
    'FontName','Times New Roman', 'FontSize', 13);

legend({'Original image', 'KPD parameter matrices', 'Encrypted parameter matrices'}, ...
    'Location','northeast', ...
    'FontName','Times New Roman', ...
    'FontSize', 11);

title('Normalized histogram curves of three stages', ...
    'FontName','Times New Roman', 'FontSize', 14);

set(gca, 'FontName','Times New Roman', 'FontSize', 12);

exportgraphics(gcf, 'Fig_Histogram_ThreeStage_Overlay.png', ...
    'Resolution', 300);
exportgraphics(gcf, 'Fig_Histogram_ThreeStage_Overlay.pdf', ...
    'ContentType', 'image', 'Resolution', 300);

fprintf('\nHistogram analysis finished. Figures and CSV files have been saved.\n');

%% ========================================================================
%% Local functions
%% ========================================================================

function B = param_to_byte_block(param_vec, key, img_size)
    bytes = typecast(param_vec(:)', 'uint8');

    if isfield(key, 'byte_len')
        bytes = bytes(1:key.byte_len);
    end

    total_bytes = prod(double(img_size));

    if numel(bytes) < total_bytes
        bytes = [bytes, zeros(1, total_bytes - numel(bytes), 'uint8')];
    elseif numel(bytes) > total_bytes
        error('The byte stream is longer than the target byte matrix.');
    end

    B = reshape(bytes, double(img_size));
end

function mosaic = make_block_mosaic(blocks, img_size)
    K = numel(blocks);

    block_h = double(img_size(1));
    block_w = double(img_size(2));

    tile_cols = ceil(sqrt(K));
    tile_rows = ceil(K / tile_cols);

    mosaic = zeros(tile_rows * block_h, tile_cols * block_w, 'uint8');

    for k = 1:K
        block = uint8(blocks{k});

        row_id = floor((k-1) / tile_cols) + 1;
        col_id = mod(k-1, tile_cols) + 1;

        r1 = (row_id-1) * block_h + 1;
        r2 = row_id * block_h;
        c1 = (col_id-1) * block_w + 1;
        c2 = col_id * block_w;

        mosaic(r1:r2, c1:c2) = block;
    end
end

function H = entropy_from_prob(p)
    p = p(:);
    p = p(p > 0);
    H = -sum(p .* log2(p));
end