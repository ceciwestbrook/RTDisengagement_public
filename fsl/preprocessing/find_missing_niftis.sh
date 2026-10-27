#!/bin/bash

dest_dir=${TREW_DATA_ROOT}/rawdata/

for subdir in `ls -d ${TREW_DATA_ROOT}/rawdata/*`
	do
		subnum=$(echo $subdir | grep -oE '[0-9]+')
		
		if [[ -e $dest_dir/sub-$subnum/ses-01/func/sub-${subnum}_ses-01_task-PDT_run-01_bold.json ]] ; then
			echo "$subnum found json"
			if [[ -e $dest_dir/sub-$subnum/ses-01/func/sub-${subnum}_ses-01_task-PDT_run-01_bold.nii.gz ]] ; then
				echo "$subnum found nifti"
			else echo  "$subnum no nifti"
			fi
		else
			echo "$subnum no json"
		fi

	done