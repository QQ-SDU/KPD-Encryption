# Reproducibility guide

## Recommended run order

From the repository root:

```matlab
run_project_tests
prepare_usc_sipi
run_project_tests
run_baseline([],100)
run_round_ablation
run_k_sensitivity
run_progressive_access
run_group_loss
run_dataset_validation
run_controlled_baselines
run_progressive_visual_export_blocks
```

The first execution of experiments requiring large `K` can be slower because a representation cache is created. Subsequent experiments reuse compatible cache files.

## Main operating points

- 256x256 grayscale partition: `[64 32 32]`
- parameters per group: 128 doubles
- selected encryption rounds after Exp01: `R=3`
- representative paper setting: `K=100`
- full progressive-access representation: `K_total=300`
- visual-release prefix sizes: `q=[25 50 100 200 300]`

For a 256x256 image,

```text
eta_r = r * 128 / (256*256) * 100%
```

where `r` is `K` for the representation budget or `q` for authorized progressive access.

## Expected correctness invariants

For correct keys:

1. serialized floating-point parameters are recovered bit-for-bit;
2. direct KPD reconstruction and decrypted KPD reconstruction are exactly equal;
3. the protection layer adds no reconstruction error beyond the KPD approximation itself.

## Generated output policy

Fresh runs write to:

```text
results/tables/
results/figures/
results/images/
results/raw/
```

These folders are ignored by git to avoid mixing generated outputs with source code. Frozen numerical outputs corresponding to the manuscript are kept in `paper_results/tables/`.

## Dataset notes

### USC-SIPI

The repository contains only a manifest, not the TIFF files. `prepare_usc_sipi` downloads the exact subset used by the scripts from the official USC-SIPI database.

### Kodak

`run_dataset_validation` downloads the 24 Kodak images from the public mirror specified in the script and creates center 256x256 crops without resizing.

## Timing

Absolute runtime depends on the MATLAB version and hardware. The intended comparisons are within-run comparisons using identical timing boundaries. Decomposition and key-generation time are excluded from the encryption/decryption timing experiments.
