# Container Build Documentation — `jupyter-sc-modular`

## Architecture

Monolithic multi-kernel container. One Apptainer SIF image built on `mambaorg/micromamba:1.5-jammy` (Ubuntu 22.04) containing multiple isolated micromamba environments, each registered as a named Jupyter kernel. JupyterLab runs from the `base` conda environment; scientific tools are isolated in cartridge environments (`env_core`, `env_velocity`, `env_spatial`, `env_pseudo`).

CPU and GPU variants are built from the same `Dockerfile` using `--build-arg DEVICE=cpu|gpu`. GPU-specific conda channels, packages, and pip extras are gated behind `#gpu#` comment markers in each environment `.yml` file, which are activated at build time via `sed` substitution.

**Alternative design considered:** A microkernel architecture (separate SIF per kernel, spawned on demand) was evaluated but not implemented. The monolithic approach was retained because it maps cleanly to the Docker build workflow, simplifies GPU passthrough, and avoids per-kernel SIF management overhead. The main argument for microkernel — container startup latency — is resolved by `squashfuse` (pending HPC sysadmin installation). Reference: http://www.physics.mcgill.ca/~obriens/Tutorials/containerized_kernels/

---

## CPU Container — `jupyter-sc-modular-cpu-v01.sif`

### Base image
`mambaorg/micromamba:1.5-jammy`

### Key packages

| Environment | Packages |
|---|---|
| `env_base` | JupyterLab>=4.0, jupyterlab-git, jupytext, jupyter-resource-usage, nbstripout |
| `env_core` | scanpy, anndata, scvi-tools, cellpose, cell2location (GitHub), celltypist, pertpy, decoupler, pydeseq2, mudata, muon, scirpy, pyclustree, scrublet (on-demand), narwhals>=2.0, numpy<2.0, python=3.12 |
| `env_velocity` | scvelo, cellrank[scvelo], narwhals>=2.0, numpy<2.0, python=3.12 |
| `env_spatial` | spatialdata, spatialdata-io, spatialdata-plot, squidpy, pyclustree, narwhals>=2.0, python=3.12 |
| `env_pseudo` | pydeseq2, decoupler, liana, python=3.12 |

### Build method
`docker buildx build --platform linux/amd64` on Apple M4, pushed to DockerHub as `chrishegde/jupyter-sc-modular:cpu-v01`, converted to `.sif` via `apptainer build --fakeroot` on HPC (Rutgers Amarel, Slurm, `main` partition).

### Test result
✓ Pass

### Tests run
- All four kernels visible in JupyterLab kernel selector via SSH tunnel
- Import tests in browser:
  - `env_core`: `import scanpy; import scvi; import celltypist; import pyclustree` → ok
  - `env_velocity`: `import scvelo; import cellrank` → ok
  - `env_spatial`: `import spatialdata; import squidpy` → ok
  - `env_pseudo`: `import pydeseq2; import decoupler` → ok
- Dataset tests:
  - PBMC 3k (scanpy built-in): 2700 → 2497 cells, 5 Leiden clusters, CellTypist annotated ✓
  - SOLO doublet detection (scvi-tools): ran on CPU, flagged doublets correctly ✓

### Issues encountered and resolved

| Issue | Fix |
|---|---|
| `jupyterlab-topbar` and `jupyterlab-system-monitor` incompatible with JupyterLab 4 | Replaced with `jupyter-resource-usage` |
| `decoupler-py` incorrect PyPI name | Corrected to `decoupler` |
| `narwhals.stable.v2` not found | Pinned `narwhals>=2.0` |
| Python 3.11 insufficient | Bumped to 3.12 (required by scvi-tools, cellrank, scirpy, mudata) |
| `ipykernel install --sys-prefix` writing kernels to wrong prefix | Changed to `--prefix /opt/conda` |
| Apptainer sandbox conversion slow (~10 min) | `squashfuse` not installed on HPC — sysadmin contacted, FUSE libraries available but squashfuse binary missing |
| JupyterLab writing to read-only `/home/mambauser/.jupyter` | Bind-mounted writable `${workdir}/home:/home/mambauser` and set `APPTAINERENV_JUPYTER_CONFIG_DIR` |
| Apptainer cache serving stale Docker layers | Clear `/scratch/ch1199/apptainer/cache/` before each SIF build |
| `scrublet` incompatible with Python 3.12 (pulls pandas 1.5.3, fails to build) | Removed from container — installed on-demand in notebook via `pip install scrublet==0.2.3` |
| `clustree` pulls old pandas, incompatible with Python 3.12 | Replaced with `pyclustree` (Python 3.12 + pandas 2.x compatible) |
| `cell2location` PyPI v0.1.3 incompatible with scvi-tools>=1.1 | Switched to GitHub install: `git+https://github.com/BayraktarLab/cell2location.git` |
| `cell2location` still fails — pyro `deep_getattr` removed in pyro 1.9.x | Deferred — not needed until spatial deconvolution work begins |
| `numpy>=2.0` breaks scvelo numerical computation | Pinned `numpy<2.0` in `env_core` and `env_velocity` |

