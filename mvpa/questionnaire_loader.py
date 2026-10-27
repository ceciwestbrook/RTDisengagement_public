"""
Loaders for Qualtrics CSV exports.

Two questionnaires are handled here:
1. The pre-scan thought interview (one row per subject, ratings for ~9 thoughts)
2. The trait baseline (PTQ-15, PSWQ-16, plus an attention check)

Both files are exported from Qualtrics with a 3-row header:
- Row 0: machine-readable column names
- Row 1: human-readable question text
- Row 2: JSON metadata (contains 'ImportId' for canonical column lookup)

The two loaders use different lookup strategies:
  - Prescan: ImportId-based (column names repeat across the 9 thought blocks)
  - Trait:   Direct Qualtrics column names like 'Q219', 'Q3', etc.
              (these are stable in this study's export)

Subject IDs are formatted with a 2-letter prefix ('HH302', 'YA303' etc.).
We extract the digits.

Likert responses can be either text labels or numeric. The text-to-number
maps handle conversion. Numbered text like '3 Somewhat typical' is also
parsed by extracting the leading digits.

Prorating: for traits, if a participant completed >= 80% of items in a
(sub)scale, total = mean(completed) * total_items. Otherwise NaN.
"""
from __future__ import annotations

import json
import re
import warnings
from pathlib import Path

import numpy as np
import pandas as pd


# =============================================================================
# Constants -- prescan layout
# =============================================================================
# The 9 thought blocks use rotating QID numbers (in this order):
PRESCAN_BLOCK_QIDS = [1, 35, 31, 27, 23, 19, 14, 10, 6]
PRESCAN_REMINDER_TEXT_QIDS = [39, 41, 42, 43, 44, 45, 46, 48, 49]

# Per-block QID groupings: (content, form, quality, emotion)
PRESCAN_BLOCK_ITEM_QIDS = {
    1:  (1, 2, 3, 5),     # block 1 has a gap: emotion is at QID5 not QID4
    35: (35, 36, 37, 38),
    31: (31, 32, 33, 34),
    27: (27, 28, 29, 30),
    23: (23, 24, 25, 26),
    19: (19, 20, 21, 22),
    14: (14, 15, 16, 17),
    10: (10, 11, 12, 13),
    6:  (6, 7, 8, 9),
}

# Within-block item structure
PRESCAN_CONTENT_ITEMS = 13
PRESCAN_FORM_ITEMS = 4
PRESCAN_QUALITY_ITEMS = 8
PRESCAN_EMOTION_ITEMS = 11


# =============================================================================
# Constants -- trait layout
# =============================================================================
# PTQ items map to Qualtrics columns Q219-Q234 (with Q226 as the attention
# check, NOT a real PTQ item).
PTQ_ITEM_COLS = {
    1: 'Q219', 2: 'Q220', 3: 'Q221', 4: 'Q222', 5: 'Q223',
    6: 'Q224', 7: 'Q225',
    # Q226 = attention check, skipped
    8: 'Q227', 9: 'Q228', 10: 'Q229', 11: 'Q230', 12: 'Q231',
    13: 'Q232', 14: 'Q233', 15: 'Q234',
}
PTQ_ATTENTION_CHECK_COL = 'Q226'
# 'Almost always' on the standard 0-4 PTQ scale = 4
PTQ_ATTENTION_CHECK_VALUE = 4

# PTQ subscales (Ehring et al. 2011)
PTQ_SUBSCALES = {
    'core': [1, 2, 3, 6, 11],          # repetitive/intrusive/hard-to-disengage
    'unproductive': [4, 9, 10, 13, 14], # unproductiveness
    'capacity': [5, 7, 8, 12, 15],     # mental capacity
}

# PSWQ-16 items at Q3-Q18 (16 items, 1-5 scale)
PSWQ_ITEM_COLS = {i: f'Q{i + 2}' for i in range(1, 17)}

# PSWQ items reverse-coded (positively worded)
PSWQ_REVERSE_ITEMS = [1, 3, 8, 10, 11]


# =============================================================================
# Likert text-to-number maps
# =============================================================================
# PTQ-15: 0-4 ("Never" to "Almost always")
PTQ_TEXT_TO_NUM = {
    'never': 0,
    'rarely': 1,
    'sometimes': 2,
    'often': 3,
    'almost always': 4,
}

# PSWQ-16: 1-5 ("Not typical at all" to "Very typical")
PSWQ_TEXT_TO_NUM = {
    'not typical at all': 1,
    'somewhat typical': 3,
    'very typical': 5,
}


