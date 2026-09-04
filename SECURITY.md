# Security scope

This repository implements a research prototype for parameter-domain image protection and progressive access experiments.

It is **not** intended as a production cryptographic library. The entropy, correlation, NPCR, UACI, and key-sensitivity evaluations are statistical diagnostics under the paper's experimental protocol and should not be interpreted as a formal cryptographic security proof.

The current code does not provide authenticated encryption, integrity protection, a deployment key-management protocol, or side-channel hardening. These concerns must be addressed separately in any real security-sensitive deployment.
