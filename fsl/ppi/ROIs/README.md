# Ceci Westbrook 7/2025

This directory contains the script used to generate sphere ROIs in MNI space (i.e., group-level). The ROIs used in analyses are included in this directory. The script extract_timeseries_groupmasks.sh was the primary script used to extract preprocessed timeseries data averaged across each ROI for use as PPI regressors.
## PCC seed

`mask_sphere_PCC_45-36-49_10mm.nii.gz` (seed name `PCC_seed` in the PPI designs) is a sphere
of radius 10 mm (515 voxels, 4120 mm^3) in the 2 mm MNI152 template, centred on voxel
45 36 49, which is MNI (0, -54, 26) mm. Regenerate it with:

    bash make_sphereROIs.sh PCC 45 36 49 10

The script takes voxel coordinates, and the last argument is the radius in mm.
