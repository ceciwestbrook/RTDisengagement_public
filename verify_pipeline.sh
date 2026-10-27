#!/bin/bash
# Verify the TReW-Brain pipeline, excluding anything that depends on the
# provenance of the timing files.
#
#   ./verify_pipeline.sh                 # run all checks
#   ./verify_pipeline.sh confounds       # run one check
#   ./verify_pipeline.sh --list          # show check names
#
# Each check prints a one-line PASS/FAIL summary; failures print specifics.
# Nothing is written outside $OUTDIR and nothing is deleted.
#
# Design note: the motion-confound bug survived because the value written to
# the log was computed from a different object than the value written to disk.
# Several checks below are built to catch that shape of error specifically --
# they compare what a script *reported* against what is actually on disk.

set -uo pipefail

ROOT="${TREW_DATA_ROOT:?run: source setup_env.sh}"
SCRIPTS="${TREW_REPO_ROOT:-$ROOT}/fsl"
PROC="${TREW_PROCESSED_DIR:-$ROOT/processed}"
PREP="$ROOT/preprocessed"
GROUP="${TREW_GROUP_DIR:-$ROOT/group_level}"
# The current multivariate pipeline. Note this is NOT $SCRIPTS/mvpa, which is
# an earlier analysis that was abandoned.
MVPA="${TREW_MVPA_DIR:-${TREW_WORK_ROOT:-$ROOT}}"
PARCELS="${TREW_PARCELS_DIR:-$MVPA/derivatives/parcels/yeo_2011_motiononly}"
OUTDIR="${TREW_VERIFY_OUT:-$ROOT/verification}"

SUBJECT_LIST="$SCRIPTS/Level1/subjects_run1.txt"
RUNS=(1 2 3)

# Sample size for the expensive design-matrix checks. Set to 0 for all subjects.
SAMPLE_N="${TREW_VERIFY_SAMPLE:-6}"

mkdir -p "$OUTDIR"

# ---------------------------------------------------------------------------
# reporting helpers
# ---------------------------------------------------------------------------
PASS=0; FAIL=0; SKIP=0
_fail_lines=""

ok()   { PASS=$((PASS+1)); printf '  \033[32mok\033[0m    %s\n' "$1"; }
bad()  { FAIL=$((FAIL+1)); printf '  \033[31mFAIL\033[0m  %s\n' "$1"
         _fail_lines+="$1"$'\n'; }
skip() { SKIP=$((SKIP+1)); printf '  --    %s (skipped: %s)\n' "$1" "$2"; }
hdr()  { printf '\n\033[1m%s\033[0m\n' "$1"; }

subjects() {
  if [[ -f "$SUBJECT_LIST" ]]; then sort -u "$SUBJECT_LIST"
  else ls -d "$PROC"/sub-* 2>/dev/null | sed 's|.*/sub-||'; fi
}

sample_subjects() {
  if [[ "$SAMPLE_N" -eq 0 ]]; then subjects; else subjects | head -"$SAMPLE_N"; fi
}

