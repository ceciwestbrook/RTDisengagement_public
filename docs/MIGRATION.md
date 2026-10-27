# Migrating the existing scripts into this structure

The scripts in the current public repository need three mechanical fixes and
one substantive one before they are moved here. Run these from the root of a
checkout that has the old files in place.

## 1. Substantive: the motion confound script

`fsl/preprocessing/extract_motion_confounds.R` in this repository is the
corrected version. Do not carry the old one across. The difference is at the
column-selection step: the old version computed spike regressors into a local
data frame named `censors`, then selected `motion_outlier` columns from `d`,
fMRIPrep's confounds table, which carries its own differently-defined outlier
columns. The corrected version appends the locally computed spikes.

Anything downstream of the old confound files must be rebuilt: first level,
registration fix, second level, group level.

## 2. The PPI three-way interaction

The level-1 PPI templates set `interactions8.1` to 1, making EV8 a three-way
product of task, modulator and seed. EV8 should be the two-way modulator ×
seed interaction.

```bash
sed -i 's|set fmri(interactions8.1) 1|set fmri(interactions8.1) 0|' \
  fsl/ppi/design_template_level1_*.fsf
grep -h 'interactions8.1)' fsl/ppi/design_template_level1_*.fsf | sort | uniq -c
```

Expect every template to report `0`. Regenerate the `.fsf` files afterwards and
rerun the PPI analyses.

## 3. Hardcoded FSL path

Sixteen files reference an FSL installation path that no longer exists on our
cluster and will not exist on anyone else's.

```bash
grep -rl '/ihome/crc/install/fsl' fsl/ | wc -l
grep -rl '/ihome/crc/install/fsl' fsl/ | xargs sed -i \
  's|/ihome/crc/install/fsl/6.0.7/fsl|${FSLDIR}|g'
```

Then confirm the generators substitute `FSLDIR` when writing `.fsf` files,
since FEAT does not expand shell variables in design files. The generator needs
a line such as:

```bash
sed -e "s|FSLDIRPLACEHOLDER|${FSLDIR}|g" "$template" > "$out"
```

## 4. Scheduler specifics

Fourteen submission scripts hardcode `--cluster=smp`. These are site-specific
and now read from `fsl/config.sh`.

```bash
grep -rl 'cluster=smp' fsl/ | xargs sed -i \
  's|#SBATCH --cluster=smp|#SBATCH --cluster=${SLURM_CLUSTER}|'
```

Array bounds also drift during debugging; check each wrapper covers the full
subject list rather than a leftover single-index range:

```bash
grep -r 'array=' fsl/ | grep -v '0-'
```

## 5. Files to drop

```
cnc                 stray PostScript export from ImageMagick
.DS_Store           four locations
Untitled.ipynb      empty
Untitled1.ipynb     empty
```

## 6. Files still missing

Not present in the old repository and needed for completeness:

- group-level FLAME designs, submission script, and cluster summary script
- the cluster-table generator (`make_tables.sh` and `parse_clusters.py`)
- the multivariate pipeline
- figure generation, including the Network Correspondence Toolbox configs

## 7. Before committing notebooks

Notebook outputs can embed participant thought content. `data_merge.ipynb`
printed subject-level thought phrases in at least three cells. Clear outputs
on every notebook before committing:

```bash
jupyter nbconvert --clear-output --inplace mvpa/*.ipynb
```

Consider adding a pre-commit hook so this is not left to memory.

---

# Known fragilities in the submission scripts

These work as written but would break under small changes. Recorded rather
than fixed, since fixing them would mean regenerating designs that produced
published results.

**Hardcoded run number.** `run_feat_level1_arraybatch_*.sh` sets `run=3` near
the top and must be edited and resubmitted once per run. There is no loop.

**Leftover array restriction.** `fmriprep_arraybatch.sh` has
`#SBATCH --array=50-50`, i.e. a single subject. It was last used for a
one-off rerun. Restore the full range before reuse.

**Scheduler name case.** `fmriprep_arraybatch.sh` used `--cluster=SMP` while
the FEAT wrappers used `--cluster=htc`. Both now read
`${TREW_SLURM_CLUSTER}`, but note that fMRIPrep and FEAT were run on different
partitions.

**Volume count extraction.** The level-1 generators read the volume count with

```bash
fslinfo ... | sed -n 5p | grep -Eo '[0-9]{3}'
```

which takes line 5 of `fslinfo` output and the first three-digit run. This
works for the 440-volume runs in this dataset but would silently truncate a
four-digit count (1320 would become 132) or pick up the wrong field if
`fslinfo`'s output order changed.

**Subject number extraction.** Several scripts derive the subject number with
`grep -Eo '[0-9]{3}'` on a full path. This works only because no earlier path
component contains three consecutive digits. On a path such as
`/data/study2024/...` every subject number would be wrong. The R generators
have the same pattern via `str_extract(fulldir, "[[:digit:]]+")`.

**Data read from a global.** `make_fsl_timing_files(fulldir, dest_vol)` in
`fsl/preprocessing/make_timing_files.R` derives the subject number from its
argument but reads the data from the global `filename`. Every call site passes
the same variable, so it is correct as written; a call passing a directory
instead would write one subject's data under another's number. This is the same
shape as the motion-confound bug described above.
