"""
Atlas-agnostic parcellation pipeline for fMRIPrep-preprocessed BOLD data.

Pipeline per (subject, run):
  1. Load fMRIPrep BOLD (MNI152NLin6Asym, 2mm, unsmoothed)
  2. Load confounds.tsv from fMRIPrep
  3. Build a denoising regressor matrix from the active confound groups
  4. Compute spike mask from framewise displacement
  5. Parcellate with nilearn (regression of confounds happens at parcel
     extraction step via NiftiLabelsMasker.fit_transform with confounds=)
  6. Save parcels.npy + spike_mask.npy + provenance.json

Pipeline output structure:
  derivatives/parcels/<atlas_name>/
    sub-<X>_run-<NN>_parcel_ts.npy      (n_TRs x n_parcels)
    sub-<X>_run-<NN>_spike_mask.npy     (n_TRs,) bool
    sub-<X>_run-<NN>_provenance.json    metadata (atlas, confounds used, etc.)

Atlas swapping: edit ATLAS_NAME in config.py. All paths are namespaced by
atlas name so multiple atlases can coexist.
"""
from __future__ import annotations

import json
import warnings
from pathlib import Path

import nibabel as nib
import numpy as np
import pandas as pd
from nilearn import datasets, maskers


# =============================================================================
# Atlas loading
# =============================================================================

def load_atlas(atlas_name: str, atlas_kwargs: dict | None = None):
    """
    Load an atlas by name. Returns (atlas_img, atlas_labels).

    Supported atlases (passed through to nilearn):
        'yeo_2011'        -> nilearn.datasets.fetch_atlas_yeo_2011
        'schaefer_2018'   -> nilearn.datasets.fetch_atlas_schaefer_2018
        'aal'             -> nilearn.datasets.fetch_atlas_aal
        'harvard_oxford'  -> nilearn.datasets.fetch_atlas_harvard_oxford
        'destrieux_2009'  -> nilearn.datasets.fetch_atlas_destrieux_2009
        'pauli_2017'      -> nilearn.datasets.fetch_atlas_pauli_2017

    Returns
    -------
    atlas_img : nibabel image
        The deterministic (label) atlas image.
    atlas_labels : list of str
        Labels for each parcel (index-aligned).
    """
    atlas_kwargs = atlas_kwargs or {}

    if atlas_name == 'yeo_2011':
        atlas = datasets.fetch_atlas_yeo_2011(**atlas_kwargs)
        n_networks = atlas_kwargs.get('n_networks', 17)
        atlas_img = nib.load(atlas['maps'])
        atlas_labels = [f'parcel_{i:02d}' for i in range(n_networks)]

    elif atlas_name == 'schaefer_2018':
        atlas = datasets.fetch_atlas_schaefer_2018(**atlas_kwargs)
        atlas_img = nib.load(atlas['maps'])
        atlas_labels = [
            l.decode('utf-8') if isinstance(l, bytes) else str(l)
            for l in atlas['labels']
        ]

    elif atlas_name == 'aal':
        atlas = datasets.fetch_atlas_aal(**atlas_kwargs)
        atlas_img = nib.load(atlas['maps'])
        atlas_labels = list(atlas['labels'])

    elif atlas_name == 'harvard_oxford':
        atlas = datasets.fetch_atlas_harvard_oxford(**atlas_kwargs)
        atlas_img = atlas['maps']
        atlas_labels = list(atlas['labels'])[1:]  # drop background

    elif atlas_name == 'destrieux_2009':
        atlas = datasets.fetch_atlas_destrieux_2009(**atlas_kwargs)
        atlas_img = nib.load(atlas['maps'])
        atlas_labels = [str(l) for l in atlas['labels']['name']]

    elif atlas_name == 'pauli_2017':
        atlas = datasets.fetch_atlas_pauli_2017(**atlas_kwargs)
        atlas_img = nib.load(atlas['maps'])
        atlas_labels = list(atlas['labels'])

    else:
        raise ValueError(
            f"Unknown atlas: {atlas_name}. Supported: yeo_2011, schaefer_2018, "
            f"aal, harvard_oxford, destrieux_2009, pauli_2017."
        )

    return atlas_img, atlas_labels


