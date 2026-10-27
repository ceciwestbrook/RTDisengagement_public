# Data

Nothing in this directory is tracked by git except these README files. The
pipeline reads from here by default; point it elsewhere by setting
`TREW_DATA_ROOT` (shell) or `TREW_DATA_ROOT` (Python, read by `mvpa/config.py`).

```
data/
├── rawdata/         BIDS raw data, including *_events.tsv
├── preprocessed/    fMRIPrep derivatives
├── timing/          FEAT 3-column timing files (generated; see fsl/README.md)
└── questionnaires/  pre-scan ratings and trait questionnaires  [ON REQUEST]
```

## Availability

| What | Where |
|---|---|
| Raw and preprocessed imaging | OpenNeuro `ds006683`, public on publication |
| Trial-level behavioural data | On request |
| Questionnaire data | On request |
| Participant-nominated thought topics | **Not shared** — see below |

Requests to the corresponding author.

## Withheld content

Participants nominated nine personally relevant repetitive-thought topics,
which were used as scanner stimuli and recorded as short reminder phrases.
These phrases are participant-generated free text describing private concerns
and in some cases name other people. They are not shared in any form, and are
not present in this repository, in notebook outputs, or in the OpenNeuro
dataset.

Code that depends on these phrases (the pre-scan merge in `mvpa/merge.py`)
will not run without them. See `mvpa/README.md` for what to do instead.
