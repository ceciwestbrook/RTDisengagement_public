#!/bin/bash
# fMRIPrep, one subject per array task. Submit with submit_fmriprep.sh (same folder),
# or directly:  sbatch --clusters=$TREW_SLURM_CLUSTER --array=0 fmriprep_arraybatch.sh
# Array index N = Nth subject (0-based) in sorted order of $TREW_DATA_ROOT/rawdata/sub-*.
# Environment (see setup_env.sh): TREW_DATA_ROOT required. Optional overrides:
#   TREW_FMRIPREP_SIMG  (default $TREW_DATA_ROOT/fmriprep-24.1.1.simg)
#   TREW_FS_LICENSE     (default $TREW_DATA_ROOT/license_free_surfer.txt)
#   TREW_FMRIPREP_WORK  (default $TREW_DATA_ROOT/work; large, safe to delete afterwards)
#SBATCH -J fmriprep
#SBATCH --time=12:00:00
#SBATCH -N 1
#SBATCH --cpus-per-task=16
#SBATCH --mem=32G

set -eu
: "${TREW_DATA_ROOT:?run: source setup_env.sh}"
: "${SLURM_ARRAY_TASK_ID:?submit as an array job, e.g. --array=0}"

BIDS_dir=$TREW_DATA_ROOT/rawdata
preprocessed_dir=$TREW_DATA_ROOT/preprocessed
work_dir=${TREW_FMRIPREP_WORK:-$TREW_DATA_ROOT/work}
fsfileloc=${TREW_FS_LICENSE:-$TREW_DATA_ROOT/license_free_surfer.txt}
simg=${TREW_FMRIPREP_SIMG:-$TREW_DATA_ROOT/fmriprep-24.1.1.simg}

subs=($(ls -d "$BIDS_dir"/sub-* | xargs -n1 basename | sed 's/^sub-//' | sort -u))
subject="${subs[$SLURM_ARRAY_TASK_ID]:-}"
if [ -z "$subject" ]; then
  echo "No subject at index $SLURM_ARRAY_TASK_ID (${#subs[@]} subjects in $BIDS_dir)" >&2
  exit 1
fi
echo "Running subject: $subject (index $SLURM_ARRAY_TASK_ID of ${#subs[@]})"

# nprocs must equal --cpus-per-task above
options=(--fs-license-file "$fsfileloc"
  --nprocs 16
  --work-dir "$work_dir"
  --ignore fieldmaps slicetiming
  --fd-spike-threshold 0.6
  --output-spaces MNI152NLin6Asym:res-2
  --participant-label "$subject"
  --skip-bids-validation)

module load singularity
mkdir -p "$preprocessed_dir" "$work_dir"
cd "$TREW_DATA_ROOT"

singularity run --cleanenv --bind "$TREW_DATA_ROOT:$TREW_DATA_ROOT" "$simg" \
  "$BIDS_dir" "$preprocessed_dir" participant "${options[@]}"

# fMRIPrep can print "finished successfully" and still skip outputs after a node crash.
n=$(find "$preprocessed_dir/sub-$subject" -name '*desc-preproc_bold.nii.gz' 2>/dev/null | wc -l)
if [ "$n" -lt 1 ]; then
  echo "fMRIPrep exited 0 but sub-$subject has no desc-preproc_bold outputs" >&2
  exit 1
fi
