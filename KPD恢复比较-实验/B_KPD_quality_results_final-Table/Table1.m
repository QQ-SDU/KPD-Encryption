function KPDA()
% KPDA
%
% KPD representation quality experiments on USC-SIPI misc folder.
%
% Four groups:
%   1. Grayscale 256 x 256
%   2. Grayscale 512 x 512
%   3. Color     256 x 256
%   4. Color     512 x 512
%
% Settings:
%   256 x 256: n = [64, 32, 32],       K = 10:10:350
%   512 x 512: n = [32, 32, 16, 16],   K = 30:30:1800
%
% Outputs:
%   1. Four PSNR/SSIM curves.
%   2. Table of PSNR, SSIM, and average cumulative decomposition time.
%   3. CSV and MAT files for the quantitative table.

clc; close all;

%% ===================== User settings =====================

cfg.miscDir = fullfile(pwd, 'misc');

cfg.outDir = fullfile(pwd, 'B_KPD_quality_results_final');
if ~exist(cfg.outDir, 'dir')
    mkdir(cfg.outDir);
end

% 256 x 256 groups
cfg.K_list_256 = 10:10:350;
cfg.n_256 = [64, 32, 32];

% 512 x 512 groups
cfg.K_list_512 = 30:30:1800;
cfg.n_512 = [32, 32, 16, 16];

% CLSA sweeps for each extracted KPD term.
% For quick testing: 3-5.
% For formal experiment: 8-15.
cfg.clsaSweeps = 8;

cfg.tol = 1e-7;
cfg.rngSeed = 20260519;

% Expected number of selected images from misc
cfg.expectedTotalImages = 38;

% Sampling-rate labels on the curves
cfg.samplingRatesToMark = [10, 20, 30, 40, 50];

% Sampling rates used for the quantitative table
cfg.tableSamplingRates = [10, 20, 30, 40, 50];

%% ===================== Collect and classify images =====================

miscFiles = collect_image_files(cfg.miscDir);

if isempty(miscFiles)
    error('No image files found in folder: %s', cfg.miscDir);
end

fprintf('Total images found in misc: %d\n', numel(miscFiles));

[fileInfo, groupFiles] = classify_misc_images_by_size_and_type(miscFiles);

fprintf('\nSelected image groups from misc:\n');
fprintf('  Gray  256 x 256: %d\n', numel(groupFiles.gray256));
fprintf('  Gray  512 x 512: %d\n', numel(groupFiles.gray512));
fprintf('  Color 256 x 256: %d\n', numel(groupFiles.color256));
fprintf('  Color 512 x 512: %d\n', numel(groupFiles.color512));

totalSelected = numel(groupFiles.gray256) + numel(groupFiles.gray512) + ...
                numel(groupFiles.color256) + numel(groupFiles.color512);

fprintf('  Total selected:   %d\n\n', totalSelected);

if totalSelected ~= cfg.expectedTotalImages
    warning(['The selected image number is %d, not the expected %d. ', ...
             'Please check image sizes and color types in misc.'], ...
             totalSelected, cfg.expectedTotalImages);
end

save(fullfile(cfg.outDir, 'selected_misc_file_list.mat'), ...
    'fileInfo', 'groupFiles', 'cfg');

%% ===================== Define four experiment groups =====================

groups = struct([]);

groups(1).name       = 'Gray_256';
groups(1).titleName  = 'Grayscale images, 256 \times 256';
groups(1).files      = groupFiles.gray256;
groups(1).targetSize = 256;
groups(1).isColor    = false;
groups(1).n          = cfg.n_256;
groups(1).K_list     = cfg.K_list_256;

groups(2).name       = 'Gray_512';
groups(2).titleName  = 'Grayscale images, 512 \times 512';
groups(2).files      = groupFiles.gray512;
groups(2).targetSize = 512;
groups(2).isColor    = false;
groups(2).n          = cfg.n_512;
groups(2).K_list     = cfg.K_list_512;

groups(3).name       = 'Color_256';
groups(3).titleName  = 'Color images, 256 \times 256';
groups(3).files      = groupFiles.color256;
groups(3).targetSize = 256;
groups(3).isColor    = true;
groups(3).n          = cfg.n_256;
groups(3).K_list     = cfg.K_list_256;

