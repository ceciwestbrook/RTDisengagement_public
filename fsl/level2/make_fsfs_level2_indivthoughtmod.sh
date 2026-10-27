#!/bin/bash

# This script replaces the subject and run numbers in template fsf files

fsfdir=${TREW_REPO_ROOT}/fsl/Level2/level2_fsf_files/indivthoughtmod
preprocdir=${TREW_DATA_ROOT}/preprocessed/

for dir in `ls -d ${TREW_DATA_ROOT}/preprocessed/sub-*/`; do
	rawname=`basename $dir`
	subject=`echo ${rawname} | grep -Eo '[0-9]{3}'`

	  sed 's/SUBNUM/'${subject}'/g' design_template_level2_indivthoughtmod.fsf > $fsfdir'/sub-'${subject}'_ses-01_fsf-lv2_indivthoughtmod.fsf'

done

