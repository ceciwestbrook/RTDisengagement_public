"""
Paths and parameters for the multivariate pipeline.

Nothing here needs editing for a standard checkout: paths resolve relative to
the repository, and data is expected under `data/` (see data/README.md).
Override by exporting environment variables instead of editing this file:

    export TREW_DATA_ROOT=/path/to/data        # rawdata/, preprocessed/
    export TREW_WORK_ROOT=/path/to/scratch     # derivatives/ output

Preprocessing choices here match the FSL first-level analyses so that the
univariate and multivariate pipelines operate on comparably processed data:
24 motion parameters, cosine-basis high-pass confounds, no aCompCor.
"""
import os
from pathlib import Path

# =============================================================================
# Paths
# =============================================================================
REPO_ROOT = Path(__file__).resolve().parent.parent

DATA_ROOT = Path(os.environ.get('TREW_DATA_ROOT', REPO_ROOT / 'data'))
RAWDATA_ROOT = DATA_ROOT / 'rawdata'
FMRIPREP_ROOT = DATA_ROOT / 'preprocessed'
QUESTIONNAIRE_DIR = DATA_ROOT / 'questionnaires'

# Outputs. Kept out of the repository by .gitignore; set TREW_WORK_ROOT to put
# them on scratch instead.
WORK_ROOT = Path(os.environ.get('TREW_WORK_ROOT', REPO_ROOT))
DERIVATIVES_DIR = WORK_ROOT / 'derivatives'
PARCELS_DIR = DERIVATIVES_DIR / 'parcels'
DECODING_OUT_DIR = DERIVATIVES_DIR / 'decoding'
FIGURES_DIR = DERIVATIVES_DIR / 'figures'

TRIAL_LEVEL_CSV = DERIVATIVES_DIR / 'trial_level_merged.csv'
BLOCK_FEATURES_CSV = DERIVATIVES_DIR / 'block_features.csv'

# Input data files. Filenames vary with the export date, so these are
# discovered by pattern rather than hardcoded. See data/questionnaires/README.md.
ALLDATA_PATH = DATA_ROOT / 'alldata.csv'


def _find_one(directory: Path, pattern: str):
    """Return the single file in `directory` matching `pattern`, or None."""
    if not directory.is_dir():
        return None
    hits = sorted(directory.glob(pattern))
    return hits[-1] if hits else None


PRESCAN_PATH = _find_one(QUESTIONNAIRE_DIR, '*Thoughts*Interview*.csv')
QUALTRICS_PATH = _find_one(QUESTIONNAIRE_DIR, '*Baseline*Questionnaire*.csv')

# Thought-key corrections for the pre-scan merge. The real file contains
# participant-generated phrases and is not distributed; see
# mvpa/manual_corrections.template.json.
MANUAL_CORRECTIONS_PATH = REPO_ROOT / 'mvpa' / 'manual_corrections.json'

# =============================================================================
# Parcellation
# =============================================================================
ATLAS_NAME = 'yeo_2011'
ATLAS_KWARGS = {'n_networks': 17, 'thickness': 'thick'}
SESSION = 'ses-01'
TASK = 'PDT'
TR_SECONDS = 2.0

# No spatial smoothing for the multivariate analyses: smoothing removes the
# fine-grained pattern information decoding depends on. The FSL univariate
# analyses use 5 mm FWHM.
SMOOTHING_FWHM = None

ACTIVE_CONFOUND_GROUPS = ['motion_24', 'cosine_highpass']

ATLAS_SUBDIR = f'{ATLAS_NAME}_motiononly'
ATLAS_OUT_DIR = PARCELS_DIR / ATLAS_SUBDIR

# =============================================================================
# Quality control
# =============================================================================
# Volume-level censoring threshold, matching the FSL pipeline.
FD_SPIKE_THRESHOLD = 0.6

# A block is usable if at least this fraction of its volumes survive censoring.
MIN_FRACTION_USABLE = 0.7

# Block-level subject exclusion: drop a subject if more than this many of their
# 27 thought blocks fall below MIN_FRACTION_USABLE. Block patterns are the unit
# of analysis here, so a subject can pass the univariate volume-level criterion
# and still have too few usable blocks to contribute.
MAX_UNUSABLE_BLOCKS = 16
N_THOUGHT_BLOCKS = 27

