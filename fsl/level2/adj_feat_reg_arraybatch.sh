#!/bin/bash

# FEAT registration workaround (Jeanette Mumford):
# https://mumfordbrainstats.tumblr.com/post/166054797696/feat-registration-workaround
#
# Because the data are already in standard space from fMRIPrep, level 1 was run
# without registration. FEAT still expects registration matrices at level 2, so
# we copy each .feat directory, insert identity transforms, and point
# reg/standard.nii.gz at the mean functional.
#
# Originally written Feb 2022; rewritten to loop over models rather than
# duplicating a block per model.
#
# Submit with:  sbatch adj_feat_reg_arraybatch.sh
# Check first with:  ./adj_feat_reg_arraybatch.sh --dry-run <subject>

# Batch options
# Inputs ----------------------------------
#SBATCH -J adj_feat_reg
#SBATCH --time=2:00:00
#SBATCH --cluster=htc
#SBATCH -N 1
#SBATCH --cpus-per-task=1
#SBATCH --array=0-56%20
# Outputs ----------------------------------
#SBATCH -o log/%x-%A-%a.out
#SBATCH -e log/%x-%A-%a.err
# ------------------------------------------

# ======================= settings ==========================================
FSLDIR=/software/rhel9/manual/install/fsl/6.0.7.18
PROC=${TREW_PROCESSED_DIR}/
SUBJECT_LIST=${TREW_REPO_ROOT}/fsl/Level1/subjects_run1.txt

# Models to process. Comment out any that are not ready yet.
MODELS=(
  dyscontrolmod_censorRT
  indivthoughtmod_censorRT
  ACCmod_censorRT
  dyscontrolandeffortmods_censorRT
  dyscontrolandACCmods_censorRT
  PCC_PPI_DC
  PCC_PPI_ACC
  PCC_PPI
# SARTACCcluster_PPI       # seed depends on group maps; enable once rebuilt
)
# ===========================================================================

IDENT="$FSLDIR/etc/flirtsch/ident.mat"
if [[ ! -f "$IDENT" ]]; then
  echo "ERROR: identity matrix not found at $IDENT" >&2
  echo "       Check FSLDIR. Current value: $FSLDIR" >&2
  exit 1
fi

# ---- dry-run mode: ./adj_feat_reg_arraybatch.sh --dry-run 301 --------------
DRY_RUN=0
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=1
  subject="${2:?Usage: $0 --dry-run <subject>}"
  echo "=== DRY RUN for sub-$subject (nothing will be written) ==="
else
  # ---- pick this array task's subject --------------------------------------
  if [[ ! -f "$SUBJECT_LIST" ]]; then
    echo "ERROR: subject list not found: $SUBJECT_LIST" >&2
    exit 1
  fi
  mapfile -t subs < <(sort -u "$SUBJECT_LIST")
  subject="${subs[$SLURM_ARRAY_TASK_ID]}"
  if [[ -z "$subject" ]]; then
    echo "No subject at array index $SLURM_ARRAY_TASK_ID (list has ${#subs[@]}); nothing to do."
    exit 0
  fi
  echo "Processing sub-$subject (array index $SLURM_ARRAY_TASK_ID)"
fi

LEVEL1="$PROC/sub-${subject}/ses-01/level1"
if [[ ! -d "$LEVEL1" ]]; then
  echo "ERROR: no level1 directory for sub-$subject: $LEVEL1" >&2
  exit 1
fi

n_done=0
n_skip=0

for run in 1 2 3; do
  for model in "${MODELS[@]}"; do
    src="$LEVEL1/run${run}_${model}.feat"
    dst="$LEVEL1/run${run}_${model}_adjreg.feat"

    # Only proceed if the source analysis actually finished.
    if [[ ! -f "$src/stats/cope1.nii.gz" ]]; then
      echo "  SKIP run${run} ${model} (no stats/cope1.nii.gz)"
      n_skip=$((n_skip+1))
      continue
    fi

    if [[ $DRY_RUN -eq 1 ]]; then
      echo "  would copy run${run} ${model} -> $(basename "$dst")"
      [[ -e "$dst" ]] && echo "    (existing $(basename "$dst") would be removed first)"
      n_done=$((n_done+1))
      continue
    fi

    # Replace any previous adjreg copy so we never accumulate +.feat dirs.
    rm -rf "$dst"
    cp -r "$src" "$dst" || { echo "  ERROR copying $src" >&2; continue; }

    mkdir -p "$dst/reg"
    cp "$IDENT" "$dst/reg/example_func2standard.mat" || echo "  ERROR: ident copy failed for $dst" >&2
    cp "$IDENT" "$dst/reg/standard2example_func.mat" || echo "  ERROR: ident copy failed for $dst" >&2
    cp "$dst/mean_func.nii.gz" "$dst/reg/standard.nii.gz" || echo "  ERROR: mean_func copy failed for $dst" >&2

    # Verify the three files landed.
    for f in reg/example_func2standard.mat reg/standard2example_func.mat reg/standard.nii.gz; do
      [[ -s "$dst/$f" ]] || echo "  WARNING: $dst/$f missing or empty" >&2
    done

    echo "  done run${run} ${model}"
    n_done=$((n_done+1))
  done
done

echo "sub-${subject}: $n_done processed, $n_skip skipped"
