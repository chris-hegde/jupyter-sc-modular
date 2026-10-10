FROM mambaorg/micromamba:1.5-jammy

# ── CPU vs GPU build ────────────────────────────────────────────────────
# Default: CPU. To build GPU: docker build --build-arg DEVICE=gpu
# or: bash scripts/build.sh gpu
#
# DEVICE controls sed substitutions that activate #gpu# lines in env YAMLs.
# CONDA_OVERRIDE_CUDA tells the conda solver to treat CUDA 12.8 as available
# during build -- there is no GPU at docker build time, only at runtime.
# CUDA_WHEEL is fixed at 12 (A100 nodes, CUDA 12.8 driver).
ARG DEVICE=cpu
ARG CUDA_WHEEL=12

# ── System dependencies ──────────────────────────────────────────────────
USER root
SHELL ["/bin/bash", "-c"]
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libhdf5-dev \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    libfontconfig1-dev \
    libharfbuzz-dev \
    libfribidi-dev \
    libfreetype6-dev \
    libpng-dev \
    libtiff5-dev \
    libjpeg-dev \
    libgeos-dev \
    libproj-dev \
    libgl1-mesa-glx \
    libglib2.0-0 \
    libspatialindex-dev \
    git \
    procps \
    less \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
USER $MAMBA_USER
SHELL ["/usr/local/bin/_dockerfile_shell.sh"]

# ── Base environment: JupyterLab ─────────────────────────────────────────
# Installs into the default 'base' conda environment -- this is what runs
# when the container starts. Contains only Jupyter infrastructure, no
# scientific packages.
COPY --chown=$MAMBA_USER:$MAMBA_USER envs/env_base.yml /tmp/env_base.yml
RUN micromamba install -y -n base -f /tmp/env_base.yml \
    && micromamba clean --all --yes

# ── Cartridge: core (scanpy, scvi-tools, cellpose, cell2location) ────────
# Heaviest cartridge first for Docker layer caching.
# GPU build: sed activates #gpu# lines and swaps pytorch-cpu → pytorch-gpu.
# CONDA_OVERRIDE_CUDA tells the solver CUDA 12.8 is available at build time.
COPY --chown=$MAMBA_USER:$MAMBA_USER envs/env_core.yml /tmp/env_core.yml
RUN if [ "$DEVICE" = "gpu" ]; then \
      sed -i 's/pytorch-cpu/pytorch-gpu/g' /tmp/env_core.yml; \
      sed -i 's/#gpu# //g' /tmp/env_core.yml; \
      sed -i "s/__CUDA__/${CUDA_WHEEL}/g" /tmp/env_core.yml; \
      export CONDA_OVERRIDE_CUDA="12.8"; \
      export CONDA_CHANNEL_PRIORITY=flexible; \
    fi \
    && micromamba create -y -f /tmp/env_core.yml \
    && micromamba clean --all --yes

# ── Cartridge: velocity (scvelo, cellrank) ───────────────────────────────
COPY --chown=$MAMBA_USER:$MAMBA_USER envs/env_velocity.yml /tmp/env_velocity.yml
RUN if [ "$DEVICE" = "gpu" ]; then \
      sed -i 's/pytorch-cpu/pytorch-gpu/g' /tmp/env_velocity.yml; \
      sed -i 's/#gpu# //g' /tmp/env_velocity.yml; \
      sed -i "s/__CUDA__/${CUDA_WHEEL}/g" /tmp/env_velocity.yml; \
      export CONDA_OVERRIDE_CUDA="12.8"; \
    fi \
    && micromamba create -y -f /tmp/env_velocity.yml \
    && micromamba clean --all --yes

