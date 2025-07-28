# Ceci Westbrook, 7/2025

This directory contains the template design (fsf) files for level 2 analyses, and a helper script to populate them for all subjects. The purpose of the level2 analyses is to average the two runs together for input into the group-level analyses. As with the level 1 analyses, there are 3 different versions of these files based on the parametric modulation at level 1.

The adj_feat_arraybatch.sh script applies an adjustment to the level 1 feat analyses to account for the fact that registration was not completed in FEAT (it was done by fmriprep).

Once again, fsf files can be batch-submitted to SLURM filesystems using the array batch files.