---

## GPU Container — `jupyter-sc-modular-gpu-cu12-v01.sif`

### Base image
`mambaorg/micromamba:1.5-jammy`

### Key packages
All CPU packages plus the following GPU additions:

| Environment | GPU additions |
|---|---|
| `env_core` | pytorch-gpu (conda-forge), torchvision (conda-forge), cuda-version=12, cuml=26.04, cudf=26.04, cugraph=26.04, cuvs=26.04, cuda-python=12.9, cuda-bindings=12.9, rapids-singlecell-cu12==0.15.2, nvitop |
| `env_velocity` | pytorch-gpu (conda-forge) |
| `env_spatial` | pytorch-gpu (conda-forge) |

### Build method
`docker buildx build --platform linux/amd64 --build-arg DEVICE=gpu --build-arg CUDA_WHEEL=12` on Apple M4, pushed to DockerHub as `chrishegde/jupyter-sc-modular:gpu-cu12-v01`, converted via `apptainer build --fakeroot` on HPC GPU partition (NVIDIA A100 40GB, CUDA 12.9).

### Test result
✓ Pass

### Tests run
- All four kernels visible in JupyterLab kernel selector via SSH tunnel on GPU node
- Import tests on GPU node:
  - `env_core`: `import rapids_singlecell; import torch; torch.cuda.is_available()` → True
  - `env_velocity`: `import scvelo; import cellrank` → ok
  - `env_spatial`: `import spatialdata; import squidpy` → ok
  - `env_pseudo`: `import pydeseq2; import decoupler` → ok
- GPU pipeline tests:
  - `rsc.pp.pca(adata)` after `filter_genes`, normalisation, HVG selection → ok ✓
  - SOLO doublet detection on A100 40GB → completed in ~30 seconds ✓
- Dataset tests:
  - PBMC 3k: 2700 → 2497 cells, 6 Leiden clusters, CellTypist annotated ✓

### Issues encountered and resolved

| Issue | Fix |
|---|---|
| `#gpu#` sed replacement missing from `env_velocity` and `env_spatial` Dockerfile sections | Added `sed -i "s/__CUDA__/${CUDA_WHEEL}/g"` to both sections |
| RAPIDS 26.04 pulling `cuda-bindings 13.x` despite cu12 tag | Pinned `cuda-python=12.9` and `cuda-bindings=12.9` in both conda and pip sections |
| `pytorch-gpu` resolving to `2.14.1+cu130` (cu13) from NVIDIA channel | Pinned to `conda-forge::pytorch-gpu` |
| `torchvision` pip version incompatible with conda pytorch | Added `conda-forge::torchvision` to conda section |
| `rapids-singlecell-cu12` latest (0.17.0) requires cu13 bindings internally | Pinned to `==0.15.2` |
| CuPy JIT compilation fails — `cuda-bindings 13.x` overwriting cu12 install | `cupy-cuda12x` pip package conflicted with conda `cupy 13.6.0` from RAPIDS — removed pip install, conda RAPIDS cupy is sufficient |
| GPU PCA fails: `zero expression genes` | Added `sc.pp.filter_genes(adata, min_cells=3)` before `rsc.pp.pca()` |

### Known limitations

| Issue | Status |
|---|---|
| `cell2location` — pyro `deep_getattr` incompatibility | Deferred until spatial deconvolution work begins. Will isolate in separate cartridge with pinned pyro version |
| `squashfuse` not installed on HPC | Sysadmin contacted. FUSE 3.9.1 libraries available but squashfuse binary missing. Sandbox conversion takes ~10 min without it |
| `celltypist` not in `env_spatial` | Deferred — add to `env_spatial.yml` pip section and rebuild when spatial annotation is needed |

---

## Analysis templates

| Template | Kernel | Status | Test dataset |
|---|---|---|---|
| `01_scrna_analysis.ipynb` | `env_core` | ✓ Validated | PBMC 3k |
| `02_spatial_analysis.ipynb` | `env_spatial` | ✓ Validated | Visium H&E mouse brain |
| `03_velocity_analysis.ipynb` | `env_velocity` | Planned | — |
| `04_pseudo_analysis.ipynb` | `env_pseudo` | Planned | — |
| `report.ipynb` | `env_core` | ✓ Working | — |

---

## Repository
`https://github.com/chris-hegde/jupyter-sc-modular`

## Git tags
- `cpu-v01-working` — CPU container fully validated
- `gpu-cu12-v01-working` — GPU container fully validated
