# Manuscript reference results

The CSV files in `paper_results/tables/` are frozen numerical outputs corresponding to the manuscript experiments. They are provided for inspection and comparison with fresh runs.

Fresh executions write their outputs to `results/` and do not overwrite these reference files.

## Portability note

Machine-specific absolute cache paths have been normalized to repository-relative paths such as `representation/cache/<file>.mat`. This normalization changes metadata only; numerical experimental fields are unchanged.

## Experiment mapping

- `exp01_*`: encryption-round ablation
- `exp02_*`: K / representation-budget sensitivity
- `exp03_*`: progressive authorization
- `exp04_*`: encrypted-group loss
- `exp05_*`: USC-SIPI + Kodak dataset validation
- `exp06_*`: controlled direct/monolithic/group-wise baselines
- `exp07_*`: progressive visual reconstruction metrics
