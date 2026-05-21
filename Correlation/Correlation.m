%% correlation_original_kpd_encrypted.m
% Correlation analysis for three stages:
% 1) Original image
% 2) Plain KPD parameter byte matrices
% 3) Encrypted KPD parameter byte matrices

clear; clc; close all;

%% ========== Load encrypted KPD data ==========
load('encrypted_params.mat', ...
    'cipher_data', 'key_data', 'n', 'v', 'img_size');

K = numel(cipher_data);
fprintf('Loaded %d KPD parameter groups.\n', K);

%% ========== Stage 1: Original image ==========
% v{1} is the original vectorized image used before KPD decomposition.
ori_img = reshape(v{1}, 256, 256);
ori_img = uint8(min(max(round(ori_img), 0), 255));

%% ========== Stage 2 and Stage 3: KPD parameter matrices ==========
plain_blocks = cell(K, 1);
cipher_blocks = cell(K, 1);

for k = 1:K
    key = key_data{k};

    % Recover the original KPD parameter vector.
    % This is only used to obtain the plaintext KPD parameter byte matrix,
    % not to reconstruct the image.
    param_vec = decrypt_params(cipher_data{k}, key, img_size);

    % Plain KPD parameter byte matrix
    plain_blocks{k} = param_to_byte_block(param_vec, key, img_size);

    % Encrypted KPD parameter byte matrix
    cipher_blocks{k} = reshape(uint8(cipher_data{k}), img_size);
end

%% ========== Compute adjacent correlation ==========
directions = {'Horizontal', 'Vertical', 'Diagonal'};
stage_names = {'Original image', ...
               'KPD parameter matrices', ...
               'Encrypted parameter matrices'};
stage_short = {'Original', 'KPD params', 'Encrypted'};

corr_global = zeros(3, 3);
corr_mean   = zeros(3, 3);
corr_std    = zeros(3, 3);

% Stage 1: original image
[corr_global(1,1), corr_global(1,2), corr_global(1,3)] = adjacent_corr(ori_img);
corr_mean(1,:) = corr_global(1,:);
corr_std(1,:) = [0, 0, 0];

% Stage 2: plaintext KPD parameter byte matrices
[corr_global(2,:), corr_mean(2,:), corr_std(2,:)] = ...
    block_correlation_statistics(plain_blocks);

% Stage 3: encrypted KPD parameter byte matrices
[corr_global(3,:), corr_mean(3,:), corr_std(3,:)] = ...
    block_correlation_statistics(cipher_blocks);

%% ========== Display and save results ==========
T_global = array2table(corr_global, ...
    'VariableNames', directions, ...
    'RowNames', stage_short);

T_mean = array2table(corr_mean, ...
    'VariableNames', directions, ...
    'RowNames', stage_short);

T_std = array2table(corr_std, ...
    'VariableNames', directions, ...
    'RowNames', stage_short);

disp('===== Global adjacent correlation =====');
disp(T_global);

disp('===== Block-wise mean adjacent correlation =====');
disp(T_mean);

disp('===== Block-wise std adjacent correlation =====');
disp(T_std);

writetable(T_global, 'Correlation_Global_Original_KPD_Encrypted.csv', ...
    'WriteRowNames', true);
writetable(T_mean, 'Correlation_BlockMean_Original_KPD_Encrypted.csv', ...
    'WriteRowNames', true);
writetable(T_std, 'Correlation_BlockStd_Original_KPD_Encrypted.csv', ...
    'WriteRowNames', true);

%% ========== Build mosaics for visualization ==========
plain_mosaic  = make_block_mosaic(plain_blocks, img_size);
cipher_mosaic = make_block_mosaic(cipher_blocks, img_size);

%% ========== Figure 1: Visual comparison ==========
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

exportgraphics(gcf, 'Fig_Correlation_ThreeStage_Visual.png', ...
    'Resolution', 600);
exportgraphics(gcf, 'Fig_Correlation_ThreeStage_Visual.pdf', ...
    'ContentType', 'vector');

%% ========== Figure 2: Scatter plots ==========
figure('Color','w','Position',[80 80 1250 950]);

plot_id = 1;

