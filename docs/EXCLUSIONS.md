# Participant exclusions

Recorded here because the rationale otherwise exists only as comments in the
driver section of the timing-file generator and in a QC spreadsheet.

61 participants completed the fMRI session.

## Excluded from all analyses (n = 4)

| Participant | Reason |
|---|---|
| 304 | Did not complete most thought probes |
| 366 | Not enough probe responses; task code crashed on run 1 |
| 315 | Almost no SART responses |
| 384 | No SART responses; also exceeded 25% motion on two of three runs |

Participant 393 is excluded in a subset of the behavioural models as an
influential outlier. This is a reported sensitivity analysis, not an exclusion:
the primary behavioural results are full-sample, and the manuscript states that
they hold with the outlier removed. See `behavioral/README.md`.

Leaves n = 57 for the univariate analyses.

## Run-level exclusion

| Participant | Run | Reason |
|---|---|---|
| 303 | 3 | 152 of 440 volumes (34.5%) over the FD censoring threshold |

Applied to the univariate analyses: the level-2 design for this participant has
two inputs. Not applied to the multivariate pipeline, where the block-level
criterion below governs instead and had already removed 7 of that run's 9
thought blocks. `EXCLUDE_RUNS` in `mvpa/config.py` records the decision but is
not read by the pipeline; this is documented rather than enforced.

Run 2 for the same participant was at 25.2% and was judged not to meet the
criterion, so the threshold was applied as approximately 25% rather than as a
strict inequality.

## Excluded from multivariate analyses only (n = 1)

| Participant | Reason |
|---|---|
| 351 | 23 of 27 thought blocks retained fewer than 70% of volumes |

Block patterns are the unit of analysis for the multivariate work, so a
participant can pass the volume-level criterion and still have too few usable
blocks. Leaves n = 56.

Note that this block-level count uses fMRIPrep's outlier columns rather than
the FD-only mask used for volume censoring inside the models. fMRIPrep was run
with `--fd-spike-threshold 0.6`, so both use the same framewise displacement
threshold; fMRIPrep additionally flags frames on standardized DVARS > 1.5,
which is the entire source of the difference. Under the FD-only criterion this
participant has 11 censored volumes in total, so the block-level exclusion
rests on DVARS-flagged frames.

## Three motion criteria, and which figure each produced

| Purpose | Criterion | Figure |
|---|---|---|
| Run-level exclusion | ~25% of volumes over FD >= 0.6 mm | 303 run 3 |
| Block-level exclusion (multivariate) | fMRIPrep outliers: FD > 0.6 mm **or** std DVARS > 1.5 | 351, 23 of 27 blocks |
| Volume censoring in all models | FD >= 0.6 mm, no DVARS | spike regressors in every first-level model |

Stating which definition produced which number is what makes each figure
reproducible; the three give very different values for the same participant.
