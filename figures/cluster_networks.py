#!/usr/bin/env python3
"""
Per-cluster anatomical and network assignment for a thresholded FEAT map.

Why this exists: running a whole-map overlap against a cortical atlas conflates
"not in a cortical network" with "not real". A map that is half cerebellum comes
back as 80% 'outside atlas', which says nothing. This splits each cluster into
cortical / subcortical / cerebellar compartments first, then reports network
membership *within the cortical part*, so the percentages mean what they appear
to mean.

Usage:
    python cluster_networks.py <cope.feat dir> <zstat number> [--min-voxels N]

    python cluster_networks.py \\
        ${TREW_GROUP_DIR}/PPI/PPI_PCC_DC/SARTDCPPI.gfeat/cope1.feat 1

Reads cluster_mask_zstat<N>.nii.gz and thresh_zstat<N>.nii.gz from that
directory. Atlases come from $FSLDIR (local, no download needed) except Yeo,
which is read from the nilearn_data cache that yeo_overlap.py already populated.
"""

import os
import sys
import argparse
import numpy as np
import nibabel as nib

try:
    from nilearn.image import resample_to_img
except ImportError:
    sys.exit("ERROR: nilearn not available. Try: module load fsl; pip install --user nilearn")

# ---------------------------------------------------------------- atlas paths

FSLDIR = os.environ.get('FSLDIR', '')
if not FSLDIR:
    sys.exit("ERROR: FSLDIR not set. Run: module load fsl")

ATLAS_DIR = os.path.join(FSLDIR, 'data', 'atlases')

HO_SUB = os.path.join(ATLAS_DIR, 'HarvardOxford',
                      'HarvardOxford-sub-maxprob-thr25-1mm.nii.gz')
HO_CORT = os.path.join(ATLAS_DIR, 'HarvardOxford',
                       'HarvardOxford-cort-maxprob-thr25-1mm.nii.gz')
CEREB = os.path.join(ATLAS_DIR, 'Cerebellum',
                     'Cerebellum-MNIfnirt-maxprob-thr25-1mm.nii.gz')

# Yeo: look where nilearn put it
YEO_CANDIDATES = [
    os.path.expanduser('~/nilearn_data/yeo_2011/Yeo_JNeurophysiol11_MNI152/'
                       'Yeo2011_17Networks_MNI152_FreeSurferConformed1mm_LiberalMask.nii.gz'),
    os.path.expanduser('~/nilearn_data/yeo_2011/Yeo_JNeurophysiol11_MNI152/'
                       'Yeo2011_17Networks_MNI152_FreeSurferConformed1mm.nii.gz'),
]

YEO17 = {
    1: 'Visual A',            2: 'Visual B',
    3: 'Somatomotor A',       4: 'Somatomotor B',
    5: 'Dorsal Attention A',  6: 'Dorsal Attention B',
    7: 'Salience/VentAttn A', 8: 'Salience/VentAttn B',
    9: 'Limbic A',           10: 'Limbic B',
    11: 'Control C',         12: 'Control A',
    13: 'Control B',         14: 'Temporal/Parietal',
    15: 'Default D',         16: 'Default C',
    17: 'Default A',
}
# Note: Yeo-17 index-to-name mappings differ between releases. If these labels
# disagree with yeo_overlap.py, trust that script and adjust this dict.

FAMILY = {
    'Visual': 'Visual', 'Somatomotor': 'Somatomotor',
    'Dorsal Attention': 'DorsAttn', 'Salience/VentAttn': 'SalVentAttn',
    'Limbic': 'Limbic', 'Control': 'Control (FPN)', 'Default': 'Default (DMN)',
    'Temporal/Parietal': 'Temporal/Parietal',
}


def family_of(name):
    for prefix, fam in FAMILY.items():
        if name.startswith(prefix):
            return fam
    return name


def load_labels(path):
    """Harvard-Oxford / Cerebellum label names from the FSL XML, if present."""
    xml = path
    for marker in ['-maxprob-thr25-1mm.nii.gz', '-MNIfnirt-maxprob-thr25-1mm.nii.gz']:
        xml = xml.replace(marker, '')
    xml = xml.replace(os.path.join(ATLAS_DIR, 'HarvardOxford', ''),
                      os.path.join(ATLAS_DIR, ''))
    xml = xml.replace(os.path.join(ATLAS_DIR, 'Cerebellum', ''),
                      os.path.join(ATLAS_DIR, ''))
    xml += '.xml'
    labels = {}
    if os.path.exists(xml):
        import re
        with open(xml) as f:
            for line in f:
                m = re.search(r'index="(\d+)"[^>]*>([^<]+)<', line)
                if m:
                    labels[int(m.group(1)) + 1] = m.group(2).strip()
    return labels


