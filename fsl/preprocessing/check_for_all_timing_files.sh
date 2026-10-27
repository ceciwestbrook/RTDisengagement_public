#!/bin/bash

dest_dir=${TREW_DATA_ROOT}/timing/

for subdir in `ls -d ${TREW_DATA_ROOT}/rawdata/*`
	do
		subnum=$(echo $subdir | grep -oE '[0-9]+')
		echo $subnum
		
		if [[ -e $dest_dir/$subnum/sub-${subnum}_run-01_CRs.txt ]] ; then
			echo 'found'
		else
			echo 'not found'
		fi

	done