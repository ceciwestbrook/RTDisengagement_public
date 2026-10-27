# Pipeline verification

`verify_pipeline.sh` in the repository root runs automated checks over a
completed analysis tree. Run it after `source setup_env.sh`:

```bash
./verify_pipeline.sh            # all checks
./verify_pipeline.sh --list     # check names
./verify_pipeline.sh confounds  # one check
```

It writes only to `$TREW_DATA_ROOT/verification/` and deletes nothing.
Failures print specifics; passes print a one-line summary.

## What each check establishes

| Check | What it tests |
|---|---|
| `confounds` | Each FEAT confound file has 24 motion parameters plus one column per spike, each spike column sums to 1, row count matches volume count, no header |
| `designs` | `feat_model` output is full rank over non-constant columns and parametric regressors are demeaned |
| `registration` | Every `_adjreg.feat/reg/example_func2standard.mat` is actually identity, not merely present |
| `level2` | Each level-2 design's `npts` matches its input count, all inputs are `_adjreg` directories and exist on disk, `mixed_yn` is 3 |
| `group_copes` | Lists which cope number each group design reads; confirming correctness needs comparison against `conname_real` in the level-1 template |
| `mvpa` | Block-feature table: block counts per subject, condition balance, target columns present |
| `cross` | FSL and multivariate pipelines agree on censored-volume counts, comparing each `provenance.json` against the corresponding confound file |

## Notes on interpreting results

**Constant columns are expected.** The missed-trial EVs are empty for
participants with no missed trials. A zero column is orthogonal to everything
else and does not affect estimates for the contrasts of interest, so these are
reported separately rather than as failures. The rank check runs over
non-constant columns, which still catches genuine collinearity between two real
regressors.

**Excluded participants produce level-2 "failures".** Designs are generated for
everyone, but first-level analyses were not run for excluded participants, so
their level-2 inputs are legitimately absent. Filter before reading the output.

**The `cross` check is the only one comparing independent implementations.**
The FSL confound files are written by R; the multivariate spike masks by
Python. Agreement between them is evidence; agreement within a single pipeline
is not.

## What this does not verify

Timing-file onsets cannot be checked against an independent source, because the
timing files and the BIDS `_events.tsv` files are produced by the same script
from the same PsychoPy output. What can be and has been established:

- Modulator values match the probe data, which never passes through the
  generator (`probe1`, mean-centred within run)
- Row ordering matches presentation order, and `thoughtNumber` is presentation
  order, so the position-based indexing in the generator is correct by
  construction
- Time zero is the scanner trigger (see `data/example/README.md`)
- Block durations match the design: 32 s thought blocks, 34-38 s SART blocks

## Preprocessing options worth noting

`fsl/preprocessing/fmriprep_arraybatch.sh` was run with:

```
--ignore fieldmaps slicetiming
--fd-spike-threshold 0.6
--output-spaces MNI152NLin6Asym:res-2
```

Three consequences:

- **No susceptibility distortion correction.** Opposite-phase-encoding field
  maps were acquired and are present in the BIDS tree (see
  `move_nifti_and_deface.sh`), but were not used.
- **No slice-timing correction**, by either fMRIPrep or FEAT
  (`set fmri(st) 0` in the level-1 templates). `SliceTiming` is populated in
  the BOLD sidecars, so this was a choice rather than missing metadata.
- **fMRIPrep's outlier columns use FD > 0.6 mm**, the same threshold as the
  FD-only mask built by `extract_motion_confounds.R`. The two differ only in
  that fMRIPrep additionally flags frames on standardized DVARS > 1.5.
