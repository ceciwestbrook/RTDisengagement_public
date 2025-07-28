#!/bin/bash
# Ceci Westbrook, March 2025
# reads the confound files output by fmriprep and calls an R script to generate motion confound files for
# later use in FSL

# run all subjects
#for dir in `ls -d /ix1/lhallion/TReW-Brain/preprocessed/sub-*/`; do

# run an individual subject
for dir in `ls -d /ix1/lhallion/TReW-Brain/preprocessed/sub-358/`; do
	rawname=`basename $dir`
	subject=`echo ${rawname} | grep -Eo '[0-9]{3}'`

	if [[ -d $dir"/ses-01"  ]] ; then
	  cd $dir"/ses-01/func"
	  for runnum in 1 2 3; do
		echo $subject $runnum
	    Rscript /ix1/lhallion/TReW-Brain/Scripts/preprocessing/extract_motion_confounds.R $subject  $runnum >> /ix1/lhallion/TReW-Brain/Scripts/preprocessing/spike_numbers.txt
	  done
	fi
done
