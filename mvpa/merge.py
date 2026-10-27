"""
Strict merge of alldata trial-level data with prescan thought ratings.

Replaces the upstream R fuzzy-match merge, which was unreliable. Our approach:

1. Apply manual corrections to alldata thought_keys (e.g., spelling typos
   that prevent exact match with prescan).
2. Inner-merge on (subject, thought_key). Both keys are pre-normalized
   (lowercase, punctuation -> space, whitespace collapsed).
3. Final dedup on (subject, run, ThoughtNumber, thought_key) to catch any
   row-level duplicates that came in from the source file (e.g., sub-356
   had every row duplicated in alldata.csv due to an upstream R error).
4. Report unmatched rows for further manual-correction discovery.

Outputs a clean DataFrame with one row per scanner trial, including
dyscontrol_imputed from the prescan.
"""
from __future__ import annotations

import json
from pathlib import Path

import pandas as pd


def load_manual_corrections(path: Path | str) -> list[dict]:
    """Load manual corrections from JSON file."""
    path = Path(path)
    with open(path, 'r') as f:
        data = json.load(f)
    return data['corrections']


def apply_manual_corrections(
    alldata: pd.DataFrame,
    corrections: list[dict],
    verbose: bool = True,
) -> pd.DataFrame:
    """
    Apply manual corrections to alldata thought_keys.

    Each correction maps (subject, alldata_thought_key) -> prescan_thought_key.
    We replace alldata's thought_key with the prescan version so the
    subsequent inner-merge succeeds.

    Parameters
    ----------
    alldata : pd.DataFrame
        Trial-level alldata (must have 'subject' and 'thought_key' columns)
    corrections : list of dict
        Each dict: {'subject': int, 'from': str, 'to': str, 'note': str}
    verbose : bool

    Returns
    -------
    pd.DataFrame (copy with corrections applied)
    """
    df = alldata.copy()
    n_total_changed = 0
    for entry in corrections:
        sub = entry['subject']
        from_key = entry['from']
        to_key = entry['to']
        mask = (df['subject'] == sub) & (df['thought_key'] == from_key)
        n_changed = mask.sum()
        if n_changed > 0:
            df.loc[mask, 'thought_key'] = to_key
            n_total_changed += n_changed

    if verbose:
        print(f"  Applied {len(corrections)} manual corrections "
              f"({n_total_changed} rows rewritten)")
    return df


def strict_merge_prescan(
    alldata_corrected: pd.DataFrame,
    prescan: pd.DataFrame,
    verbose: bool = True,
) -> tuple[pd.DataFrame, pd.DataFrame]:
    """
    Inner-merge alldata with prescan ratings on (subject, thought_key).

    Parameters
    ----------
    alldata_corrected : pd.DataFrame
        Alldata after applying manual corrections.
    prescan : pd.DataFrame
        Prescan thought ratings, must have (subject, thought_key, dyscontrol_imputed).
    verbose : bool

    Returns
    -------
    matched : pd.DataFrame
        Inner-merged rows. Same columns as alldata plus dyscontrol_imputed.
    unmatched : pd.DataFrame
        Alldata rows that did not find a prescan match. Useful for finding
        new manual corrections.
    """
    keep_cols = ['subject', 'thought_key', 'dyscontrol_imputed', 'dyscontrol_raw']
    prescan_subset = prescan[keep_cols].drop_duplicates(
        subset=['subject', 'thought_key'], keep='first'
    )

    matched = alldata_corrected.merge(
        prescan_subset,
        on=['subject', 'thought_key'],
        how='inner',
        validate='many_to_one',
    )

    # Unmatched rows from alldata (left side without a prescan partner)
    matched_keys = set(zip(matched['subject'], matched['thought_key']))
    is_unmatched = ~alldata_corrected.apply(
        lambda r: (r['subject'], r['thought_key']) in matched_keys, axis=1
    )
    unmatched = alldata_corrected[is_unmatched].copy()

    if verbose:
        print(f"\nStrict prescan merge:")
        print(f"  Matched rows: {len(matched)}")
        print(f"  Unmatched rows: {len(unmatched)}")
        n_subj_matched = matched['subject'].nunique()
        n_subj_with_unmatched = unmatched['subject'].nunique()
        print(f"  Subjects with all rows matched: "
              f"{n_subj_matched - n_subj_with_unmatched}")
        print(f"  Subjects with at least one unmatched row: "
              f"{n_subj_with_unmatched}")
        if len(unmatched) > 0 and verbose:
            print(f"\nUnmatched (subject, thought_key) pairs (for manual review):")
            unique_unmatched = (
                unmatched[['subject', 'thought_key']]
                .drop_duplicates()
                .sort_values(['subject', 'thought_key'])
            )
            for _, row in unique_unmatched.head(30).iterrows():
                # Show prescan options for this subject
                subj_options = prescan[prescan['subject'] == row['subject']]['thought_key'].tolist()
                print(f"  sub-{row['subject']}: '{row['thought_key']}'")
                print(f"    prescan available: {subj_options}")

    return matched, unmatched


def final_dedup(matched: pd.DataFrame, verbose: bool = True) -> pd.DataFrame:
    """
    Drop row-level duplicates on (subject, run, ThoughtNumber, thought_key).

    This catches cases like sub-356 where the source alldata.csv had every
    row duplicated identically. After the prescan merge, the dedup ensures
    we have one row per scanner trial.

    Returns deduplicated DataFrame.
    """
    n_before = len(matched)
    deduped = matched.drop_duplicates(
        subset=['subject', 'run', 'ThoughtNumber', 'thought_key'],
        keep='first',
    ).reset_index(drop=True)
    n_after = len(deduped)
    if verbose:
        n_dropped = n_before - n_after
        print(f"\nFinal dedup on (subject, run, ThoughtNumber, thought_key):")
        print(f"  Before: {n_before} rows")
        print(f"  After:  {n_after} rows")
        print(f"  Dropped: {n_dropped} duplicate rows")
        if n_dropped > 0:
            # Identify which subjects had duplicates
            counts_before = matched.groupby('subject').size()
            counts_after = deduped.groupby('subject').size()
            with_dupes = (counts_before - counts_after) > 0
            affected = counts_before[with_dupes].index.tolist()
            print(f"  Affected subjects: {affected}")
    return deduped
