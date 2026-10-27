#!/bin/bash

for dir in `ls -d ${TREW_PROCESSED_DIR}/sub-*/`; do
	rawname=`basename $dir`
	subject=`echo ${rawname} | grep -Eo '[0-9]{3}'`

	  #if [[ -e "$dir/ses-01/level1/run1_nomod_adjreg.feat" ]] ; then
	#	echo "$subject found nomod"
	 # else
	#	echo "$subject nomod NOT FOUND"
	 # fi

	  if [[ -e "$dir/ses-01/level1/run3_PCC_PPI_ACC.feat/stats/cope4.nii.gz" ]] ; then
		echo "$subject found feat"
	  else
		echo "$subject feat NOT FOUND"
	  fi

	  #if [[ -e "$dir/ses-01/level1/run3_dyscontrolmod_censorRT_adjreg.feat" ]] ; then
		#echo "$subject found dyscontrolmod"
	  #else
		#echo "$subject dyscontrolmod NOT FOUND"
	  #fi

done
