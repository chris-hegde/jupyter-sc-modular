# Key package versions per environment

Source: `micromamba env export` and `pip freeze` run inside each SIF.
`-` means not installed in that environment. `git@` = installed from git at that commit.
† = pip overwrote the conda build; the conda export lists a different version. Runtime-checked for numpy and torch.

## env_core

| Package | cpu-v01 | gpu-cu12-v01 |
|---|---|---|
| scanpy | 1.11.5 | 1.11.5 |
| anndata | 0.12.19 | 0.12.19 |
| scvi-tools | 1.5.1 | 1.5.1 |
| celltypist | 1.7.1 | 1.7.1 |
| pyclustree | 0.4.1 | 0.4.1 |
| decoupler | 1.5.0 | 1.5.0 |
| pydeseq2 | 0.5.4 | 0.5.4 |
| cell2location | git@afb07fda | git@afb07fda |
| cellpose | 4.2.1.1 | 4.2.1.1 |
| numpy | 2.5.4 † | 2.4.6 † |
| scipy | 1.17.1 | 1.16.3 |
| pandas | 2.3.3 | 2.3.3 |
| leidenalg | 0.12.0 | 0.12.0 |
| umap-learn | 0.5.12 | 0.5.12 |
| pytorch | 2.14.1 † | 2.10.0 (cuda129) |
| torchvision | 0.29.1 | 0.26.0 |
| rapids-singlecell | - | 0.15.2 |
| cuml | - | 26.04.00 |
| cudf | - | 26.04.00 |
| cugraph | - | 26.04.00 |
| cuvs | - | 26.04.00 |
| cupy | - | 13.6.0 |
| cuda-version | - | 12.9 |
| cuda-python | - | 12.9.9 |
| cuda-bindings | 13.4.4 | 12.9.9 |

## env_velocity

| Package | cpu-v01 | gpu-cu12-v01 |
|---|---|---|
| scvelo | 0.3.4 | 0.3.4 |
| cellrank | 2.3.3 | 2.3.3 |
| scanpy | 1.11.5 | 1.11.5 |
| anndata | 0.12.19 | 0.12.19 |
| numpy | 2.5.4 † | 2.5.4 † |
| pytorch | 2.14.1 (cpu) | 2.14.1 (cuda129) |

## env_spatial

| Package | cpu-v01 | gpu-cu12-v01 |
|---|---|---|
| squidpy | 1.8.2 | 1.8.2 |
| spatialdata | 0.8.0 | 0.8.0 |
| spatialdata-io | 0.7.1 | 0.7.1 |
| spatialdata-plot | 0.4.2 | 0.4.2 |
| scanpy | 1.12.4 | 1.12.4 |
| anndata | 0.13.4 | 0.13.4 |
| cellpose | 4.2.1.1 | 4.2.1.1 |
| numpy | 2.5.4 | 2.5.4 |
| pytorch | 2.14.1 (cpu) | 2.14.1 (cuda129) |

## env_pseudo

| Package | cpu-v01 | gpu-cu12-v01 |
|---|---|---|
| pydeseq2 | 0.5.4 | 0.5.4 |
| decoupler | 2.2.0 | 2.2.0 |
| liana | 1.10.0 | 1.10.0 |
| scanpy | 1.12.4 | 1.12.4 |
| anndata | 0.13.4 | 0.13.4 |
| statsmodels | 0.15.0 | 0.15.0 |
| numpy | 2.5.4 | 2.5.4 |

