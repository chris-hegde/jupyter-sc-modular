#!/bin/bash
#SBATCH --partition=gpu
#SBATCH --job-name=jupyter-sc
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=32000
#SBATCH --gres=gpu:1
#SBATCH --time=8:00:00
#SBATCH --output=logs/jupyter.%N.%j.out
#SBATCH --error=logs/jupyter.%N.%j.err

module purge
module load apptainer/1.3.6

# ── Container path ───────────────────────────────────────────────────────
SIF=/projectsp/f_salgampa_1/chris_h/containers/jupyter-sc-modular-gpu-cu12-v01.sif

# ── Random port allocation ───────────────────────────────────────────────
readonly PORT=$(python -c 'import socket; s=socket.socket(); s.bind(("", 0)); print(s.getsockname()[1]); s.close()')

# ── Connection instructions ──────────────────────────────────────────────
cat 1>&2 <<END

1. SSH tunnel from your workstation:

   ssh -N -L 8888:${HOSTNAME}:${PORT} ${USER}@amarel3.hpc.rutgers.edu

2. Open your browser and go to:

   http://localhost:8888/lab

   Token is in the Slurm log below.

When done, cancel the job with:

   scancel -f ${SLURM_JOB_ID}

END

# ── Slack notification ───────────────────────────────────────────────────
# SLACK_WEBHOOK_URL must be set in ~/.bashrc on the HPC:
# export SLACK_WEBHOOK_URL="https://hooks.slack.com/services/..."
if [ -n "$SLACK_WEBHOOK_URL" ]; then
    curl -X POST -H 'Content-type: application/json' \
        --data "{\"text\":\"Jupyter job started!\nSSH tunnel:\n\`\`\`ssh -N -L 8888:${HOSTNAME}:${PORT} ${USER}@amarel3.hpc.rutgers.edu\`\`\`\nURL: http://localhost:8888/lab\nJob ID: ${SLURM_JOB_ID}\"}" \
        "$SLACK_WEBHOOK_URL"
fi

# ── Launch container ─────────────────────────────────────────────────────
apptainer exec --cleanenv --nv \
    -B /projectsp/f_salgampa_1/chris_h:/projectsp/f_salgampa_1/chris_h \
    "$SIF" \
    jupyter lab \
        --ip=0.0.0.0 \
        --port=${PORT} \
        --no-browser
        
