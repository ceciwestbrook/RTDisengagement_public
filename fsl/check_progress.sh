#!/bin/bash
# Count completed level-1 FEAT analyses per model.
#
# Uses a single shell glob rather than a recursive walk, so it is much faster
# on a busy filesystem. Completion marker is stats/cope1.nii.gz, which FEAT
# writes at the end of the stats stage.
#
# Usage:
#   ./check_progress.sh                      # print to terminal
#   ./check_progress.sh > ./progress.txt     # save
#   nohup ./check_progress.sh > ./progress_$(date +%m%d_%H%M).txt 2>&1 &

PROC=${TREW_PROCESSED_DIR}/
N_EXPECTED=171   # 57 subjects x 3 runs

echo "Checked: $(date)"
echo

echo "=== Completed level-1 analyses (stats/cope1.nii.gz present) ==="
ls -d $PROC/sub-*/ses-01/level1/*/stats/cope1.nii.gz 2>/dev/null \
  | sed 's|.*/run[0-9]*_\(.*\)\.feat/stats.*|\1|' \
  | sort | uniq -c | sort -rn \
  | awk -v exp=$N_EXPECTED '{printf "  %-42s %4d / %d\n", $2, $1, exp}'

echo
echo "=== adjreg copies (reg/standard.nii.gz present) ==="
ls -d $PROC/sub-*/ses-01/level1/*_adjreg.feat/reg/standard.nii.gz 2>/dev/null \
  | sed 's|.*/run[0-9]*_\(.*\)_adjreg\.feat/reg.*|\1|' \
  | sort | uniq -c | sort -rn \
  | awk -v exp=$N_EXPECTED '{printf "  %-42s %4d / %d\n", $2, $1, exp}'

echo
echo "=== level-2 outputs (.gfeat directories) ==="
ls -d $PROC/sub-*/ses-01/level2/*.gfeat 2>/dev/null \
  | sed 's|.*/\(.*\)\.gfeat|\1|' \
  | sort | uniq -c | sort -rn \
  | awk '{printf "  %-42s %4d / 57\n", $2, $1}'

echo
echo "=== SLURM queue (htc) ==="
squeue -u "$USER" -M htc -h -r -o '%T' 2>/dev/null | sort | uniq -c \
  | awk '{printf "  %-12s %4d\n", $2, $1}'
if [[ -z "$(squeue -u "$USER" -M htc -h -r 2>/dev/null)" ]]; then
  echo "  (queue empty)"
fi

echo
echo "=== recent job states ==="
sacct -u "$USER" -M htc --format=State --noheader 2>/dev/null \
  | awk '{print $1}' | sort | uniq -c | sort -rn \
  | awk '{printf "  %-14s %4d\n", $2, $1}'