# =============================================================================
# fMRIPrep file resolution
# =============================================================================

def get_bold_paths(fmriprep_root: Path, subject: int, run: str,
                    session: str = 'ses-01', task: str = 'PDT',
                    space: str = 'MNI152NLin6Asym', res: str = '2'):
    """
    Resolve fMRIPrep BOLD, mask, and confounds paths for a given subject/run.

    Returns
    -------
    dict with keys 'bold', 'mask', 'confounds', 'confounds_meta'
    """
    sub_func = (Path(fmriprep_root) / f'sub-{subject}' / session / 'func')
    base_run = f'sub-{subject}_{session}_task-{task}_run-{run}'
    base_run_space = f'{base_run}_space-{space}_res-{res}'

    return {
        'bold': sub_func / f'{base_run_space}_desc-preproc_bold.nii.gz',
        'mask': sub_func / f'{base_run_space}_desc-brain_mask.nii.gz',
        'confounds': sub_func / f'{base_run}_desc-confounds_timeseries.tsv',
        'confounds_meta': sub_func / f'{base_run}_desc-confounds_timeseries.json',
    }


# =============================================================================
# Confound assembly
# =============================================================================

def build_confound_matrix(
    confounds_path: Path,
    active_groups: list[str],
    confound_groups: dict,
    fill_na: bool = True,
):
    """
    Build a confound regressor DataFrame from selected groups.

    Parameters
    ----------
    confounds_path : Path
        Path to fMRIPrep's *_desc-confounds_timeseries.tsv
    active_groups : list of str
        Group names to include (keys of confound_groups dict)
    confound_groups : dict
        Mapping group_name -> list of column names
    fill_na : bool
        If True, fill NaN values with the column mean (NaN appears at TR 0
        for derivative regressors).

    Returns
    -------
    out : pd.DataFrame
        One row per TR, one column per regressor.
    cols_used : list of str
        Column names actually pulled.
    """
    df = pd.read_csv(confounds_path, sep='\t')

    cols_to_use = []
    missing = []
    for group in active_groups:
        if group not in confound_groups:
            warnings.warn(f"Confound group '{group}' not in confound_groups dict")
            continue
        for col in confound_groups[group]:
            if col in df.columns:
                cols_to_use.append(col)
            else:
                missing.append(col)

    if missing:
        warnings.warn(
            f"  {len(missing)} confound columns missing from "
            f"{confounds_path.name}: {missing[:5]}..."
        )

    out = df[cols_to_use].copy()
    if fill_na:
        out = out.fillna(out.mean()).fillna(0)

    return out, cols_to_use


# =============================================================================
# Spike mask
# =============================================================================

def compute_spike_mask(confounds_path: Path,
                        fd_threshold: float = 0.5) -> np.ndarray:
    """
    Compute boolean spike mask from framewise displacement.

    Returns
    -------
    spike_mask : np.ndarray of bool, shape (n_TRs,)
        True at TRs where FD exceeds threshold (i.e., to be excluded from
        analyses). NaN values (typically the first TR) are treated as
        non-spikes (False).
    """
    df = pd.read_csv(confounds_path, sep='\t')
    if 'framewise_displacement' not in df.columns:
        raise ValueError(
            f"framewise_displacement column missing from {confounds_path}"
        )
    fd = df['framewise_displacement'].values
    spike_mask = np.zeros(len(fd), dtype=bool)
    valid = ~np.isnan(fd)
    spike_mask[valid] = fd[valid] > fd_threshold
    return spike_mask


# =============================================================================
# Parcellation
# =============================================================================

