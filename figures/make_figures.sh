#!/bin/bash
# Generate univariate figure panels with fsleyes render.
#
# Matches the slice positions used in the manuscript figures:
#   axial z = -20, -12, 8, 25, 48   and   sagittal x = -3
# Activation (zstat1) in red-yellow, deactivation (zstat2) in blue-lightblue,
# both scaled 0-7 as in the original colour bar.
#
# fsleyes render cannot put axial and sagittal views in one image, and cannot
# pick arbitrary non-uniform slices in lightbox mode. So this writes each slice
# as a separate PNG and leaves the compositing to Photoshop, which is what you
# were doing anyway.
#
# Usage:
#   ./make_figures.sh                 # all contrasts in CONTRASTS below
#   ./make_figures.sh dyscontrolmod/SARTdcBaseline
#
# Output: $OUTDIR/<model>_<contrast>_z<NN>.png  and  ..._x-3.png

set -uo pipefail

ROOT=${TREW_GROUP_DIR}/
OUTDIR=${TREW_DATA_ROOT}/figures
MNI=$FSLDIR/data/standard/MNI152_T1_2mm_brain

# Slices from the existing figures
AXIAL_Z=(-20 -12 8 25 48)
SAG_X=(-3)

# Colour scaling (matches the z=0..7 bar in the manuscript figure)
ZMIN=0
ZMAX=7

# Contrasts to render: paths relative to ROOT, without the .gfeat suffix
CONTRASTS=(
  dyscontrolmod/SARTdcBaseline
  dyscontrolandeffortmods/SARTdcBaseline
  dyscontrolmod/ThoughtdcBaseline
  dyscontrolandACCmods/ThoughtblockdcBaseline
  ACCmod/SARTACCbaseline
  dyscontrolmod/ThoughtdcSARTdc
)

# ---------------------------------------------------------------------------

if [[ -z "${FSLDIR:-}" ]]; then
  echo "ERROR: FSLDIR not set. Run: module load fsl" >&2
  exit 1
fi
command -v fsleyes >/dev/null || { echo "ERROR: fsleyes not on PATH" >&2; exit 1; }

mkdir -p "$OUTDIR"

# Allow a single contrast as an argument
if [[ $# -ge 1 ]]; then
  CONTRASTS=("$@")
fi

render_one() {
  local statdir=$1 tag=$2 axis=$3 coord=$4 outfile=$5
  local pos=$6   # thresh_zstat1 (activation)
  local neg=$7   # thresh_zstat2 (deactivation)

  local -a overlays=()
  if [[ -s "$neg" ]]; then
    overlays+=("$neg" --cmap blue-lightblue --displayRange "$ZMIN" "$ZMAX")
  fi
  if [[ -s "$pos" ]]; then
    overlays+=("$pos" --cmap red-yellow --displayRange "$ZMIN" "$ZMAX")
  fi
  if [[ ${#overlays[@]} -eq 0 ]]; then
    echo "    no stat maps for $tag; skipping"
    return
  fi

  # --scene ortho with two axes hidden gives a single clean slice.
  local hide
  case "$axis" in
    z) hide=(--hidex --hidey) ;;
    x) hide=(--hidey --hidez) ;;
    y) hide=(--hidex --hidez) ;;
  esac

  local loc
  case "$axis" in
    z) loc=(0 0 "$coord") ;;
    x) loc=("$coord" 0 0) ;;
    y) loc=(0 "$coord" 0) ;;
  esac

  fsleyes render \
    --scene ortho \
    --outfile "$outfile" \
    --hideCursor --hideLabels \
    "${hide[@]}" \
    --worldLoc "${loc[@]}" \
    --size 600 600 \
    "$MNI" --cmap greyscale \
    "${overlays[@]}" \
    2>&1 | grep -v '^$' | sed 's/^/      /'
}

for c in "${CONTRASTS[@]}"; do
  statdir="$ROOT/${c}.gfeat/cope1.feat"
  if [[ ! -d "$statdir" ]]; then
    echo "SKIP $c: no $statdir" >&2
    continue
  fi

  tag=$(echo "$c" | tr '/' '_')
  pos="$statdir/thresh_zstat1.nii.gz"
  neg="$statdir/thresh_zstat2.nii.gz"

  echo "=== $c"
  [[ -s "$pos" ]] && echo "    activation:   thresh_zstat1" || echo "    activation:   (none)"
  [[ -s "$neg" ]] && echo "    deactivation: thresh_zstat2" || echo "    deactivation: (none)"

  for z in "${AXIAL_Z[@]}"; do
    out="$OUTDIR/${tag}_z${z}.png"
    echo "    -> $(basename "$out")"
    render_one "$statdir" "$tag" z "$z" "$out" "$pos" "$neg"
  done

  for x in "${SAG_X[@]}"; do
    out="$OUTDIR/${tag}_x${x}.png"
    echo "    -> $(basename "$out")"
    render_one "$statdir" "$tag" x "$x" "$out" "$pos" "$neg"
  done

  echo
done

echo "Wrote PNGs to $OUTDIR"
echo
echo "Notes:"
echo "  - One PNG per slice; composite in Photoshop as before."
echo "  - If the colour scaling looks wrong, adjust ZMIN/ZMAX at the top."
echo "  - fsleyes has no 3D render equivalent to MRIcroGL's; that panel"
echo "    still needs MRIcroGL or an alternative."
