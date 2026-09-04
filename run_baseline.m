function summary = run_baseline(image_file, K)
%RUN_BASELINE Convenience entry point for exp00.
project_root = fileparts(mfilename('fullpath'));
addpath(project_root);
setup_paths();
addpath(fullfile(project_root, 'experiments', 'exp00_baseline'));
if nargin < 1, image_file = []; end
if nargin < 2, K = []; end
summary = run_exp00_baseline(image_file, K);
end
