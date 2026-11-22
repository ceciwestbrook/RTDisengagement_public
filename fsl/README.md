# FSL pipeline

Univariate and PPI analyses in FEAT. Source `config.sh` from any script here;
it resolves data paths and FSL location from the environment.

Subdirectories run in order: `preprocessing`, `level1`, `level2`, `group`.
`ppi` branches off after preprocessing and has its own level-1 and level-2
stages.

## Running fMRIPrep

Source the environment, then submit with the wrapper rather than `sbatch` on
the script directly:

    source setup_env.sh
    bash fsl/preprocessing/submit_fmriprep.sh

`submit_fmriprep.sh` runs the first subject by itself and starts the rest a few
minutes later. This is deliberate. On a fresh output directory, fMRIPrep tasks
that start at the same moment can collide while setting up the shared
`sourcedata/freesurfer/fsaverage` folder, a known fMRIPrep race condition. A
collision can leave tasks that exit with status 0 and print "finished
successfully" but have no `desc-preproc_bold` or confounds files, or cause a
later `recon-all` failure ("Label BA1_exvivo does not exist in SUBJECTS_DIR
fsaverage"). If you submit the script yourself, run one subject first
(`--array=0`), wait until it is past startup, then submit the rest.

Optional settings (set before sourcing, or in your shell):

| Variable | Default | Purpose |
|---|---|---|
| `TREW_SLURM_CLUSTER` | `htc` | Slurm cluster |
| `TREW_STAGGER_MIN` | `5` | Minutes between the first subject and the rest |
| `TREW_MAX_CONCURRENT` | `20` | Maximum simultaneous subjects |
| `TREW_LOG_DIR` | `$TREW_DATA_ROOT/logs` | Slurm log location |
| `TREW_FMRIPREP_SIMG` | `$TREW_DATA_ROOT/fmriprep-24.1.1.simg` | Container image |
| `TREW_FS_LICENSE` | `$TREW_DATA_ROOT/license_free_surfer.txt` | FreeSurfer license (keep out of the repository) |
| `TREW_FMRIPREP_WORK` | `$TREW_DATA_ROOT/work` | Working directory; large, safe to delete when finished |

Check each subject afterwards. A complete subject has one `desc-preproc_bold`
file and one confounds file per run, plus an `.html` report. The Slurm state
`COMPLETED` alone does not show this.

## Models

| Model | Modulator on the SART block |
|---|---|
| `dyscontrolmod` | probe-caught dyscontrol |
| `ACCmod` | SART accuracy |
| `dyscontrolandeffortmods` | dyscontrol and probe-caught effort |
| `dyscontrolandACCmods` | dyscontrol and accuracy |
| `indivthoughtmod` | pre-scan dyscontrol for the individual thought |

Each also carries an unmodulated SART-block regressor, thought-block regressors
(unmodulated and modulated), and a probe-period nuisance regressor.

Contrasts against implicit baseline (`SARTBaseline`, `ThoughtVsBaseline`) are
generated but not interpreted: with no explicit rest condition the baseline is
ill-defined and these contrasts produce implausibly extensive clusters. The
interpretable contrasts are the parametric ones and the direct condition
comparisons.

## A note on registration

fMRIPrep has already normalized the data to MNI space, so FEAT must not apply
its own registration at higher levels. `level2/adj_feat_reg_arraybatch.sh`
replaces each first-level `reg/` directory's transforms with identity matrices
before level 2 runs. Skipping this step silently resamples already-normalized
data.
