# MRIcroGL scripting console script.
# Paste into Window > Scripting, or open as a .py from the Scripting menu.
#
# Generates one PNG per model, each showing both directions overlaid:
#   thresh_zstat1 (activation)   -> red-yellow
#   thresh_zstat2 (deactivation) -> blue-cyan
# Colour scaling 0-7 to match the published colour bar.
#
# Edit BASE and SLICES below, then run. Output goes to BASE/panels/.

import gl
import os

# ----------------------------------------------------------------- settings
BASE = os.environ.get('TREW_GROUP_DIR', './data/group_level')

OUTDIR = os.path.join(BASE, 'panels')

# Axial slices (mm) and sagittal slice, matching the published figure layout.
# Published set was -20 -12 8 25 48 / x=-3; the corrected results sit more
# dorsally (peaks at 32-60), so consider -16 -4 16 32 56.
AXIAL_ROW1 = [-20, -12, 8]
AXIAL_ROW2 = [25, 48]
SAGITTAL   = -3

ZMIN = 0.0
ZMAX = 7.0

# Colormaps. Check Options > Colour schemes for the exact names in your build;
# '4hot' and 'electric_blue' are the usual red-yellow / blue-cyan pair.
CMAP_POS = '4hot'
CMAP_NEG = 'electric_blue'

MODELS = [
    'dyscontrolmod',
    'dyscontrolandeffortmods',
    'ACCmod',
    'PPI_PCC_DC',
    'PPI_SARTACCcluster',
]
# ---------------------------------------------------------------------------


def mosaic_string():
    """Two rows of axials plus the sagittal, then a render."""
    row1 = ' '.join(str(z) for z in AXIAL_ROW1)
    row2 = ' '.join(str(z) for z in AXIAL_ROW2)
    return 'A L+ H -0.1 {} S {}; A {} R 0'.format(row1, SAGITTAL, row2)


def panel(model):
    pos = os.path.join(BASE, model, 'thresh_zstat1.nii')
    neg = os.path.join(BASE, model, 'thresh_zstat2.nii')

    gl.resetdefaults()
    gl.loadimage('mni152')

    layer = 0

    # Deactivation first so activation draws on top where they touch.
    if os.path.exists(neg):
        gl.overlayload(neg)
        layer += 1
        gl.minmax(layer, ZMIN, ZMAX)
        gl.colorname(layer, CMAP_NEG)
        gl.opacity(layer, 100)

    if os.path.exists(pos):
        gl.overlayload(pos)
        layer += 1
        gl.minmax(layer, ZMIN, ZMAX)
        gl.colorname(layer, CMAP_POS)
        gl.opacity(layer, 100)

    if layer == 0:
        print('  no stat maps found for ' + model)
        return

    gl.colorbarposition(0)       # 0 = hidden; make the bar once separately
    gl.mosaic(mosaic_string())

    out = os.path.join(OUTDIR, model + '.png')
    gl.savebmp(out)
    print('  wrote ' + out)


# ---------------------------------------------------------------------------
if not os.path.isdir(OUTDIR):
    os.makedirs(OUTDIR)

print('Slices: axial ' + str(AXIAL_ROW1 + AXIAL_ROW2) +
      '  sagittal x=' + str(SAGITTAL))
print('Mosaic: ' + mosaic_string())
print('')

for m in MODELS:
    print(m)
    panel(m)

print('')
print('Done. PNGs in ' + OUTDIR)