% Original image scatter
for d = 1:3
    subplot(3,3,plot_id);
    plot_scatter_single(ori_img, directions{d}, ...
        sprintf('Original: %s', directions{d}));
    plot_id = plot_id + 1;
end

% Plain KPD parameter matrices scatter
for d = 1:3
    subplot(3,3,plot_id);
    plot_scatter_blocks(plain_blocks, directions{d}, ...
        sprintf('KPD params: %s', directions{d}));
    plot_id = plot_id + 1;
end

% Encrypted parameter matrices scatter
for d = 1:3
    subplot(3,3,plot_id);
    plot_scatter_blocks(cipher_blocks, directions{d}, ...
        sprintf('Encrypted: %s', directions{d}));
    plot_id = plot_id + 1;
end

sgtitle('Adjacent correlation of original image, KPD parameters, and encrypted parameters', ...
    'FontName','Times New Roman', 'FontSize', 16);

exportgraphics(gcf, 'Fig_Correlation_ThreeStage_Scatter.png', ...
    'Resolution', 600);
exportgraphics(gcf, 'Fig_Correlation_ThreeStage_Scatter.pdf', ...
    'ContentType', 'vector');

%% ========== Figure 3: Bar chart ==========
figure('Color','w','Position',[100 100 880 500]);

bar(corr_global);
grid on;

set(gca, ...
    'XTickLabel', stage_short, ...
    'FontName','Times New Roman', ...
    'FontSize', 12);

ylabel('Correlation coefficient', ...
    'FontName','Times New Roman', ...
    'FontSize', 13);

legend(directions, ...
    'Location','northoutside', ...
    'Orientation','horizontal', ...
    'FontName','Times New Roman', ...
    'FontSize', 11);

title('Adjacent correlation comparison of three stages', ...
    'FontName','Times New Roman', ...
    'FontSize', 14);

ylim([-1 1]);

exportgraphics(gcf, 'Fig_Correlation_ThreeStage_Bar.png', ...
    'Resolution', 600);
exportgraphics(gcf, 'Fig_Correlation_ThreeStage_Bar.pdf', ...
    'ContentType', 'vector');

%% ========== Figure 4: Heatmap ==========
figure('Color','w','Position',[100 100 760 420]);

imagesc(abs(corr_global));
colorbar;
colormap parula;

set(gca, ...
    'XTick', 1:3, ...
    'XTickLabel', directions, ...
    'YTick', 1:3, ...
    'YTickLabel', stage_short, ...
    'FontName','Times New Roman', ...
    'FontSize', 12);

title('Absolute adjacent correlation of three stages', ...
    'FontName','Times New Roman', ...
    'FontSize', 14);

for i = 1:3
    for j = 1:3
        text(j, i, sprintf('%.4f', abs(corr_global(i,j))), ...
            'HorizontalAlignment','center', ...
            'FontName','Times New Roman', ...
            'FontSize', 11, ...
            'Color','w');
    end
end

exportgraphics(gcf, 'Fig_Correlation_ThreeStage_Heatmap.png', ...
    'Resolution', 600);
exportgraphics(gcf, 'Fig_Correlation_ThreeStage_Heatmap.pdf', ...
    'ContentType', 'vector');

fprintf('\nAll correlation results and figures have been saved.\n');

%% ========================================================================
%% Local functions
%% ========================================================================