groups(4).name       = 'Color_512';
groups(4).titleName  = 'Color images, 512 \times 512';
groups(4).files      = groupFiles.color512;
groups(4).targetSize = 512;
groups(4).isColor    = true;
groups(4).n          = cfg.n_512;
groups(4).K_list     = cfg.K_list_512;

%% ===================== Run four experiments =====================

results = cell(1, numel(groups));

for g = 1:numel(groups)

    fprintf('\n====================================================\n');
    fprintf('Running group: %s\n', groups(g).name);
    fprintf('Number of images: %d\n', numel(groups(g).files));
    fprintf('Target size: %d x %d\n', groups(g).targetSize, groups(g).targetSize);
    fprintf('KPD dimension: [%s]\n', num2str(groups(g).n));
    fprintf('K list: %d:%d:%d\n', groups(g).K_list(1), ...
        groups(g).K_list(2)-groups(g).K_list(1), groups(g).K_list(end));
    fprintf('====================================================\n');

    if isempty(groups(g).files)
        warning('No images available for group %s. Skipped.', groups(g).name);
        results{g} = [];
        continue;
    end

    res_g = run_one_group(groups(g), cfg);
    results{g} = res_g;

    save(fullfile(cfg.outDir, [groups(g).name, '_results.mat']), ...
        'cfg', 'groups', 'res_g', '-v7.3');

    plot_one_group_curve_academic_no_shadow( ...
        res_g, cfg.outDir, cfg.samplingRatesToMark);
end

save(fullfile(cfg.outDir, 'All_B_KPD_quality_results_final.mat'), ...
    'cfg', 'groups', 'results', 'groupFiles', 'fileInfo', '-v7.3');

%% ===================== Generate quantitative table =====================

tableSummary = build_and_print_kpd_quality_table(results, cfg);

save(fullfile(cfg.outDir, 'Table_KPD_quality_time.mat'), ...
    'tableSummary', '-v7.3');

writetable(tableSummary.csvTable, ...
    fullfile(cfg.outDir, 'Table_KPD_quality_time.csv'));

fprintf('\nAll experiments finished.\n');
fprintf('Results saved in: %s\n', cfg.outDir);

end

%% ========================================================================
%                           Group experiment
% ========================================================================

function result = run_one_group(group, cfg)

K_list = group.K_list;
numK = numel(K_list);
numImgs = numel(group.files);

PSNR_all   = nan(numImgs, numK);
SSIM_all   = nan(numImgs, numK);
RRE_all    = nan(numImgs, numK);
Energy_all = nan(numImgs, numK);

% Cumulative decomposition time at each recorded K point.
TimeK_all  = nan(numImgs, numK);

% Total wall-clock time for each image.
Time_all   = nan(numImgs, 1);

for i = 1:numImgs

    filePath = group.files{i};

    fprintf('[%s] Image %d/%d: %s\n', ...
        group.name, i, numImgs, get_file_name(filePath));

    rng(cfg.rngSeed + i);

    if group.isColor
        I = read_and_preprocess_rgb(filePath, group.targetSize);
        tic;
        metrics = kpd_curve_rgb(I, group.n, K_list, cfg.clsaSweeps, cfg.tol);
        Time_all(i) = toc;
    else
        I = read_and_preprocess_gray(filePath, group.targetSize);
        tic;
        metrics = kpd_curve_gray(I, group.n, K_list, cfg.clsaSweeps, cfg.tol);
        Time_all(i) = toc;
    end

    PSNR_all(i, :)   = metrics.psnr;
    SSIM_all(i, :)   = metrics.ssim;
    RRE_all(i, :)    = metrics.rre;
    Energy_all(i, :) = metrics.energy;
    TimeK_all(i, :)  = metrics.timeK;

    fprintf('    Total time: %.2f s, Time@Kmax: %.2f s, PSNR@Kmax: %.3f dB, SSIM@Kmax: %.4f\n', ...
        Time_all(i), TimeK_all(i,end), PSNR_all(i,end), SSIM_all(i,end));
end

result.name       = group.name;
result.titleName  = group.titleName;
result.files      = group.files;
result.targetSize = group.targetSize;
result.isColor    = group.isColor;
result.n          = group.n;
result.K_list     = K_list;

result.PSNR_all   = PSNR_all;
result.SSIM_all   = SSIM_all;
result.RRE_all    = RRE_all;
result.Energy_all = Energy_all;
result.TimeK_all  = TimeK_all;
result.Time_all   = Time_all;

