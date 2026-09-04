function results = run_project_tests()
%RUN_PROJECT_TESTS Convenience entry point.
project_root = fileparts(mfilename('fullpath'));
addpath(project_root);
setup_paths();
results = run_all_tests();
end
