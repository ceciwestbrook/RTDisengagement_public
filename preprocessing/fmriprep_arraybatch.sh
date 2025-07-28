#!/bin/bash
# Script written in April 2022 by Ceci Westbrook

# Batch options I have found to work best on HTC
# Inputs ----------------------------------
#SBATCH -J fmriprep
#SBATCH --time=12:00:00
#SBATCH --cluster=SMP
#SBATCH -N 1
#SBATCH --cpus-per-task=16
#SBATCH --mem=32G
#SBATCH --array=50-50
# Outputs ----------------------------------
#SBATCH -o log/%x-%A-%a.out
#SBATCH -e log/%x-%A-%a.err
# ------------------------------------------

# creates an array of all subjects from directories in BIDS dir (rawdata)
subs=()
for dir in `ls -d /ix1/lhallion/TReW-Brain/rawdata/*`; do
	rawname=`basename $dir`
	subject=`echo ${rawname} | grep -Eo '[0-9]{3}'`
	subs+=($subject)
done

# chooses a subset of #x subjects starting at index #n
n=$SLURM_ARRAY_TASK_ID # index of subject to start at
x=1 # number of subjects to run
uniq_subs=($(printf "%s\n" ${subs[@]} | sort -u))
subjectlist="${uniq_subs[@]:${n}:${x}}"
echo "Running batch: $subjectlist ncores: 16 mem: 32G"

# Build the fmriprep command
base_dir=/ix1/lhallion/TReW-Brain
BIDS_dir=$base_dir/rawdata
preprocessed_dir=$base_dir/preprocessed
fsfileloc=$base_dir/license_free_surfer.txt
singularity_cmd="singularity run --cleanenv --bind $base_dir:$base_dir $base_dir/fmriprep-24.1.1.simg"

# Options - specify for individual study needs
# The below run fmriprep on $subjectlist specified above
# !!Important note! Make sure nprocs is set equal to cpus-per-task in the header!
options="--fs-license-file $fsfileloc \
--nprocs 16 \
--ignore fieldmaps slicetiming \
--fd-spike-threshold 0.6 \
--output-spaces MNI152NLin6Asym:res-2 \
--participant-label $subjectlist \
--skip-bids-validation"

# load singularity module
module load singularity

# move to the location you're running fmriprep from (optional, but makes some things easier)
cd /ix1/lhallion/TReW-Brain/

# build the command, with option to write out for debugging purposes
# including "time" to check how long batches take to run at different parameters--this writes out in the outfile
cmd="$singularity_cmd $BIDS_dir $preprocessed_dir participant $options"
echo $cmd
eval $cmd
