#!/bin/bash

# This script replaces the subject and run numbers in template fsf files

fsfdir=/ix1/lhallion/TReW-Brain/Scripts/Level2/level2_fsf_files/dyscontrolmod
preprocdir=/ix1/lhallion/TReW-Brain/preprocessed

for dir in `ls -d /ix1/lhallion/TReW-Brain/preprocessed/sub-*/`; do
	rawname=`basename $dir`
	subject=`echo ${rawname} | grep -Eo '[0-9]{3}'`

	  sed 's/SUBNUM/'${subject}'/g' design_template_level2_dyscontrolmod.fsf > $fsfdir'/sub-'${subject}'_ses-01_fsf-lv2_dyscontrolmod.fsf'

done

