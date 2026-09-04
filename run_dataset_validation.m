function [individual, aggregate] = run_dataset_validation(K, num_rounds, runtime_repeats)
%RUN_DATASET_VALIDATION Project-root wrapper for Exp05.
project_root = fileparts(mfilename('fullpath'));
addpath(project_root);
setup_paths();
addpath(fullfile(project_root, 'experiments', 'exp05_dataset_validation'));
if nargin < 1, K = []; end
if nargin < 2, num_rounds = []; end
if nargin < 3, runtime_repeats = []; end
[individual, aggregate] = run_exp05_dataset_validation(K, num_rounds, runtime_repeats);
end
