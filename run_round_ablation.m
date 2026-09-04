function summary = run_round_ablation(image_file, K, rounds_list, runtime_repeats)
%RUN_ROUND_ABLATION Convenience entry point for Exp01.
project_root = fileparts(mfilename('fullpath'));
addpath(project_root);
setup_paths();
addpath(fullfile(project_root, 'experiments', 'exp01_round_ablation'));
if nargin < 1, image_file = []; end
if nargin < 2, K = []; end
if nargin < 3, rounds_list = []; end
if nargin < 4, runtime_repeats = []; end
summary = run_exp01_round_ablation(image_file, K, rounds_list, runtime_repeats);
end
