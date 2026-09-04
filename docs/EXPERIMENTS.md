# Experiment map

## Exp00 — Integrity baseline
Entry point: `run_baseline`

Checks lossless serialization/encryption/decryption and verifies that correct-key reconstruction equals direct KPD reconstruction.

## Exp01 — Round ablation
Entry point: `run_round_ablation`

Tests `R=1,...,5` at fixed `K=100`. Reports entropy, adjacent-byte correlations, NPCR/UACI, and encryption/decryption time.

## Exp02 — Representation budget
Entry point: `run_k_sensitivity`

Uses `K=[25 50 75 100 125 150 200 250 300]` with `R=3` to measure PSNR/SSIM and protection cost. All smaller settings are prefixes of the same `K=300` ordered representation.

## Exp03 — Progressive authorization
Entry point: `run_progressive_access`

Encrypts 300 ordered groups and compares equal-size ordered-prefix, random-subset, and tail-subset key release.

## Exp04 — Group erasure
Entry point: `run_group_loss`

Compares random group loss with targeted early-group and late-group loss. Missing groups are omitted from reconstruction.

## Exp05 — Dataset validation
Entry point: `run_dataset_validation`

Evaluates the fixed operating point across the USC-SIPI subset and 24 Kodak images. Reports reconstruction quality, ciphertext statistics, pass rates, runtime, and exact recovery.

## Exp06 — Controlled baselines
Entry point: `run_controlled_baselines`

Uses the same 2D-LSCM core for:

1. direct image encryption;
2. monolithic encryption of KPD parameters;
3. independent group-wise encryption of KPD parameters.

This isolates conventional cipher behavior from the access granularity provided by the ordered representation.

## Exp07 — Progressive visual blocks
Entry point: `run_progressive_visual_export_blocks`

Exports separate full-image and fixed-ROI zoom blocks for Clock, Aerial, and Portrait at `q=[25 50 100 200 300]`. The final multi-panel figure can then be assembled in LaTeX without re-running MATLAB.
