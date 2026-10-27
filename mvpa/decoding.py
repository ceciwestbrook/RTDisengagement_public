"""
Decoding analyses for block-level parcel features.

This module provides the core MVPA functions used by decoding.ipynb:
  - Cross-subject leave-one-out (LOSO) ridge/lasso regression
  - Permutation null testing (shuffle labels within subject)
  - Univariate per-parcel correlations
  - Within-trial probe correlations (validation)

All decoding uses within-subject z-scoring of features and within-subject
mean-centering of the target. This focuses the model on within-subject
variation in dyscontrol while still allowing cross-subject generalization
of the discovered pattern.

Saved outputs (used by figures.ipynb):
  - derivatives/decoding/loso_per_subject.csv : one row per held-out subject
  - derivatives/decoding/loso_permutation_null.csv : per-permutation mean r
  - derivatives/decoding/parcel_coefficients.csv : ridge coef + univariate r per parcel
  - derivatives/decoding/probe_validation.csv : decoder x probe correlations
"""
from __future__ import annotations

import warnings
from pathlib import Path

import numpy as np
import pandas as pd
from scipy.stats import pearsonr, ttest_1samp
from sklearn.linear_model import Ridge, Lasso


# =============================================================================
# Helpers: within-subject z-scoring and centering
# =============================================================================

def zscore_within_subject(X: np.ndarray, subject_ids: np.ndarray) -> np.ndarray:
    """
    Z-score features within each subject's blocks.

    Parameters
    ----------
    X : np.ndarray, shape (n_blocks, n_features)
    subject_ids : np.ndarray, shape (n_blocks,)
        Subject ID per row.

    Returns
    -------
    Z : np.ndarray, same shape as X, with each subject's data z-scored
        independently. Constant features (sd=0) are left at 0.
    """
    Z = X.copy().astype(float)
    for s in np.unique(subject_ids):
        mask = subject_ids == s
        mu = Z[mask].mean(axis=0)
        sd = Z[mask].std(axis=0)
        sd[sd == 0] = 1
        Z[mask] = (Z[mask] - mu) / sd
    return Z


def center_within_subject(y: np.ndarray, subject_ids: np.ndarray) -> np.ndarray:
    """Mean-center target within each subject."""
    yc = y.copy().astype(float)
    for s in np.unique(subject_ids):
        mask = subject_ids == s
        yc[mask] = yc[mask] - yc[mask].mean()
    return yc


# =============================================================================
# LOSO cross-subject decoding
# =============================================================================

def loso_decode(
    block_df: pd.DataFrame,
    parcel_cols: list[str],
    target_col: str = 'dyscontrol_imputed',
    model_class=Ridge,
    model_kwargs: dict | None = None,
    standardize_within_subject: bool = True,
    center_y_within_subject: bool = True,
) -> pd.DataFrame:
    """
    Leave-one-subject-out decoding. Train on N-1 subjects, predict held-out
    subject's blocks. Score is per-subject Pearson r between predicted and
    actual target.

    Parameters
    ----------
    block_df : pd.DataFrame
        Block-level features. Must have 'subject', target_col, and parcel_cols.
    parcel_cols : list of str
        Feature column names (e.g. ['parcel_00', 'parcel_01', ...]).
    target_col : str
        Target column to predict.
    model_class : sklearn estimator class
        Default: Ridge.
    model_kwargs : dict
        Passed to model_class(**model_kwargs). Default: {'alpha': 1.0}.
    standardize_within_subject : bool
        Z-score features within each subject before training.
    center_y_within_subject : bool
        Mean-center target within each training subject before fit.

    Returns
    -------
    pd.DataFrame with columns:
        held_out_subject : int
        n_test_blocks : int
        r : float -- pearson r on held-out subject's blocks
    """
    if model_kwargs is None:
        model_kwargs = {'alpha': 1.0}
    model_kwargs = dict(model_kwargs)
    df = block_df.dropna(subset=[target_col] + list(parcel_cols)).copy()

    subjects = sorted(df['subject'].unique())
    rows = []

    for held_out in subjects:
        train = df[df['subject'] != held_out]
        test = df[df['subject'] == held_out]
        if len(test) < 2:
            continue

        X_train = train[parcel_cols].values.astype(float)
        y_train = train[target_col].values.astype(float)
        X_test = test[parcel_cols].values.astype(float)
        y_test = test[target_col].values.astype(float)
        train_subs = train['subject'].values

        if standardize_within_subject:
            X_train = zscore_within_subject(X_train, train_subs)
            # Z-score test features within the held-out subject (which has only
            # itself, so this is just centering + unit-scaling of its own data)
            mu_test = X_test.mean(axis=0)
            sd_test = X_test.std(axis=0)
            sd_test[sd_test == 0] = 1
            X_test = (X_test - mu_test) / sd_test

        if center_y_within_subject:
            y_train = center_within_subject(y_train, train_subs)
            y_test = y_test - y_test.mean()

        model = model_class(**model_kwargs)
        with warnings.catch_warnings():
            warnings.simplefilter('ignore')
            model.fit(X_train, y_train)
        y_pred = model.predict(X_test)

        if y_test.std() == 0 or y_pred.std() == 0:
            r = np.nan
        else:
            r = pearsonr(y_test, y_pred)[0]

        rows.append({
            'held_out_subject': int(held_out),
            'n_test_blocks': len(test),
            'r': r,
        })

    return pd.DataFrame(rows)


