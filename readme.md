# WorryMindfulness
This is the accompanying analysis code for the RT Disengagement, PI Hallion. Please see our preregistration at https://osf.io/qy4df for more information.

All code and associated documents were written by Ceci Westbrook 2022-2025 unless otherwise noted.

 # Task description: # 
Participants provided self-generated repetitive thought (RT) topics during an interview on a preceding session, which were converted to scanner stimuli. The fMRI task was completed on a subsequent visit, during which they were also instructed in worry disengagement strategies. The task comprised 3 runs of 9 trials each. For each trial, self-generated RT stimuli were presented for ~30s, followed by a 30s disengagement period in which participants completed a competing attention task (the Sustained Attention to Responses Task, SART). Following the SART, participants responded to thought probes including degree of uncontrollability of thoughts (i.e., disengagement success).

 # How to use this repository: # 
This dataset was analyzed primarily using FSL's Feat program, which takes design files (.fsf) as input. These files can be batch-edited and submitted, which was the approach used here, following Jeanette Mumford's approach (please see: https://www.youtube.com/playlist?list=PLB2iAtgpI4YHlH4sno3i3CUjCofI38a-3). The order of use for these scripts are:
 1) Preprocessing using fmriprep (batch call located in this directory)
 2) level 1 analyses conducted by batch-editing the template .fsf scripts found in the level1/ directory
 3) the same process for level 2 analyses; and finally
 4) group-level analyses utilizing the template scripts in the group_level directory
 
A similar process was followed for the psychophysiological interaction (PPI), in which case seed timeseries were extracted from preprocessed data and included in level1 analyses as well.

 # Data included: # 
All imaging data was collected on a 3T MRI scanner (MAGNETOM Verio syngo MR B17, Siemens Corporation) with a 64-channel radio-frequency (RF) head coil array.

Anatomical 
T1-weighted structural images (1 mm3 voxels) were acquired in the sagittal plane with an isotropic MPRAGE sequence using a parallel imaging factor of 2 (TR=2500, TE=2.90, TI = 1070, flip angle = 8º, voxel size = 1.0mm3, matrix size 256x256).

Functional
Functional data were collected as T2*-weighted gradient-echo echo-planar images with a multiband acceleration factor of 3 (TR = 2000, TE = 30, flip angle = 79º, echo spacing = 0.62, voxel size = 2.0mm3, matrix size 106x106, transversal orientation, 72 interleaved slices). 

Fieldmap
Two opposite phase-encoding (A>>P, P>>A) field maps were collected with resolution 3.0x3.0x2.0mm and matrix size 72x72. 

 # Preregistration: # 
This dataset corresponds to pre-registered analyses which can be found here: https://osf.io/qy4df.

 # Associated neural data # 
This code is associated with a neural dataset published on openneuro.org. DOI for this dataset will be added when it becomes publicly available.

 # Data collection and acknowledgements: # 
Data were collected at the CMU-Pitt Brain Imaging Data Generation & Education (BRIDGE) Center in Pittsburgh, PA, USA.
Funding was provided by the National Institute of Mental Health K01MH116328 (PI: Hallion).

 # Authors: # 
Cecilia A. Westbrook1, Brittany Alberts2, M. Kathleen Caulfield3, Mary Blendermann2, Peter J. Gianaros12, Jonathan Smallwood4, Jennifer S. Silk12, and Lauren S. Hallion5
1Department of Psychiatry, University of Pittsburgh, Pittsburgh, PA, USA
2Department of Psychology, University of Pittsburgh, Pittsburgh, PA, USA
3Reason Research, Philadelphia, PA, USA
4Department of Psychology, Queen's University, Kingston, ON, CA
5Department of Psychology, University of Regina, Regina, SK, CA

 # Status of current dataset: # 
Data are currently under submission at the Journal of Psychopathology and Clinical Science. Publication information will be forthcoming as it becomes available.
