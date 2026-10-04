#!/bin/bash
# Sourced at login via /etc/profile.d/ inside the container.
# Initialises micromamba so conda environments are accessible when
# Apptainer runs the container on HPC with a host UID.
#
# Without this, micromamba activate fails because the shell has no
# knowledge of the conda environment system.

export MAMBA_ROOT_PREFIX=/opt/conda
eval "$(micromamba shell hook --shell bash)"