# =============================================================================
# Helpers
# =============================================================================

def normalize_thought_key(s) -> str | None:
    """
    Normalize a thought reminder phrase for matching.
    Lowercase, strip, replace punctuation with spaces, collapse whitespace.
    Punctuation handled: , . - _ / ; : ! ? \\ " ' ( ) & [ ] { }
    Returns None for NaN/missing input.
    """
    if pd.isna(s):
        return None
    s = str(s).strip().lower()
    s = re.sub(r"[,.\-_/;:!?\\\"'()&\[\]{}]", ' ', s)
    s = re.sub(r'\s+', ' ', s).strip()
    return s


def _strip_subject_id_to_int(raw_id) -> int | None:
    """'HH302' -> 302 (int). Returns None if no digits."""
    if pd.isna(raw_id):
        return None
    m = re.match(r'^[A-Za-z]*(\d+)$', str(raw_id).strip())
    return int(m.group(1)) if m else None


def _safe_float(val) -> float:
    """Convert to float, NaN if missing/blank/non-numeric."""
    if val is None or pd.isna(val):
        return np.nan
    s = str(val).strip()
    if s == '' or s.lower() in ('na', 'none'):
        return np.nan
    try:
        return float(s)
    except ValueError:
        return np.nan


def _parse_likert_value(val, text_to_num=None) -> float:
    """
    Parse a Qualtrics Likert response into a number.
    Handles:
    - Pure numeric ('2', '3.0')
    - Numbered text ('3  Somewhat typical', '1 Not typical at all')
    - Pure text labels ('Sometimes', 'Almost always')
    - Missing values
    """
    if val is None or pd.isna(val):
        return np.nan
    s = str(val).strip()
    if s == '' or s.lower() in ('na', 'none', 'nan'):
        return np.nan
    # Pure numeric
    try:
        return float(s)
    except ValueError:
        pass
    # Leading number ('3  Somewhat typical' -> 3)
    m = re.match(r'^(\d+)', s)
    if m:
        return float(m.group(1))
    # Text label
    if text_to_num is not None:
        s_lower = s.lower()
        if s_lower in text_to_num:
            return float(text_to_num[s_lower])
    return np.nan


def _prorate(values, n_items: int, min_completion: float = 0.8) -> float:
    """
    Prorated total: if >= min_completion fraction of items completed,
    total = mean(completed) * n_items. Otherwise NaN.
    """
    completed = pd.Series(values).dropna()
    if len(completed) / n_items < min_completion:
        return np.nan
    return float(completed.mean() * n_items)


def _detect_separator(path: Path) -> str:
    """Auto-detect tab vs comma separator from the first line."""
    with open(path, 'r') as f:
        first_line = f.readline()
    return '\t' if first_line.count('\t') > first_line.count(',') else ','


def _qualtrics_load_with_metadata(path: Path):
    """
    Read a Qualtrics export, returning (data_df, headers_df, import_ids).

    - data_df: actual response rows, INTEGER POSITIONAL columns
    - headers_df: 3-row header block
    - import_ids: ImportId per column (canonical key for repeated names)
    """
    sep = _detect_separator(path)
    full = pd.read_csv(path, sep=sep, dtype=str, header=None)
    headers_df = full.iloc[:3].copy()
    data_df = full.iloc[3:].copy()
    data_df.columns = list(range(len(data_df.columns)))
    data_df = data_df.reset_index(drop=True)

    import_ids = []
    for raw in headers_df.iloc[2].tolist():
        try:
            import_ids.append(json.loads(raw).get('ImportId'))
        except (json.JSONDecodeError, TypeError):
            import_ids.append(None)

    return data_df, headers_df, import_ids


def _load_qualtrics_named(path: Path) -> pd.DataFrame:
    """
    Load a Qualtrics export using NAMED columns (skipping rows 1, 2 of header).
    Used for the trait file where column names are stable / non-repeating.
    """
    sep = _detect_separator(path)
    return pd.read_csv(path, sep=sep, skiprows=[1, 2], dtype=str)


# =============================================================================
# Prescan thought-rating loader
# =============================================================================