result.PSNR_mean   = mean(PSNR_all, 1, 'omitnan');
result.PSNR_std    = std(PSNR_all, 0, 1, 'omitnan');

result.SSIM_mean   = mean(SSIM_all, 1, 'omitnan');
result.SSIM_std    = std(SSIM_all, 0, 1, 'omitnan');

result.RRE_mean    = mean(RRE_all, 1, 'omitnan');
result.RRE_std     = std(RRE_all, 0, 1, 'omitnan');

result.Energy_mean = mean(Energy_all, 1, 'omitnan');
result.Energy_std  = std(Energy_all, 0, 1, 'omitnan');

result.TimeK_mean  = mean(TimeK_all, 1, 'omitnan');
result.TimeK_std   = std(TimeK_all, 0, 1, 'omitnan');

H = group.targetSize;
W = group.targetSize;

% Parameter sampling rate:
%   K * sum(n_i) / (H * W)
% For RGB channel-wise KPD, numerator and denominator are both multiplied by 3,
% so the ratio remains the same.
result.parameterRatio = 100 * K_list * sum(group.n) / (H * W);

result.Time_mean = mean(Time_all, 'omitnan');
result.Time_std  = std(Time_all, 0, 'omitnan');

end

%% ========================================================================
%                           KPD quality curves
% ========================================================================

function metrics = kpd_curve_gray(I, n, K_list, clsaSweeps, tol)

[chMetrics, ~] = kpd_curve_one_channel(I, n, K_list, clsaSweeps, tol);

metrics.psnr   = chMetrics.psnr;
metrics.ssim   = chMetrics.ssim;
metrics.rre    = chMetrics.rre;
metrics.energy = chMetrics.energy;
metrics.timeK  = chMetrics.timeK;

end

function metrics = kpd_curve_rgb(Irgb, n, K_list, clsaSweeps, tol)

numK = numel(K_list);

mse_ch   = zeros(3, numK);
sse_ch   = zeros(3, numK);
norm2_ch = zeros(3, 1);
ssim_ch  = zeros(3, numK);
time_ch  = zeros(3, numK);

for c = 1:3
    Ic = Irgb(:,:,c);
    [chMetrics, aux] = kpd_curve_one_channel(Ic, n, K_list, clsaSweeps, tol);

    mse_ch(c,:)   = aux.mse;
    sse_ch(c,:)   = aux.sse;
    norm2_ch(c)   = aux.normV2;
    ssim_ch(c,:)  = chMetrics.ssim;
    time_ch(c,:)  = chMetrics.timeK;
end

mse_rgb = mean(mse_ch, 1);
sse_rgb = sum(sse_ch, 1);
norm2_rgb = sum(norm2_ch);

metrics.psnr = 10 * log10(1 ./ max(mse_rgb, eps));
metrics.ssim = mean(ssim_ch, 1);
metrics.rre = sqrt(sse_rgb ./ max(norm2_rgb, eps));
metrics.energy = 1 - sse_rgb ./ max(norm2_rgb, eps);

% Color decomposition time is the sum of three channel-wise decomposition times.
metrics.timeK = sum(time_ch, 1);

end

function [metrics, aux] = kpd_curve_one_channel(I, n, K_list, clsaSweeps, tol)

I = double(I);
V = I(:);
Vhat = zeros(size(V));
R = V;

Kmax = max(K_list);
numK = numel(K_list);

psnrList   = nan(1, numK);
ssimList   = nan(1, numK);
rreList    = nan(1, numK);
energyList = nan(1, numK);
mseList    = nan(1, numK);
sseList    = nan(1, numK);
timeList   = nan(1, numK);

normV2 = sum(V.^2);
recIdx = 1;

tStart = tic;

for k = 1:Kmax

    [~, term] = clsa_one_term_fast_general(R, n, clsaSweeps, tol);

    Vhat = Vhat + term;
    R = R - term;

    if recIdx <= numK && k == K_list(recIdx)

        Irec = reshape(Vhat, size(I));

        diff = Irec(:) - I(:);
        sse = sum(diff.^2);
        mse = mean(diff.^2);

        mseList(recIdx) = mse;
        sseList(recIdx) = sse;

        psnrList(recIdx) = 10 * log10(1 / max(mse, eps));

        if exist('ssim', 'file')
            ssimList(recIdx) = ssim(Irec, I, 'DynamicRange', 1);
        else
            ssimList(recIdx) = NaN;
        end

        rreList(recIdx) = sqrt(sse / max(normV2, eps));
        energyList(recIdx) = 1 - sse / max(normV2, eps);

        timeList(recIdx) = toc(tStart);

        fprintf('        K = %4d / %4d, PSNR = %.3f dB, SSIM = %.4f, Time = %.2f s\n', ...
            k, Kmax, psnrList(recIdx), ssimList(recIdx), timeList(recIdx));

        recIdx = recIdx + 1;
    end
