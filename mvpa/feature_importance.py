"""
Preregistered feature importance for the LOSO ridge decoder.

The preregistration specifies permutation importance with bootstrapping
("the relative decrease in accuracy with each feature left-out is estimated
using a bootstrapping method"), not model coefficients. Ridge coefficients
on correlated network features are not independently interpretable under L2
penalization, so this module replaces parcel_coefficients() as the basis for
any claim about which networks carried the decoding.

Two estimators are provided:

  permutation_importance_loso  -- shuffle a feature (or group of features)
                                  within the held-out subject, measure the
                                  drop in LOSO accuracy. No refitting.

  ablation_importance_loso     -- refit without a feature (or group), measure
                                  the drop. Closer to the prereg's
                                  "left-out" wording; slower but still fast
                                  with ridge.

Both default to GROUPED features (all Default subnetworks together, all
Control subnetworks together, etc.) because permuting one Yeo subnetwork at a
time lets the model recover its signal from correlated neighbours, which
understates importance. Grouping also matches the network-level hypotheses
(H1 predicted DMN; H2 predicted FPN/SN).

Outputs, for figures.ipynb:
  derivatives/decoding/feature_importance_permutation.csv
  derivatives/decoding/feature_importance_ablation.csv
"""
from __future__ import annotations

import warnings

import numpy as np
import pandas as pd
from scipy.stats import pearsonr
from sklearn.linear_model import Ridge

from decoding import zscore_within_subject, center_within_subject


# =============================================================================
# Feature groupings
# =============================================================================

def yeo17_network_groups(parcel_cols: list[str],
                         parcel_labels: list[str]) -> dict[str, list[int]]:
    """
    Group Yeo-17 subnetworks into the families the hypotheses are about.

    Returns {group_name: [column indices]}. Indices are positions within
    parcel_cols, matching how X is assembled.
    """
    families = {
        'DMN':          'Default',
        'Control':      'Control',
        'DorsAttn':     'Dorsal Attention',
        'SalVentAttn':  'Salience/VentAttn',
        'Limbic':       'Limbic',
        'Somatomotor':  'Somatomotor',
        'Visual':       'Visual',
    }
    groups = {}
    for name, prefix in families.items():
        idx = [i for i, lab in enumerate(parcel_labels)
               if lab.startswith(prefix)]
        if idx:
            groups[name] = idx
    if len(parcel_cols) != len(parcel_labels):
        raise ValueError(
            f'parcel_cols ({len(parcel_cols)}) and parcel_labels '
            f'({len(parcel_labels)}) must be the same length'
        )
    return groups


# =============================================================================
# Shared fold machinery
# =============================================================================

def _fold_arrays(df, parcel_cols, target_col, held_out,
                 standardize=True, center_y=True):
    """Build (X_train, y_train, X_test, y_test) for one LOSO fold.

    Mirrors loso_decode() in decoding.py exactly, so importance values are
    comparable to the reported accuracy.
    """
    train = df[df['subject'] != held_out]
    test = df[df['subject'] == held_out]
    if len(test) < 2:
        return None

    X_train = train[parcel_cols].values.astype(float)
    y_train = train[target_col].values.astype(float)
    X_test = test[parcel_cols].values.astype(float)
    y_test = test[target_col].values.astype(float)
    train_subs = train['subject'].values

    if standardize:
        X_train = zscore_within_subject(X_train, train_subs)
        mu, sd = X_test.mean(axis=0), X_test.std(axis=0)
        sd[sd == 0] = 1
        X_test = (X_test - mu) / sd
    if center_y:
        y_train = center_within_subject(y_train, train_subs)
        y_test = y_test - y_test.mean()

    return X_train, y_train, X_test, y_test


def _fit(X, y, alpha):
    m = Ridge(alpha=alpha)
    with warnings.catch_warnings():
        warnings.simplefilter('ignore')
        m.fit(X, y)
    return m


def _r(y_true, y_pred):
    if np.std(y_true) == 0 or np.std(y_pred) == 0:
        return np.nan
    return pearsonr(y_true, y_pred)[0]


# =============================================================================
# Permutation importance
# =============================================================================

