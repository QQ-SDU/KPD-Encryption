# KPD-Encryption

MATLAB code and reference experiment outputs for the paper:

**Ordered CLSA-KPD Image Representation with Group-Wise Protection for Progressive Secure Access**

The repository separates four layers:

```text
image
  -> ordered CLSA-KPD representation
  -> lossless parameter-byte serialization
  -> independent group-wise permutation/diffusion protection
  -> authorized reconstruction and evaluation
```

The code is organized to reproduce the main experimental claims without relying on historical one-off scripts.

## Repository structure

```text
config/           shared experiment settings
representation/   CLSA-KPD decomposition and reconstruction
crypto/           serialization, 2D-LSCM, permutation/diffusion, encryption/decryption
evaluation/       PSNR, SSIM, entropy, correlation, NPCR/UACI and related utilities
experiments/      Exp00--Exp07 experiment implementations
tests/            integrity/unit tests
data/              dataset manifest and download instructions
paper_results/     CSV outputs used as numerical reference for the manuscript
results/           generated outputs (ignored by git except placeholders)
docs/              reproduction and experiment mapping
```

Root-level wrappers provide stable entry points for all experiments; the implementations live under `experiments/exp00_*` through `experiments/exp07_*`.

## Requirements

- MATLAB R2020a or later is recommended.
- Image Processing Toolbox is recommended for image I/O and SSIM-related workflows.
- Internet access is needed only when downloading the public datasets automatically.

The paper experiments were run on a desktop with an Intel Core i5-10300H CPU, 16 GB RAM, and an NVIDIA GeForce GTX 1650 GPU. The MATLAB implementation is CPU-oriented; GPU hardware is not required by the current scripts.

## Quick start

Clone/download the repository and open MATLAB in the repository root.

### 1. Check the code path

```matlab
run_project_tests
```

The pure code tests should pass even before the external image files are downloaded. Dataset file-level checks are performed when the files are present.

### 2. Prepare USC-SIPI images

The image files are **not redistributed in this repository**. Download the exact subset listed in `data/USC_SIPI/manifest.csv` from the official USC-SIPI database with:

```matlab
prepare_usc_sipi
```

Please review the USC-SIPI copyright information before redistributing or publishing database images.

### 3. Run the integrity baseline

```matlab
run_baseline([],100)
```

Expected invariants include bit-exact parameter recovery and reconstruction equivalence between direct KPD reconstruction and encryption/decryption followed by reconstruction.

## Paper experiments

| ID | Entry point | Purpose |
|---|---|---|
| Exp01 | `run_round_ablation` | round-count ablation, `R=1:5` |
| Exp02 | `run_k_sensitivity` | reconstruction quality / protection-cost tradeoff versus `K` |
| Exp03 | `run_progressive_access` | ordered-prefix vs. random/tail key release |
| Exp04 | `run_group_loss` | random, early-group and late-group erasure |
| Exp05 | `run_dataset_validation` | USC-SIPI + Kodak dataset-level validation |
| Exp06 | `run_controlled_baselines` | direct-image, monolithic-KPD and group-wise-KPD comparison |
| Exp07 | `run_progressive_visual_export_blocks` | publication visual blocks for Clock, Aerial and Portrait |

Exp05 downloads the Kodak Lossless True Color images automatically when needed and creates center-cropped 256x256 versions without interpolation.

## Reference numerical outputs

`paper_results/tables/` contains the CSV summaries used to check the manuscript tables and plots. Generated results from a fresh run are written to `results/` and are intentionally kept separate from the frozen reference CSVs.

See:

- `docs/REPRODUCIBILITY.md`
- `docs/EXPERIMENTS.md`
- `paper_results/README.md`

For maintainers replacing the earlier public repository layout, see `docs/GITHUB_MIGRATION.md`.

## Reproducibility conventions

- The random seed is fixed in `config/default_config.m`.
- Representation caches are reused so different settings are compared using prefixes of the same ordered CLSA-KPD representation where required.
- Encryption/decryption timing excludes CLSA decomposition and key generation unless a script explicitly states otherwise.
- Correct-key decryption is checked with `isequal` on the floating-point parameter vectors.
- `K` is a representation budget; it is not an encryption-round parameter.
- `eta_K` denotes the retained representation-parameter rate, while `eta_q` denotes the authorized parameter rate for progressive key release.

## Security scope

This repository is research code for the experimental framework described in the paper. The 2D-LSCM permutation--diffusion implementation and the reported entropy/correlation/NPCR/UACI tests are experimental components, not a production cryptographic library or a formal cryptographic security proof. See `SECURITY.md`.

## Citation

If you use this repository, please cite the associated paper after its bibliographic record becomes available. GitHub-compatible metadata is provided in `CITATION.cff`.
