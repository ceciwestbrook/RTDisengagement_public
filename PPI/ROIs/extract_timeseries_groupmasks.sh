#!/bin/bash
# extract average functional data across binary masks for each contrast.

# we'll use the level1 feat with no mod to extract the timeseries
featname="ACCmod_adjreg.feat"
basedir="/ix1/lhallion/TReW-Brain/processed"
ROIdir="/ix1/lhallion/TReW-Brain/Scripts/PPI/ROIs"
maskname=$1
outdir="/ix1/lhallion/TReW-Brain/Scripts/PPI/seed_timeseries/${maskname}"
mask=$ROIdir/$2

mkdir $outdir

module load fsl

for dir in `ls -d $basedir/*` ; do
	rawname=`basename $dir`
	subject=`echo ${rawname} | grep -Eo '[0-9]{3}'`

	for run in 1 2 3 ; do
		echo $subject $run
		featdata=$basedir"/sub-"$subject"/ses-01/level1/run"$run"_ACCmod_adjreg.feat/filtered_func_data.nii.gz"

	fslmeants -i $featdata -o $outdir/${subject}_run${run}_seedtimeseries_${maskname} -m $mask
	done
done