function B = param_to_byte_block(param_vec, key, img_size)
    bytes = typecast(param_vec(:)', 'uint8');

    if isfield(key, 'byte_len')
        bytes = bytes(1:key.byte_len);
    end

    total_bytes = prod(img_size);

    if numel(bytes) < total_bytes
        bytes = [bytes, zeros(1, total_bytes - numel(bytes), 'uint8')];
    elseif numel(bytes) > total_bytes
        error('The byte stream is longer than the target byte matrix.');
    end

    B = reshape(bytes, img_size);
end

function mosaic = make_block_mosaic(blocks, img_size)
    K = numel(blocks);

    block_h = img_size(1);
    block_w = img_size(2);

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

function [corr_global, corr_mean, corr_std] = block_correlation_statistics(blocks)
    K = numel(blocks);

    corr_each = zeros(K, 3);

    all_x_h = []; all_y_h = [];
    all_x_v = []; all_y_v = [];
    all_x_d = []; all_y_d = [];

    for k = 1:K
        B = blocks{k};

        [ch, cv, cd] = adjacent_corr(B);
        corr_each(k,:) = [ch, cv, cd];

        [xh, yh] = adjacent_pairs(B, 'Horizontal');
        [xv, yv] = adjacent_pairs(B, 'Vertical');
        [xd, yd] = adjacent_pairs(B, 'Diagonal');

        all_x_h = [all_x_h; xh(:)];
        all_y_h = [all_y_h; yh(:)];

        all_x_v = [all_x_v; xv(:)];
        all_y_v = [all_y_v; yv(:)];

        all_x_d = [all_x_d; xd(:)];
        all_y_d = [all_y_d; yd(:)];
    end

    corr_global = [ ...
        corr_value(all_x_h, all_y_h), ...
        corr_value(all_x_v, all_y_v), ...
        corr_value(all_x_d, all_y_d)];

    corr_mean = mean(corr_each, 1);
    corr_std  = std(corr_each, 0, 1);
end

function [ch, cv, cd] = adjacent_corr(B)
    [xh, yh] = adjacent_pairs(B, 'Horizontal');
    [xv, yv] = adjacent_pairs(B, 'Vertical');
    [xd, yd] = adjacent_pairs(B, 'Diagonal');

    ch = corr_value(xh, yh);
    cv = corr_value(xv, yv);
    cd = corr_value(xd, yd);
end

function [x, y] = adjacent_pairs(B, direction)
    B = double(B);

    switch lower(direction)
        case {'horizontal', 'h'}
            x = B(:, 1:end-1);
            y = B(:, 2:end);

        case {'vertical', 'v'}
            x = B(1:end-1, :);
            y = B(2:end, :);

        case {'diagonal', 'd'}
            x = B(1:end-1, 1:end-1);
            y = B(2:end, 2:end);

        otherwise
            error('Unknown direction.');
    end

    x = x(:);
    y = y(:);
end

function c = corr_value(x, y)
    x = double(x(:));
    y = double(y(:));

    if numel(x) < 2 || std(x) == 0 || std(y) == 0
        c = 0;
        return;
    end

    R = corrcoef(x, y);
    c = R(1,2);
end

function plot_scatter_single(B, direction, ttl)
    [x, y] = adjacent_pairs(B, direction);
    c = corr_value(x, y);

    max_points = 6000;
    if numel(x) > max_points
        rng(1);
        idx = randperm(numel(x), max_points);
        x = x(idx);
        y = y(idx);
    end

    scatter(x, y, 6, 'filled', ...
        'MarkerFaceAlpha', 0.35, ...
        'MarkerEdgeAlpha', 0.35);

    xlim([0 255]);
    ylim([0 255]);
    axis square;
    grid on;

    xlabel('Current value', 'FontName','Times New Roman', 'FontSize', 10);
    ylabel('Adjacent value', 'FontName','Times New Roman', 'FontSize', 10);

    title(sprintf('%s, r = %.4f', ttl, c), ...
        'FontName','Times New Roman', ...
        'FontSize', 11);
end

function plot_scatter_blocks(blocks, direction, ttl)
    all_x = [];
    all_y = [];

    for k = 1:numel(blocks)
        [x, y] = adjacent_pairs(blocks{k}, direction);
        all_x = [all_x; x(:)];
        all_y = [all_y; y(:)];
    end

    c = corr_value(all_x, all_y);

    max_points = 6000;
    if numel(all_x) > max_points
        rng(1);
        idx = randperm(numel(all_x), max_points);
        all_x = all_x(idx);
        all_y = all_y(idx);
    end

    scatter(all_x, all_y, 6, 'filled', ...
        'MarkerFaceAlpha', 0.35, ...
        'MarkerEdgeAlpha', 0.35);

    xlim([0 255]);
    ylim([0 255]);
    axis square;
    grid on;

    xlabel('Current byte value', ...
        'FontName','Times New Roman', ...
        'FontSize', 10);

    ylabel('Adjacent byte value', ...
        'FontName','Times New Roman', ...
        'FontSize', 10);

    title(sprintf('%s, r = %.4f', ttl, c), ...
        'FontName','Times New Roman', ...
        'FontSize', 11);
end