def load_prescan_thought_ratings(path: Path | str) -> pd.DataFrame:
    """
    Load pre-scan thought ratings into a long-format DataFrame.

    Returns one row per (subject, thought_position) with reminder phrase,
    36 ratings (content / form / quality / emotion), and dyscontrol scores.
    """
    path = Path(path)
    df, headers, import_ids = _qualtrics_load_with_metadata(path)
    qid_to_idx = {qid: i for i, qid in enumerate(import_ids) if qid}

    if 'externalDataReference' not in qid_to_idx:
        raise ValueError(
            f"Couldn't find externalDataReference column in {path.name}. "
            f"Available ImportIds: {list(qid_to_idx.keys())[:30]}..."
        )
    subj_idx = qid_to_idx['externalDataReference']
    df['subject'] = df[subj_idx].apply(_strip_subject_id_to_int)
    df = df.dropna(subset=['subject']).copy()
    df['subject'] = df['subject'].astype(int)

    rows = []
    for position, (block_qid, reminder_qid) in enumerate(
        zip(PRESCAN_BLOCK_QIDS, PRESCAN_REMINDER_TEXT_QIDS), start=1
    ):
        reminder_idx = qid_to_idx.get(f'QID{reminder_qid}_TEXT')
        if reminder_idx is None:
            warnings.warn(
                f"reminder phrase column QID{reminder_qid}_TEXT not found "
                f"for thought position {position}"
            )
            continue

        content_qid, form_qid, quality_qid, emotion_qid = (
            PRESCAN_BLOCK_ITEM_QIDS[block_qid]
        )
        content_idxs = [qid_to_idx.get(f'QID{content_qid}_{i}')
                        for i in range(1, PRESCAN_CONTENT_ITEMS + 1)]
        form_idxs = [qid_to_idx.get(f'QID{form_qid}_{i}')
                     for i in range(1, PRESCAN_FORM_ITEMS + 1)]
        quality_idxs = [qid_to_idx.get(f'QID{quality_qid}_{i}')
                        for i in range(1, PRESCAN_QUALITY_ITEMS + 1)]
        emotion_idxs = [qid_to_idx.get(f'QID{emotion_qid}_{i}')
                        for i in range(1, PRESCAN_EMOTION_ITEMS + 1)]

        for _, subject_row in df.iterrows():
            reminder = subject_row[reminder_idx]
            if pd.isna(reminder) or str(reminder).strip() == '':
                continue
            row = {
                'subject': int(subject_row['subject']),
                'thought_position': position,
                'reminder_phrase': str(reminder).strip(),
                'thought_key': normalize_thought_key(reminder),
            }
            for i, idx in enumerate(content_idxs, start=1):
                row[f'content_{i}'] = _safe_float(
                    subject_row[idx] if idx is not None else None
                )
            for i, idx in enumerate(form_idxs, start=1):
                row[f'form_{i}'] = _safe_float(
                    subject_row[idx] if idx is not None else None
                )
            for i, idx in enumerate(quality_idxs, start=1):
                row[f'quality_{i}'] = _safe_float(
                    subject_row[idx] if idx is not None else None
                )
            for i, idx in enumerate(emotion_idxs, start=1):
                row[f'emotion_{i}'] = _safe_float(
                    subject_row[idx] if idx is not None else None
                )

            # Dyscontrol from quality 1, 2, 3 (repetitive, intrusive, uncontrollable)
            q1 = row['quality_1']
            q2 = row['quality_2']
            q3 = row['quality_3']
            row['dyscontrol_raw'] = (
                np.nanmean([q1, q2, q3])
                if not all(pd.isna(v) for v in (q1, q2, q3))
                else np.nan
            )
            row['dyscontrol_imputed'] = np.mean([
                v if not pd.isna(v) else 0.0 for v in (q1, q2, q3)
            ])
            rows.append(row)

    long_df = pd.DataFrame(rows)
    print(f"Loaded {len(long_df)} (subject, thought) prescan ratings "
          f"from {long_df['subject'].nunique()} subjects")
    return long_df


# =============================================================================
# Trait loader (PTQ + PSWQ)
# =============================================================================

