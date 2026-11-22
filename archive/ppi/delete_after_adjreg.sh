for dir in `ls -d ${TREW_DATA_ROOT}/preprocessed/sub-*/`; do
	rawname=`basename $dir`
	subject=`echo ${rawname} | grep -Eo '[0-9]{3}'`

	# Remove old feat directories if re-running
	for run in 1 2 3; do
		if [[ -e "${TREW_PROCESSED_DIR}/sub-${subject}/ses-01/level1/run"${run}"_PCC_PPI_DC_adjreg.feat" ]] ; then
			echo $subject $run "found PCC feat"
				rm -r "${TREW_PROCESSED_DIR}/sub-${subject}/ses-01/level1/run"${run}"_PCC_PPI_DC.feat"
			else
				echo $subject $run "PCC dir not found"
		fi

		if [[ -e "${TREW_PROCESSED_DIR}/sub-${subject}/ses-01/level1/run"${run}"_PCC_PPI_ACC_adjreg.feat" ]] ; then
			echo $subject $run "found SARTACCcluster feat"
				rm -r "${TREW_PROCESSED_DIR}/sub-${subject}/ses-01/level1/run"${run}"_PCC_PPI_ACC.feat"
			else
				echo $subject $run "SARTACCcluster dir not found"
		fi
	done
done
