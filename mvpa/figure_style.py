"""
Consistent figure styling for publication-grade output.

Usage in notebooks:

    from figure_style import setup_style, save_fig, NETWORK_COLORS

    setup_style()  # call once at the top of figures.ipynb

    fig, ax = plt.subplots(figsize=(4, 3))
    # ... plot ...
    save_fig(fig, 'fig01_loso_decoding')

All saved figures go to derivatives/figures/ as PDF (vector). Use save_fig with
`also_png=True` if you want a PNG copy too.

Edit the style here -- everything centralized for easy revision.
"""
from __future__ import annotations

from pathlib import Path

import matplotlib as mpl
import matplotlib.pyplot as plt

from config import DERIVATIVES_DIR


# =============================================================================
# Output location
# =============================================================================
FIGURES_DIR = DERIVATIVES_DIR / 'figures'


# =============================================================================
# Color palette
# =============================================================================
# Conditions
COLORS = {
    'thoughtblock': '#2E5EAA',  # blue
    'sart':         '#D55E00',  # orange
    'fixation':     '#999999',  # gray
    'high':         '#C73C3C',  # red (high dyscontrol)
    'low':          '#4A8FCC',  # blue (low dyscontrol)
    'real':         '#222222',  # near-black (real data line)
    'permuted':     '#999999',  # gray (null distribution)
    'positive':     '#2E5EAA',  # ridge coef positive
    'negative':     '#C73C3C',  # ridge coef negative
}

# Yeo-17 network colors (one per network), grouping the 17 parcels into
# functional families. Matches the standard Yeo network color scheme.
NETWORK_COLORS = {
    'Visual A':              '#7E1F86',  # purple
    'Visual B':              '#9B3FA1',
    'Somatomotor A':         '#5BAEC8',  # cyan
    'Somatomotor B':         '#7BC0D5',
    'Dorsal Attention A':    '#33A02C',  # green
    'Dorsal Attention B':    '#5DBA56',
    'Salience/VentAttn A':   '#C56CCC',  # magenta
    'Salience/VentAttn B':   '#D78DDA',
    'Limbic A':              '#FFBB78',  # tan/cream
    'Limbic B':              '#FFD09E',
    'Control C':             '#E2A930',  # gold
    'Control A':             '#E5B947',
    'Control B':             '#E8C760',
    'Default D':             '#D32F1E',  # red
    'Default C':             '#D9483B',
    'Default A':             '#E0625A',
    'Default B':             '#E77B7B',
}


# =============================================================================
# Apply a generic-clean style
# =============================================================================
def setup_style():
    """Apply consistent styling to matplotlib. Call once per session."""
    mpl.rcParams.update({
        # Font
        'font.family': 'sans-serif',
        'font.sans-serif': ['Helvetica', 'Arial', 'DejaVu Sans'],
        'font.size': 9,
        'axes.titlesize': 10,
        'axes.labelsize': 9,
        'xtick.labelsize': 8,
        'ytick.labelsize': 8,
        'legend.fontsize': 8,
        'figure.titlesize': 11,

        # Lines and markers
        'lines.linewidth': 1.2,
        'lines.markersize': 4,
        'patch.linewidth': 0.5,

        # Axes
        'axes.linewidth': 0.6,
        'axes.spines.top': False,
        'axes.spines.right': False,
        'axes.edgecolor': '#333333',
        'axes.labelcolor': '#222222',
        'axes.titlecolor': '#222222',
        'axes.titleweight': 'normal',
        'axes.titlepad': 6.0,
        'axes.labelpad': 4.0,

        # Ticks
        'xtick.direction': 'out',
        'ytick.direction': 'out',
        'xtick.major.size': 3,
        'ytick.major.size': 3,
        'xtick.major.width': 0.6,
        'ytick.major.width': 0.6,
        'xtick.color': '#333333',
        'ytick.color': '#333333',

        # Grid
        'axes.grid': False,

        # Background
        'figure.facecolor': 'white',
        'axes.facecolor': 'white',
        'savefig.facecolor': 'white',

        # Save defaults (PDF will override these for vector output)
        'savefig.dpi': 300,
        'savefig.bbox': 'tight',
        'savefig.pad_inches': 0.05,
        'pdf.fonttype': 42,  # embed TrueType fonts (editable in Illustrator)
        'ps.fonttype': 42,
    })


# =============================================================================
# Save helpers
# =============================================================================
def save_fig(fig, name: str, also_png: bool = False, dpi: int = 300):
    """
    Save a figure as PDF (default) and optionally PNG.

    Parameters
    ----------
    fig : matplotlib Figure
    name : str
        Base name (no extension). Sanitized: spaces -> underscores.
    also_png : bool
        If True, also save a PNG copy.
    dpi : int
        DPI for PNG (PDF is vector, dpi is irrelevant).

    Returns
    -------
    list of Path
        Paths to all saved files.
    """
    FIGURES_DIR.mkdir(parents=True, exist_ok=True)
    safe_name = name.replace(' ', '_').replace('/', '_')
    saved = []
    pdf_path = FIGURES_DIR / f'{safe_name}.pdf'
    fig.savefig(pdf_path, bbox_inches='tight', pad_inches=0.05)
    saved.append(pdf_path)
    if also_png:
        png_path = FIGURES_DIR / f'{safe_name}.png'
        fig.savefig(png_path, bbox_inches='tight', pad_inches=0.05, dpi=dpi)
        saved.append(png_path)
    return saved