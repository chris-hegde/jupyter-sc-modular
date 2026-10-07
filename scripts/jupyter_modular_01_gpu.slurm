#!/bin/bash
#SBATCH --partition=main
#SBATCH --job-name=jupyter-sc
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=32000
#SBATCH --time=8:00:00
#SBATCH --output=/projectsp/f_salgampa_1/chris_h/logs/jupyter.%N.%j.out
#SBATCH --error=/projectsp/f_salgampa_1/chris_h/logs/jupyter.%N.%j.err

module purge
module load apptainer/1.3.6

SIF_IMAGE="/projectsp/f_salgampa_1/chris_h/containers/jupyter-sc-modular_gpu-v01.sif"

# Auto-detect --nv flag from image name
NV_FLAG=""
if [[ "${SIF_IMAGE}" == *gpu* ]]; then
    NV_FLAG="--nv"
    echo "GPU image detected (${SIF_IMAGE}) — adding --nv flag" >&2
fi

# Create temporary directories for Jupyter runtime files
workdir=$(python3 -c 'import tempfile; print(tempfile.mkdtemp())')
mkdir -p "${workdir}/tmp" "${workdir}/jupyter_runtime" "${workdir}/jupyter_data"

# Set thread limits to match allocated CPUs
export APPTAINERENV_OMP_NUM_THREADS=${SLURM_JOB_CPUS_PER_NODE}
export APPTAINERENV_OPENBLAS_NUM_THREADS=${SLURM_JOB_CPUS_PER_NODE}

# Jupyter runtime directories
export APPTAINERENV_JUPYTER_RUNTIME_DIR="${workdir}/jupyter_runtime"
export APPTAINERENV_JUPYTER_DATA_DIR="${workdir}/jupyter_data"
export APPTAINERENV_XDG_CACHE_HOME="${workdir}/tmp"

# Library cache redirects
export APPTAINERENV_CELLTYPIST_FOLDER="${workdir}/tmp/celltypist"
export APPTAINERENV_TORCH_HOME="${workdir}/tmp/torch_hub"
export APPTAINERENV_SCVI_DATA_DIR="${workdir}/tmp/scvi_data"
export APPTAINERENV_NUMBA_CACHE_DIR="${workdir}/tmp/numba_cache"
export APPTAINERENV_MPLCONFIGDIR="${workdir}/tmp/mpl_cache"
mkdir -p "${workdir}/tmp/celltypist" "${workdir}/tmp/torch_hub" \
         "${workdir}/tmp/scvi_data" "${workdir}/tmp/numba_cache" \
         "${workdir}/tmp/mpl_cache"

# Get unused port
readonly PORT=$(python3 -c 'import socket; s=socket.socket(); s.bind(("", 0)); print(s.getsockname()[1]); s.close()')

# Generate random token
readonly TOKEN=$(python3 -c 'import secrets; print(secrets.token_hex(24))')

cat 1>&2 <<END

================================================================================
  JupyterLab is starting on ${HOSTNAME}:${PORT}
  Image: ${SIF_IMAGE}
================================================================================

1. SSH tunnel from your workstation:

   ssh -N -L 8888:${HOSTNAME}:${PORT} ${USER}@amarel3.hpc.rutgers.edu

2. Open in your browser:

   http://localhost:8888

3. Jupyter token:

   ${TOKEN}

4. When done:

   scancel ${SLURM_JOB_ID}

================================================================================
END

# Slack notification
if [ -n "$SLACK_WEBHOOK_URL" ]; then
    curl -X POST -H 'Content-type: application/json' \
        --data "{\"text\":\"Jupyter started!\nSSH: \`\`\`ssh -N -L 8888:${HOSTNAME}:${PORT} ${USER}@amarel3.hpc.rutgers.edu\`\`\`\nToken: ${TOKEN}\nJob: ${SLURM_JOB_ID}\"}" \
        "$SLACK_WEBHOOK_URL"
fi

# Launch JupyterLab
apptainer exec --cleanenv ${NV_FLAG} \
    --bind "${workdir}/tmp:/tmp" \
    --bind "${workdir}/jupyter_runtime:${workdir}/jupyter_runtime" \
    --bind "${workdir}/jupyter_data:${workdir}/jupyter_data" \
    --bind "$PWD:/home/jovyan/work" \
    "${SIF_IMAGE}" \
    /usr/local/bin/_entrypoint.sh \
    jupyter lab \
        --ip=0.0.0.0 \
        --port="${PORT}" \
        --no-browser \
        --notebook-dir=/home/jovyan/work \
        --IdentityProvider.token="${TOKEN}"

printf 'JupyterLab exited\n' >&2
