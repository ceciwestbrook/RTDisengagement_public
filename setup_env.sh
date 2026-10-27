#!/bin/bash
# Source once per session before running anything in this repository:
#     source setup_env.sh
#
# AFTER A FILESYSTEM MIGRATION, ONLY TREW_DATA_ROOT BELOW NEEDS CHANGING.
# No script in this repository contains an absolute path.

_repo="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export TREW_REPO_ROOT="$_repo"

# Data: rawdata/, preprocessed/, timing/, questionnaires/, sourcedata/.
# Defaults to ./data so the repository runs standalone once data is placed
# there (see data/README.md).
export TREW_DATA_ROOT="${TREW_DATA_ROOT:-$_repo/data}"

# Analysis outputs. Large; on a cluster these usually belong on scratch
# rather than alongside the code, and may move independently of the data.
export TREW_PROCESSED_DIR="${TREW_PROCESSED_DIR:-$TREW_DATA_ROOT/processed}"
export TREW_GROUP_DIR="${TREW_GROUP_DIR:-$TREW_DATA_ROOT/group_level}"
export TREW_WORK_ROOT="${TREW_WORK_ROOT:-$_repo}"

# FSL. Leave unset to use whatever `module load fsl` provides.
# export TREW_FSLDIR=/path/to/fsl

# Scheduler. Site-specific; used only by the SLURM wrappers. On other
# systems ignore the wrappers and call `feat` on the generated .fsf files.
export TREW_SLURM_CLUSTER="${TREW_SLURM_CLUSTER:-htc}"
export TREW_SLURM_ACCOUNT="${TREW_SLURM_ACCOUNT:-}"

printf '%-20s %s\n' \
  TREW_REPO_ROOT "$TREW_REPO_ROOT" \
  TREW_DATA_ROOT "$TREW_DATA_ROOT" \
  TREW_PROCESSED_DIR "$TREW_PROCESSED_DIR" \
  TREW_GROUP_DIR "$TREW_GROUP_DIR" \
  FSL "${TREW_FSLDIR:-${FSLDIR:-(unset - run module load fsl)}}"
unset _repo
