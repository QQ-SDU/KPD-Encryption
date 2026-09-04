function prepare_usc_sipi(overwrite)
%PREPARE_USC_SIPI Download the USC-SIPI images used by the paper experiments.
%
%   prepare_usc_sipi
%   prepare_usc_sipi(true)
%
% The repository does not redistribute USC-SIPI image files. This helper
% downloads the exact files listed in data/USC_SIPI/manifest.csv from the
% official USC-SIPI Image Database and stores them at the relative paths
% expected by the experiment scripts.
%
% The USC-SIPI database notes that many images have uncertain copyright
% status. Users are responsible for complying with the database terms and
% copyright information when using the images.

if nargin < 1
    overwrite = false;
end

project_root = fileparts(mfilename('fullpath'));
manifest_file = fullfile(project_root,'data','USC_SIPI','manifest.csv');
T = readtable(manifest_file,'TextType','string');

base_url = 'https://sipi.usc.edu/database/download.php?vol=misc&img=';

fprintf('Preparing USC-SIPI subset (%d files)...\n',height(T));
for i = 1:height(T)
    target = fullfile(project_root, char(T.relative_path(i)));
    [target_dir,~,~] = fileparts(target);
    if exist(target_dir,'dir') ~= 7
        mkdir(target_dir);
    end

    if exist(target,'file') == 2 && ~overwrite
        fprintf('  [%02d/%02d] exists: %s\n',i,height(T),T.filename(i));
        continue;
    end

    [~,stem,~] = fileparts(char(T.filename(i)));
    url = [base_url stem];
    fprintf('  [%02d/%02d] downloading %s\n',i,height(T),T.filename(i));
    try
        websave(target,url);
    catch ME
        error('prepare_usc_sipi:DownloadFailed', ...
            'Failed to download %s from USC-SIPI.\nURL: %s\n%s', ...
            T.filename(i),url,ME.message);
    end
end

fprintf('USC-SIPI subset ready under %s\n',fullfile(project_root,'data','USC_SIPI'));
fprintf('Run run_project_tests to verify metadata and the code path.\n');
end