def _score_ptq(qualtrics_df: pd.DataFrame, min_completion: float = 0.8) -> pd.DataFrame:
    """
    Score PTQ-15: total + 3 subscales + attention check.

    Returns a DataFrame with subject, ptq_total, ptq_core, ptq_unproductive,
    ptq_capacity, ptq_attention_pass, ptq_n_missing.
    """
    out = pd.DataFrame()
    out['subject'] = qualtrics_df['ExternalReference'].apply(_strip_subject_id_to_int)

    item_data = pd.DataFrame()
    for item_num, col in PTQ_ITEM_COLS.items():
        if col not in qualtrics_df.columns:
            raise ValueError(f"PTQ column {col} (item {item_num}) "
                             f"not found in qualtrics file")
        item_data[item_num] = qualtrics_df[col].apply(
            lambda v: _parse_likert_value(v, PTQ_TEXT_TO_NUM)
        )

    out['ptq_total'] = item_data.apply(
        lambda row: _prorate(row, n_items=15, min_completion=min_completion),
        axis=1,
    )
    for name, items in PTQ_SUBSCALES.items():
        sub_data = item_data[items]
        out[f'ptq_{name}'] = sub_data.apply(
            lambda row: _prorate(row, n_items=len(items),
                                  min_completion=min_completion),
            axis=1,
        )

    if PTQ_ATTENTION_CHECK_COL in qualtrics_df.columns:
        attn = qualtrics_df[PTQ_ATTENTION_CHECK_COL].apply(
            lambda v: _parse_likert_value(v, PTQ_TEXT_TO_NUM)
        )
        out['ptq_attention_pass'] = (attn == PTQ_ATTENTION_CHECK_VALUE)
    else:
        out['ptq_attention_pass'] = np.nan

    out['ptq_n_missing'] = item_data.isna().sum(axis=1)
    out = out.dropna(subset=['subject']).reset_index(drop=True)
    out['subject'] = out['subject'].astype(int)
    return out


def _score_pswq(qualtrics_df: pd.DataFrame, min_completion: float = 0.8) -> pd.DataFrame:
    """
    Score PSWQ-16. Returns subject, pswq_total, pswq_n_missing.
    """
    out = pd.DataFrame()
    out['subject'] = qualtrics_df['ExternalReference'].apply(_strip_subject_id_to_int)

    item_data = pd.DataFrame()
    for item_num, col in PSWQ_ITEM_COLS.items():
        if col not in qualtrics_df.columns:
            raise ValueError(f"PSWQ column {col} (item {item_num}) "
                             f"not found in qualtrics file")
        vals = qualtrics_df[col].apply(
            lambda v: _parse_likert_value(v, PSWQ_TEXT_TO_NUM)
        )
        if item_num in PSWQ_REVERSE_ITEMS:
            vals = 6 - vals
        item_data[item_num] = vals

    out['pswq_total'] = item_data.apply(
        lambda row: _prorate(row, n_items=16, min_completion=min_completion),
        axis=1,
    )
    out['pswq_n_missing'] = item_data.isna().sum(axis=1)
    out = out.dropna(subset=['subject']).reset_index(drop=True)
    out['subject'] = out['subject'].astype(int)
    return out


def load_trait_scores(path: Path | str, min_completion: float = 0.8) -> pd.DataFrame:
    """
    Load PTQ-15 and PSWQ-16 scores from the trait Qualtrics export.

    Parameters
    ----------
    path : Path or str
        Path to the trait Qualtrics file.
    min_completion : float
        Minimum fraction of items completed for prorating (default 0.8).

    Returns
    -------
    pd.DataFrame with subject, ptq_total, ptq_core, ptq_unproductive,
    ptq_capacity, ptq_attention_pass, ptq_n_missing,
    pswq_total, pswq_n_missing.
    """
    path = Path(path)
    df = _load_qualtrics_named(path)

    ptq = _score_ptq(df, min_completion=min_completion)
    pswq = _score_pswq(df, min_completion=min_completion)
    merged = ptq.merge(pswq, on='subject', how='outer')

    n_pass = merged['ptq_attention_pass'].sum()
    n_total = len(merged)
    print(f"Loaded {n_total} subjects from {path.name}")
    print(f"  PTQ attention check passed: {n_pass}/{n_total}")
    if 'ptq_total' in merged.columns:
        valid = merged.dropna(subset=['ptq_total'])
        print(f"  PTQ total: M={valid['ptq_total'].mean():.1f}, "
              f"SD={valid['ptq_total'].std():.1f}, "
              f"range {valid['ptq_total'].min():.0f}-"
              f"{valid['ptq_total'].max():.0f}")
    if 'pswq_total' in merged.columns:
        valid = merged.dropna(subset=['pswq_total'])
        print(f"  PSWQ total: M={valid['pswq_total'].mean():.1f}, "
              f"SD={valid['pswq_total'].std():.1f}, "
              f"range {valid['pswq_total'].min():.0f}-"
              f"{valid['pswq_total'].max():.0f}")

    return merged