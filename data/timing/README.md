# timing/

FEAT three-column timing files (onset, duration, weight), one per subject, run
and regressor. They are generated from the BIDS `events.tsv` files in
`rawdata/`, so no PsychoPy output is needed:

    source setup_env.sh
    python3 fsl/preprocessing/make_timing_files.py

Output: `timing/censorRT/<subject>/sub-<ID>_run-<NN>_<name>.txt`

| File | Contents |
|---|---|
| `thoughtblock` | thought blocks, unmodulated |
| `Thoughtblock_dyscontrolmod` | thought blocks, weighted by mean-centred probe-caught dyscontrol (probe 1) |
| `SART` | SART blocks, unmodulated |
| `SART_dyscontrolmod` | SART blocks, weighted by mean-centred probe-caught dyscontrol |
| `SART_effortmod` | SART blocks, weighted by mean-centred probe-caught effort (probe 3) |
| `SART_ACCmod` | SART blocks, weighted by the mean-centred accuracy index |
| `thoughtprobeblock` | probe-response period (nuisance) |
| `*_missedtrials` | blocks with no rating for that modulator, weight 1 |

Rules, applied per subject and run:

- SART trials with a response time more than 3 SD from the run mean are
  dropped ("censorRT"); trials with no response are kept.
- A SART block starts at its first kept trial and lasts for the sum of its kept
  trials.
- Modulators are mean-centred within the run: probe ratings across thoughts,
  the accuracy index across kept SART trials.
- A block without a rating goes to the `*_missedtrials` file and is removed from
  the modulated file. An empty regressor is written as `0 0 0`.
- The probe period runs from the Reflect screen to the fixation before the next
  thought block. `events.tsv` records when a participant finished early, not
  when the probe window ended, so the end is the next block's onset minus 2 s,
  and the last thought of a run uses the run's typical window. This
  approximates the original and differs from it by at most 0.06 s on a 28 s
  block.

Checked against the timing files used for the original analyses (173
subject-runs): every file type is identical except the probe-period durations,
which agree to within 0.06 s.

`fsl/level1/example_timing_file.txt` shows the expected format.
