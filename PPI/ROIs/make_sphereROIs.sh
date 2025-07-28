#! /bin/sh
# Ceci Westbrook 3/2023:
# script to make spherical ROIs using fsl and set coordinates.
# adapted from a script by Martin M Monti (monti@psych.ucla.edu)

# Notes:
# 		<input image> is an image that has the same resolution as the image you want to apply the ROI to. Edited by Ceci to point to the 2mm brain from FSL's standard directory. Change this to something else by editing the "infile" variable.
#		<x y z> are the ROI coordinates
#		<mm>  is the width of the ROI. If you will always want it to be the same (say 10mm), then you can just delete the $5
#				in the line starting with "echo", and replace the '$5' in the last line with the number you want (e.g. 10).

infile='/ihome/crc/install/fsl/6.0.4/centos7/fsl/data/standard/MNI152_T1_2mm_brain'

# also added in a field to name the output mask something more memorable.
# new use is:
# ./make_sphere_roi.sh <output_name> <x y z> <mm>

echo "******************************"
echo "Input image: ${infile} "
echo "ROI coordinates: ${2} ${3} ${4} "
echo "ROI size: ${5} "
fslmaths ${infile} -roi ${2} 1 ${3} 1 ${4} 1 0 1 tmp_point_mask
fslmaths tmp_point_mask -kernel sphere $5 -fmean -bin mask_sphere_${1}_${2}-${3}-${4}_${5}mm -odt float
rm tmp_point_mask.*
echo "Done! The output file is called 'mask_sphere_${1}_${2}-${3}-${4}_${5}mm' "

