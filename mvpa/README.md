# Multivariate pipeline

Parcel-level decoding and representational similarity analyses.

## Order

1. `data_merge.ipynb` — load and merge trial-level, pre-scan and trait data
2. `features.ipynb` — parcellate and build block-level features
3. `decoding.ipynb` — leave-one-subject-out ridge regression, permutation
   importance, representational similarity
4. `figures.ipynb` — figure generation

Modules: `config.py` (paths and parameters), `alldata_loader.py`,
`questionnaire_loader.py`, `events_loader.py`, `merge.py`,
`parcellation.py`, `decoding.py`, `similarity.py`, `figure_style.py`.

Start by running `config.check_paths()`, which reports which inputs are
present.

## Sample

The multivariate analyses use 56 participants against 57 for the univariate
analyses. Block patterns are the unit of analysis here, so a subject can pass
the volume-level motion criterion and still have too few usable blocks: one
participant had 23 of 27 thought blocks with over 70% of volumes censored.
Parameters are `MAX_UNUSABLE_BLOCKS` and `MIN_FRACTION_USABLE` in `config.py`.

## Feature importance

Network importance is estimated by permutation with bootstrapping. Within each
LOSO fold, one network family's features are permuted within the held-out
subject and importance taken as the resulting decrease in prediction accuracy;
confidence intervals are bootstrapped across subjects.

Families are permuted together rather than individual Yeo subnetworks, because
correlated features let the model recover a permuted subnetwork's signal from
its neighbours, biasing single-subnetwork importance toward zero. See
`NETWORK_FAMILIES` in `config.py`.

## The merge, and what you can run without the withheld data

`merge.py` matches in-scanner trials to pre-scan ratings on
(subject, normalized thought phrase). The phrases are participant-generated and
are not distributed. Questionnaire copies supplied on request have them replaced
with opaque per-subject identifiers, which supports the merge without exposing
content — the merge needs consistent matching, not readable text.

`manual_corrections.json` reconciles phrase mismatches between the two sources
and is likewise not distributed; see `manual_corrections.template.json` for the
format and how to regenerate it. With identifier-substituted data, no
corrections are needed.