end

metrics.psnr   = psnrList;
metrics.ssim   = ssimList;
metrics.rre    = rreList;
metrics.energy = energyList;
metrics.timeK  = timeList;

aux.mse = mseList;
aux.sse = sseList;
aux.normV2 = normV2;

end

%% ========================================================================
%                General fast CLSA for one KPD term
% ========================================================================

function [X, term] = clsa_one_term_fast_general(V, n, maxSweeps, tol)

V = V(:);
d = numel(n);

X = cell(1, d);

for s = 1:d
    X{s} = randn(n(s), 1);
    X{s} = X{s} / max(norm(X{s}), eps);
end

lastErr = inf;
normV = max(norm(V), eps);

for it = 1:maxSweeps

    for s = 1:d

        X{s} = fast_update_dfactor(n, s, V, X);

        if norm(X{s}) < eps || any(~isfinite(X{s}))
            X{s} = randn(n(s), 1);
            X{s} = X{s} / max(norm(X{s}), eps);
        end
    end

    X = balance_scaling_general(X);

    if tol > 0

        termNow = kron_all(X);
        errNow = norm(V - termNow) / normV;

        if abs(lastErr - errNow) < tol
            break;
        end

        lastErr = errNow;
    end
end

term = kron_all(X);

end

function z = fast_update_dfactor(n, s, V, X)

d = numel(n);
V = V(:);

denom = 1;

