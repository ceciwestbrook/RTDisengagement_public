# Behavioural analyses

`behavioral_analyses.R` contains the behavioural models reported in the
manuscript (preregistered hypotheses H1 and H2), together with the
robustness checks run alongside them. It also contains the loader that builds
the trial-level behavioural table from PsychoPy session output.

## Models

Mixed-effects models with participant random intercepts and random slopes,
fitted with `lme4`/`lmerTest`. All variables standardized.

| Hypothesis | Predictor of interest | Outcome |
|---|---|---|
| H1 | SART performance | pre-scan dyscontrol (`dyscontrol_imputed`) |
| H2 | SART performance | probe-caught dyscontrol (`probe1`) |

Three performance measures are modelled separately:

- `AccIndex` — no-go accuracy divided by mean go reaction time, a
  speed-accuracy-tradeoff-corrected skill index
- `NoGo_ACC` — no-go accuracy alone
- `Mean_go_RT` — mean go reaction time alone

Note that dyscontrol is on the left-hand side and performance on the right.
These are correlational models and the direction of the regression does not
reflect a causal claim; the manuscript describes the association in the
direction of dyscontrol predicting performance.

## Robustness checks

The script runs each model under several additional specifications. These are
retained rather than pruned so that the analytic decisions are visible:

| Variation | Appears in |
|---|---|
| Excluding participant 393 (influential outlier) | 17 models |
| Restricting to `Mean_go_RT < 1.0` s | 3 models |
| Adding pre-scan dyscontrol as a covariate | 4 models |
| Adding task effort (`probe3`) as a covariate | 2 models |

Inline comments record the outcome of each: for example, the no-go accuracy
model for H1 is noted as significant in a single-level model but not in the
mixed model, and the H2 reaction-time model is noted as not robust to the
exclusion of participant 393 and as losing significance when baseline
dyscontrol is included.

**Before release, confirm that the specification reported in the manuscript as
primary matches the preregistration, and that the manuscript states which
performance measure each hypothesis test used.** The script contains more
specifications than the manuscript reports, which is normal, but the mapping
between them should be explicit. Participant 393 is excluded in some models
here and is not among the exclusions documented in `docs/EXCLUSIONS.md`; if any
reported result rests on that exclusion it should be stated.

## Inputs

Requires the trial-level behavioural table, which the script builds from
PsychoPy session output under `$TREW_DATA_ROOT/sourcedata/psychopy/`. The
derived table contains participant-generated thought text and is not
distributed; see `data/README.md`.
