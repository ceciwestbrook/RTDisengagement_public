#!/bin/bash
# Script written in May 2022 by Ceci Westbrook

# Batch options
# Inputs ----------------------------------
#SBATCH -J feat_level2
#SBATCH --time=12:00:00
#SBATCH --cluster=smp
#SBATCH -N 1
#SBATCH --cpus-per-task=2
#SBATCH --array=0-70
# Outputs ----------------------------------
#SBATCH -o log/%x-%A-%a.out
#SBATCH -e log/%x-%A-%a.err
# ------------------------------------------

# creates an array of all subjects from directories in BIDS dir (rawdata)
subs=()
for dir in `ls -d /ix1/lhallion/TReW-Brain/processed/*`; do
	rawname=`basename $dir`
	subject=`echo ${rawname} | grep -Eo '[0-9]{3}'`
	subs+=($subject)
done

# chooses a subset of #x subjects starting at index #n
n=$SLURM_ARRAY_TASK_ID # index of subject to start at
x=1 # number of subjects to run
uniq_subs=($(printf "%s\n" ${subs[@]} | sort -u))
subject="${uniq_subs[@]:${n}:${x}}"

fsfdir=/ix1/lhallion/TReW-Brain/Scripts/Level2/level2_fsf_files/ACCmod
module load fsl
echo "running $subject"

# Make directories if needed
if [[ -d "/ix1/lhallion/TReW-Brain/processed/sub-${subject}/ses-01/level1" ]] ; then
	mkdir "/ix1/lhallion/TReW-Brain/processed/sub-${subject}/ses-01/level2"
fi

# Remove old feat directories if re-running
if [[ -d "/ix1/lhallion/TReW-Brain/processed/sub-${subject}/ses-01/level2/ACCmod_censorRT.gfeat/" ]] ; then
	echo "found old feat dir"
	rm -r /ix1/lhallion/TReW-Brain/processed/sub-${subject}/ses-01/level2/ACCmod_censorRT*.gfeat
	else echo "no old feat dirs found"
fi

for featfile in `ls "$fsfdir/sub-${subject}_ses-01_fsf-lv2_ACCmod.fsf"` ; do
	feat $featfile
done