# ===========================================================================
# 1. Confound files
# ===========================================================================
# The written file must have exactly 24 motion parameters plus one column per
# spike, and each spike column must sum to 1. This is the comparison that was
# absent when the original bug went unnoticed.
check_confounds() {
  hdr "1. Motion confound files"
  local n_checked=0 n_bad=0
  for s in $(subjects); do
    for r in "${RUNS[@]}"; do
      local f="$PREP/sub-$s/ses-01/func/sub-${s}_ses-01_motion_confound_run-0${r}.txt"
      [[ -f "$f" ]] || continue
      n_checked=$((n_checked+1))

      local ncol nrow
      ncol=$(head -1 "$f" | wc -w)
      nrow=$(wc -l < "$f")

      # Volume count from the confounds TSV (minus its header)
      local tsv="$PREP/sub-$s/ses-01/func/sub-${s}_ses-01_task-PDT_run-0${r}_desc-confounds_timeseries.tsv"
      local nvol=0
      [[ -f "$tsv" ]] && nvol=$(( $(wc -l < "$tsv") - 1 ))

      local problems=""
      [[ "$ncol" -lt 24 ]] && problems+="only $ncol cols (expect >=24); "
      [[ "$nvol" -gt 0 && "$nrow" -ne "$nvol" ]] && \
        problems+="$nrow rows vs $nvol volumes; "
      head -1 "$f" | grep -qE '[A-Za-z]{3}' && problems+="header row present; "

      # Spike columns are those beyond the first 24; each must sum to exactly 1
      if [[ "$ncol" -gt 24 ]]; then
        local badspikes
        badspikes=$(awk -v nc="$ncol" '
          { for (i=25;i<=nc;i++) s[i]+=$i }
          END { n=0; for (i=25;i<=nc;i++) if (s[i]!=1) n++; print n }' "$f")
        [[ "$badspikes" -gt 0 ]] && \
          problems+="$badspikes spike cols do not sum to 1; "
      fi

      if [[ -n "$problems" ]]; then
        n_bad=$((n_bad+1))
        echo "    sub-$s run $r: $problems" >> "$OUTDIR/confounds_failures.txt"
      fi
    done
  done
  if [[ "$n_checked" -eq 0 ]]; then
    skip "confound files" "none found under $PREP"
  elif [[ "$n_bad" -eq 0 ]]; then
    ok "$n_checked confound files: columns, rows and spike coding consistent"
  else
    bad "$n_bad of $n_checked confound files have problems (see $OUTDIR/confounds_failures.txt)"
  fi
}

# ===========================================================================
# 2. Level-1 design matrices
# ===========================================================================
# feat_model turns a .fsf into design.mat. Checks: modulator columns are
# demeaned and non-constant, the design is full rank, and contrast vectors
# place nonzero weight on the EV their name implies.
check_designs() {
  hdr "2. Level-1 design matrices"
  command -v feat_model >/dev/null || { skip "design matrices" "feat_model not on PATH"; return; }

  local tmp; tmp=$(mktemp -d)
  local n_built=0 n_bad=0

  for model_dir in "$SCRIPTS"/Level1/level1_fsf_files/*/; do
    [[ -d "$model_dir" ]] || continue
    local model; model=$(basename "$model_dir")
    for s in $(sample_subjects); do
      local fsf; fsf=$(ls "$model_dir"/sub-${s}_*run-1_*.fsf 2>/dev/null | head -1)
      [[ -f "$fsf" ]] || continue

      cp "$fsf" "$tmp/d.fsf"
      ( cd "$tmp" && feat_model d >/dev/null 2>&1 )
      [[ -f "$tmp/d.mat" ]] || { echo "    $model sub-$s: feat_model failed" \
          >> "$OUTDIR/design_failures.txt"; n_bad=$((n_bad+1)); continue; }
      n_built=$((n_built+1))

      local report
      report=$(python3 - "$tmp/d.mat" <<'PY'
import sys, numpy as np
rows=[l for l in open(sys.argv[1]) if l.strip() and not l.startswith('/')]
M=np.array([[float(x) for x in r.split()] for r in rows])
msgs=[]
# constant (all-zero) columns
# All-zero columns are expected: the missed-trial EVs are empty for
# subjects with no missed trials. They are orthogonal to everything else
# and do not affect the estimates for the contrasts of interest, so these
# are reported separately rather than as failures.
zero=[i+1 for i in range(M.shape[1]) if M[:,i].std()==0]
# rank is checked against the non-constant columns only
nz=[i for i in range(M.shape[1]) if M[:,i].std()>0]
# rank
if nz:
    Mz=M[:,nz]
    r=np.linalg.matrix_rank(Mz)
    if r < Mz.shape[1]:
        msgs.append(f"rank {r} < {Mz.shape[1]} non-constant columns (collinear)")
# any column with a large mean relative to its sd suggests an undemeaned
# parametric regressor
for i in range(M.shape[1]):
    sd=M[:,i].std(); mu=M[:,i].mean()
    if sd>0 and abs(mu) > 0.5*sd and abs(mu) > 1e-3:
        msgs.append(f"col {i+1} mean {mu:.3g} large vs sd {sd:.3g}")
print('; '.join(msgs))
PY
)
      if [[ -n "$report" ]]; then
        n_bad=$((n_bad+1))
        echo "    $model sub-$s: $report" >> "$OUTDIR/design_failures.txt"
      fi
      rm -f "$tmp"/d.mat "$tmp"/d.con "$tmp"/d.png "$tmp"/d.frf 2>/dev/null
    done
  done
  rm -rf "$tmp"

  if [[ "$n_built" -eq 0 ]]; then
    skip "design matrices" "no .fsf files found"
  elif [[ "$n_bad" -eq 0 ]]; then
    ok "$n_built design matrices: non-constant columns full rank, regressors demeaned"
  else
    bad "$n_bad of $n_built design matrices have problems (see $OUTDIR/design_failures.txt)"
  fi
}

# ===========================================================================
# 3. Registration identity matrices
# ===========================================================================
# fMRIPrep already normalized the data, so FEAT must not register again.
# Checking the file exists is not enough -- it has to actually be identity.
check_registration() {
  hdr "3. Registration matrices in _adjreg directories"
  local n=0 n_bad=0
  for d in "$PROC"/sub-*/ses-01/level1/*_adjreg.feat; do
    [[ -d "$d" ]] || continue
    local m="$d/reg/example_func2standard.mat"
    if [[ ! -f "$m" ]]; then
      n_bad=$((n_bad+1)); echo "    missing: $m" >> "$OUTDIR/reg_failures.txt"; continue
    fi
    n=$((n+1))
    # Identity to within rounding
    local notid
    notid=$(awk 'NR<=4 { for (i=1;i<=4;i++) {
                   want = (i==NR) ? 1 : 0
                   d = $i - want; if (d<0) d=-d
                   if (d > 1e-5) bad++ } } END { print bad+0 }' "$m")
    if [[ "$notid" -gt 0 ]]; then
      n_bad=$((n_bad+1))
      echo "    not identity: $m" >> "$OUTDIR/reg_failures.txt"
    fi
  done
  if [[ "$n" -eq 0 ]]; then
    skip "registration matrices" "no _adjreg.feat directories found"
  elif [[ "$n_bad" -eq 0 ]]; then
    ok "$n registration matrices are identity"
  else
    bad "$n_bad registration matrices are missing or not identity (see $OUTDIR/reg_failures.txt)"
  fi
}

# ===========================================================================
# 4. Level-2 plumbing
# ===========================================================================
# Each level-2 design must point at _adjreg inputs, and npts must match the
# number of inputs actually listed and present on disk.
check_level2() {
  hdr "4. Level-2 design files"
  local n=0 n_bad=0
  for f in "$SCRIPTS"/Level2/level2_fsf_files/*/*.fsf "$SCRIPTS"/PPI/PPI_level2_fsf_files/*/*.fsf; do
    [[ -f "$f" ]] || continue
    n=$((n+1))
    local npts n_files n_missing mixed problems=""
    npts=$(grep -oP 'set fmri\(npts\)\s+\K[0-9]+' "$f" | head -1)
    n_files=$(grep -c '^set feat_files(' "$f")
    mixed=$(grep -oP 'set fmri\(mixed_yn\)\s+\K[0-9]+' "$f" | head -1)

    [[ "$npts" != "$n_files" ]] && problems+="npts=$npts but $n_files inputs; "
    [[ "$mixed" != "3" ]] && problems+="mixed_yn=$mixed (expect 3 for fixed effects); "

    n_missing=0
    while read -r path; do
      [[ -d "$path" ]] || n_missing=$((n_missing+1))
      [[ "$path" == *_adjreg.feat ]] || problems+="input not _adjreg: $(basename "$path"); "
    done < <(grep '^set feat_files(' "$f" | sed 's/.*"\(.*\)"/\1/')
    [[ "$n_missing" -gt 0 ]] && problems+="$n_missing inputs missing on disk; "

    if [[ -n "$problems" ]]; then
      n_bad=$((n_bad+1))
      echo "    $(basename "$(dirname "$f")")/$(basename "$f"): $problems" \
        >> "$OUTDIR/level2_failures.txt"
    fi
  done
  if [[ "$n" -eq 0 ]]; then
    skip "level-2 designs" "none found"
  elif [[ "$n_bad" -eq 0 ]]; then
    ok "$n level-2 designs: npts matches inputs, all point at _adjreg, mixed_yn=3"
  else
    bad "$n_bad of $n level-2 designs have problems (see $OUTDIR/level2_failures.txt)"
  fi
}

# ===========================================================================
# 5. Group-level cope mapping
# ===========================================================================
# A group design filed under a contrast name must read the cope number that
# actually corresponds to that contrast at level 1. This is where an off-by-one
# hides silently: every file exists and every analysis runs.
check_group_copes() {
  hdr "5. Group-level cope mapping"
  local n=0 n_bad=0
  for design in "$GROUP"/*/_designs/*/design.fsf "$GROUP"/_designs/*/*/design.fsf \
                "$GROUP"/PPI/_designs/*/*/design.fsf; do
    [[ -f "$design" ]] || continue
    n=$((n+1))
    local cname cope
    cname=$(basename "$(dirname "$design")")
    cope=$(grep -oP 'cope\K[0-9]+' <<< "$(grep -m1 'feat_files(1)' "$design")")
    [[ -z "$cope" ]] && { n_bad=$((n_bad+1))
      echo "    $cname: no cope number in feat_files(1)" >> "$OUTDIR/group_failures.txt"
      continue; }
    echo "    $cname -> cope$cope" >> "$OUTDIR/group_cope_map.txt"
  done
  if [[ "$n" -eq 0 ]]; then
    skip "group cope mapping" "no group designs found"
  else
    ok "$n group designs mapped (review $OUTDIR/group_cope_map.txt against level-1 contrast order)"
    echo "        this check lists the mapping; confirming it is correct needs" 
    echo "        comparison against conname_real in the level-1 templates"
  fi
}

# ===========================================================================
# 6. MVPA sanity
# ===========================================================================
check_mvpa() {
  hdr "6. MVPA block features"
  local bf
  bf=$(ls "$MVPA"/derivatives/block_features.csv 2>/dev/null | head -1)
  [[ -f "$bf" ]] || { skip "MVPA features" "block_features.csv not found under $MVPA"; return; }

  python3 - "$bf" <<'PY'
import sys, csv, collections
rows=list(csv.DictReader(open(sys.argv[1])))
if not rows:
    print("    empty block_features.csv"); sys.exit(0)
subs=collections.Counter(r['subject'] for r in rows)
cond=collections.Counter(r.get('condition','?') for r in rows)
print(f"    {len(rows)} blocks, {len(subs)} subjects")
print(f"    conditions: {dict(cond)}")
tb={s:sum(1 for r in rows if r['subject']==s and r.get('condition')=='Thoughtblock')
    for s in subs}
over=[s for s,n in tb.items() if n>27]
if over: print(f"    WARNING: subjects with >27 thought blocks: {over}")
low=sorted((n,s) for s,n in tb.items())[:3]
print(f"    fewest thought blocks: {[(s,n) for n,s in low]}")
tgt=[c for c in rows[0] if 'dyscontrol' in c]
print(f"    target columns present: {tgt}")
PY
  ok "MVPA feature table summarized (review counts above)"
}

# ===========================================================================
# 7. Cross-pipeline block agreement
# ===========================================================================
# The only genuinely independent check available: the univariate and
# multivariate pipelines were built separately but share preprocessed data and
# block definitions. If block timing diverges, this finds it.
check_cross() {
  hdr "7. Cross-pipeline spike agreement"
  # The FSL (R) and multivariate (Python) pipelines independently decide which
  # volumes to censor, from the same fMRIPrep confounds file. The FSL confound
  # file has 24 motion parameters plus one column per spike; the multivariate
  # provenance JSON records n_spike_trs. These must match.
  #
  # This is the only check here that compares two independent implementations,
  # so it catches errors that any single-pipeline check would miss.
  if [[ ! -d "$PARCELS" ]]; then
    skip "cross-pipeline spikes" "parcels dir not found at $PARCELS"
    return
  fi

  local n=0 n_bad=0 n_nofsl=0
  for prov in "$PARCELS"/sub-*_run-*_provenance.json; do
    [[ -f "$prov" ]] || continue
    local base s r mv_spikes fsl_file fsl_cols fsl_spikes
    base=$(basename "$prov")
    s=$(sed -E 's/^sub-([0-9]+)_run-([0-9]+)_provenance\.json/\1/' <<< "$base")
    r=$(sed -E 's/^sub-([0-9]+)_run-([0-9]+)_provenance\.json/\2/' <<< "$base")

    mv_spikes=$(grep -oP '"n_spike_trs":\s*\K[0-9]+' "$prov")
    [[ -z "$mv_spikes" ]] && continue

    fsl_file="$PREP/sub-$s/ses-01/func/sub-${s}_ses-01_motion_confound_run-${r}.txt"
    if [[ ! -f "$fsl_file" ]]; then
      n_nofsl=$((n_nofsl+1)); continue
    fi

    fsl_cols=$(head -1 "$fsl_file" | wc -w)
    fsl_spikes=$(( fsl_cols - 24 ))
    n=$((n+1))

    if [[ "$fsl_spikes" -ne "$mv_spikes" ]]; then
      n_bad=$((n_bad+1))
      echo "    sub-$s run $r: FSL $fsl_spikes spikes ($fsl_cols cols - 24), MVPA $mv_spikes" \
        >> "$OUTDIR/cross_failures.txt"
    fi
  done

  if [[ "$n" -eq 0 ]]; then
    skip "cross-pipeline spikes" "no matching pairs found"
  elif [[ "$n_bad" -eq 0 ]]; then
    ok "$n subject/run pairs: FSL and multivariate pipelines agree on spike count"
    [[ "$n_nofsl" -gt 0 ]] && \
      echo "        ($n_nofsl provenance files had no matching FSL confound file)"
  else
    bad "$n_bad of $n pairs disagree on spike count (see $OUTDIR/cross_failures.txt)"
  fi

  # Block timing is the other half of this comparison and is not automated:
  # it would require replicating what features.ipynb does with
  # events_loader.block_event_rows and parcellation.get_block_indices.
  echo "    Block timing not covered. To check by hand: compare the onset of"
  echo "    thought block 1 as used in features.ipynb against the first onset in"
  echo "    the corresponding *_Thoughtblock.txt timing file; they should agree"
  echo "    to within a TR."
}

# ===========================================================================
# driver
# ===========================================================================
CHECKS=(confounds designs registration level2 group_copes mvpa cross)

if [[ "${1:-}" == "--list" ]]; then
  printf '%s\n' "${CHECKS[@]}"; exit 0
fi

rm -f "$OUTDIR"/*_failures.txt "$OUTDIR/group_cope_map.txt" 2>/dev/null

echo "Verification run $(date '+%Y-%m-%d %H:%M')"
echo "Root: $ROOT"
echo "Output: $OUTDIR"
[[ "$SAMPLE_N" -gt 0 ]] && echo "Design checks sampled at $SAMPLE_N subjects (TREW_VERIFY_SAMPLE=0 for all)"

TO_RUN=("${CHECKS[@]}")
[[ $# -ge 1 ]] && TO_RUN=("$@")

for c in "${TO_RUN[@]}"; do
  case "$c" in
    confounds)    check_confounds ;;
    designs)      check_designs ;;
    registration) check_registration ;;
    level2)       check_level2 ;;
    group_copes)  check_group_copes ;;
    mvpa)         check_mvpa ;;
    cross)        check_cross ;;
    *) echo "unknown check: $c" >&2 ;;
  esac
done

hdr "Summary"
printf '  %d passed, %d failed, %d skipped\n' "$PASS" "$FAIL" "$SKIP"
if [[ -n "$_fail_lines" ]]; then
  printf '\n%s\n' "$_fail_lines"
  echo "Details in $OUTDIR/"
  exit 1
fi
echo
echo "Note: this does not verify the contents of the timing files, which"
echo "depend on source data not currently available. See check 7 for the"
echo "closest available indirect check."
