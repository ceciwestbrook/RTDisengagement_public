"""
Report which Yeo-17 networks a thresholded FEAT cluster map falls in.

Uses the same atlas the MVPA parcellation used (nilearn fetch_atlas_yeo_2011,
17 networks, thick), so the network labels match the decoding features.

Run with the my_env environment active:
    source activate /ix/cladouceur/westbroo/envs/my_env
    python yeo_overlap.py <thresh_zstat.nii.gz> [more maps ...]

With no arguments it uses the effort-model map set in DEFAULT_MAPS below.
"""
import sys

import nibabel as nib
import numpy as np
from nilearn import datasets
from nilearn.image import resample_to_img

# Yeo-17 "thick" network order, matching config.py YEO17_NAMES
NAMES = [
    'Visual A', 'Visual B',
    'Somatomotor A', 'Somatomotor B',
    'Dorsal Attention A', 'Dorsal Attention B',
    'Salience/VentAttn A', 'Salience/VentAttn B',
    'Limbic A', 'Limbic B',
    'Control A', 'Control B', 'Control C',
    'Default A', 'Default B', 'Default C', 'Default D',
]

# Which family each network belongs to, for the summary line
FAMILY = {
    'Visual': 'Visual', 'Somatomotor': 'Somatomotor',
    'Dorsal Attention': 'DorsAttn', 'Salience/VentAttn': 'SalVentAttn',
    'Limbic': 'Limbic', 'Control': 'Control (FPN)', 'Default': 'Default (DMN)',
}

GROUP = '${TREW_GROUP_DIR}/'
DEFAULT_MAPS = [
    f'{GROUP}/dyscontrolandeffortmods/SARTdcBaseline.gfeat/cope1.feat/thresh_zstat2.nii.gz',
]


def family_of(name):
    for prefix, fam in FAMILY.items():
        if name.startswith(prefix):
            return fam
    return 'Other'


def load_yeo17():
    """Fetch the Yeo-17 thick atlas, across nilearn API versions.

    Newer nilearn: fetch_atlas_yeo_2011(n_networks=17, thickness='thick')
                   -> dict with 'maps'
    Older nilearn: fetch_atlas_yeo_2011()
                   -> dict with 'thick_17', 'thin_17', 'thick_7', ...
    """
    try:
        atlas = datasets.fetch_atlas_yeo_2011(n_networks=17,
                                              thickness='thick')
    except TypeError:
        atlas = datasets.fetch_atlas_yeo_2011()

    for key in ('maps', 'thick_17', 'thin_17'):
        try:
            path = atlas[key]
        except (KeyError, TypeError):
            path = getattr(atlas, key, None)
        if path:
            print(f'Atlas key "{key}": {path}')
            return nib.load(path)

    raise RuntimeError(
        f'Could not find a 17-network map in the fetched atlas. '
        f'Available: {list(atlas) if hasattr(atlas, "__iter__") else dir(atlas)}'
    )


def report(map_path, atlas_img):
    print(f'\n=== {map_path}')
    try:
        z = nib.load(map_path)
    except Exception as e:
        print(f'  could not load: {e}')
        return

    zdat = np.asarray(z.dataobj).squeeze()
    mask = zdat > 0
    n_vox = int(mask.sum())
    if n_vox == 0:
        print('  no suprathreshold voxels')
        return
    print(f'  {n_vox} suprathreshold voxels, max z = {zdat.max():.2f}')

    # Put the atlas on the map's grid (nearest-neighbour keeps labels intact)
    try:
        at = resample_to_img(atlas_img, z, interpolation='nearest',
                             force_resample=True, copy_header=True)
    except TypeError:
        at = resample_to_img(atlas_img, z, interpolation='nearest')
    adat = np.asarray(at.dataobj).squeeze().astype(int)

    labs, cts = np.unique(adat[mask], return_counts=True)

    print('\n  By network:')
    fam_tot = {}
    unlabelled = 0
    for lab, ct in sorted(zip(labs, cts), key=lambda x: -x[1]):
        if lab == 0:
            unlabelled = ct
            continue
        name = NAMES[lab - 1] if 1 <= lab <= 17 else f'label {lab}'
        pct = 100 * ct / n_vox
        print(f'    {name:<22} {ct:6d}  ({pct:5.1f}%)')
        fam_tot[family_of(name)] = fam_tot.get(family_of(name), 0) + ct

    print('\n  By family:')
    for fam, ct in sorted(fam_tot.items(), key=lambda x: -x[1]):
        print(f'    {fam:<22} {ct:6d}  ({100 * ct / n_vox:5.1f}%)')
    if unlabelled:
        print(f'    {"outside atlas":<22} {unlabelled:6d}  '
              f'({100 * unlabelled / n_vox:5.1f}%)')


if __name__ == '__main__':
    maps = sys.argv[1:] or DEFAULT_MAPS
    atlas_img = load_yeo17()
    for m in maps:
        report(m, atlas_img)
