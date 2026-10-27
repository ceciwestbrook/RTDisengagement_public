#!/bin/bash
# Submit level-1 FEAT arrays for several models across all three runs.
#
# The per-model wrapper scripts hardcode `run=N`, so this edits that line,
# submits, and moves on. Each submission is a separate array job.
#
# Usage:
#   ./submit_level1.sh              # dry run: show what would be submitted
#   ./submit_level1.sh --go         # actually submit
#
# After it finishes, the run= line is left at 3 in each wrapper.

set -uo pipefail

SCRIPTDIR=${TREW_REPO_ROOT}/fsl/Level1

# Models to submit. Edit this list as needed.
MODELS=(
  ACCmod
  indivthoughtmod
  dyscontrolandACCmods
  dyscontrolandeffortmods
)

RUNS=(1 2 3)

DRY_RUN=1
[[ "${1:-}" == "--go" ]] && DRY_RUN=0

cd "$SCRIPTDIR" || { echo "ERROR: cannot cd to $SCRIPTDIR" >&2; exit 1; }
mkdir -p log

[[ $DRY_RUN -eq 1 ]] && echo "=== DRY RUN — nothing submitted. Use --go to submit. ===" && echo

for model in "${MODELS[@]}"; do
  wrapper="run_feat_level1_arraybatch_${model}.sh"

  if [[ ! -f "$wrapper" ]]; then
    echo "SKIP $model: no $wrapper" >&2
    continue
  fi

  # Sanity checks before touching anything
  cluster=$(grep -oP '(?<=#SBATCH --cluster=)\S+' "$wrapper" | head -1)
  if [[ "$cluster" != "htc" ]]; then
    echo "SKIP $model: wrapper targets cluster '$cluster', expected htc" >&2
    continue
  fi
  if ! grep -q '^run=' "$wrapper"; then
    echo "SKIP $model: no 'run=' line found in $wrapper" >&2
    continue
  fi

  for run in "${RUNS[@]}"; do
    # Check the designs exist for this model/run before submitting
    n_fsf=$(ls level1_fsf_files/${model}/sub-*_ses-01_fsf-lv1_run-${run}_${model}.fsf 2>/dev/null | wc -l)
    if [[ "$n_fsf" -eq 0 ]]; then
      echo "SKIP $model run $run: no .fsf files in level1_fsf_files/${model}/" >&2
      continue
    fi

    if [[ $DRY_RUN -eq 1 ]]; then
      printf '%-26s run %s : would set run=%s and sbatch (%s design files)\n' \
             "$model" "$run" "$run" "$n_fsf"
      continue
    fi

    # Set the run number, then submit
    sed -i "s|^run=[0-9].*|run=${run} #1, 2 or 3|" "$wrapper"
    actual=$(grep -oP '(?<=^run=)[0-9]+' "$wrapper")
    if [[ "$actual" != "$run" ]]; then
      echo "ERROR: $model run= is '$actual' after edit, expected $run; not submitting" >&2
      continue
    fi

    jid=$(sbatch --parsable "$wrapper" 2>&1)
    if [[ "$jid" =~ ^[0-9]+$ ]]; then
      printf '%-26s run %s : submitted as %s (%s designs)\n' "$model" "$run" "$jid" "$n_fsf"
    else
      echo "ERROR submitting $model run $run: $jid" >&2
      continue
    fi

    # Small pause so the next sed does not race a still-reading sbatch
    sleep 3
  done
done

echo
if [[ $DRY_RUN -eq 1 ]]; then
  echo "Dry run complete."
else
  echo "Queue:"
  squeue -u "$USER" -M htc -h -r -o '%T' 2>/dev/null | sort | uniq -c
fi
