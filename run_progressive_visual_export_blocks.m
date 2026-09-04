function summary = run_progressive_visual_export_blocks()
%RUN_PROGRESSIVE_VISUAL_EXPORT_BLOCKS Project-root wrapper for Exp07.
project_root = fileparts(mfilename('fullpath'));
addpath(project_root);
setup_paths();
addpath(fullfile(project_root, 'experiments', 'exp07_progressive_visual'));
summary = run_exp07_progressive_visual_export_blocks();
end
