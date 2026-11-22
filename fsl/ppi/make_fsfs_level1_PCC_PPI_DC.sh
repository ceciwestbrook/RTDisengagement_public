#!/bin/bash

# This script replaces the subject and run numbers in template fsf files

fsfdir=${TREW_REPO_ROOT}/fsl/ppi/PPI_level1_fsf_files/PCC_PPI_DC
FSF_VARS='${TREW_REPO_ROOT} ${TREW_DATA_ROOT} ${TREW_PROCESSED_DIR} ${TREW_GROUP_DIR} ${FSLDIR}'
: "${FSLDIR:?run: module load fsl}" "${TREW_REPO_ROOT:?run: source setup_env.sh}" "${TREW_DATA_ROOT:?run: source setup_env.sh}" "${TREW_PROCESSED_DIR:?run: source setup_env.sh}" "${TREW_GROUP_DIR:?run: source setup_env.sh}"
mkdir -p "$fsfdir"
cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1
preprocdir=${TREW_DATA_ROOT}/preprocessed/

for dir in `ls -d ${TREW_DATA_ROOT}/preprocessed/sub-*/`; do
	rawname=`basename $dir`
	subject=`echo ${rawname} | grep -Eo '[0-9]{3}'`

	for run in 1 2 3; do
	# not all files have same # of RTs, so have to set for each run
	  RTnum=`fslinfo $preprocdir/sub-$subject/ses-01/func/sub-${subject}_ses-01_task-PDT_run-0${run}_space-MNI152NLin6Asym_res-2_desc-preproc_bold.nii.gz | sed -n 5p | grep -Eo '[0-9]{3}'`
	  [ -z "$RTnum" ] && { echo "skip sub-$subject run $run: no preprocessed bold" >&2; continue; }

	  sed 's/SUBNUM/'${subject}'/g' design_template_level1_PCC_PPI_DC.fsf | envsubst "$FSF_VARS" > $fsfdir'/sub-'${subject}'_ses-01_fsf-lv1_run-'${run}'_PCC_PPI_DC.fsf'
	  sed -i 's/RUNNUM/'${run}'/g' $fsfdir'/sub-'${subject}'_ses-01_fsf-lv1_run-'${run}'_PCC_PPI_DC.fsf'
	  sed -i 's/RTNUM/'${RTnum}'/g' $fsfdir'/sub-'${subject}'_ses-01_fsf-lv1_run-'${run}'_PCC_PPI_DC.fsf'
	
	done

done

