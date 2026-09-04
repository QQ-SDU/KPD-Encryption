# Exp02 — K sensitivity and the quality--cost tradeoff

`K` is the number of retained ordered CLSA-KPD terms. It controls the representation budget and reconstruction quality; it is not an encryption-round parameter.

For the 256x256 partition `[64 32 32]`, each group contains 128 floating-point parameters, so

```text
eta_K = 128*K/(256*256) * 100%
```

## Default protocol
- image: `5.1.09.tiff`
- `K = [25 50 75 100 125 150 200 250 300]`
- `R = 3`
- all operating points use prefixes of one common K=300 representation
- encryption/decryption timing excludes decomposition and key generation

Run:

```matlab
run_k_sensitivity
```

Outputs are written under `results/`.
