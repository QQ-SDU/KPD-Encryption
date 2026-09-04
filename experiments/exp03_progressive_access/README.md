# Exp03 — Progressive authorized reconstruction

This experiment isolates the contribution of the ordered CLSA-KPD representation to progressive access.

A complete `K_total=300` representation is encrypted group by group. Reconstruction is then evaluated after releasing only selected group keys. Three equal-size policies are compared:

1. ordered prefix — keys `1:q`;
2. random subset — `q` randomly selected keys;
3. tail subset — the final `q` keys.

The ciphertext collection is unchanged; only the authorized key subset changes.

## Default protocol
- image: `5.1.09.tiff`
- partition: `[64 32 32]`
- `K_total = 300`
- `q = [25 50 75 100 150 200 250 300]`
- `R = 3`
- 30 random-subset trials

Run:

```matlab
run_progressive_access
```

Unreleased groups are omitted from reconstruction rather than decrypted with incorrect keys. Key-distribution protocol design is outside this codebase.
