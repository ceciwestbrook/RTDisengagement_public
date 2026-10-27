#!/bin/bash
# Summarize cluster results across a tree of higher-level FEAT (.gfeat) outputs.
#
# For every contrast in every .gfeat, reports: number of surviving clusters,
# max Z, peak coordinates, and total suprathreshold voxels. Optionally diffs
# a new tree against an old one so you can see what changed.
#
# Usage:
#   ./summarize_feat_clusters.sh /path/to/group_level_flame1
#   ./summarize_feat_clusters.sh /path/to/group_level_flame1 --csv > results.csv
#   ./summarize_feat_clusters.sh /path/to/group_level_flame1 --vs /path/to/group_level
#
# Reads only FEAT's own cluster_zstat*.txt tables. No FSL commands needed,
# so it is safe and fast on a login node.

set -uo pipefail

NEW_ROOT=""
OLD_ROOT=""
FORMAT="table"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --vs)   OLD_ROOT="$2"; shift 2 ;;
    --csv)  FORMAT="csv"; shift ;;
    -h|--help) sed -n '2,16p' "$0"; exit 0 ;;
    *) if [[ -z "$NEW_ROOT" ]]; then NEW_ROOT="$1"; else echo "Unexpected arg: $1" >&2; exit 1; fi; shift ;;
  esac
done

if [[ -z "$NEW_ROOT" ]]; then
  echo "Usage: $0 <gfeat_tree> [--vs <old_tree>] [--csv]" >&2
  exit 1
fi
if [[ ! -d "$NEW_ROOT" ]]; then
  echo "Not a directory: $NEW_ROOT" >&2
  exit 1
fi

# Parse one cluster_zstat*.txt -> "nclusters maxZ peakX peakY peakZ totalvox"
# FEAT cluster tables are tab-delimited with a header line. Column names vary
# slightly by FSL version, so locate them by name rather than by position.
parse_cluster_file() {
  local f="$1"
  [[ -s "$f" ]] || { echo "0 . . . . 0"; return; }
  awk -F'\t' '
    NR==1 {
      for (i=1; i<=NF; i++) {
        h=$i
        gsub(/^[ \t]+|[ \t]+$/, "", h)
        if (h ~ /^Voxels$/)        vcol=i
        if (h ~ /^Z-MAX$/)         zcol=i
        if (h ~ /Z-MAX X \(mm\)/)  xcol=i
        if (h ~ /Z-MAX Y \(mm\)/)  ycol=i
        if (h ~ /Z-MAX Z \(mm\)/)  zzcol=i
      }
      # fall back to voxel coords if mm columns absent
      if (!xcol) { for (i=1;i<=NF;i++) { h=$i; if (h ~ /Z-MAX X/) xcol=i; if (h ~ /Z-MAX Y/) ycol=i; if (h ~ /Z-MAX Z/) zzcol=i } }
      next
    }
    NF < 2 { next }
    {
      n++
      tv += (vcol ? $vcol : 0)
      z = (zcol ? $zcol+0 : 0)
      if (z > maxz) { maxz=z; px=(xcol?$xcol:"."); py=(ycol?$ycol:"."); pz=(zzcol?$zzcol:".") }
    }
    END {
      if (n=="") n=0
      if (maxz=="") { maxz="."; px="."; py="."; pz="." }
      printf "%d %s %s %s %s %d\n", n, (maxz=="."?".":sprintf("%.2f",maxz)), px, py, pz, tv+0
    }
  ' "$f"
}

# Find every cluster table under a tree, emit "key<TAB>parsed"
# key = <model path>|<cope dir>|<zstat name>
collect() {
  local root="$1"
  find "$root" -type f -name 'cluster_zstat*.txt' 2>/dev/null | sort | while read -r f; do
    local copedir modelpath zname rel
    copedir="$(dirname "$f")"
    zname="$(basename "$f")"
    zname="${zname#cluster_}"; zname="${zname%.txt}"       # e.g. zstat1 or zstat1_std
    zname="${zname%_std}"
    rel="${copedir#"$root"/}"
    modelpath="$(dirname "$rel")"                           # .../X.gfeat
    modelpath="${modelpath%.gfeat}"
    printf '%s|%s|%s\t%s\n' "$modelpath" "$(basename "$copedir")" "$zname" "$(parse_cluster_file "$f")"
  done
}

