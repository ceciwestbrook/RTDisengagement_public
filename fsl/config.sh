#!/bin/bash
# Shared paths and parameters for the FSL pipeline.
#
# Source this at the top of any script in fsl/:
#     source "$(dirname "${BASH_SOURCE[0]}")/../config.sh"
#
# Override any of these from the environment rather than editing this file:
#     export TREW_DATA_ROOT=/path/to/your/data
#     export TREW_FSLDIR=/path/to/fsl

# --- Paths ------------------------------------------------------------------
# Root containing rawdata/ and preprocessed/. Defaults to the repo's data/
# directory so the pipeline runs out of the box once data is placed there.
TREW_REPO_ROOT="${TREW_REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
TREW_DATA_ROOT="${TREW_DATA_ROOT:-$TREW_REPO_ROOT/data}"

RAWDATA_DIR="$TREW_DATA_ROOT/rawdata"
PREPROC_DIR="$TREW_DATA_ROOT/preprocessed"
PROCESSED_DIR="${TREW_PROCESSED_DIR:-$TREW_DATA_ROOT/processed}"
TIMING_DIR="$TREW_DATA_ROOT/timing"
GROUP_DIR="${TREW_GROUP_DIR:-$TREW_DATA_ROOT/group_level}"

# FSL. Set TREW_FSLDIR if FSL is not on the default FSLDIR.
FSL_ROOT="${TREW_FSLDIR:-$FSLDIR}"
if [[ -z "$FSL_ROOT" ]]; then
  echo "ERROR: FSLDIR not set and TREW_FSLDIR not provided." >&2
  echo "       Run 'module load fsl' or export TREW_FSLDIR=/path/to/fsl" >&2
  return 1 2>/dev/null || exit 1
fi
MNI_BRAIN="$FSL_ROOT/data/standard/MNI152_T1_2mm_brain"

# --- Study parameters -------------------------------------------------------
SESSION="ses-01"
TASK="PDT"
RUNS=(1 2 3)
TR_SECONDS=2.0

# Motion censoring. FD threshold for spike regressors; runs exceeding
# MAX_SPIKE_FRACTION of censored volumes are dropped.
FD_SPIKE_THRESHOLD=0.6
MAX_SPIKE_FRACTION=0.25

# --- Cluster (SLURM) --------------------------------------------------------
# Adjust for your own scheduler, or ignore these scripts entirely and call
# feat directly on the generated .fsf files.
SLURM_CLUSTER="${TREW_SLURM_CLUSTER:-htc}"
SLURM_ACCOUNT="${TREW_SLURM_ACCOUNT:-}"
