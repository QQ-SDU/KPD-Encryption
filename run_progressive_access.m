function summary = run_progressive_access(image_file, K_total, q_values, num_rounds, random_trials)
%RUN_PROGRESSIVE_ACCESS Project-root wrapper for Exp03.
project_root = fileparts(mfilename('fullpath'));
addpath(project_root);
setup_paths();
addpath(fullfile(project_root, 'experiments', 'exp03_progressive_access'));
if nargin < 1, image_file = []; end
if nargin < 2, K_total = []; end
if nargin < 3, q_values = []; end
if nargin < 4, num_rounds = []; end
if nargin < 5, random_trials = []; end
summary = run_exp03_progressive_access(image_file, K_total, q_values, num_rounds, random_trials);
end
