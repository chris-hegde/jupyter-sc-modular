# Cartridge List — jupyter-sc-modular

## Overview
Modular JupyterLab container for single-cell and spatial transcriptomics analysis.
Built with micromamba on Ubuntu 22.04 (jammy). CPU and GPU (CUDA 12.8, A100) variants.

## Base Environment
**`env_base`** — JupyterLab infrastructure only, no scientific packages.
- JupyterLab, jupyter_server, ipywidgets, jupyterlab-git
- jupyterlab-system-monitor, jupytext, nbstripout

---

## Kernels

### Python (core) — `env_core`
Core single-cell analysis stack. GPU-aware via pytorch/RAPIDS.
- **Preprocessing/analysis:** scanpy, anndata, leidenalg, bbknn, umap-learn
- **Deep learning:** scvi-tools, pytorch
- **Cell typing:** celltypist
- **Segmentation:** cellpose
- **Spatial deconvolution:** cell2location
- **Perturbation:** pertpy
- **Differential expression:** pydeseq2, decoupler-py
- **Multimodal:** mudata, scirpy, muon
- **GPU only:** rapids-singlecell-cu12, cuml, cudf, cugraph, cuvs

### Python (velocity) — `env_velocity`
RNA velocity and trajectory analysis. GPU-aware via pytorch.
- scvelo, cellrank, scanpy, anndata

### Python (spatial) — `env_spatial`
Spatial transcriptomics analysis. GPU-aware via pytorch.
- spatialdata, spatialdata-io, spatialdata-plot
- squidpy, cellpose

### Python (pseudo) — `env_pseudo`
Pseudobulk, differential expression, and functional analysis. CPU only.
- pydeseq2, decoupler-py, liana
- statsmodels, scanpy, anndata

---

## Build variants
| Tag | Device | CUDA |
|-----|--------|------|
| `cpu-v01` | CPU | — |
| `gpu-cu12-v01` | GPU | 12.8 (A100) |

## Image
`chrishegde/jupyter-sc-modular`