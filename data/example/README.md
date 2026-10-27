# Example PsychoPy session data

Two task output files from non-participant sessions, included so that the
timing-file pipeline can be run end to end without any participant data.

| File | Session |
|---|---|
| `999_TREW-SIMULATIONONLY_*.csv` | Simulation only; no scanner, no trigger recorded |
| `111_TREW-scannerReady_*.csv`   | Scanner-ready practice session, including a real trigger |

Neither contains participant-generated thought topics.

## Running the generators on these files

```bash
source setup_env.sh
Rscript fsl/preprocessing/make_timing_files.R      # FEAT timing files
Rscript fsl/preprocessing/make_bids_events.R       # BIDS _events.tsv
```

Both scripts expect PsychoPy output under
`$TREW_DATA_ROOT/sourcedata/psychopy/<subject>/`; copy or symlink these files
there to try them.

## Why the scanner-ready file is useful

`111_TREW-scannerReady` records an actual scanner trigger, which is what
establishes the time-zero convention used by both generators. The trigger
arrives at `triggerCheck.started + triggerCheck.rt`, and the first
`ThoughtText.started` follows it by 42 ms. Both scripts set event onsets
relative to the first thought block of each run:

```r
onset <- ThoughtText.started - split$ThoughtText.started[1]
```

so onsets are referenced to the scanner trigger to within a small fraction of
one TR. The simulation file has no trigger and cannot be used for this check.