def resample_atlas(atlas_path, target_img):
    a = nib.load(atlas_path)
    return resample_to_img(a, target_img, interpolation='nearest',
                           force_resample=True, copy_header=True)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('featdir')
    ap.add_argument('zstat', type=int)
    ap.add_argument('--min-voxels', type=int, default=0,
                    help='skip clusters smaller than this')
    args = ap.parse_args()

    cmask_p = os.path.join(args.featdir, f'cluster_mask_zstat{args.zstat}.nii.gz')
    thresh_p = os.path.join(args.featdir, f'thresh_zstat{args.zstat}.nii.gz')
    for p in (cmask_p, thresh_p):
        if not os.path.exists(p):
            sys.exit(f"ERROR: not found: {p}")

    cmask_img = nib.load(cmask_p)
    cmask = np.asarray(cmask_img.dataobj)
    zmap = np.asarray(nib.load(thresh_p).dataobj)

    print(f"\n=== {args.featdir}")
    print(f"    zstat{args.zstat}\n")

    # Atlases, resampled onto the stat map grid
    yeo_p = next((p for p in YEO_CANDIDATES if os.path.exists(p)), None)
    if yeo_p is None:
        sys.exit("ERROR: Yeo atlas not found in ~/nilearn_data. "
                 "Run yeo_overlap.py once to download it.")
    print(f"    Yeo:       {yeo_p}")
    print(f"    HO subcort:{HO_SUB}")
    print(f"    Cerebellum:{CEREB}\n")

    yeo = np.asarray(resample_atlas(yeo_p, cmask_img).dataobj).astype(int)
    sub = np.asarray(resample_atlas(HO_SUB, cmask_img).dataobj).astype(int)
    cer = np.asarray(resample_atlas(CEREB, cmask_img).dataobj).astype(int)

    sub_labels = load_labels(HO_SUB)
    cer_labels = load_labels(CEREB)

    idxs = sorted([int(i) for i in np.unique(cmask) if i > 0], reverse=True)

    hdr = f"{'Clus':>5} {'Vox':>6} {'Zmax':>6} {'Peak (x y z)':>16}  Compartment / networks"
    print(hdr)
    print('-' * len(hdr))

    for ci in idxs:
        m = (cmask == ci)
        n = int(m.sum())
        if n < args.min_voxels:
            continue

        zvals = zmap[m]
        zmax = float(zvals.max())
        pk = np.unravel_index(np.argmax(np.where(m, zmap, -np.inf)), zmap.shape)
        mni = nib.affines.apply_affine(cmask_img.affine, np.array(pk))
        mni_s = f"{mni[0]:.0f} {mni[1]:.0f} {mni[2]:.0f}"

        # compartments
        in_cer = int((m & (cer > 0)).sum())
        in_sub = int((m & (sub > 0) & (cer == 0)).sum())
        in_yeo = int((m & (yeo > 0) & (cer == 0) & (sub == 0)).sum())
        unassigned = n - in_cer - in_sub - in_yeo

        print(f"{ci:>5} {n:>6} {zmax:>6.2f} {mni_s:>16}")
        print(f"{'':>36}  cortical(Yeo) {in_yeo:>5}  subcortical {in_sub:>4}  "
              f"cerebellar {in_cer:>4}  unassigned {unassigned:>4}")

        # networks within the cortical part only
        if in_yeo > 0:
            cm = m & (yeo > 0) & (cer == 0) & (sub == 0)
            vals, counts = np.unique(yeo[cm], return_counts=True)
            fam = {}
            for v, c in zip(vals, counts):
                fam[family_of(YEO17.get(int(v), f'net{v}'))] = \
                    fam.get(family_of(YEO17.get(int(v), f'net{v}')), 0) + int(c)
            parts = [f"{k} {v} ({100.0*v/in_yeo:.0f}% of cortical)"
                     for k, v in sorted(fam.items(), key=lambda x: -x[1])]
            print(f"{'':>36}  " + '; '.join(parts))

        # named subcortical structures
        if in_sub > 0 and sub_labels:
            sm = m & (sub > 0) & (cer == 0)
            vals, counts = np.unique(sub[sm], return_counts=True)
            order = np.argsort(-counts)
            parts = [f"{sub_labels.get(int(vals[i]), int(vals[i]))} {int(counts[i])}"
                     for i in order[:4]]
            print(f"{'':>36}  subcortical: " + '; '.join(parts))

        # named cerebellar lobules
        if in_cer > 0 and cer_labels:
            km = m & (cer > 0)
            vals, counts = np.unique(cer[km], return_counts=True)
            order = np.argsort(-counts)
            parts = [f"{cer_labels.get(int(vals[i]), int(vals[i]))} {int(counts[i])}"
                     for i in order[:3]]
            print(f"{'':>36}  cerebellar: " + '; '.join(parts))

        print()

    # whole-map compartment summary
    allm = cmask > 0
    tot = int(allm.sum())
    c_cer = int((allm & (cer > 0)).sum())
    c_sub = int((allm & (sub > 0) & (cer == 0)).sum())
    c_yeo = int((allm & (yeo > 0) & (cer == 0) & (sub == 0)).sum())
    print(f"WHOLE MAP  {tot} voxels: cortical {c_yeo} ({100.0*c_yeo/tot:.0f}%), "
          f"subcortical {c_sub} ({100.0*c_sub/tot:.0f}%), "
          f"cerebellar {c_cer} ({100.0*c_cer/tot:.0f}%), "
          f"unassigned {tot-c_yeo-c_sub-c_cer} ({100.0*(tot-c_yeo-c_sub-c_cer)/tot:.0f}%)")
    print()


if __name__ == '__main__':
    main()
