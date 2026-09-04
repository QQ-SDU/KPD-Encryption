# Datasets

Third-party image files are not redistributed in this repository.

## USC-SIPI

`USC_SIPI/manifest.csv` lists the exact 20 files used by the project, including their expected dimensions, channel counts, relative paths, and SHA-256 values from the frozen experiment set.

Download the subset from the official USC-SIPI Image Database by running:

```matlab
prepare_usc_sipi
```

The USC-SIPI site states that the database is intended for research use and that the copyright status of many images is not owned or known by USC-SIPI. Users should review the official copyright information before redistribution or publication.

Expected local layout after download:

```text
data/USC_SIPI/color_256/
data/USC_SIPI/color_512/
data/USC_SIPI/gray_256/
data/USC_SIPI/gray_512/
```

## Kodak

`run_dataset_validation` downloads 24 Kodak Lossless True Color images when needed and stores originals/crops under `data/Kodak_original/` and `data/Kodak_256/`. These generated/downloaded dataset folders are ignored by git.