for i = 1:d
    if i ~= s
        xi = X{i}(:);
        denom = denom * (xi' * xi);
    end
end

if denom < eps
    z = zeros(n(s), 1);
    return;
end

% MATLAB kron order:
% x1 ⊗ x2 ⊗ ... ⊗ xd has xd as the fastest varying factor.
T = reshape(V, fliplr(n));

% In reversed dimensions, factor s corresponds to index d-s+1.
idx = d - s + 1;

permOrder = [1:idx-1, idx+1:d, idx];

A = reshape(permute(T, permOrder), [], n(s));

qCell = X;
qCell(s) = [];

q = kron_all(qCell);

z = (A' * q) / denom;
z = z(:);

end

function X = balance_scaling_general(X)

d = numel(X);
norms = zeros(1, d);

for s = 1:d
    norms(s) = norm(X{s});
end

if any(norms < eps) || any(~isfinite(norms))
    return;
end

scale = prod(norms);

for s = 1:d
    X{s} = X{s} / norms(s);
end

X{1} = scale * X{1};

end

function y = kron_all(X)

y = X{1}(:);

for i = 2:numel(X)
    y = kron(y, X{i}(:));
end

y = y(:);

end

%% ========================================================================
%                         Plotting
% ========================================================================

function plot_one_group_curve_academic_no_shadow(result, outDir, samplingRatesToMark)

K = result.K_list;

navy      = [31, 78, 121] / 255;
teal      = [42, 157, 143] / 255;
grayText  = [45, 45, 45] / 255;

fig = figure('Color', 'w', 'Position', [100, 100, 900, 560]);
ax = axes(fig);
hold(ax, 'on');

set(ax, ...
    'FontName', 'Times New Roman', ...
    'FontSize', 13, ...
    'LineWidth', 1.1, ...
    'Box', 'on', ...
    'XColor', grayText, ...
    'GridColor', [0.82, 0.82, 0.82], ...
    'GridAlpha', 0.30);

grid(ax, 'on');

% ---------- Left axis: PSNR ----------
yyaxis left;
hold on;

p1 = plot(K, result.PSNR_mean, '-o', ...
    'Color', navy, ...
    'LineWidth', 2.0, ...
    'MarkerSize', 4.3, ...
    'MarkerFaceColor', 'w', ...
    'MarkerEdgeColor', navy);

ylabel('PSNR (dB)', 'FontName', 'Times New Roman', 'Color', navy);
ax.YAxis(1).Color = navy;

psnrMin = min(result.PSNR_mean, [], 'omitnan');
psnrMax = max(result.PSNR_mean, [], 'omitnan');
psnrPad = 0.08 * max(psnrMax - psnrMin, eps);
ylim([psnrMin - psnrPad, psnrMax + psnrPad]);

yl_psnr = ylim;

% ---------- Right axis: SSIM ----------
yyaxis right;
hold on;

p2 = plot(K, result.SSIM_mean, '-s', ...
    'Color', teal, ...
    'LineWidth', 2.0, ...
    'MarkerSize', 4.3, ...
    'MarkerFaceColor', 'w', ...
    'MarkerEdgeColor', teal);

ylabel('SSIM', 'FontName', 'Times New Roman', 'Color', teal);
ax.YAxis(2).Color = teal;

ssimMin = min(result.SSIM_mean, [], 'omitnan');
ssimMax = max(result.SSIM_mean, [], 'omitnan');
ssimPad = 0.08 * max(ssimMax - ssimMin, eps);
ylim([max(0, ssimMin - ssimPad), min(1, ssimMax + ssimPad)]);

yl_ssim = ylim;

% ---------- Sampling-rate labels only ----------
mark_sampling_rate_points_label_only(result, samplingRatesToMark, grayText, yl_psnr, yl_ssim);

xlabel('Number of KPD terms K', 'FontName', 'Times New Roman');

title(sprintf('%s, n = [%s], N = %d', ...
    result.titleName, num2str(result.n), numel(result.files)), ...
    'FontName', 'Times New Roman', ...
    'FontWeight', 'normal', ...
    'Color', grayText);

legend([p1, p2], {'PSNR', 'SSIM'}, ...
    'Location', 'southeast', ...
    'FontName', 'Times New Roman', ...
    'Box', 'off');

xlim([min(K), max(K)]);

set(fig, 'PaperPositionMode', 'auto');

fileBase = fullfile(outDir, ['Curve_', result.name]);

exportgraphics(fig, [fileBase, '.png'], 'Resolution', 600);
exportgraphics(fig, [fileBase, '.pdf'], 'ContentType', 'vector');

fprintf('    Figure saved: %s.png / .pdf\n', fileBase);

end

function mark_sampling_rate_points_label_only(result, samplingRatesToMark, labelColor, yl_psnr, yl_ssim)

K = result.K_list;
H = result.targetSize;
W = result.targetSize;
paramPerTerm = sum(result.n);

K_exact = samplingRatesToMark / 100 * (H * W) / paramPerTerm;

K_mark = zeros(size(K_exact));
idx_mark = zeros(size(K_exact));

for i = 1:numel(K_exact)
    [~, idx] = min(abs(K - K_exact(i)));
    idx_mark(i) = idx;
    K_mark(i) = K(idx);
end

yyaxis left;
ylim(yl_psnr);
hold on;

psnrVals = result.PSNR_mean(idx_mark);

plot(K_mark, psnrVals, 'v', ...
    'Color', labelColor, ...
    'MarkerFaceColor', 'w', ...
    'MarkerEdgeColor', labelColor, ...
    'MarkerSize', 6.5, ...
    'LineWidth', 1.0, ...
    'HandleVisibility', 'off');

for i = 1:numel(K_mark)
    text(K_mark(i), psnrVals(i), sprintf('  %d%%', samplingRatesToMark(i)), ...
        'FontName', 'Times New Roman', ...
        'FontSize', 10.5, ...
        'Color', labelColor, ...
        'HorizontalAlignment', 'left', ...
        'VerticalAlignment', 'middle', ...
        'HandleVisibility', 'off');
end

yyaxis left;
ylim(yl_psnr);

yyaxis right;
ylim(yl_ssim);

end

%% ========================================================================
%                         Image classification
% ========================================================================

function [fileInfo, groupFiles] = classify_misc_images_by_size_and_type(files)

fileInfo = struct([]);

groupFiles.gray256  = {};
groupFiles.gray512  = {};
groupFiles.color256 = {};
groupFiles.color512 = {};

for i = 1:numel(files)

    filePath = files{i};

    try
        info = imfinfo(filePath);
        width = info.Width;
        height = info.Height;

        isColor = is_color_file(filePath);

        fileInfo(i).path = filePath;
        fileInfo(i).name = get_file_name(filePath);
        fileInfo(i).width = width;
        fileInfo(i).height = height;
        fileInfo(i).isColor = isColor;

        if height == 256 && width == 256
            if isColor
                groupFiles.color256{end+1,1} = filePath; %#ok<AGROW>
            else
                groupFiles.gray256{end+1,1} = filePath; %#ok<AGROW>
            end
        elseif height == 512 && width == 512
            if isColor
                groupFiles.color512{end+1,1} = filePath; %#ok<AGROW>
            else
                groupFiles.gray512{end+1,1} = filePath; %#ok<AGROW>
            end
        end

    catch ME
        warning('Failed to inspect image: %s\nReason: %s', filePath, ME.message);
    end
end

groupFiles.gray256  = sort(groupFiles.gray256);
groupFiles.gray512  = sort(groupFiles.gray512);
groupFiles.color256 = sort(groupFiles.color256);
groupFiles.color512 = sort(groupFiles.color512);

end

function isColor = is_color_file(filePath)

[A, map] = imread(filePath);

if ~isempty(map)
    isColor = any(abs(map(:,1) - map(:,2)) > eps) || ...
              any(abs(map(:,1) - map(:,3)) > eps) || ...
              any(abs(map(:,2) - map(:,3)) > eps);
else
    isColor = ndims(A) == 3 && size(A,3) >= 3;
end

end

%% ========================================================================
%                         Image reading and preprocessing
% ========================================================================

function Igray = read_and_preprocess_gray(filePath, targetSize)

[I, ~] = read_image_any(filePath);

if size(I, 3) == 3
    I = rgb2gray(I);
elseif size(I, 3) > 3
    I = I(:,:,1);
end

Igray = imresize(I, [targetSize, targetSize]);
Igray = min(max(Igray, 0), 1);

end

function Irgb = read_and_preprocess_rgb(filePath, targetSize)

[I, ~] = read_image_any(filePath);

if size(I, 3) == 1
    I = repmat(I, [1, 1, 3]);
elseif size(I, 3) > 3
    I = I(:,:,1:3);
end

Irgb = imresize(I, [targetSize, targetSize]);
Irgb = min(max(Irgb, 0), 1);

end

function [I, isColor] = read_image_any(filePath)

[A, map] = imread(filePath);

if ~isempty(map)
    I = ind2rgb(A, map);
else
    I = im2double(A);
end

if ndims(I) == 2
    isColor = false;
else
    isColor = size(I, 3) >= 3;
end

end

%% ========================================================================
%                              File utilities
% ========================================================================

function files = collect_image_files(folder)

if ~exist(folder, 'dir')
    files = {};
    return;
end

exts = {'*.bmp','*.png','*.jpg','*.jpeg','*.tif','*.tiff','*.ppm','*.pgm'};
files = {};

for i = 1:numel(exts)
    d = dir(fullfile(folder, exts{i}));
    for j = 1:numel(d)
        files{end+1, 1} = fullfile(d(j).folder, d(j).name); %#ok<AGROW>
    end
end

files = sort(files);

end

function name = get_file_name(filePath)

[~, name, ext] = fileparts(filePath);
name = [name, ext];

end

%% ========================================================================
%                 Table generation for PSNR, SSIM and time
% ========================================================================

function tableSummary = build_and_print_kpd_quality_table(results, cfg)

rates = cfg.tableSamplingRates(:);

groupOrder = {'Gray_256', 'Color_256', 'Gray_512', 'Color_512'};
groupLabel = {'Gray256', 'Color256', 'Gray512', 'Color512'};

numRates = numel(rates);
numGroups = numel(groupOrder);

K_used    = nan(numRates, numGroups);
PSNR_val  = nan(numRates, numGroups);
SSIM_val  = nan(numRates, numGroups);
Time_val  = nan(numRates, numGroups);
ActualSR  = nan(numRates, numGroups);

for g = 1:numGroups

    res = get_result_by_name(results, groupOrder{g});

    if isempty(res)
        continue;
    end

    for r = 1:numRates

        targetRate = rates(r);

        [~, idx] = min(abs(res.parameterRatio - targetRate));

        K_used(r,g)   = res.K_list(idx);
        ActualSR(r,g) = res.parameterRatio(idx);
        PSNR_val(r,g) = res.PSNR_mean(idx);
        SSIM_val(r,g) = res.SSIM_mean(idx);
        Time_val(r,g) = res.TimeK_mean(idx);
    end
end

fprintf('\n\n');
fprintf('====================================================================================================================\n');
fprintf('Nearest K values used for the quantitative table\n');
fprintf('Sampling rate is defined as K * sum(n_i) / (H * W).\n');
fprintf('====================================================================================================================\n');
fprintf('%8s | %18s | %18s | %18s | %18s\n', ...
    'Rate', 'Gray256', 'Color256', 'Gray512', 'Color512');
fprintf('--------------------------------------------------------------------------------------------------------------------\n');

for r = 1:numRates
    fprintf('%7.0f%% |', rates(r));
    for g = 1:numGroups
        fprintf(' K=%4.0f (%6.2f%%) |', K_used(r,g), ActualSR(r,g));
    end
    fprintf('\n');
end

fprintf('\n\n');
fprintf('====================================================================================================================\n');
fprintf('KPD representation quality and average cumulative decomposition time\n');
fprintf('Time means the average cumulative decomposition time to the corresponding sampling rate.\n');
fprintf('====================================================================================================================\n');

fprintf('%8s | %26s | %26s | %26s | %26s\n', ...
    'Rate', 'Gray 256x256', 'Color 256x256', 'Gray 512x512', 'Color 512x512');

fprintf('%8s | %8s %8s %8s | %8s %8s %8s | %8s %8s %8s | %8s %8s %8s\n', ...
    '', 'PSNR', 'SSIM', 'Time', ...
    'PSNR', 'SSIM', 'Time', ...
    'PSNR', 'SSIM', 'Time', ...
    'PSNR', 'SSIM', 'Time');

fprintf('--------------------------------------------------------------------------------------------------------------------\n');

for r = 1:numRates

    fprintf('%7.0f%% |', rates(r));

    for g = 1:numGroups
        fprintf(' %8.2f %8.4f %8.2f |', ...
            PSNR_val(r,g), SSIM_val(r,g), Time_val(r,g));
    end

    fprintf('\n');
end

fprintf('====================================================================================================================\n');

fprintf('\nLaTeX table rows:\n');
fprintf('--------------------------------------------------------------------------------------------------------------------\n');

for r = 1:numRates

    fprintf('%d\\%% ', rates(r));

    for g = 1:numGroups
        fprintf('& %.2f & %.4f & %.2f ', ...
            PSNR_val(r,g), SSIM_val(r,g), Time_val(r,g));
    end

    fprintf('\\\\\n');
end

fprintf('--------------------------------------------------------------------------------------------------------------------\n\n');

csvTable = table(rates, ...
    K_used(:,1), ActualSR(:,1), PSNR_val(:,1), SSIM_val(:,1), Time_val(:,1), ...
    K_used(:,2), ActualSR(:,2), PSNR_val(:,2), SSIM_val(:,2), Time_val(:,2), ...
    K_used(:,3), ActualSR(:,3), PSNR_val(:,3), SSIM_val(:,3), Time_val(:,3), ...
    K_used(:,4), ActualSR(:,4), PSNR_val(:,4), SSIM_val(:,4), Time_val(:,4), ...
    'VariableNames', { ...
    'SamplingRate', ...
    'Gray256_K', 'Gray256_ActualRate', 'Gray256_PSNR', 'Gray256_SSIM', 'Gray256_Time', ...
    'Color256_K', 'Color256_ActualRate', 'Color256_PSNR', 'Color256_SSIM', 'Color256_Time', ...
    'Gray512_K', 'Gray512_ActualRate', 'Gray512_PSNR', 'Gray512_SSIM', 'Gray512_Time', ...
    'Color512_K', 'Color512_ActualRate', 'Color512_PSNR', 'Color512_SSIM', 'Color512_Time'});

tableSummary.rates = rates;
tableSummary.groupOrder = groupOrder;
tableSummary.groupLabel = groupLabel;
tableSummary.K_used = K_used;
tableSummary.ActualSamplingRate = ActualSR;
tableSummary.PSNR = PSNR_val;
tableSummary.SSIM = SSIM_val;
tableSummary.Time = Time_val;
tableSummary.csvTable = csvTable;

end

function res = get_result_by_name(results, targetName)

res = [];

for i = 1:numel(results)

    if isempty(results{i})
        continue;
    end

    if strcmp(results{i}.name, targetName)
        res = results{i};
        return;
    end
end

end