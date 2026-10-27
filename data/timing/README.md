# timing/

FEAT three-column timing files (onset, duration, weight), one per subject,
run, and regressor.

```
timing/<subject>/sub-<ID>_run-<NN>_<regressor>.txt
```

Regressors used by the level-1 models:

| File suffix | Contents |
|---|---|
| `Thoughtblock` | unmodulated thought blocks |
| `Thoughtblock_dyscontrolmod` | thought blocks, weighted by mean-centred probe-caught dyscontrol |
| `SARTblock` | unmodulated SART blocks |
| `SART_dyscontrolmod` | SART blocks, weighted by mean-centred probe-caught dyscontrol |
| `SART_ACCmod` | SART blocks, weighted by mean-centred accuracy |
| `SART_effortmod` | SART blocks, weighted by mean-centred probe-caught effort |
| `ThoughtProbe` | probe-response periods (nuisance) |

Modulator weights are mean-centred within subject and run. Building these
requires the trial-level behavioural file; request it from the corresponding
author.

`fsl/level1/example_timing_file.txt` shows the expected format.
