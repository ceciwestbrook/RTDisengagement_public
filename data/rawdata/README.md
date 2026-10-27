# rawdata/

BIDS-format raw data. Expected layout:

```
rawdata/sub-<ID>/ses-01/func/
    sub-<ID>_ses-01_task-PDT_run-<01|02|03>_bold.nii.gz
    sub-<ID>_ses-01_task-PDT_run-<01|02|03>_events.tsv
rawdata/sub-<ID>/ses-01/anat/
    sub-<ID>_ses-01_T1w.nii.gz
rawdata/sub-<ID>/ses-01/fmap/
    (two opposite phase-encoding field maps)
```

Available from OpenNeuro `ds006683` (public on publication).

## events.tsv

One row per SART trial (`trial_type` of `go` or `nogo`) and one row per block
(`eventType` of `Thoughtblock`, `ThoughtProbe`). Columns used by this pipeline:
`onset`, `duration`, `trial_type`, `eventType`, `thoughtNumber`, `response_time`,
`accuracy`.

The OpenNeuro copy has the `Thought` column (the participant's reminder phrase)
removed. `mvpa/events_loader.py` tolerates its absence.