def summarize_loso(results_df: pd.DataFrame, label: str = '') -> dict:
    """Print and return summary stats for a LOSO results df."""
    valid = results_df['r'].dropna()
    t, p = ttest_1samp(valid, 0)
    pct_pos = (valid > 0).mean() * 100
    summary = {
        'label': label,
        'n_subjects': len(valid),
        'mean_r': float(valid.mean()),
        'sd_r': float(valid.std()),
        't_stat': float(t),
        'p_value': float(p),
        'pct_positive': float(pct_pos),
    }
    print(f'{label} LOSO: M={summary["mean_r"]:+.3f}, '
          f'SD={summary["sd_r"]:.3f}, '
          f't({summary["n_subjects"]-1})={summary["t_stat"]:.2f}, '
          f'p={summary["p_value"]:.4f}, '
          f'{summary["pct_positive"]:.0f}% positive')
    return summary


# =============================================================================
# Permutation null
# =============================================================================

def loso_permutation_null(
    block_df: pd.DataFrame,
    parcel_cols: list[str],
    target_col: str = 'dyscontrol_imputed',
    model_class=Ridge,
    model_kwargs: dict | None = None,
    n_permutations: int = 100,
    random_seed: int = 42,
    verbose: bool = True,
) -> pd.DataFrame:
    """
    Permutation null for LOSO decoding. For each permutation, the target is
    shuffled within each subject before the LOSO loop. Returns the mean r
    across held-out subjects per permutation.

    Use to compare against the real LOSO mean r: permutation p-value =
    fraction of permutations with mean r >= real mean r.

    Parameters
    ----------
    block_df, parcel_cols, target_col, model_class, model_kwargs : as in loso_decode
    n_permutations : int
        Number of shuffles. 100 is typical for a quick check; 1000+ for paper.
    random_seed : int
    verbose : bool
        Print progress every 20 perms.

    Returns
    -------
    pd.DataFrame with columns:
        permutation : int
        mean_r : float
    """
    rng = np.random.default_rng(random_seed)
    df_orig = block_df.copy()
    rows = []

    for p_idx in range(n_permutations):
        df_perm = df_orig.copy()
        # Shuffle target within each subject
        for sub in df_perm['subject'].unique():
            mask = df_perm['subject'] == sub
            shuffled = rng.permutation(df_perm.loc[mask, target_col].values)
            df_perm.loc[mask, target_col] = shuffled

        results = loso_decode(
            df_perm, parcel_cols, target_col=target_col,
            model_class=model_class, model_kwargs=model_kwargs,
        )
        mean_r = results['r'].dropna().mean()
        rows.append({'permutation': p_idx, 'mean_r': mean_r})

        if verbose and ((p_idx + 1) % 20 == 0):
            running = pd.DataFrame(rows)['mean_r'].mean()
            print(f'  perm {p_idx+1}/{n_permutations}: '
                  f'running mean = {running:+.4f}')

    return pd.DataFrame(rows)


def permutation_pvalue(real_r: float, perm_means: np.ndarray) -> float:
    """
    Two-tailed permutation p-value: fraction of |perm_r| >= |real_r|.
    """
    return float((np.abs(perm_means) >= np.abs(real_r)).mean())


# =============================================================================
# Parcel coefficient interpretation
# =============================================================================

