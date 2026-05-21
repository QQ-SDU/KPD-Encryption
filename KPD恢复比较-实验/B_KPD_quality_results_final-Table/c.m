function extract_KPD_table_from_subfiles()
% EXTRACT_KPD_TABLE_FROM_SUBFILES
%
% Extract PSNR, SSIM, and average decomposition time from four saved files:
%   Color_256_results.mat
%   Color_512_results.mat
%   Gray_256_results.mat
%   Gray_512_results.mat
%
% It prints:
%   1. Nearest K values for 10%,20%,30%,40%,50%
%   2. PSNR / SSIM / Time table
%   3. LaTeX table rows
%   4. Saves CSV file

clc;

%% ===================== User settings =====================

% Folder containing the four .mat files
resultsDir = pwd;

targetRates = [10, 20, 30, 40, 50];

fileMap = struct();

fileMap(1).name  = 'Gray_256';
fileMap(1).label = 'Gray 256x256';
fileMap(1).file  = 'Gray_256_results.mat';

fileMap(2).name  = 'Color_256';
fileMap(2).label = 'Color 256x256';
fileMap(2).file  = 'Color_256_results.mat';

fileMap(3).name  = 'Gray_512';
fileMap(3).label = 'Gray 512x512';
fileMap(3).file  = 'Gray_512_results.mat';

fileMap(4).name  = 'Color_512';
fileMap(4).label = 'Color 512x512';
fileMap(4).file  = 'Color_512_results.mat';

csvFile = fullfile(resultsDir, 'Table_KPD_quality_time_extracted.csv');

%% ===================== Load four result files =====================

numGroups = numel(fileMap);
results = cell(1, numGroups);

for g = 1:numGroups

    matPath = fullfile(resultsDir, fileMap(g).file);

    if ~exist(matPath, 'file')
        error('Cannot find file:\n%s', matPath);
    end

    S = load(matPath);
    res = extract_result_struct(S);

    if isempty(res)
        error('Cannot find result structure in file:\n%s', matPath);
    end

    res.name = fileMap(g).name;

    if ~isfield(res, 'titleName')
        res.titleName = fileMap(g).label;
    end

    % If parameterRatio does not exist, compute it.
    if ~isfield(res, 'parameterRatio')
        if ~isfield(res, 'K_list') || ~isfield(res, 'n') || ~isfield(res, 'targetSize')
            error('Cannot compute parameterRatio for %s. Missing K_list, n, or targetSize.', fileMap(g).file);
        end

        H = res.targetSize;
        W = res.targetSize;
        res.parameterRatio = 100 * res.K_list * sum(res.n) / (H * W);
    end

    results{g} = res;

    fprintf('Loaded: %-25s  N = %d, Kmax = %d\n', ...
        fileMap(g).file, get_num_images(res), max(res.K_list));
end

%% ===================== Extract table values =====================

numRates = numel(targetRates);

K_used   = nan(numRates, numGroups);
ActRate  = nan(numRates, numGroups);
PSNR_val = nan(numRates, numGroups);
SSIM_val = nan(numRates, numGroups);
Time_val = nan(numRates, numGroups);

for g = 1:numGroups

    res = results{g};

    for r = 1:numRates

        targetRate = targetRates(r);

        [~, idx] = min(abs(res.parameterRatio - targetRate));

        K_used(r,g)   = res.K_list(idx);
        ActRate(r,g)  = res.parameterRatio(idx);
        PSNR_val(r,g) = get_vector_value(res, 'PSNR_mean', idx);
        SSIM_val(r,g) = get_vector_value(res, 'SSIM_mean', idx);
        Time_val(r,g) = get_time_value(res, idx);
    end
end

%% ===================== Print nearest K table =====================

fprintf('\n');
fprintf('====================================================================================================================\n');
fprintf('Nearest K values used for each target sampling rate\n');
fprintf('Sampling rate = K * sum(n_i) / (H * W) * 100%%\n');
fprintf('====================================================================================================================\n');

fprintf('%8s | %20s | %20s | %20s | %20s\n', ...
    'Rate', fileMap(1).label, fileMap(2).label, fileMap(3).label, fileMap(4).label);

fprintf('--------------------------------------------------------------------------------------------------------------------\n');

for r = 1:numRates

    fprintf('%7.0f%% |', targetRates(r));

    for g = 1:numGroups
        fprintf(' K=%4.0f (%6.2f%%) |', K_used(r,g), ActRate(r,g));
    end

    fprintf('\n');
end

fprintf('====================================================================================================================\n');

%% ===================== Print PSNR / SSIM / Time table =====================

fprintf('\n');
fprintf('====================================================================================================================\n');
fprintf('KPD representation quality and average decomposition time\n');
fprintf('Time is the average cumulative decomposition time to the corresponding sampling rate.\n');
fprintf('If TimeK data are missing, the script linearly estimates time from total Time_all.\n');
fprintf('====================================================================================================================\n');

fprintf('%8s | %26s | %26s | %26s | %26s\n', ...
    'Rate', fileMap(1).label, fileMap(2).label, fileMap(3).label, fileMap(4).label);

