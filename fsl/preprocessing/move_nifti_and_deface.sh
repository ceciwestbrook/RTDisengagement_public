#!/bin/bash
# Ceci Westbrook, 2025
# script to unzip TReW-Brain MRI data, deface and move to CRC

# destination directory
dest_dir=${TREW_DATA_ROOT}/rawdata/

for subdir in `ls -d ${TREW_DATA_ROOT}/sourcedata/dicom/*`
	do
		subnum=$(echo $subdir | grep -oE '[0-9]+')
		fullsub=$(basename $subdir)
		echo $fullsub' '$subnum
		
		if [ -e $subdir/flywheel*zip ] &&  [ ! -d $subdir/flywheel ]; then
			unzip $subdir/flywheel*zip -d $subdir/
		fi
		
		if [[ ! -e $dest_dir/sub-$subnum ]] ; then
			mkdir $dest_dir/sub-$subnum
			mkdir $dest_dir/sub-$subnum/ses-01
			mkdir $dest_dir/sub-$subnum/ses-01/anat
			mkdir $dest_dir/sub-$subnum/ses-01/func
			mkdir $dest_dir/sub-$subnum/ses-01/fmap
		fi
		
		cp $subdir/flywheel/halliongroup/StickyThoughts/$fullsub/ses-01/anat-T1w_acq-MPRvNav/*nii.gz $dest_dir/sub-$subnum/ses-01/anat/sub-${subnum}_ses-01_acq-MPRvNav_T1w_nondefaced.nii.gz
		cp $subdir/flywheel/halliongroup/StickyThoughts/$fullsub/ses-01/anat-T1w_acq-MPRvNav/*json $dest_dir/sub-$subnum/ses-01/anat/sub-${subnum}_ses-01_acq-MPRvNav_T1w.json
		cp $subdir/flywheel/halliongroup/StickyThoughts/$fullsub/ses-01/func-bold_task-restingstate_run-01/*nii.gz $dest_dir/sub-$subnum/ses-01/func/sub-${subnum}_ses-01_task-restingstate_run-01_bold.nii.gz
		cp $subdir/flywheel/halliongroup/StickyThoughts/$fullsub/ses-01/func-bold_task-restingstate_run-01/*json $dest_dir/sub-$subnum/ses-01/func/sub-${subnum}_ses-01_task-restingstate_run-01_bold.json
		cp $subdir/flywheel/halliongroup/StickyThoughts/$fullsub/ses-01/func-bold_task-runA_run-01/*nii.gz $dest_dir/sub-$subnum/ses-01/func/sub-${subnum}_ses-01_task-PDT_run-01_bold.nii.gz
		cp $subdir/flywheel/halliongroup/StickyThoughts/$fullsub/ses-01/func-bold_task-runA_run-01/*json $dest_dir/sub-$subnum/ses-01/func/sub-${subnum}_ses-01_task-PDT_run-01_bold.json
		cp $subdir/flywheel/halliongroup/StickyThoughts/$fullsub/ses-01/func-bold_task-runB_run-01/*nii.gz $dest_dir/sub-$subnum/ses-01/func/sub-${subnum}_ses-01_task-PDT_run-02_bold.nii.gz
		cp $subdir/flywheel/halliongroup/StickyThoughts/$fullsub/ses-01/func-bold_task-runB_run-01/*json $dest_dir/sub-$subnum/ses-01/func/sub-${subnum}_ses-01_task-PDT_run-02_bold.json		
		cp $subdir/flywheel/halliongroup/StickyThoughts/$fullsub/ses-01/func-bold_task-runC_run-01/*nii.gz $dest_dir/sub-$subnum/ses-01/func/sub-${subnum}_ses-01_task-PDT_run-03_bold.nii.gz
		cp $subdir/flywheel/halliongroup/StickyThoughts/$fullsub/ses-01/func-bold_task-runC_run-01/*json $dest_dir/sub-$subnum/ses-01/func/sub-${subnum}_ses-01_task-PDT_run-03_bold.json
		cp $subdir/flywheel/halliongroup/StickyThoughts/$fullsub/ses-01/fmap-epi_acq-opphase_dir-AP/*nii.gz $dest_dir/sub-$subnum/ses-01/fmap/sub-${subnum}_ses-01_acq-opphase_dir-AP.nii.gz
		cp $subdir/flywheel/halliongroup/StickyThoughts/$fullsub/ses-01/fmap-epi_acq-opphase_dir-PA/*nii.gz $dest_dir/sub-$subnum/ses-01/fmap/sub-${subnum}_ses-01_acq-opphase_dir-PA.nii.gz
		cp $subdir/flywheel/halliongroup/StickyThoughts/$fullsub/ses-01/fmap-epi_acq-opphase_dir-AP/*json $dest_dir/sub-$subnum/ses-01/fmap/sub-${subnum}_ses-01_acq-opphase_dir-AP.json
		cp $subdir/flywheel/halliongroup/StickyThoughts/$fullsub/ses-01/fmap-epi_acq-opphase_dir-PA/*json $dest_dir/sub-$subnum/ses-01/fmap/sub-${subnum}_ses-01_acq-opphase_dir-PA.json
			
		#deface anatomicals
 		cd $dest_dir/sub-$subnum/ses-01/anat
     	pydeface 'sub-'$subnum'_ses-01_acq-MPRvNav_T1w_nondefaced.nii.gz' --outfile 'sub-'$subnum'_ses-01_acq-MPRvNav_T1w.nii.gz'
     	rm 'sub-'$subnum'_ses-01_acq-MPRvNav_T1w_nondefaced.nii.gz'
     	cd $dest_dir
	done