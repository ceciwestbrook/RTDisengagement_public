# Figures

Brain figures are generated in MRIcroGL from thresholded group maps, then
composited. `make_panels.py` runs in MRIcroGL's scripting console
(Window > Scripting) and writes one panel per model with consistent slices,
colour scaling and orientation.

Slices: axial z = −20, −12, 8, 25, 56; sagittal x = −3; plus a surface render.
Activation in `6warm`, deactivation in `7cool`, both scaled z = 0–7. PPI
figures additionally overlay the seed mask in `1red`.

MRIcroGL renders in radiological convention here: the left of each axial slice
is the right of the brain. Verify after any version change by loading a
known-lateralized mask.

## Network correspondence

Thresholded maps are characterized against six atlases with the Network
Correspondence Toolbox (Kong et al., 2025, *Nat Commun* 16:2930):

| Key | Atlas |
|---|---|
| MG360J12 | Glasser 2016 360 ROI, Ji 2019 Cole–Anticevic networks |
| AL20 | Laird 2011 20-node ICA |
| XS268_8 | Shen 2013 268 ROI, 8 networks |
| EG17 | Gordon 2017, 17 networks |
| TY7 | Yeo 7 networks |
| XY200K17 | Yan 2023 200 ROI, Kong 2021 17 networks |

Input maps are FSL MNI 2 mm volumes; the toolbox projects them to fsaverage6
for its spin test, so the correspondence is cortical. Cerebellar and subcortical
clusters are not characterized by it and are described from atlas labels
instead.
