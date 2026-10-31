#!/usr/bin/env python3
"""
Build a key-package version table from the container manifest files.

Usage (from the repo root, stdlib only, no install needed):
    python3 make_version_table.py containers/manifests > containers/manifests/key_versions.md

Inputs, per container (cpu-v01, gpu-cu12-v01) and environment:
    <container>_<env>.yml      from `micromamba env export`
    <container>_<env>_pip.txt  from `pip freeze`

Lookup rule: conda/env version and pip version are both read. If they disagree
(e.g. conda numpy 1.26.4 but pip numpy 2.5.4) the pip version is reported with a dagger,
because pip ran later in the build and overwrote the conda files.

Otherwise: conda version first, then pip. Packages that pip freeze lists as
`name @ file:///...` are conda builds, so their version comes from the .yml.
Packages installed from git are reported as `git@<commit>`.
"""
import re
import sys
from pathlib import Path

CONTAINERS = ["cpu-v01", "gpu-cu12-v01"]

# display name -> candidate package names (conda and pip names differ for some)
KEY_PACKAGES = {
    "env_core": {
        "scanpy": ["scanpy"], "anndata": ["anndata"], "scvi-tools": ["scvi-tools"],
        "celltypist": ["celltypist"], "pyclustree": ["pyclustree"],
        "decoupler": ["decoupler"], "pydeseq2": ["pydeseq2"],
        "cell2location": ["cell2location"], "cellpose": ["cellpose"],
        "numpy": ["numpy"], "scipy": ["scipy"], "pandas": ["pandas"],
        "leidenalg": ["leidenalg"], "umap-learn": ["umap-learn"],
        "pytorch": ["pytorch", "torch"], "torchvision": ["torchvision"],
        "rapids-singlecell": ["rapids-singlecell-cu12", "rapids-singlecell"],
        "cuml": ["cuml"], "cudf": ["cudf"], "cugraph": ["cugraph"], "cuvs": ["cuvs"],
        "cupy": ["cupy"], "cuda-version": ["cuda-version"],
        "cuda-python": ["cuda-python"], "cuda-bindings": ["cuda-bindings"],
    },
    "env_velocity": {
        "scvelo": ["scvelo"], "cellrank": ["cellrank"], "scanpy": ["scanpy"],
        "anndata": ["anndata"], "numpy": ["numpy"], "pytorch": ["pytorch", "torch"],
    },
    "env_spatial": {
        "squidpy": ["squidpy"], "spatialdata": ["spatialdata"],
        "spatialdata-io": ["spatialdata-io"], "spatialdata-plot": ["spatialdata-plot"],
        "scanpy": ["scanpy"], "anndata": ["anndata"], "cellpose": ["cellpose"],
        "numpy": ["numpy"], "pytorch": ["pytorch", "torch"],
    },
    "env_pseudo": {
        "pydeseq2": ["pydeseq2"], "decoupler": ["decoupler"], "liana": ["liana"],
        "scanpy": ["scanpy"], "anndata": ["anndata"], "statsmodels": ["statsmodels"],
        "numpy": ["numpy"],
    },
}


def norm(name):
    return re.sub(r"[-_.]+", "-", name).lower()


def parse_yml(path):
    """conda lines: `- name=version=build`; pip lines inside export: `- name==version`."""
    out = {}
    if not path.exists():
        return out
    for line in path.read_text().splitlines():
        m = re.match(r"^\s*-\s*([^=\s]+)==(\S+)", line)
        if m:
            out[norm(m.group(1))] = m.group(2)
            continue
        m = re.match(r"^\s*-\s*([^=\s]+)=([^=\s]+)(?:=(\S+))?", line)
        if m:
            version, build = m.group(2), m.group(3) or ""
            # keep cpu/cuda tag for pytorch so the table shows which build it is
            if norm(m.group(1)) == "pytorch" and build:
                version = f"{version} ({build.split('_')[0]})"
            out[norm(m.group(1))] = version
    return out


def parse_pip(path):
    out = {}
    if not path.exists():
        return out
    for line in path.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if " @ " in line:
            name, src = line.split(" @ ", 1)
            if src.startswith("git+") and "@" in src:
                out[norm(name)] = "git@" + src.rsplit("@", 1)[-1][:8]
            # file:/// entries are conda builds: version comes from the yml
        elif "==" in line:
            name, ver = line.split("==", 1)
            out[norm(name)] = ver
    return out


def lookup(conda, pip, candidates):
    """Effective version. pip runs after conda in the build, so when the two
    disagree the pip install has overwritten the conda files; the pip version is
    reported with a dagger. Verified at runtime for numpy (all envs) and torch
    (cpu env_core)."""
    hits = []
    for c in candidates:
        c = norm(c)
        if c in conda:
            hits.append((conda[c], "env"))
        if c in pip:
            hits.append((pip[c], "pip"))
    if not hits:
        return None
    distinct = {}
    for v, src in hits:
        distinct.setdefault(v.split(" ")[0], (v, src))
    if len(distinct) == 1:
        return hits[0][0]
    pip_hits = [v for v, src in hits if src == "pip"]
    return (pip_hits[0] if pip_hits else hits[0][0]) + " \u2020"


def main(manifest_dir):
    d = Path(manifest_dir)
    print("# Key package versions per environment\n")
    print("Source: `micromamba env export` and `pip freeze` run inside each SIF.")
    print("`-` means not installed in that environment. `git@` = installed from git at that commit.")
    print("\u2020 = pip overwrote the conda build; the conda export lists a different version. Runtime-checked for numpy and torch.\n")
    for env, pkgs in KEY_PACKAGES.items():
        rows = []
        for display, candidates in pkgs.items():
            vals = []
            for cont in CONTAINERS:
                conda = parse_yml(d / f"{cont}_{env}.yml")
                pip = parse_pip(d / f"{cont}_{env}_pip.txt")
                vals.append(lookup(conda, pip, candidates) or "-")
            if all(v == "-" for v in vals):
                continue  # skip packages absent from both variants
            rows.append((display, *vals))
        print(f"## {env}\n")
        print("| Package | " + " | ".join(CONTAINERS) + " |")
        print("|---|" + "---|" * len(CONTAINERS))
        for r in rows:
            print("| " + " | ".join(r) + " |")
        print()


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit("usage: python3 make_version_table.py <manifest_dir>")
    main(sys.argv[1])
