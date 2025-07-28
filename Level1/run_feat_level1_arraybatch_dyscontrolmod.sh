#!/bin/bash
# Script written in May 2022 by Ceci Westbrook

# Batch options
# Inputs ----------------------------------
#SBATCH -J feat
#SBATCH --time=12:00:00
#SBATCH --cluster=smp
#SBATCH -N 1
#SBATCH --cpus-per-task=2
#SBATCH --array=0-70
# Outputs ----------------------------------
#SBATCH -o log/%x-%A-%a.out
#SBATCH -e log/%x-%A-%a.err
# ------------------------------------------

run=2 #1, 2 or 3

# creates an array of all subjects from saved file
subs=()

# if running all subjects:
filename="subjects_run${run}.txt"
subs=(`cat "$filename"`)

# if running/rerunning a subset:
#subs=(XXX)

# chooses a subset of #x subjects starting at index #n
n=$SLURM_ARRAY_TASK_ID # index of subject to start at
x=1 # number of subjects to run
uniq_subs=($(printf "%s\n" ${subs[@]} | sort -u))
subject="${uniq_subs[@]:${n}:${x}}"
echo "Running batch: $subject"

# Make directories if needed
if [[ -d "/ix1/lhallion/TReW-Brain/preprocessed/sub-${subject}/ses-01" ]] ; then
	mkdir /ix1/lhallion/TReW-Brain/processed/sub-${subject}/
	mkdir /ix1/lhallion/TReW-Brain/processed/sub-${subject}/ses-01
	mkdir /ix1/lhallion/TReW-Brain/processed/sub-${subject}/ses-01/level1
fi


# Remove old feat directories if re-running
if [[ -e "/ix1/lhallion/TReW-Brain/processed/sub-${subject}/ses-01/level1/run${run}_dyscontrolmod_censorRT.feat" ]] ; then
	echo "found old feat"
	rm -r /ix1/lhallion/TReW-Brain/processed/sub-${subject}/ses-01/level1/run"${run}"_dyscontrolmod_censorRT*.feat
	else
		echo "old dirs not found"
fi

# load singularity module
module load fsl

# build the command, with option to write out for debugging purposes
featfile="/ix1/lhallion/TReW-Brain/Scripts/Level1/level1_fsf_files/dyscontrolmod/sub-${subject}_ses-01_fsf-lv1_run-${run}_dyscontrolmod.fsf"
cmd="feat $featfile"
eval $cmd

# for testing
#echo $cmd
