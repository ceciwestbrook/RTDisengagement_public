#!/bin/bash

# Ceci Westbrook February 2022
# This code implements the FEAT registration workaround listed here:
# https://mumfordbrainstats.tumblr.com/post/166054797696/feat-registration-workaround

# Batch options
# Inputs ----------------------------------
#SBATCH -J adj_feat_reg
#SBATCH --time=1:00:00
#SBATCH --cluster=${TREW_SLURM_CLUSTER}
#SBATCH -N 1
#SBATCH --cpus-per-task=1
#SBATCH --array=0-57
# Outputs ----------------------------------
#SBATCH -o log/%x-%A-%a.out
#SBATCH -e log/%x-%A-%a.err
# ------------------------------------------

FSLDIR=${FSLDIR}

# to run all subjects
subs=()
for dir in `ls -d ${TREW_PROCESSED_DIR}/*`; do
	rawname=`basename $dir`
	subject=`echo ${rawname} | grep -Eo '[0-9]{3}'`
	subs+=($subject)
done

n=$SLURM_ARRAY_TASK_ID # index of subject to start at
x=1 # number of subjects to run
uniq_subs=($(printf "%s\n" ${subs[@]} | sort -u))
subject="${uniq_subs[@]:${n}:${x}}"
	for run in 1 2 3; do
	  if [[ -d ${TREW_PROCESSED_DIR}/sub-$subject/ses-01/level1/run${run}_PCC_PPI_DC.feat/stats ]]; then
		if [[ -e ${TREW_PROCESSED_DIR}/sub-$subject/ses-01/level1/run${run}_PCC_PPI_DC_adjreg.feat ]]; then
			rm -r ${TREW_PROCESSED_DIR}/sub-$subject/ses-01/level1/run${run}_PCC_PPI_DC_adjreg.feat
		fi
	    cp -r ${TREW_PROCESSED_DIR}/sub-$subject/ses-01/level1/run${run}_PCC_PPI_DC.feat ${TREW_PROCESSED_DIR}/sub-$subject/ses-01/level1/run${run}_PCC_PPI_DC_adjreg.feat
	       featdir_dys=${TREW_PROCESSED_DIR}/sub-$subject/ses-01/level1/run${run}_PCC_PPI_DC_adjreg.feat
	    cp $FSLDIR/etc/flirtsch/ident.mat $featdir_dys/reg/example_func2standard.mat 
	    cp $FSLDIR/etc/flirtsch/ident.mat $featdir_dys/reg/standard2example_func.mat
	    cp $featdir_dys/mean_func.nii.gz $featdir_dys/reg/standard.nii.gz
	  else
	   	mv ${TREW_PROCESSED_DIR}/sub-$subject/ses-01/level1/run${run}_PCC_PPI_DC.feat ${TREW_PROCESSED_DIR}/sub-$subject/ses-01/level1/run${run}_dyscontrol_toremove.feat
	  fi

	  if [[ -d ${TREW_PROCESSED_DIR}/sub-$subject/ses-01/level1/run${run}_PCC_PPI_ACC.feat/stats ]]; then
		if [[ -e ${TREW_PROCESSED_DIR}/sub-$subject/ses-01/level1/run${run}_PCC_PPI_ACC_adjreg.feat ]]; then
			rm -r ${TREW_PROCESSED_DIR}/sub-$subject/ses-01/level1/run${run}_PCC_PPI_ACC_adjreg.feat
		fi
	    cp -r ${TREW_PROCESSED_DIR}/sub-$subject/ses-01/level1/run${run}_PCC_PPI_ACC.feat ${TREW_PROCESSED_DIR}/sub-$subject/ses-01/level1/run${run}_PCC_PPI_ACC_adjreg.feat
	       featdir_dys=${TREW_PROCESSED_DIR}/sub-$subject/ses-01/level1/run${run}_PCC_PPI_ACC_adjreg.feat
	    cp $FSLDIR/etc/flirtsch/ident.mat $featdir_dys/reg/example_func2standard.mat 
	    cp $FSLDIR/etc/flirtsch/ident.mat $featdir_dys/reg/standard2example_func.mat
	    cp $featdir_dys/mean_func.nii.gz $featdir_dys/reg/standard.nii.gz
	  else
	   	mv ${TREW_PROCESSED_DIR}/sub-$subject/ses-01/level1/run${run}_PCC_PPI_ACC.feat ${TREW_PROCESSED_DIR}/sub-$subject/ses-01/level1/run${run}_dyscontrol_toremove.feat
	  fi
	done