def parcellate_run(
    bold_path: Path,
    mask_path: Path,
    atlas_img,
    confounds_df: pd.DataFrame,
    tr: float = 2.0,
    standardize: bool = False,
    detrend: bool = False,
    smoothing_fwhm: float | None = None,
):
    """
    Parcellate one run's BOLD into mean signal per atlas parcel.

    Confounds are regressed out at the same time as parcel extraction.

    Parameters
    ----------
    bold_path : Path
        Path to preprocessed BOLD (4D Nifti).
    mask_path : Path
        Path to brain mask (3D Nifti). If None, no mask applied.
    atlas_img : nibabel image
        Deterministic (label) atlas. Must be in same space as BOLD.
    confounds_df : pd.DataFrame
        Confound regressors, one row per TR, one column per regressor.
    tr : float
        Repetition time in seconds.
    standardize : bool
        Whether to z-score parcel timeseries (False = leave on raw scale).
    detrend : bool
        Whether to remove linear trend (False = handled by cosine confounds
        if those are in the active groups).
    smoothing_fwhm : float or None
        If not None, apply spatial smoothing with this FWHM (mm) before
        parcellation. fMRIPrep BOLDs are unsmoothed; parcel-mean averaging
        provides implicit spatial smoothing.

    Returns
    -------
    parcel_ts : np.ndarray, shape (n_TRs, n_parcels)
    """
    masker = maskers.NiftiLabelsMasker(
        labels_img=atlas_img,
        mask_img=str(mask_path) if mask_path else None,
        standardize=standardize,
        detrend=detrend,
        smoothing_fwhm=smoothing_fwhm,
        t_r=tr,
        memory_level=0,
        verbose=0,
    )
    parcel_ts = masker.fit_transform(str(bold_path), confounds=confounds_df.values)
    return parcel_ts


# =============================================================================
# Per-run pipeline
# =============================================================================

def process_run(
    subject: int,
    run: str,
    fmriprep_root: Path,
    atlas_img,
    output_dir: Path,
    *,
    session: str = 'ses-01',
    task: str = 'PDT',
    tr: float = 2.0,
    confound_groups: dict,
    active_confound_groups: list[str],
    fd_spike_threshold: float = 0.5,
    smoothing_fwhm: float | None = None,
    overwrite: bool = False,
    verbose: bool = True,
) -> dict | None:
    """
    Full per-run pipeline: parcellate + spike mask + provenance.

    Saves outputs to:
        output_dir / sub-<X>_run-<NN>_parcel_ts.npy
        output_dir / sub-<X>_run-<NN>_spike_mask.npy
        output_dir / sub-<X>_run-<NN>_provenance.json

    Returns
    -------
    dict with keys 'parcel_ts_path', 'spike_mask_path', 'provenance_path',
                   'n_trs', 'n_parcels', 'n_spike_trs', 'skipped'.
    Returns None if the BOLD file isn't found (run wasn't collected).
    """
    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    parcel_ts_path = output_dir / f'sub-{subject}_run-{run}_parcel_ts.npy'
    spike_mask_path = output_dir / f'sub-{subject}_run-{run}_spike_mask.npy'
    provenance_path = output_dir / f'sub-{subject}_run-{run}_provenance.json'

    # Skip if already done and not overwriting
    if (not overwrite and parcel_ts_path.exists() and spike_mask_path.exists()):
        if verbose:
            print(f"  sub-{subject} run-{run}: outputs exist, skipping")
        parcel_ts = np.load(parcel_ts_path)
        spike_mask = np.load(spike_mask_path)
        return {
            'parcel_ts_path': parcel_ts_path,
            'spike_mask_path': spike_mask_path,
            'provenance_path': provenance_path,
            'n_trs': len(parcel_ts),
            'n_parcels': parcel_ts.shape[1],
            'n_spike_trs': int(spike_mask.sum()),
            'skipped': True,
        }

    # Resolve input paths
    paths = get_bold_paths(fmriprep_root, subject, run,
                            session=session, task=task)
    if not paths['bold'].exists():
        if verbose:
            print(f"  sub-{subject} run-{run}: BOLD not found, skipping")
        return None
    if not paths['confounds'].exists():
        warnings.warn(f"sub-{subject} run-{run}: confounds.tsv not found, skipping")
        return None

    if verbose:
        print(f"  sub-{subject} run-{run}: parcellating...")

    # Build confound matrix
    confounds_df, cols_used = build_confound_matrix(
        paths['confounds'], active_confound_groups, confound_groups,
    )

    # Spike mask (computed from raw FD, independent of confound regression)
    spike_mask = compute_spike_mask(
        paths['confounds'], fd_threshold=fd_spike_threshold,
    )

    # Parcellate
    parcel_ts = parcellate_run(
        paths['bold'],
        paths['mask'] if paths['mask'].exists() else None,
        atlas_img=atlas_img,
        confounds_df=confounds_df,
        tr=tr,
        smoothing_fwhm=smoothing_fwhm,
    )

    # Save outputs
    np.save(parcel_ts_path, parcel_ts)
    np.save(spike_mask_path, spike_mask)

    provenance = {
        'subject': int(subject),
        'run': str(run),
        'session': str(session),
        'task': str(task),
        'bold_path': str(paths['bold']),
        'mask_path': str(paths['mask']),
        'confounds_path': str(paths['confounds']),
        'tr': float(tr),
        'fd_spike_threshold': float(fd_spike_threshold),
        'active_confound_groups': list(active_confound_groups),
        'confound_columns_used': list(cols_used),
        'n_confound_columns': int(len(cols_used)),
        'smoothing_fwhm': float(smoothing_fwhm) if smoothing_fwhm is not None else None,
        'n_trs': int(parcel_ts.shape[0]),
        'n_parcels': int(parcel_ts.shape[1]),
        'n_spike_trs': int(spike_mask.sum()),
    }
    with open(provenance_path, 'w') as f:
        json.dump(provenance, f, indent=2)

    return {
        'parcel_ts_path': parcel_ts_path,
        'spike_mask_path': spike_mask_path,
        'provenance_path': provenance_path,
        'n_trs': int(parcel_ts.shape[0]),
        'n_parcels': int(parcel_ts.shape[1]),
        'n_spike_trs': int(spike_mask.sum()),
        'skipped': False,
    }


