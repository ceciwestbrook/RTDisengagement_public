#!/bin/bash
# Small-volume-corrected H3 tests.
#
# Takes a group-level FLAME design and, for each 2023 disengagement mask,
# writes a single-contrast version with:
#   threshmask    -> that mask
#   one contrast  -> +1 or -1, whichever matches the mask's definition
#   thresh        -> 3 (cluster), z = 3.1, p < 0.05
#   outputdir     -> a per-mask directory under svc/
# then submits each via sbatch.
#
# Sign logic (dyscontrol modulator: +1 = activity rises with WORSE disengagement):
#   masks defined by SUCCESS  -> pair with -1  (FPN/SN up with better disengagement)
#   masks defined by FAILURE  -> pair with +1  (DMN up with worse disengagement)
# For an ACCURACY modulator this inverts; see --model accuracy below.
#
# Usage:
#   ./run_svc_analyses.sh                      # dry run
#   ./run_svc_analyses.sh --go                 # write designs, no submission
#   ./run_svc_analyses.sh --go --slurm         # write and submit
#   ./run_svc_analyses.sh --model accuracy ... # for SARTACCbaseline

set -euo pipefail

# ---------------------------------------------------------------- config
PROJ="${TREW_DATA_ROOT}/"
MASKDIR="$PROJ/Scripts/ROI_analyses/ROIs"
DESIGN_ROOT="$PROJ/group_level_flame1/_designs"
OUT_ROOT="$PROJ/group_level_flame1/svc"

SRC_MODEL="dyscontrolmod/SARTdcBaseline"       # overridden by --model accuracy
MODTYPE="dyscontrol"

SLURM_TIME="12:00:00"
SLURM_MEM="16G"
SLURM_CPUS="4"
SLURM_PARTITION="smp"
SLURM_LOGDIR="$OUT_ROOT/slurm_logs"

# ---------------------------------------------------------------- args
DRY_RUN=1; SUBMIT="none"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --go) DRY_RUN=0; shift ;;
    --slurm) SUBMIT="slurm"; shift ;;
    --model)
      case "$2" in
        dyscontrol) SRC_MODEL="dyscontrolmod/SARTdcBaseline"; MODTYPE="dyscontrol" ;;
        accuracy)   SRC_MODEL="ACCmod/SARTACCbaseline";       MODTYPE="accuracy" ;;
        *) echo "--model must be dyscontrol or accuracy" >&2; exit 1 ;;
      esac
      shift 2 ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

SRC_FSF="$DESIGN_ROOT/$SRC_MODEL/design.fsf"
MODEL_NAME="$(basename "$SRC_MODEL")"

# ---------------------------------------------------------------- pairings
# mask_basename : defined_by  (success | failure)
MASKS=(
  "DisengagementWNnoWorry_maskpos:success"
  "DisengagementWNnoWorry_maskneg:failure"
  "DisengagementWNyesWorry_maskpos:failure"
  "DisengagementWNyesWorry_maskneg:success"
  "DisengagementWNyesno_maskpos:failure"
  "DisengagementWNyesno_maskneg:success"
)

# For a dyscontrol modulator, success-defined masks pair with -1.
# For an accuracy modulator (accuracy runs with success), that inverts.
sign_for() {
  local defined_by="$1"
  if [[ "$MODTYPE" == "dyscontrol" ]]; then
    [[ "$defined_by" == "success" ]] && echo "-1.0" || echo "1.0"
  else
    [[ "$defined_by" == "success" ]] && echo "1.0" || echo "-1.0"
  fi
}

# ---------------------------------------------------------------- checks
[[ -f "$SRC_FSF" ]] || { echo "ERROR: source design not found: $SRC_FSF" >&2; exit 1; }
[[ -d "$MASKDIR" ]] || { echo "ERROR: mask directory not found: $MASKDIR" >&2; exit 1; }
if [[ "$SUBMIT" != "none" ]] && ! command -v sbatch >/dev/null 2>&1; then
  echo "ERROR: sbatch not found." >&2; exit 1
fi

src_mixed=$(grep -oP '(?<=set fmri\(mixed_yn\) )\S+' "$SRC_FSF" || echo "?")
if [[ "$src_mixed" != "2" ]]; then
  echo "ERROR: source design has mixed_yn=$src_mixed, expected 2 (FLAME 1)." >&2
  echo "       Point --model at a design under group_level_flame1/_designs." >&2
  exit 1
fi

echo "Source design : $SRC_FSF  (mixed_yn=$src_mixed)"
echo "Modulator     : $MODTYPE"
echo "Masks         : $MASKDIR"
echo "Output        : $OUT_ROOT/$SRC_MODEL"
[[ $DRY_RUN -eq 1 ]] && echo "=== DRY RUN — use --go to write, --slurm to submit ==="
echo

printf '%-42s %-9s %-7s %9s %12s\n' "MASK" "DEFINED" "SIGN" "VOXELS" "BINARY"
printf '%-42s %-9s %-7s %9s %12s\n' "----" "-------" "----" "------" "------"

TO_RUN=()

