#!/bin/bash

for boldfile in `ls ${TREW_DATA_ROOT}/rawdata/*/*/func/*nii.gz` ; do
	filename=${boldfile%%.*}
	echo ${filename}
	#mv ${filename}.json "${filename//_events_bold/}_events.json"
	#mv $filename.nii.gz ${filename}_bold.nii.gz
	#mv $filename.json ${filename}_bold.json
done
