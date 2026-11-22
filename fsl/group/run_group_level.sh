#!/bin/bash
# Expand the group-level FLAME designs and (optionally) run them.
#
# The designs under fsl/group/designs/<model>/<contrast>/design.fsf contain shell variables
# (${TREW_PROCESSED_DIR}, ${TREW_GROUP_DIR}, ${FSLDIR}) that FEAT does not expand, so each
# design is expanded into $TREW_GROUP_DIR/_designs/<model>/<contrast>/design.fsf first.
# A design is only written if all of its level-2 inputs exist.
#
#   ./run_group_level.sh                         # dry run: inputs found per design
#   ./run_group_level.sh --go                    # write the expanded designs
#   ./run_group_level.sh --go --slurm            # ... and submit one FEAT job per design
#   ./run_group_level.sh --go dyscontrolmod      # only the named model(s)
#
# Needs:  source setup_env.sh ; module load fsl
# Optional: TREW_SLURM_CLUSTER (default htc), TREW_GROUP_MEM (default 16G), TREW_GROUP_TIME (default 12:00:00)

set -euo pipefail
: "${TREW_REPO_ROOT:?run: source setup_env.sh}"
: "${TREW_DATA_ROOT:?run: source setup_env.sh}"
: "${TREW_PROCESSED_DIR:?run: source setup_env.sh}"
: "${TREW_GROUP_DIR:?run: source setup_env.sh}"
: "${FSLDIR:?run: module load fsl}"

GO=0; SLURM=0; MODELS=()
for a in "$@"; do
  case "$a" in
    --go) GO=1 ;;
    --slurm) SLURM=1 ;;
    -*) echo "unknown option: $a" >&2; exit 2 ;;
    *) MODELS+=("$a") ;;
  esac
done
if [[ $SLURM -eq 1 && $GO -eq 0 ]]; then echo "--slurm needs --go" >&2; exit 2; fi

DESIGNS="$TREW_REPO_ROOT/fsl/group/designs"
OUT="$TREW_GROUP_DIR/_designs"
VARS='${TREW_REPO_ROOT} ${TREW_DATA_ROOT} ${TREW_PROCESSED_DIR} ${TREW_GROUP_DIR} ${FSLDIR}'
CLUSTER="${TREW_SLURM_CLUSTER:-htc}"
if [[ ${#MODELS[@]} -eq 0 ]]; then mapfile -t MODELS < <(ls "$DESIGNS"); fi

n_written=0; n_blocked=0
for model in "${MODELS[@]}"; do
  [[ -d "$DESIGNS/$model" ]] || { echo "no such model: $model" >&2; exit 1; }
  for src in "$DESIGNS/$model"/*/design.fsf; do
    contrast=$(basename "$(dirname "$src")")
    tmp=$(mktemp)
    envsubst "$VARS" < "$src" > "$tmp"

    n_in=0; n_miss=0; first_missing=""
    while IFS= read -r p; do
      n_in=$((n_in + 1))
      if [[ ! -d "$p" ]]; then
        n_miss=$((n_miss + 1)); [[ -z "$first_missing" ]] && first_missing="$p"
      fi
    done < <(sed -nE 's/^set feat_files\([0-9]+\) "(.*)"$/\1/p' "$tmp")

    printf '%-26s %-20s inputs %3d, missing %3d' "$model" "$contrast" "$n_in" "$n_miss"
    if [[ $n_miss -gt 0 ]]; then
      printf '  -> NOT written (first missing: %s)\n' "$first_missing"
      n_blocked=$((n_blocked + 1)); rm -f "$tmp"; continue
    fi
    if [[ $GO -eq 0 ]]; then printf '\n'; rm -f "$tmp"; continue; fi

    dest="$OUT/$model/$contrast/design.fsf"
    mkdir -p "$(dirname "$dest")"
    outdir=$(sed -nE 's/^set fmri\(outputdir\) "(.*)"$/\1/p' "$tmp")
    mkdir -p "$(dirname "$outdir")"
    mv "$tmp" "$dest"
    n_written=$((n_written + 1))

    if [[ $SLURM -eq 1 ]]; then
      mkdir -p "$OUT/logs"
      jid=$(sbatch --parsable --clusters="$CLUSTER" -J "grp_${model}_${contrast}" \
            --time="${TREW_GROUP_TIME:-12:00:00}" --mem="${TREW_GROUP_MEM:-16G}" \
            -o "$OUT/logs/%x-%j.out" -e "$OUT/logs/%x-%j.err" \
            --wrap "module load fsl; feat $dest")
      printf '  -> written, submitted as %s\n' "$jid"
    else
      printf '  -> written\n'
    fi
  done
done
echo "designs written: $n_written, blocked by missing inputs: $n_blocked"
