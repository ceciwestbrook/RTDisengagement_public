#!/bin/bash

# Ceci Westbrook February 2022
# This code implements the FEAT registration workaround listed here:
# https://mumfordbrainstats.tumblr.com/post/166054797696/feat-registration-workaround

# Batch options
# Inputs ----------------------------------
#SBATCH -J adj_feat_reg
#SBATCH --time=1:00:00
#SBATCH --cluster=smp
#SBATCH -N 1
#SBATCH --cpus-per-task=1
#SBATCH --array=0-57
# Outputs ----------------------------------
#SBATCH -o log/%x-%A-%a.out
#SBATCH -e log/%x-%A-%a.err
# ------------------------------------------

FSLDIR=/ihome/crc/install/fsl/6.0.4/centos7/fsl

# to run all subjects
subs=()
for dir in `ls -d /ix1/lhallion/TReW-Brain/processed/*`; do
	rawname=`basename $dir`
	subject=`echo ${rawname} | grep -Eo '[0-9]{3}'`
	subs+=($subject)
done

n=$SLURM_ARRAY_TASK_ID # index of subject to start at
x=1 # number of subjects to run
uniq_subs=($(printf "%s\n" ${subs[@]} | sort -u))
subject="${uniq_subs[@]:${n}:${x}}"
	for run in 1 2 3; do
	  if [[ -d /ix1/lhallion/TReW-Brain/processed/sub-$subject/ses-01/level1/run${run}_PCC_PPI_DC.feat/stats ]]; then
		if [[ -e /ix1/lhallion/TReW-Brain/processed/sub-$subject/ses-01/level1/run${run}_PCC_PPI_DC_adjreg.feat ]]; then
			rm -r /ix1/lhallion/TReW-Brain/processed/sub-$subject/ses-01/level1/run${run}_PCC_PPI_DC_adjreg.feat
		fi
	    cp -r /ix1/lhallion/TReW-Brain/processed/sub-$subject/ses-01/level1/run${run}_PCC_PPI_DC.feat /ix1/lhallion/TReW-Brain/processed/sub-$subject/ses-01/level1/run${run}_PCC_PPI_DC_adjreg.feat
	       featdir_dys=/ix1/lhallion/TReW-Brain/processed/sub-$subject/ses-01/level1/run${run}_PCC_PPI_DC_adjreg.feat
	    cp $FSLDIR/etc/flirtsch/ident.mat $featdir_dys/reg/example_func2standard.mat 
	    cp $FSLDIR/etc/flirtsch/ident.mat $featdir_dys/reg/standard2example_func.mat
	    cp $featdir_dys/mean_func.nii.gz $featdir_dys/reg/standard.nii.gz
	  else
	   	mv /ix1/lhallion/TReW-Brain/processed/sub-$subject/ses-01/level1/run${run}_PCC_PPI_DC.feat /ix1/lhallion/TReW-Brain/processed/sub-$subject/ses-01/level1/run${run}_dyscontrol_toremove.feat
	  fi

	  if [[ -d /ix1/lhallion/TReW-Brain/processed/sub-$subject/ses-01/level1/run${run}_PCC_PPI_ACC.feat/stats ]]; then
		if [[ -e /ix1/lhallion/TReW-Brain/processed/sub-$subject/ses-01/level1/run${run}_PCC_PPI_ACC_adjreg.feat ]]; then
			rm -r /ix1/lhallion/TReW-Brain/processed/sub-$subject/ses-01/level1/run${run}_PCC_PPI_ACC_adjreg.feat
		fi
	    cp -r /ix1/lhallion/TReW-Brain/processed/sub-$subject/ses-01/level1/run${run}_PCC_PPI_ACC.feat /ix1/lhallion/TReW-Brain/processed/sub-$subject/ses-01/level1/run${run}_PCC_PPI_ACC_adjreg.feat
	       featdir_dys=/ix1/lhallion/TReW-Brain/processed/sub-$subject/ses-01/level1/run${run}_PCC_PPI_ACC_adjreg.feat
	    cp $FSLDIR/etc/flirtsch/ident.mat $featdir_dys/reg/example_func2standard.mat 
	    cp $FSLDIR/etc/flirtsch/ident.mat $featdir_dys/reg/standard2example_func.mat
	    cp $featdir_dys/mean_func.nii.gz $featdir_dys/reg/standard.nii.gz
	  else
	   	mv /ix1/lhallion/TReW-Brain/processed/sub-$subject/ses-01/level1/run${run}_PCC_PPI_ACC.feat /ix1/lhallion/TReW-Brain/processed/sub-$subject/ses-01/level1/run${run}_dyscontrol_toremove.feat
	  fi
	done