NEW_DATA="$(collect "$NEW_ROOT")"

if [[ -z "$NEW_DATA" ]]; then
  echo "No cluster_zstat*.txt files found under $NEW_ROOT" >&2
  echo "Either the models have not finished, or post-stats did not run" >&2
  echo "(check that poststats_yn was 1 in the design)." >&2
  exit 1
fi

if [[ -n "$OLD_ROOT" ]]; then
  OLD_DATA="$(collect "$OLD_ROOT")"
fi

# ------------------------------------------------------------------ output
if [[ "$FORMAT" == "csv" ]]; then
  if [[ -n "$OLD_ROOT" ]]; then
    echo "model,cope,zstat,n_clusters_new,maxZ_new,voxels_new,n_clusters_old,maxZ_old,voxels_old"
  else
    echo "model,cope,zstat,n_clusters,maxZ,peak_x,peak_y,peak_z,total_voxels"
  fi
fi

if [[ "$FORMAT" == "table" ]]; then
  if [[ -n "$OLD_ROOT" ]]; then
    printf '%-46s %-8s %-8s %10s %8s %10s %8s\n' "MODEL" "COPE" "ZSTAT" "CLUST new" "Zmax" "CLUST old" "Zmax"
    printf '%-46s %-8s %-8s %10s %8s %10s %8s\n' "-----" "----" "-----" "---------" "----" "---------" "----"
  else
    printf '%-46s %-8s %-8s %7s %7s %22s %9s\n' "MODEL" "COPE" "ZSTAT" "CLUST" "Zmax" "PEAK (x y z)" "VOXELS"
    printf '%-46s %-8s %-8s %7s %7s %22s %9s\n' "-----" "----" "-----" "-----" "----" "------------" "------"
  fi
fi

while IFS=$'\t' read -r key vals; do
  [[ -z "$key" ]] && continue
  IFS='|' read -r model cope zstat <<< "$key"
  read -r n maxz px py pz tv <<< "$vals"

  if [[ -n "$OLD_ROOT" ]]; then
    oldline="$(grep -F "$key"$'\t' <<< "${OLD_DATA:-}" | head -1 | cut -f2)"
    if [[ -n "$oldline" ]]; then
      read -r on omaxz _ _ _ otv <<< "$oldline"
    else
      on="-"; omaxz="-"; otv="-"
    fi
    if [[ "$FORMAT" == "csv" ]]; then
      echo "$model,$cope,$zstat,$n,$maxz,$tv,$on,$omaxz,$otv"
    else
      printf '%-46s %-8s %-8s %10s %8s %10s %8s\n' "$model" "$cope" "$zstat" "$n" "$maxz" "$on" "$omaxz"
    fi
  else
    if [[ "$FORMAT" == "csv" ]]; then
      echo "$model,$cope,$zstat,$n,$maxz,$px,$py,$pz,$tv"
    else
      printf '%-46s %-8s %-8s %7s %7s %22s %9s\n' "$model" "$cope" "$zstat" "$n" "$maxz" "$px $py $pz" "$tv"
    fi
  fi
done <<< "$NEW_DATA"

if [[ "$FORMAT" == "table" ]]; then
  echo
  total=$(wc -l <<< "$NEW_DATA")
  empty=$(awk -F'\t' '{split($2,a," "); if (a[1]=="0") c++} END {print c+0}' <<< "$NEW_DATA")
  echo "$total contrast(s) summarized; $empty with no surviving clusters."
  if [[ -n "$OLD_ROOT" ]]; then
    echo "CLUST old = same contrast in $OLD_ROOT (- means not found there)."
  fi
  echo "Note: 'no surviving clusters' means nothing passed the design's threshold,"
  echo "not that the effect is absent. Check unthresholded maps for that."
fi
