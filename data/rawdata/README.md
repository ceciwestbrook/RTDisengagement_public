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

Available from OpenNeuro `ds006683`, which also holds `stimuli/thought_ratings.tsv`
(pre-scan ratings of each participant's nine thoughts), `phenotype/` (trait and
clinical measures), `participants.tsv`, and `task-PDT_events.json`, the data
dictionary for the events files.

## events.tsv

One row per event. Columns: `onset`, `duration`, `response_time`, `response`,
`correct`, `trial_type`, `corr_ans`, `thoughtNumber`, `thought_uid`,
`Intensity`, `probenumber` and `eventType`; `task-PDT_events.json` describes
each. `eventType` is one of `Thoughtblock`, `SART`, `ThoughtProbe`, `Reflect`
or `Fixation`. `thoughtNumber` is presentation order and is reshuffled between
runs; `thought_uid` identifies the thought and is the same in every run.

The reminder phrase (the `Thought` column in the original PsychoPy output) is
not in the OpenNeuro copy; `thought_uid` replaces it. `mvpa/events_loader.py`
tolerates its absence.
