#!/bin/bash

for boldfile in `ls -d ${TREW_DATA_ROOT}/rawdata/*/*/func/*bold_bold.nii.gz` ; do
	filename=${boldfile%%.*}
	echo ${filename}
	mv ${filename}.nii.gz "${filename//_bold_bold/}_bold.nii.gz"
	#mv $filename.nii.gz ${filename}_bold.nii.gz
	#mv $filename.json ${filename}_bold.json
done