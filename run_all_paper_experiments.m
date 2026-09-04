function run_all_paper_experiments()
%RUN_ALL_PAPER_EXPERIMENTS Run the main paper experiments in sequence.
%
% Run prepare_usc_sipi before this function. Exp05 may download Kodak data.
% The full run is computationally expensive because it includes K=300 CLSA
% representations and dataset-level experiments.

run_project_tests;
run_baseline([],100);
run_round_ablation;
run_k_sensitivity;
run_progressive_access;
run_group_loss;
run_dataset_validation;
run_controlled_baselines;
run_progressive_visual_export_blocks;
end