def permutation_importance_loso(
    block_df: pd.DataFrame,
    parcel_cols: list[str],
    parcel_labels: list[str],
    target_col: str = 'dyscontrol_imputed',
    groups: dict[str, list[int]] | None = None,
    alpha: float = 1.0,
    n_permutations: int = 1000,
    n_bootstrap: int = 1000,
    random_seed: int = 42,
    verbose: bool = True,
) -> pd.DataFrame:
    """
    Permutation importance under LOSO cross-validation.

    For each fold, the model is fit once on the training subjects. For each
    feature group and each permutation, that group's columns are shuffled
    (row-wise, within the held-out subject only) and the held-out r is
    recomputed. Importance is the mean drop from the unpermuted r.

    Confidence intervals come from bootstrapping over SUBJECTS, which is the
    level at which the accuracy score is defined.

    Returns
    -------
    pd.DataFrame: group, n_features, importance, ci_low, ci_high,
                  baseline_r, permuted_r
    """
    rng = np.random.default_rng(random_seed)
    df = block_df.dropna(subset=[target_col] + list(parcel_cols)).copy()
    if groups is None:
        groups = yeo17_network_groups(parcel_cols, parcel_labels)

    subjects = sorted(df['subject'].unique())
    group_names = list(groups)

    # per-subject baseline r, and per-subject mean permuted r per group
    base_by_subj = {}
    perm_by_subj = {g: {} for g in group_names}

    for held_out in subjects:
        arrs = _fold_arrays(df, parcel_cols, target_col, held_out)
        if arrs is None:
            continue
        X_train, y_train, X_test, y_test = arrs
        model = _fit(X_train, y_train, alpha)
        base_by_subj[held_out] = _r(y_test, model.predict(X_test))

        for g in group_names:
            idx = groups[g]
            rs = np.empty(n_permutations)
            for p in range(n_permutations):
                Xp = X_test.copy()
                order = rng.permutation(Xp.shape[0])
                Xp[:, idx] = Xp[order][:, idx]   # permute the group jointly
                rs[p] = _r(y_test, model.predict(Xp))
            perm_by_subj[g][held_out] = np.nanmean(rs)

        if verbose:
            print(f'  subject {held_out}: baseline r = '
                  f'{base_by_subj[held_out]:+.3f}')

    valid = [s for s in subjects
             if s in base_by_subj and not np.isnan(base_by_subj[s])]
    base_vec = np.array([base_by_subj[s] for s in valid])

    rows = []
    for g in group_names:
        perm_vec = np.array([perm_by_subj[g][s] for s in valid])
        drop_vec = base_vec - perm_vec

        boot = np.empty(n_bootstrap)
        n = len(valid)
        for b in range(n_bootstrap):
            pick = rng.integers(0, n, n)
            boot[b] = np.nanmean(drop_vec[pick])
        lo, hi = np.nanpercentile(boot, [2.5, 97.5])

        rows.append({
            'group': g,
            'n_features': len(groups[g]),
            'importance': float(np.nanmean(drop_vec)),
            'ci_low': float(lo),
            'ci_high': float(hi),
            'baseline_r': float(np.nanmean(base_vec)),
            'permuted_r': float(np.nanmean(perm_vec)),
        })

    out = pd.DataFrame(rows).sort_values('importance', ascending=False)
    return out.reset_index(drop=True)


# =============================================================================
# Ablation importance (prereg's "left-out" wording)
# =============================================================================

def ablation_importance_loso(
    block_df: pd.DataFrame,
    parcel_cols: list[str],
    parcel_labels: list[str],
    target_col: str = 'dyscontrol_imputed',
    groups: dict[str, list[int]] | None = None,
    alpha: float = 1.0,
    n_bootstrap: int = 1000,
    random_seed: int = 42,
    verbose: bool = True,
) -> pd.DataFrame:
    """
    Leave-one-group-out importance: refit the model without a feature group
    and measure the drop in LOSO accuracy. Bootstrap CIs over subjects.

    Returns the same columns as permutation_importance_loso, with
    'reduced_r' in place of 'permuted_r'.
    """
    rng = np.random.default_rng(random_seed)
    df = block_df.dropna(subset=[target_col] + list(parcel_cols)).copy()
    if groups is None:
        groups = yeo17_network_groups(parcel_cols, parcel_labels)

    subjects = sorted(df['subject'].unique())
    group_names = list(groups)
    base_by_subj, red_by_subj = {}, {g: {} for g in group_names}

    for held_out in subjects:
        arrs = _fold_arrays(df, parcel_cols, target_col, held_out)
        if arrs is None:
            continue
        X_train, y_train, X_test, y_test = arrs
        base_by_subj[held_out] = _r(
            y_test, _fit(X_train, y_train, alpha).predict(X_test)
        )
        for g in group_names:
            keep = [i for i in range(X_train.shape[1]) if i not in groups[g]]
            red_by_subj[g][held_out] = _r(
                y_test,
                _fit(X_train[:, keep], y_train, alpha).predict(X_test[:, keep])
            )
        if verbose:
            print(f'  subject {held_out}: baseline r = '
                  f'{base_by_subj[held_out]:+.3f}')

    valid = [s for s in subjects
             if s in base_by_subj and not np.isnan(base_by_subj[s])]
    base_vec = np.array([base_by_subj[s] for s in valid])

    rows = []
    for g in group_names:
        red_vec = np.array([red_by_subj[g][s] for s in valid])
        drop_vec = base_vec - red_vec
        boot = np.empty(n_bootstrap)
        n = len(valid)
        for b in range(n_bootstrap):
            pick = rng.integers(0, n, n)
            boot[b] = np.nanmean(drop_vec[pick])
        lo, hi = np.nanpercentile(boot, [2.5, 97.5])
        rows.append({
            'group': g,
            'n_features': len(groups[g]),
            'importance': float(np.nanmean(drop_vec)),
            'ci_low': float(lo),
            'ci_high': float(hi),
            'baseline_r': float(np.nanmean(base_vec)),
            'reduced_r': float(np.nanmean(red_vec)),
        })

    out = pd.DataFrame(rows).sort_values('importance', ascending=False)
    return out.reset_index(drop=True)


# =============================================================================
# Reporting helper
# =============================================================================

def summarize_importance(imp_df: pd.DataFrame, label: str = '') -> None:
    """Print a compact table and flag whether any group is distinguishable."""
    print(f'\n{label} feature importance (drop in LOSO r, 95% bootstrap CI):')
    for _, r in imp_df.iterrows():
        star = ' *' if r['ci_low'] > 0 else ''
        print(f"  {r['group']:<14} {r['importance']:+.4f} "
              f"[{r['ci_low']:+.4f}, {r['ci_high']:+.4f}]"
              f"  ({int(r['n_features'])} features){star}")
    sig = imp_df[imp_df['ci_low'] > 0]
    if len(sig) == 0:
        print('  No group has a CI excluding zero. The decoder does not rely '
              'on any single network family; do not attribute the decoding '
              'to particular networks.')
    else:
        print(f"  Groups with CI excluding zero: "
              f"{', '.join(sig['group'].tolist())}")
