#!/bin/bash
# Submits subject index 0 first, then all remaining subjects starting
# $TREW_STAGGER_MIN minutes (default 5) after the first one has started. This avoids a
# known fMRIPrep race: on a fresh output directory, parallel tasks all try to create
# sourcedata/freesurfer/fsaverage at once. Usage: source setup_env.sh; bash submit_fmriprep.sh
set -eu
: "${TREW_DATA_ROOT:?run: source setup_env.sh}"
cluster=${TREW_SLURM_CLUSTER:-htc}
logdir=${TREW_LOG_DIR:-$TREW_DATA_ROOT/logs}
stagger=${TREW_STAGGER_MIN:-5}
maxconc=${TREW_MAX_CONCURRENT:-20}
script="$(cd "$(dirname "$0")" && pwd)/fmriprep_arraybatch.sh"
mkdir -p "$logdir"

nsub=$(ls -d "$TREW_DATA_ROOT"/rawdata/sub-* | wc -l)
out="-o $logdir/%x-%A-%a.out -e $logdir/%x-%A-%a.err"

first=$(sbatch --parsable --clusters="$cluster" $out --array=0 "$script" | cut -d';' -f1)
echo "Submitted first subject: job $first"
if [ "$nsub" -gt 1 ]; then
  rest=$(sbatch --parsable --clusters="$cluster" $out \
    --dependency="after:${first}+${stagger}" \
    --array="1-$((nsub-1))%${maxconc}" "$script" | cut -d';' -f1)
  echo "Submitted remaining $((nsub-1)) subjects: job $rest (starts ${stagger} min after $first begins)"
fi