fprintf('%8s | %8s %8s %8s | %8s %8s %8s | %8s %8s %8s | %8s %8s %8s\n', ...
    '', ...
    'PSNR', 'SSIM', 'Time', ...
    'PSNR', 'SSIM', 'Time', ...
    'PSNR', 'SSIM', 'Time', ...
    'PSNR', 'SSIM', 'Time');

fprintf('--------------------------------------------------------------------------------------------------------------------\n');

for r = 1:numRates

    fprintf('%7.0f%% |', targetRates(r));

    for g = 1:numGroups
        fprintf(' %8.2f %8.4f %8.2f |', ...
            PSNR_val(r,g), SSIM_val(r,g), Time_val(r,g));
    end

    fprintf('\n');
end

fprintf('====================================================================================================================\n');

%% ===================== Print LaTeX rows =====================

fprintf('\nLaTeX table rows:\n');
fprintf('--------------------------------------------------------------------------------------------------------------------\n');

for r = 1:numRates

    fprintf('%d\\%% ', targetRates(r));

    for g = 1:numGroups
        fprintf('& %.2f & %.4f & %.2f ', ...
            PSNR_val(r,g), SSIM_val(r,g), Time_val(r,g));
    end

    fprintf('\\\\\n');
end

fprintf('--------------------------------------------------------------------------------------------------------------------\n');

%% ===================== Save CSV =====================

T = table(targetRates(:), ...
    K_used(:,1), ActRate(:,1), PSNR_val(:,1), SSIM_val(:,1), Time_val(:,1), ...
    K_used(:,2), ActRate(:,2), PSNR_val(:,2), SSIM_val(:,2), Time_val(:,2), ...
    K_used(:,3), ActRate(:,3), PSNR_val(:,3), SSIM_val(:,3), Time_val(:,3), ...
    K_used(:,4), ActRate(:,4), PSNR_val(:,4), SSIM_val(:,4), Time_val(:,4), ...
    'VariableNames', { ...
    'SamplingRate', ...
    'Gray256_K', 'Gray256_ActualRate', 'Gray256_PSNR', 'Gray256_SSIM', 'Gray256_Time', ...
    'Color256_K', 'Color256_ActualRate', 'Color256_PSNR', 'Color256_SSIM', 'Color256_Time', ...
    'Gray512_K', 'Gray512_ActualRate', 'Gray512_PSNR', 'Gray512_SSIM', 'Gray512_Time', ...
    'Color512_K', 'Color512_ActualRate', 'Color512_PSNR', 'Color512_SSIM', 'Color512_Time'});

writetable(T, csvFile);

fprintf('\nCSV table saved to:\n%s\n', csvFile);

end

%% ========================================================================
%                              Helper functions
% ========================================================================

function res = extract_result_struct(S)
% Extract result structure from possible saved variables.

res = [];

% Most likely variable name from previous KPDA script
if isfield(S, 'res_g')
    res = S.res_g;
    return;
end

% Alternative names
if isfield(S, 'result')
    res = S.result;
    return;
end

if isfield(S, 'results')
    R = S.results;

    if iscell(R)
        for i = 1:numel(R)
            if ~isempty(R{i}) && isstruct(R{i}) && isfield(R{i}, 'K_list')
                res = R{i};
                return;
            end
        end
    elseif isstruct(R)
        for i = 1:numel(R)
            if isfield(R(i), 'K_list')
                res = R(i);
                return;
            end
        end
    end
end

% Fallback: search all variables for a structure with K_list and PSNR_mean
names = fieldnames(S);

for i = 1:numel(names)
    x = S.(names{i});

    if isstruct(x) && isfield(x, 'K_list') && isfield(x, 'PSNR_mean')
        res = x;
        return;
    end
end

end

function n = get_num_images(res)

if isfield(res, 'files')
    n = numel(res.files);
elseif isfield(res, 'PSNR_all')
    n = size(res.PSNR_all, 1);
else
    n = NaN;
end

end

function val = get_vector_value(res, fieldName, idx)

if isfield(res, fieldName)
    x = res.(fieldName);
    val = x(idx);
else
    warning('Field "%s" not found in result "%s". Value is NaN.', fieldName, res.name);
    val = NaN;
end

end

function t = get_time_value(res, idx)
% Prefer exact cumulative decomposition time.
% If unavailable, estimate from total Time_all.

if isfield(res, 'TimeK_mean')
    t = res.TimeK_mean(idx);
    return;
end

if isfield(res, 'TimeK_all')
    t = mean(res.TimeK_all(:,idx), 'omitnan');
    return;
end

% If only Time_all exists, estimate cumulative time linearly.
if isfield(res, 'Time_all')
    totalTime = mean(res.Time_all, 'omitnan');

    if isfield(res, 'K_list')
        Kmax = max(res.K_list);
        Kcur = res.K_list(idx);
        t = totalTime * Kcur / Kmax;

        warning('TimeK data missing for "%s". Time at K=%d is estimated from total Time_all.', ...
            res.name, Kcur);
        return;
    else
        t = totalTime;
        warning('K_list missing for "%s". Using total Time_all.', res.name);
        return;
    end
end

if isfield(res, 'Time_mean')
    t = res.Time_mean;
    warning('TimeK and Time_all missing for "%s". Using Time_mean.', res.name);
    return;
end

warning('No time data found for "%s". Time is NaN.', res.name);
t = NaN;

end