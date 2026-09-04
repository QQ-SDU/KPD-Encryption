# Repository refresh for the current manuscript

This package is intended to replace the historical root-level experimental scripts in the public repository with the modular code used by the current manuscript.

Key changes:

- separates representation, cryptographic transformation, evaluation, and experiment orchestration;
- uses the paper operating point `R=3` selected by a round ablation;
- treats `K` as a representation budget and includes K-sensitivity analysis;
- includes progressive authorization, group-loss, cross-dataset, controlled-baseline, and visual-block experiments;
- stores frozen manuscript CSV summaries under `paper_results/`;
- does not redistribute USC-SIPI image files; an official-source download helper is provided;
- removes historical ad-hoc scripts from the reproducibility path.

Suggested Git tag after verification: `v1.0-paper`.