# =============================================================================
# Block extraction
# =============================================================================
HRF_LAG_TRS = 3          # 3 TRs = 6 s at TR = 2 s
SART_WINDOW_TRS = 3
SART_WINDOW_STEP = 1

# =============================================================================
# Decoding
# =============================================================================
RIDGE_ALPHA = 1.0
LASSO_ALPHA = 0.1
N_PERMUTATIONS = 1000
N_BOOTSTRAP = 1000
RANDOM_SEED = 42

# With within-subject z-scored features, cosine and Pearson are equivalent.
SIMILARITY_METRIC = 'pearson'

# =============================================================================
# Subjects
# =============================================================================
# 315: excluded from all analyses.
# 351: 23 of 27 thought blocks below MIN_FRACTION_USABLE, so excluded from the
#      multivariate analyses only (n = 56 multivariate, 57 univariate).
EXCLUDE_SUBJECTS = [315, 351]

# (subject, run) pairs dropped for motion.
EXCLUDE_RUNS = [
    (303, 3),   # 152 spikes, 35% of volumes censored
]

RUNS = ['01', '02', '03']

# =============================================================================
# Confound groups
# =============================================================================
CONFOUND_GROUPS = {
    'motion_24': [
        'trans_x', 'trans_y', 'trans_z',
        'rot_x', 'rot_y', 'rot_z',
        'trans_x_derivative1', 'trans_y_derivative1', 'trans_z_derivative1',
        'rot_x_derivative1', 'rot_y_derivative1', 'rot_z_derivative1',
        'trans_x_power2', 'trans_y_power2', 'trans_z_power2',
        'rot_x_power2', 'rot_y_power2', 'rot_z_power2',
        'trans_x_derivative1_power2', 'trans_y_derivative1_power2',
        'trans_z_derivative1_power2',
        'rot_x_derivative1_power2', 'rot_y_derivative1_power2',
        'rot_z_derivative1_power2',
    ],
    'acompcor_5': [f'a_comp_cor_0{i}' for i in range(5)],
    'cosine_highpass': [],  # populated per run from the confounds TSV
}

# =============================================================================
# Yeo-17 networks
# =============================================================================
YEO17_NAMES = [
    'Visual A', 'Visual B',
    'Somatomotor A', 'Somatomotor B',
    'Dorsal Attention A', 'Dorsal Attention B',
    'Salience/VentAttn A', 'Salience/VentAttn B',
    'Limbic A', 'Limbic B',
    'Control A', 'Control B', 'Control C',
    'Default A', 'Default B', 'Default C', 'Default D',
]

# Zero-based indices into YEO17_NAMES.
DMN_INDICES = [13, 14, 15, 16]
FPN_INDICES = [10, 11, 12]
DAN_INDICES = [4, 5]
SALIENCE_INDICES = [6, 7]

# Network families, used for grouped permutation importance. Permuting a single
# subnetwork lets the model recover its signal from correlated neighbours, so
# importance is estimated over families.
NETWORK_FAMILIES = {
    'Visual': [0, 1],
    'Somatomotor': [2, 3],
    'DorsAttn': [4, 5],
    'SalVentAttn': [6, 7],
    'Limbic': [8, 9],
    'Control': [10, 11, 12],
    'Default': [13, 14, 15, 16],
}


def check_paths(verbose: bool = True) -> dict:
    """Report which expected inputs are present. Called at the top of notebooks."""
    status = {
        'rawdata': RAWDATA_ROOT.is_dir(),
        'preprocessed': FMRIPREP_ROOT.is_dir(),
        'alldata.csv': ALLDATA_PATH.is_file(),
        'prescan ratings': PRESCAN_PATH is not None and PRESCAN_PATH.is_file(),
        'baseline questionnaire': (QUALTRICS_PATH is not None
                                   and QUALTRICS_PATH.is_file()),
        'manual corrections': MANUAL_CORRECTIONS_PATH.is_file(),
    }
    if verbose:
        print(f'Data root: {DATA_ROOT}')
        for k, ok in status.items():
            print(f"  [{'x' if ok else ' '}] {k}")
        if not all(status.values()):
            print('\nMissing inputs. See data/README.md for how to obtain them.')
    return status
