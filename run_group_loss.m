function summary = run_group_loss(image_file, K_total, loss_rates, num_rounds, random_trials)
%RUN_GROUP_LOSS Project-root wrapper for Exp04.
project_root = fileparts(mfilename('fullpath'));
addpath(project_root);
setup_paths();
addpath(fullfile(project_root, 'experiments', 'exp04_group_loss'));
if nargin < 1, image_file = []; end
if nargin < 2, K_total = []; end
if nargin < 3, loss_rates = []; end
if nargin < 4, num_rounds = []; end
if nargin < 5, random_trials = []; end
summary = run_exp04_group_loss(image_file, K_total, loss_rates, num_rounds, random_trials);
end
