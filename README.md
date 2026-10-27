# Neural correlates of sustained attention during disengagement from repetitive thought

Analysis code for the TReW-Brain study (PI: Hallion). Preregistration:
<https://osf.io/qy4df>.

Code written by Ceci Westbrook, 2022–2026, unless otherwise noted.

## Task

Participants nominated nine personally relevant repetitive-thought topics in an
interview on a preceding session; these were used as scanner stimuli. In the
scanner they completed three runs of nine trials. Each trial presented one
thought stimulus for ~30 s, during which participants engaged in repetitive
thought as they ordinarily would, followed by a ~34 s disengagement period
during which they performed the Sustained Attention to Response Task (SART).
After the SART, probes asked how repetitive, intrusive and uncontrollable their
thoughts had been during the SART, and how much effort they had expended on the
task.

Participants were not instructed in any particular disengagement strategy —
this is the design feature that distinguishes the study from our earlier work,
and the reason the paradigm yields a measure of disengagement success rather
than of strategy execution.

## Repository layout

```
setup_env.sh      the only file containing paths; source once per session
verify_pipeline.sh  automated checks over a completed analysis tree
task-PDT_events.json  BIDS sidecar describing the events.tsv columns
fsl/              FEAT univariate and PPI pipeline
  config.sh         shared paths and parameters; source this from any script
  preprocessing/    task output to timing files; fMRIPrep; motion confounds
  level1/           run-level models: templates, generators, submission
  level2/           within-subject fixed-effects averaging
  group/            group-level FLAME 1 models and cluster summaries
  ppi/              psychophysiological interaction models
    ROIs/             seed masks and timeseries extraction
mvpa/             multivariate pipeline (parcel-level decoding and RSA)
behavioral/       behavioural analyses (R Markdown)
figures/          figure generation
data/             expected location of input data; contents not tracked
docs/             analysis notes, verification, exclusion rationale
```

## Running the pipeline

Set the data location once per session:

```bash
source setup_env.sh      # edit TREW_DATA_ROOT inside if the data has moved
module load fsl
```

No script in this repository contains an absolute path. After a filesystem
migration, `setup_env.sh` is the only file that needs editing.

Then, in order:

0. **Task output to timing files** — `fsl/preprocessing/make_timing_files.R`
   converts PsychoPy session output into the FEAT three-column timing files,
   and `make_bids_events.R` writes the BIDS `_events.tsv`. Both can be run
   against the example sessions in `data/example/` without participant data.
   `move_nifti_and_deface.sh` documents the DICOM-to-BIDS organisation and the
   pydeface step, including the runA/runB/runC to run-01/02/03 mapping.

1. **Preprocessing** — `fsl/preprocessing/fmriprep_arraybatch.sh`, then
   `make_motion_confound_files.sh`, which calls
   `extract_motion_confounds.R` per subject and run to build FEAT-ready
   confound matrices (24 motion parameters plus FD ≥ 0.6 spike regressors).

2. **Level 1** — `fsl/level1/make_fsfs_level1_<model>.sh` generates one `.fsf`
   per subject and run from the matching template by substituting subject, run
   and path placeholders; `run_feat_level1_arraybatch_<model>.sh` submits them.
   This follows Jeanette Mumford's batch-FEAT approach
   ([video series](https://www.youtube.com/playlist?list=PLB2iAtgpI4YHlH4sno3i3CUjCofI38a-3)).

3. **Registration fix** — `fsl/level2/adj_feat_reg_arraybatch.sh` replaces the
   registration matrices in each first-level directory with identity matrices.
   fMRIPrep has already normalized the data, so FEAT's own registration must be
   bypassed before higher-level analyses.

4. **Level 2** — within-subject fixed-effects averaging across runs.

5. **Level 3** — `fsl/group/` runs FLAME 1 mixed-effects models and summarizes
   clusters. Cluster-forming threshold z > 3.1, cluster-corrected p < .05.

6. **Multivariate** — `mvpa/`, independently of the above. Parcellates
   preprocessed data into Yeo-17 networks, builds block-level features, and runs
   leave-one-subject-out ridge regression and representational similarity
   analyses. See `mvpa/README.md`.

7. **Network correspondence** — thresholded group maps are characterized
   against six published atlases using the Network Correspondence Toolbox
   (Kong et al., 2025). See `figures/README.md`.

A note on the submission scripts: these target a SLURM cluster and encode
site-specific partition and allocation names. `fsl/config.sh` centralizes them,
but on another system it is usually simpler to ignore the wrappers and call
`feat` directly on the generated `.fsf` files.

## Data

Not tracked in this repository. `data/README.md` describes the expected layout
and what is available where. In summary: imaging data on OpenNeuro
([`ds006683`](https://openneuro.org/datasets/ds006683), public on publication);
behavioural and questionnaire data on request; participant-nominated thought
topics not shared in any form.

## Software

| | Version |
|---|---|
| fMRIPrep | 24.1.1 |
| FSL | 6.0.7.18 |
| Python | 3.11 |
| R | 4.3 |

Python: pandas, numpy, scipy, scikit-learn, nilearn, statsmodels, jupyter.
R: tidyverse, lme4, lmerTest, haven.

## A note on this repository's history

This repository was substantially revised in October 2026. Earlier commits
predate corrections to the motion confound pipeline and should not be used; all
analyses reported in the associated manuscript were produced with the current
code.

## Acknowledgements

Data were collected at the CMU–Pitt Brain Imaging Data Generation and Education
(BRIDGE) Center, Pittsburgh, PA. Funded by NIMH K01MH116328 (PI: Hallion).

## Authors

Cecilia A. Westbrook¹˒², Brittany Alberts², Peter J. Gianaros¹˒²,
Jonathan Smallwood⁴, M. Kathleen Caulfield¹˒³, Jennifer S. Silk¹˒²,
Mary Blendermann¹, Lauren S. Hallion¹˒⁵

¹ Department of Psychology, University of Pittsburgh, Pittsburgh, PA, USA
² Department of Psychiatry, University of Pittsburgh, Pittsburgh, PA, USA
³ Reason Research, Philadelphia, PA, USA
⁴ Department of Psychology, Queen's University, Kingston, ON, Canada
⁵ Department of Psychology, University of Regina, Regina, SK, Canada

## Status

Under review. Publication details to follow.
