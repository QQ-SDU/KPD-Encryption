# Exp01 — Encryption-round ablation

This experiment studies the security/efficiency behavior of the number of permutation--diffusion rounds.

## Fixed protocol
- image: `5.1.09.tiff`, 256x256 grayscale
- partition: `[64 32 32]`
- retained KPD groups: `K=100`
- round counts: `R=1:5`
- same cached CLSA-KPD representation for every `R`
- common master-key material across round settings

## Metrics
- pooled ciphertext entropy
- adjacent-byte correlations
- group-level NPCR and UACI with theoretical reference limits
- total and per-group encryption/decryption time

Run from the repository root:

```matlab
run_round_ablation
```

Outputs are written under `results/`.
