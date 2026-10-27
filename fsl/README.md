# FSL pipeline

Univariate and PPI analyses in FEAT. Source `config.sh` from any script here;
it resolves data paths and FSL location from the environment.

Subdirectories run in order: `preprocessing`, `level1`, `level2`, `group`.
`ppi` branches off after preprocessing and has its own level-1 and level-2
stages.

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