for entry in "${MASKS[@]}"; do
  mask="${entry%%:*}"
  defined_by="${entry##*:}"
  sign="$(sign_for "$defined_by")"

  # resolve the mask file (FSL accepts a prefix, but verify something exists)
  mpath=""
  for ext in ".nii.gz" ".nii" ""; do
    if [[ -f "$MASKDIR/$mask$ext" ]]; then mpath="$MASKDIR/$mask$ext"; break; fi
  done
  if [[ -z "$mpath" ]]; then
    printf '%-42s %-9s %-7s %9s %12s\n' "$mask" "$defined_by" "$sign" "MISSING" "-"
    continue
  fi

  # verify it is an image and binary
  if ! stats=$(fslstats "$MASKDIR/$mask" -R -V 2>/dev/null); then
    printf '%-42s %-9s %-7s %9s %12s\n' "$mask" "$defined_by" "$sign" "NOT-IMAGE" "-"
    continue
  fi
  read -r mn mx nvox _ <<< "$stats"
  binary="yes"
  awk -v a="$mn" -v b="$mx" 'BEGIN{exit !(a==0 && b==1)}' || binary="NO"

  printf '%-42s %-9s %-7s %9s %12s\n' "$mask" "$defined_by" "$sign" "$nvox" "$binary"
  [[ "$binary" == "NO" ]] && { echo "  !! not binary (range $mn-$mx); skipping" >&2; continue; }

  tag="${mask}_$( [[ "$sign" == "1.0" ]] && echo pos || echo neg )"
  outdir="$OUT_ROOT/$SRC_MODEL/${MODEL_NAME}_${tag}"
  fsfdir="$OUT_ROOT/_designs/$SRC_MODEL"
  newfsf="$fsfdir/design_${tag}.fsf"

  if [[ $DRY_RUN -eq 1 ]]; then
    echo "   design  : $newfsf"
    echo "   output  : $outdir  (FEAT creates ${outdir}.gfeat)"
    echo "   contrast: con_real1.1 = $sign"
    echo
    continue
  fi

  mkdir -p "$fsfdir" "$(dirname "$outdir")"

  # Reduce to a single contrast: drop all *_real.2 / con_real2.* lines and the
  # conmask lines that reference contrast 2, then set contrast 1's sign.
  grep -v -E '^set fmri\((conpic_real\.2|conname_real\.2|con_real2\.[0-9]+|conmask1_2|conmask2_1)\)' "$SRC_FSF" \
  | sed -e 's|^set fmri(ncon_real) .*$|set fmri(ncon_real) 1|' \
        -e 's|^set fmri(ncon_orig) .*$|set fmri(ncon_orig) 1|' \
        -e "s|^set fmri(con_real1\.1) .*\$|set fmri(con_real1.1) $sign|" \
        -e "s|^set fmri(conname_real\.1) .*\$|set fmri(conname_real.1) \"${tag}\"|" \
        -e 's|^set fmri(thresh) .*$|set fmri(thresh) 3|' \
        -e 's|^set fmri(poststats_yn) .*$|set fmri(poststats_yn) 1|' \
        -e 's|^set fmri(z_thresh) .*$|set fmri(z_thresh) 3.1|' \
        -e 's|^set fmri(prob_thresh) .*$|set fmri(prob_thresh) 0.05|' \
        -e "s|^set fmri(threshmask) .*\$|set fmri(threshmask) \"$MASKDIR/$mask\"|" \
        -e "s|^set fmri(outputdir) .*\$|set fmri(outputdir) \"$outdir\"|" \
  > "$newfsf"

  # verify
  ok=1
  [[ "$(grep -oP '(?<=set fmri\(con_real1\.1\) )\S+' "$newfsf")" == "$sign" ]] || { echo "  !! sign not set" >&2; ok=0; }
  [[ "$(grep -oP '(?<=set fmri\(ncon_real\) )\S+' "$newfsf")" == "1" ]] || { echo "  !! ncon_real not 1" >&2; ok=0; }
  grep -q "threshmask) \"$MASKDIR/$mask\"" "$newfsf" || { echo "  !! threshmask not set" >&2; ok=0; }
  grep -q "outputdir) \"$outdir\"" "$newfsf" || { echo "  !! outputdir not set" >&2; ok=0; }
  grep -q 'con_real2' "$newfsf" && { echo "  !! contrast 2 lines remain" >&2; ok=0; }
  [[ $ok -eq 1 ]] || continue

  echo "   wrote $newfsf"
  TO_RUN+=("$newfsf")
done

echo
[[ $DRY_RUN -eq 1 ]] && { echo "Dry run complete."; exit 0; }
echo "${#TO_RUN[@]} design(s) ready."

case "$SUBMIT" in
  none)
    for f in "${TO_RUN[@]}"; do echo "  feat $f"; done ;;
  slurm)
    mkdir -p "$SLURM_LOGDIR"
    for f in "${TO_RUN[@]}"; do
      name="$(basename "$f" .fsf)"
      jid=$(sbatch --parsable \
            --job-name="svc_${name}" \
            --time="$SLURM_TIME" --mem="$SLURM_MEM" \
            --cpus-per-task="$SLURM_CPUS" --partition="$SLURM_PARTITION" \
            --output="$SLURM_LOGDIR/${name}_%j.out" \
            --error="$SLURM_LOGDIR/${name}_%j.err" \
            --wrap="feat $f")
      echo "submitted $name as job $jid"
    done
    echo "Logs: $SLURM_LOGDIR" ;;
esac
