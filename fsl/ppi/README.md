# Psychophysiological interaction (PPI) analyses

Four PPI models, each testing whether coupling between a seed region and the
rest of the brain varies with a task modulator.

| Model | Seed | Modulator |
|---|---|---|
| `PCC_PPI_DC` | PCC sphere | probe-caught dyscontrol |
| `PCC_PPI_ACC` | PCC sphere | SART accuracy index |
| `SARTACCcluster_PPI` | medial PFC cluster from the ACCmod contrast | SART accuracy index |
| `PCC_PPI` | PCC sphere | omnibus: both modulators in one model |

## Seeds

`ROIs/make_sphereROIs.sh` builds the spherical seeds. The PCC seed is a 10 mm
sphere; a 5 mm sphere was also made at the medial PFC peak. The
`SARTACCcluster` seed is not a sphere but the thresholded cluster from the
group-level ACCmod contrast, so it depends on that analysis having been run
first.

`ROIs/extract_timeseries_groupmasks.sh` extracts the mean seed timeseries per
subject and run from the first-level `filtered_func_data`, which is already
denoised and high-pass filtered.

The seed mask volumes themselves are not included here; they are regenerated
by the scripts above.

## Interaction terms

In each level-1 design, the PPI regressors are FSL interaction EVs
(`shape 4`). Each is the product of exactly two EVs: the psychological
regressor and the seed timeseries. For example, in `PCC_PPI_DC`, EV8
(`SARTDCC_PPI`) is the product of EV3 (`SARTblock_dyscontrolmod`) and EV5
(`seed_timeseries`).

This is worth checking if these templates are ever modified. An earlier version
of three of these templates included the unmodulated `Thoughtblock` regressor
in the product as well, making EV8 a three-way interaction rather than the
intended two-way. The templates here are the corrected versions; all four
specify exactly two members per product.

## Running

PPI follows the same structure as the univariate pipeline: generate per-subject
`.fsf` files from the template, run first level, replace the registration
matrices with identity (`adj_feat_reg_arraybatch.sh`), then second level.
Group-level designs are in `../group/designs/`.

`level1_checkforfiles.sh` verifies that all expected first-level outputs exist
before second level is submitted.

## Reported results

All three preregistered connectivity hypotheses were not supported. The
unmodulated PPI terms (`SARTPPI`, `TBPPI`) were run but are not interpreted,
for the same implicit-baseline reason that applies to the unmodulated
univariate contrasts.
