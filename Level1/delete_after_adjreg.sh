for dir in `ls -d /ix1/lhallion/TReW-Brain/preprocessed/sub-*/`; do
	rawname=`basename $dir`
	subject=`echo ${rawname} | grep -Eo '[0-9]{3}'`

	# Remove old feat directories if re-running
	if [[ -e "/ix1/lhallion/TReW-Brain/processed/sub-${subject}/ses-01/level1/run${run}_dyscontrolandACCmods_censorRT_adjreg.feat" ]] ; then
		echo "found old feat"
			#rm -r /ix1/lhallion/TReW-Brain/processed/sub-${subject}/ses-01/level1/run2_dyscontrolandACCmods_censorRT.feat
		else
			echo "old dirs not found"
	fi

done
