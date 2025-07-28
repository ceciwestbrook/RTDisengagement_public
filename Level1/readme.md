# Ceci Westbrook, 7/2025

Level 1 analyses were performed using FSL's Feat program. In this directory is a copy of the template design (fsf) files and a script that can generate the design files for all participants. Note that there are 3 different versions of the design file: one with parametric modulation by the SART Skill Index (ACCmod), one with parametric modulation by probe-reported uncontrollability (dyscontrolmod), and one with both uncontrollability and probe-reported task effort (dyscontrolandeffortmod). 

The individual timing files are not included in this repository but they can be generated from the .tsv files in the associated OpenNeuro dataset. We used the 3-column FSL format. An example timing file is included in this directory with the columns 1) onset 2) duration 3) modulator (uncontrollability).

As preprocessing was completed in fmriprep, these fsf files do not contain registration. This requires an adjustment to be applied after-the-fact (see Level 2).

After the fsf files are generated, they can be batch-run on a SLURM filesystem using the arraybatch scripts in this directory.

Use of this repository assumes basic knowledge of bash or other command-line scripting and software such as Python or R for data reformatting.