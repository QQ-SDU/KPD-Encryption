function summary = run_k_sensitivity(image_file, K_values, num_rounds, runtime_repeats)
%RUN_K_SENSITIVITY Project-root wrapper for Exp02.
project_root = fileparts(mfilename('fullpath'));
addpath(project_root);
setup_paths();
addpath(fullfile(project_root, 'experiments', 'exp02_k_sensitivity'));
if nargin < 1, image_file = []; end
if nargin < 2, K_values = []; end
if nargin < 3, num_rounds = []; end
if nargin < 4, runtime_repeats = []; end
summary = run_exp02_k_sensitivity(image_file, K_values, num_rounds, runtime_repeats);
end
