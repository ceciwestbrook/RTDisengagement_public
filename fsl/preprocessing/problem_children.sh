#!/bin/bash
# Ceci Westbrook, 2025
# script to unzip TReW-Brain MRI data, deface and move to CRC

# destination directory
dest_dir=${TREW_DATA_ROOT}/rawdata/

for subdir in `ls -d ${TREW_DATA_ROOT}/sourcedata/dicom/HB384`
	do
		subnum=$(echo $subdir | grep -oE '[0-9]+')
		fullsub=$(basename $subdir)
		echo $fullsub' '$subnum

		
		cp $subdir/flywheel/halliongroup/StickyThoughts/$fullsub/ses-01/func-bold_task-runA_run-01_1/*nii.gz $dest_dir/sub-$subnum/ses-01/func/sub-${subnum}_ses-01_task-PDT_run-01_bold.nii.gz
		cp $subdir/flywheel/halliongroup/StickyThoughts/$fullsub/ses-01/func-bold_task-runA_run-01_1/*json $dest_dir/sub-$subnum/ses-01/func/sub-${subnum}_ses-01_task-PDT_run-01_bold.json
		
	done