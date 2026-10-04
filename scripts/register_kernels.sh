#!/bin/bash
# Register each cartridge environment as a named Jupyter kernel.
# Run once at container build time by the Dockerfile.
# micromamba run -n <env> executes the command inside that environment
# without needing to activate it first.
set -e

echo "Registering env_core kernel..."
micromamba run -n env_core python -m ipykernel install \
    --name env_core \
    --display-name "Python (core)"

echo "Registering env_velocity kernel..."
micromamba run -n env_velocity python -m ipykernel install \
    --name env_velocity \
    --display-name "Python (velocity)"

echo "Registering env_spatial kernel..."
micromamba run -n env_spatial python -m ipykernel install \
    --name env_spatial \
    --display-name "Python (spatial)"

echo "Registering env_pseudo kernel..."
micromamba run -n env_pseudo python -m ipykernel install \
    --name env_pseudo \
    --display-name "Python (pseudo)"

echo "All kernels registered successfully."
