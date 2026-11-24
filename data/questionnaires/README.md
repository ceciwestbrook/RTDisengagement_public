# questionnaires/

The pre-scan thought ratings and the trait and clinical measures are in the
OpenNeuro dataset, not in this folder:

| What | Where in the dataset |
|---|---|
| Pre-scan ratings: content, form, quality and emotion ratings for each of the nine thoughts, with `dyscontrol_raw` and `dyscontrol_imputed` | `stimuli/thought_ratings.tsv` (one row per participant and thought, joined to the events files by `thought_uid`) |
| ADIS diagnoses, PSWQ, PTQ and PTQ screening scores | `phenotype/` |

`mvpa/config.py` and `mvpa/questionnaire_loader.py` were written for the
original Qualtrics exports and have not been adapted to these files.
