function [summary, capabilities] = run_controlled_baselines(image_file, K, num_rounds, runtime_repeats, differential_trials)
%RUN_CONTROLLED_BASELINES Project-root wrapper for Exp06.
project_root = fileparts(mfilename('fullpath'));
addpath(project_root);
setup_paths();
addpath(fullfile(project_root, 'experiments', 'exp06_controlled_baselines'));
if nargin < 1, image_file = []; end
if nargin < 2, K = []; end
if nargin < 3, num_rounds = []; end
if nargin < 4, runtime_repeats = []; end
if nargin < 5, differential_trials = []; end
[summary, capabilities] = run_exp06_controlled_baselines(image_file, K, num_rounds, runtime_repeats, differential_trials);
end
