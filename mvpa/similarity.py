"""
Pattern similarity metrics for MVPA.

A small dispatcher over different similarity functions, plus utilities for
time-resolved similarity (sliding window through SART blocks compared to
a Thoughtblock template).

Available metrics:
  'cosine'    -- cosine similarity (range [-1, 1])
  'pearson'   -- Pearson correlation; equivalent to cosine on z-scored vectors
  'euclidean' -- negative Euclidean distance, normalized by feature dimension

Note: with within-subject z-scored features (which we use throughout),
cosine and Pearson are mathematically equivalent. The metric only
matters when patterns are not centered.
"""
from __future__ import annotations

import numpy as np


def cosine_similarity(a: np.ndarray, b: np.ndarray) -> float:
    """
    Cosine similarity between two 1D pattern vectors.
    Returns 0 if either vector has zero norm.
    """
    a = np.asarray(a, dtype=float).ravel()
    b = np.asarray(b, dtype=float).ravel()
    na = np.linalg.norm(a)
    nb = np.linalg.norm(b)
    if na == 0 or nb == 0:
        return 0.0
    return float(np.dot(a, b) / (na * nb))


def pearson_similarity(a: np.ndarray, b: np.ndarray) -> float:
    """
    Pearson correlation between two 1D pattern vectors.
    Returns 0 if either vector has zero variance.
    """
    a = np.asarray(a, dtype=float).ravel()
    b = np.asarray(b, dtype=float).ravel()
    if a.std() == 0 or b.std() == 0:
        return 0.0
    return float(np.corrcoef(a, b)[0, 1])


def euclidean_similarity(a: np.ndarray, b: np.ndarray) -> float:
    """
    Negative Euclidean distance between two 1D pattern vectors,
    normalized by sqrt(n_features) so it's comparable across different
    parcel counts. Higher = more similar.
    """
    a = np.asarray(a, dtype=float).ravel()
    b = np.asarray(b, dtype=float).ravel()
    n = len(a)
    return float(-np.linalg.norm(a - b) / np.sqrt(n))


METRICS = {
    'cosine': cosine_similarity,
    'pearson': pearson_similarity,
    'euclidean': euclidean_similarity,
}


def get_metric(name: str):
    """Return the similarity function for `name`."""
    if name not in METRICS:
        raise ValueError(
            f"Unknown similarity metric '{name}'. "
            f"Available: {list(METRICS.keys())}"
        )
    return METRICS[name]


# =============================================================================
# Sliding-window time-resolved similarity
# =============================================================================

def sliding_window_similarity(
    sart_ts: np.ndarray,
    template: np.ndarray,
    window_trs: int = 3,
    step: int = 1,
    metric: str = 'cosine',
) -> tuple[np.ndarray, np.ndarray]:
    """
    Walk a sliding window through SART block TRs and compute pattern
    similarity at each window position vs a fixed Thoughtblock template.

    Parameters
    ----------
    sart_ts : np.ndarray, shape (n_TRs, n_parcels)
        Parcel timeseries during the SART block.
    template : np.ndarray, shape (n_parcels,)
        Reference pattern (e.g., mean Thoughtblock activity).
    window_trs : int
        Width of the window in TRs.
    step : int
        Step between consecutive window centers in TRs.
    metric : str
        One of METRICS.

    Returns
    -------
    centers_tr : np.ndarray of float
        TR index of each window center (within the SART block).
    similarities : np.ndarray of float
        Similarity at each window center.
    """
    fn = get_metric(metric)
    n_trs = sart_ts.shape[0]
    centers = []
    sims = []
    half = window_trs / 2
    for start in range(0, n_trs - window_trs + 1, step):
        window = sart_ts[start:start + window_trs].mean(axis=0)
        center = start + half
        centers.append(center)
        sims.append(fn(window, template))
    return np.array(centers), np.array(sims)