# ── Cartridge: spatial (spatialdata, squidpy, cellpose) ──────────────────
# Listed last among GPU-aware cartridges -- most conflict-prone.
COPY --chown=$MAMBA_USER:$MAMBA_USER envs/env_spatial.yml /tmp/env_spatial.yml
RUN if [ "$DEVICE" = "gpu" ]; then \
      sed -i 's/pytorch-cpu/pytorch-gpu/g' /tmp/env_spatial.yml; \
      sed -i 's/#gpu# //g' /tmp/env_spatial.yml; \
      sed -i "s/__CUDA__/${CUDA_WHEEL}/g" /tmp/env_spatial.yml; \
      export CONDA_OVERRIDE_CUDA="12.8"; \
    fi \
    && micromamba create -y -f /tmp/env_spatial.yml \
    && micromamba clean --all --yes

# ── Cartridge: pseudo (pydeseq2, decoupler, liana) ───────────────────────
# CPU only -- no GPU pattern needed.
COPY --chown=$MAMBA_USER:$MAMBA_USER envs/env_pseudo.yml /tmp/env_pseudo.yml
RUN micromamba create -y -f /tmp/env_pseudo.yml \
    && micromamba clean --all --yes

# ── Register Jupyter kernels ─────────────────────────────────────────────
# Each cartridge environment is registered as a named Jupyter kernel.
# nb_conda_kernels is intentionally not used -- it requires the conda command
# which does not exist in micromamba images. Kernels are registered explicitly
# instead.
COPY --chown=$MAMBA_USER:$MAMBA_USER scripts/register_kernels.sh /tmp/register_kernels.sh
RUN bash /tmp/register_kernels.sh

# ── Apptainer/Singularity compatibility ──────────────────────────────────
# When Apptainer runs this container on HPC it uses the host user's UID,
# which does not own /opt/conda or $HOME. Three fixes:
# 1. Make all conda files readable by any UID
# 2. Create world-writable /tmp cache dirs for packages that write at runtime
# 3. Create a conda init script so micromamba environments are accessible
USER root
SHELL ["/bin/bash", "-c"]
COPY scripts/conda_init.sh /etc/profile.d/conda_init.sh
RUN chmod a+r /etc/profile.d/conda_init.sh \
    && chmod -R a+rX /opt/conda/ \
    && mkdir -p /home/jovyan/work \
    && chown -R $MAMBA_USER:$MAMBA_USER /home/jovyan \
    && mkdir -p \
        /tmp/numba_cache \
        /tmp/mpl_cache \
        /tmp/xdg_cache \
        /tmp/celltypist \
        /tmp/torch_hub \
        /tmp/scvi_data \
        /tmp/spatialdata_cache \
    && chmod -R 1777 \
        /tmp/numba_cache \
        /tmp/mpl_cache \
        /tmp/xdg_cache \
        /tmp/celltypist \
        /tmp/torch_hub \
        /tmp/scvi_data \
        /tmp/spatialdata_cache
USER $MAMBA_USER
SHELL ["/usr/local/bin/_dockerfile_shell.sh"]


# ── Cache directory redirects ─────────────────────────────────────────────
# Redirects runtime package caches to /tmp paths created in Section 6.
# Necessary because the HPC user UID does not own /opt/conda or $HOME,
# so packages that try to write caches there fail silently or crash.
ENV NUMBA_CACHE_DIR=/tmp/numba_cache \
    MPLCONFIGDIR=/tmp/mpl_cache \
    XDG_CACHE_HOME=/tmp/xdg_cache \
    CELLTYPIST_FOLDER=/tmp/celltypist \
    TORCH_HOME=/tmp/torch_hub \
    SCVI_DATA_DIR=/tmp/scvi_data \
    SPATIALDATA_CACHE_DIR=/tmp/spatialdata_cache

# ── Runtime ──────────────────────────────────────────────────────────────
WORKDIR /home/jovyan/work
EXPOSE 8888
ENTRYPOINT ["/usr/local/bin/_entrypoint.sh"]
CMD ["jupyter", "lab", "--ip=0.0.0.0", "--port=8888", "--no-browser"]