def parcel_coefficients(
    block_df: pd.DataFrame,
    parcel_cols: list[str],
    parcel_labels: list[str],
    target_col: str = 'dyscontrol_imputed',
    alpha: float = 1.0,
) -> pd.DataFrame:
    """
    Fit a single ridge model on all subjects' data (with within-subject
    z-scoring + centering, matching the LOSO setup), and report:
      - ridge coefficient per parcel (multivariate)
      - univariate per-parcel correlation between within-subject z-scored
        parcel activity and within-subject-centered target

    The univariate correlations are usually easier to interpret than ridge
    coefs (which are influenced by feature collinearity). Both are reported.

    Parameters
    ----------
    block_df, parcel_cols, target_col : as in loso_decode
    parcel_labels : list of str
        Human-readable labels per parcel (e.g. Yeo network names).
    alpha : float
        Ridge alpha.

    Returns
    -------
    pd.DataFrame with columns:
        parcel_idx : int
        network : str (the label)
        ridge_coef : float
        univariate_r : float
        univariate_p : float
    """
    df = block_df.dropna(subset=[target_col] + list(parcel_cols)).copy()
    X = df[parcel_cols].values.astype(float)
    y = df[target_col].values.astype(float)
    subs = df['subject'].values

    X_z = zscore_within_subject(X, subs)
    y_c = center_within_subject(y, subs)

    # Multivariate ridge fit
    model = Ridge(alpha=alpha)
    with warnings.catch_warnings():
        warnings.simplefilter('ignore')
        model.fit(X_z, y_c)

    # Univariate per-parcel correlation
    rows = []
    for i, (col, label) in enumerate(zip(parcel_cols, parcel_labels)):
        r, p = pearsonr(X_z[:, i], y_c)
        rows.append({
            'parcel_idx': i,
            'network': label,
            'ridge_coef': float(model.coef_[i]),
            'univariate_r': float(r),
            'univariate_p': float(p),
        })

    return pd.DataFrame(rows)


# =============================================================================
# Within-trial probe correlations
# =============================================================================

def probe_decoder_correlations(
    block_df: pd.DataFrame,
    parcel_cols: list[str],
    probe_cols: list[str],
    target_col: str = 'dyscontrol_imputed',
    alpha: float = 1.0,
) -> pd.DataFrame:
    """
    Validation analysis: does the LOSO-trained decoder predict probe ratings
    above and beyond what the prescan dyscontrol score predicts?

    For each held-out subject, generate predicted dyscontrol on their
    Thoughtblocks. Then for each probe, compute the within-subject Pearson
    correlation between the held-out subject's predicted dyscontrol and the
    probe.

    Parameters
    ----------
    block_df, parcel_cols, target_col, alpha : as elsewhere
    probe_cols : list of str
        Probe column names to test (e.g. ['probe1', ..., 'probe6']).

    Returns
    -------
    pd.DataFrame with columns:
        probe : str
        n_subj : int
        mean_r : float
        sem_r : float
        t_stat : float
        p_value : float
        pct_positive : float
    """
    df = block_df.dropna(subset=[target_col] + list(parcel_cols)).copy()
    df = df[df['condition'] == 'Thoughtblock']
    subjects = sorted(df['subject'].unique())

    # Build LOSO predictions for every block (one prediction per held-out trial)
    pred = pd.Series(index=df.index, dtype=float)
    for held_out in subjects:
        train = df[df['subject'] != held_out]
        test = df[df['subject'] == held_out]
        if len(test) < 2:
            continue

        X_train = zscore_within_subject(
            train[parcel_cols].values.astype(float),
            train['subject'].values,
        )
        y_train = center_within_subject(
            train[target_col].values.astype(float),
            train['subject'].values,
        )
        X_test = test[parcel_cols].values.astype(float)
        mu_test = X_test.mean(axis=0)
        sd_test = X_test.std(axis=0)
        sd_test[sd_test == 0] = 1
        X_test = (X_test - mu_test) / sd_test

        model = Ridge(alpha=alpha)
        with warnings.catch_warnings():
            warnings.simplefilter('ignore')
            model.fit(X_train, y_train)
        pred.loc[test.index] = model.predict(X_test)

    df = df.assign(decoder_pred=pred)

    # Per-probe within-subject r
    rows = []
    for probe in probe_cols:
        if probe not in df.columns:
            continue
        rs = []
        for sub, g in df.groupby('subject'):
            valid = g.dropna(subset=['decoder_pred', probe])
            if len(valid) < 5 or valid['decoder_pred'].std() == 0:
                continue
            v = pd.to_numeric(valid[probe], errors='coerce')
            if v.std() == 0:
                continue
            r, _ = pearsonr(valid['decoder_pred'], v)
            if not np.isnan(r):
                rs.append(r)
        if not rs:
            continue
        rs = np.array(rs)
        t, p = ttest_1samp(rs, 0)
        rows.append({
            'probe': probe,
            'n_subj': len(rs),
            'mean_r': float(rs.mean()),
            'sem_r': float(rs.std() / np.sqrt(len(rs))),
            't_stat': float(t),
            'p_value': float(p),
            'pct_positive': float((rs > 0).mean() * 100),
        })

    return pd.DataFrame(rows)
