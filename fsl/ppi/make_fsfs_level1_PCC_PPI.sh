#!/bin/bash

# This script replaces the subject and run numbers in template fsf files

fsfdir=${TREW_REPO_ROOT}/fsl/PPI/PPI_level1_fsf_files/PCC_PPI
preprocdir=${TREW_DATA_ROOT}/preprocessed/

for dir in `ls -d ${TREW_DATA_ROOT}/preprocessed/sub-*/`; do
	rawname=`basename $dir`
	subject=`echo ${rawname} | grep -Eo '[0-9]{3}'`

	for run in 1 2 3; do
	# not all files have same # of RTs, so have to set for each run
	  RTnum=`fslinfo $preprocdir/sub-$subject/ses-01/func/sub-${subject}_ses-01_task-PDT_run-0${run}_space-MNI152NLin6Asym_res-2_desc-preproc_bold.nii.gz | sed -n 5p | grep -Eo '[0-9]{3}'`

	  sed 's/SUBNUM/'${subject}'/g' design_template_level1_PCC_PPI.fsf > $fsfdir'/sub-'${subject}'_ses-01_fsf-lv1_run-'${run}'_PCC_PPI.fsf'
	  sed -i 's/RUNNUM/'${run}'/g' $fsfdir'/sub-'${subject}'_ses-01_fsf-lv1_run-'${run}'_PCC_PPI.fsf'
	  sed -i 's/RTNUM/'${RTnum}'/g' $fsfdir'/sub-'${subject}'_ses-01_fsf-lv1_run-'${run}'_PCC_PPI.fsf'
	
	done

done

