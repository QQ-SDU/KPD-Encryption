function cfg = default_config(project_root)
%DEFAULT_CONFIG Central configuration for the CLSA-KPD paper code.

if nargin < 1 || isempty(project_root)
    project_root = fileparts(fileparts(mfilename('fullpath')));
end

cfg.project_root = project_root;
cfg.seed = 20260830;

cfg.data.usc_sipi_root = fullfile(project_root, 'data', 'USC_SIPI');
cfg.data.manifest = fullfile(cfg.data.usc_sipi_root, 'manifest.csv');

% CLSA-KPD settings used by the paper experiments.
cfg.representation.partition_256 = [64, 32, 32];
cfg.representation.partition_512 = [32, 32, 16, 16];
cfg.representation.K_max = 100;
cfg.representation.init_scale = 6;
cfg.representation.inner_tol = 0.1;
cfg.representation.inner_max_iter = 200;
cfg.representation.residual_abs_tol = 1e-4;
cfg.representation.cache_enabled = true;
cfg.representation.cache_dir = fullfile(project_root, 'representation', 'cache');

% Encryption settings: one round = one permutation + one row/column diffusion.
cfg.encryption.num_rounds = 3;  % selected by Exp01 round-ablation
cfg.encryption.warmup = 500;
cfg.encryption.a_max = 2^25 - 1;

% Baseline experiment settings.
cfg.baseline.default_image = fullfile(cfg.data.usc_sipi_root, 'gray_256', '5.1.09.tiff');
cfg.baseline.K = 20;  % fast integrity baseline; paper experiments override this explicitly.

% Exp02 K-sensitivity settings.
cfg.exp02.K_values = [25, 50, 75, 100, 125, 150, 200, 250, 300];
cfg.exp02.num_rounds = 3;
cfg.exp02.runtime_repeats = 5;

% Exp03 progressive authorized reconstruction settings.
cfg.exp03.K_total = 300;
cfg.exp03.q_values = [25, 50, 75, 100, 150, 200, 250, 300];
cfg.exp03.num_rounds = 3;
cfg.exp03.random_trials = 30;

cfg.results.root = fullfile(project_root, 'results');
cfg.results.raw = fullfile(cfg.results.root, 'raw');
cfg.results.tables = fullfile(cfg.results.root, 'tables');
cfg.results.figures = fullfile(cfg.results.root, 'figures');
cfg.results.images = fullfile(cfg.results.root, 'images');
end
