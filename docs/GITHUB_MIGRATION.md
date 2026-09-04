# GitHub repository refresh

The public repository previously contained an earlier collection of one-off scripts. For the paper submission, use this reorganized tree as the new `main` branch content.

Recommended migration:

1. Preserve the current public state with a tag or archival branch, e.g. `archive-pre-reproducibility`.
2. Replace the `main` branch working tree with this package.
3. Commit with a message such as:
   `Reorganize codebase for reproducible paper experiments`
4. Optionally create a release/tag such as `v1.0-paper` after checking the repository online.
5. Add a short repository description, e.g.:
   `MATLAB implementation of ordered CLSA-KPD representation, group-wise protection, and progressive secure image access.`

Do not commit downloaded USC-SIPI or Kodak image files. Dataset preparation is handled by the scripts and manifests in `data/`.
