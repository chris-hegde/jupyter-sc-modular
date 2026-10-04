#!/bin/bash
# Validate that each cartridge kernel can import its core packages.
# Run inside the container after build or pull:
#   apptainer exec container.sif bash /path/to/test_kernels.sh
#
# Exit code 0 = all tests passed
# Exit code 1 = one or more tests failed
set -e

PASS=0
FAIL=0

run_test() {
    local env=$1
    local cmd=$2
    local label=$3

    echo -n "Testing ${label}... "
    if micromamba run -n "${env}" python -c "${cmd}" 2>/dev/null; then
        echo "PASS"
        PASS=$((PASS + 1))
    else
        echo "FAIL"
        FAIL=$((FAIL + 1))
    fi
}

# ── env_core ─────────────────────────────────────────────────────────────
run_test env_core "import scanpy" "scanpy"
run_test env_core "import anndata" "anndata"
run_test env_core "import scvi" "scvi-tools"
run_test env_core "import cellpose" "cellpose"
run_test env_core "import cell2location" "cell2location"
run_test env_core "import celltypist" "celltypist"
run_test env_core "import pertpy" "pertpy"
run_test env_core "import decoupler" "decoupler"
run_test env_core "import pydeseq2" "pydeseq2"
run_test env_core "import mudata" "mudata"

# ── env_velocity ──────────────────────────────────────────────────────────
run_test env_velocity "import scvelo" "scvelo"
run_test env_velocity "import cellrank" "cellrank"

# ── env_spatial ───────────────────────────────────────────────────────────
run_test env_spatial "import spatialdata" "spatialdata"
run_test env_spatial "import squidpy" "squidpy"
run_test env_spatial "import cellpose" "cellpose (spatial)"

# ── env_pseudo ────────────────────────────────────────────────────────────
run_test env_pseudo "import pydeseq2" "pydeseq2"
run_test env_pseudo "import decoupler" "decoupler"
run_test env_pseudo "import liana" "liana"

# ── Summary ───────────────────────────────────────────────────────────────
echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi