# preprocessed/

fMRIPrep 24.1.1 derivatives. Expected layout:

```
preprocessed/sub-<ID>/ses-01/func/
    sub-<ID>_ses-01_task-PDT_run-<NN>_space-MNI152NLin6Asym_res-2_desc-preproc_bold.nii.gz
    sub-<ID>_ses-01_task-PDT_run-<NN>_space-MNI152NLin6Asym_res-2_desc-brain_mask.nii.gz
    sub-<ID>_ses-01_task-PDT_run-<NN>_desc-confounds_timeseries.tsv
```

Regenerate from rawdata with `fsl/preprocessing/fmriprep_arraybatch.sh`, or
request the derivatives directly.

Motion confound files consumed by FEAT are built from the confounds TSV by
`fsl/preprocessing/extract_motion_confounds.R` and written alongside it as
`sub-<ID>_ses-01_motion_confound_run-<NN>.txt`.
