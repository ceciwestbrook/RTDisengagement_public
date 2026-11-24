# Data

Nothing in this directory is tracked by git except these README files. The
pipeline reads from here by default; point it elsewhere by setting
`TREW_DATA_ROOT` (shell) or `TREW_DATA_ROOT` (Python, read by `mvpa/config.py`).

~~~
data/
|-- rawdata/        the OpenNeuro dataset (imaging, events, stimuli, phenotype)
|-- preprocessed/   fMRIPrep derivatives (regenerated; see preprocessed/README.md)
`-- timing/         FEAT 3-column timing files (generated; see fsl/README.md)
~~~

## Availability

Everything the pipeline reads is in OpenNeuro dataset `ds006683`:

- Raw imaging: `sub-*/ses-01/{anat,func,fmap}/`
- In-scanner trial data (timing, responses, probe ratings):
  `sub-*/ses-01/func/*_events.tsv`, described in `task-PDT_events.json`
- Pre-scan ratings of each participant's nine thoughts:
  `stimuli/thought_ratings.tsv`
- Trait and clinical measures (ADIS, PSWQ, PTQ): `phenotype/`

The dataset does not include fMRIPrep derivatives. Regenerate them with
`fsl/preprocessing/submit_fmriprep.sh`.

## Withheld and unavailable content

Participants nominated nine personally relevant repetitive-thought topics,
which were used as scanner stimuli and recorded as short reminder phrases.
These phrases are participant-generated free text describing private concerns
and in some cases name other people. They are not shared in any form: they are
not in this repository, in notebook outputs, or in the OpenNeuro dataset, where
each thought carries an opaque identifier (`thought_uid`, t01 to t09) instead.

The original PsychoPy session files, which the first version of the timing
scripts read, are no longer accessible. The OpenNeuro `events.tsv` files carry
everything the timing files need except one value, the end of the probe period;
`data/timing/README.md` explains how it is estimated.
