#!/bin/bash
# Build and push the jupyter-sc-modular Docker image.
# Usage:
#   bash scripts/build.sh cpu      → CPU image (default)
#   bash scripts/build.sh gpu      → GPU image (cu12, A100)
#
# Requires Docker buildx for linux/amd64 cross-compilation from M4.
# Images are pushed directly to DockerHub on build.
set -e

# ── Config ───────────────────────────────────────────────────────────────
DOCKERHUB_USER="chrishegde"
IMAGE_NAME="jupyter-sc-modular"
VERSION="v01"
DEVICE="${1:-cpu}"

# ── Validate input ───────────────────────────────────────────────────────
if [[ "$DEVICE" != "cpu" && "$DEVICE" != "gpu" ]]; then
    echo "Error: DEVICE must be 'cpu' or 'gpu', got '${DEVICE}'"
    exit 1
fi

# ── Set tag ──────────────────────────────────────────────────────────────
if [ "$DEVICE" = "gpu" ]; then
    TAG="${DOCKERHUB_USER}/${IMAGE_NAME}:gpu-cu12-${VERSION}"
else
    TAG="${DOCKERHUB_USER}/${IMAGE_NAME}:cpu-${VERSION}"
fi

# ── Log ──────────────────────────────────────────────────────────────────
LOGFILE="logs/build_${DEVICE}_${VERSION}_$(date +%Y%m%d_%H%M%S).log"
mkdir -p logs
echo "Building ${TAG}" | tee "${LOGFILE}"
echo "Started: $(date)" | tee -a "${LOGFILE}"

# ── Build ────────────────────────────────────────────────────────────────
docker buildx build \
    --platform linux/amd64 \
    --build-arg DEVICE="${DEVICE}" \
    --build-arg CUDA_WHEEL=12 \
    -t "${TAG}" \
    --push \
    . 2>&1 | tee -a "${LOGFILE}"

echo "Finished: $(date)" | tee -a "${LOGFILE}"
echo "Image pushed: ${TAG}" | tee -a "${LOGFILE}"