# =============================================================================
# Block-level feature extraction
# =============================================================================

def get_block_indices(onset_sec: float, duration_sec: float,
                       n_total_trs: int, tr: float = 2.0,
                       hrf_lag_trs: int = 3) -> np.ndarray:
    """
    Return TR indices belonging to a block, HRF-shifted.

    Parameters
    ----------
    onset_sec : float
        Block onset time in seconds (from BIDS events.tsv)
    duration_sec : float
        Block duration in seconds
    n_total_trs : int
        Total TRs in this run (for clipping)
    tr : float
        Repetition time
    hrf_lag_trs : int
        Number of TRs to shift forward to align BOLD with neural events.

    Returns
    -------
    np.ndarray of int (TR indices)
    """
    start_tr = int(round(onset_sec / tr)) + hrf_lag_trs
    end_tr = int(round((onset_sec + duration_sec) / tr)) + hrf_lag_trs
    start_tr = max(0, start_tr)
    end_tr = min(n_total_trs, end_tr)
    return np.arange(start_tr, end_tr)


def extract_block_features(
    parcel_ts: np.ndarray,
    spike_mask: np.ndarray,
    onset_sec: float,
    duration_sec: float,
    tr: float = 2.0,
    hrf_lag_trs: int = 3,
    min_fraction_usable: float = 0.7,
):
    """
    Extract block-mean parcel features for a single block.

    Parameters
    ----------
    parcel_ts : np.ndarray, shape (n_TRs, n_parcels)
    spike_mask : np.ndarray, shape (n_TRs,)
        True at TRs to exclude (motion spikes).
    onset_sec, duration_sec : float
        Block timing from events.tsv
    tr, hrf_lag_trs : float, int
    min_fraction_usable : float
        Block is dropped if fewer than this fraction of TRs survive scrubbing.

    Returns
    -------
    block_mean : np.ndarray of shape (n_parcels,) or None if block dropped
    qc : dict with TR counts and usable fraction
    """
    n_trs = parcel_ts.shape[0]
    block_trs = get_block_indices(onset_sec, duration_sec, n_trs,
                                    tr=tr, hrf_lag_trs=hrf_lag_trs)
    n_block = len(block_trs)
    if n_block == 0:
        return None, {'n_block_trs': 0, 'n_usable': 0, 'fraction_usable': 0.0}

    in_block_spikes = spike_mask[block_trs]
    usable_trs = block_trs[~in_block_spikes]
    fraction_usable = len(usable_trs) / n_block

    qc = {
        'n_block_trs': n_block,
        'n_usable': len(usable_trs),
        'fraction_usable': float(fraction_usable),
    }
    if fraction_usable < min_fraction_usable or len(usable_trs) == 0:
        return None, qc

    block_mean = parcel_ts[usable_trs].mean(axis=0)
    return block_mean, qc