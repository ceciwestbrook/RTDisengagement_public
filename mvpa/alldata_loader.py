"""
Loader for the trial-level in-scanner data file (alldata.csv).

This file has one row per scanner trial, with columns for the reminder phrase,
probe responses, and various derived quantities. It was originally produced
by upstream R code that used a fuzzy-match (edit-distance) merge to attach
prescan ratings -- this is unreliable and introduced both duplicate rows
and incorrect matches. We re-do the merge from scratch in this pipeline
(see merge.py).

Two file-level issues this loader handles:

1. **Unquoted commas in Thought.x and Thought.y fields.**
   Some thought reminder phrases contain commas (e.g., "BFF, besties"),
   but the upstream R export did not quote these fields. The result is
   that ~60+ rows have *too many* fields when naively split on comma. We
   detect these and search over plausible splits, validating the split by
   checking that the 12 fields between Thought.x and Thought.y parse as
   numeric/NA (since those are probe ratings, RTs, and accuracy values).

2. **Embedded newlines in some long descriptions.**
   We collapse newline-wrapped rows by detecting that real rows start
   with a digit (subject ID).
"""
from __future__ import annotations

import re
from pathlib import Path

import numpy as np
import pandas as pd

from questionnaire_loader import normalize_thought_key


def _looks_numeric_or_na(val: str) -> bool:
    """Whether a single CSV field plausibly is a number, NA, or boolean.
    Used during recombining to validate that probe-rating columns
    are still in the right place after splitting."""
    v = val.strip()
    if v in ('', 'NA', 'None', 'TRUE', 'FALSE'):
        return True
    try:
        float(v)
        return True
    except ValueError:
        return False


def load_alldata(path: Path | str, verbose: bool = True) -> pd.DataFrame:
    """
    Load the trial-level alldata.csv file with robust handling of unquoted
    commas in free-text Thought.x / Thought.y fields.

    Parameters
    ----------
    path : Path or str
    verbose : bool

    Returns
    -------
    pd.DataFrame with at least these columns:
        subject : int
        run : int
        ThoughtNumber : int (1-9)
        thought_key : str (normalized in-scanner reminder phrase)
        probe1 .. probe6 : float (0-100, ThoughtProbe ratings)
        meanRT, Mean_go_RT, AccIndex, NoGo_ACC, TotalOutlierRT : float

    The original Thought.x / Thought.y / R-merged dyscontrol columns are
    discarded -- we rebuild the prescan merge ourselves in merge.py.
    """
    path = Path(path)

    with open(path) as f:
        raw = f.read()

    # Step 1: collapse newline-wrapped rows. Real rows start with a digit
    # (subject ID).
    raw_lines = raw.split('\n')
    fixed_lines = []
    for line in raw_lines:
        if not line.strip():
            continue
        if re.match(r'^\d+,', line):
            fixed_lines.append(line)
        elif fixed_lines:
            # Continuation of the previous row (embedded newline)
            fixed_lines[-1] = fixed_lines[-1] + ' ' + line.lstrip()
        else:
            # Header line (doesn't start with a digit)
            fixed_lines.append(line)

    header = fixed_lines[0].split(',')
    n_cols = len(header)

    # Layout constants. Once the header is parsed, these positions are fixed.
    # 0 participant, 1 run, 2 Thought.x, 3-14 (12 cols) ThoughtNumber..TotalOutlierRT,
    # 15 Thought.y, 16-... (n_tail cols) Q1_1..dyscontrol_imputed
    if 'Thought.x' not in header or 'Thought.y' not in header:
        raise ValueError(
            "alldata.csv missing Thought.x or Thought.y column. "
            f"Header: {header}"
        )
    idx_thought_x = header.index('Thought.x')
    idx_thought_y = header.index('Thought.y')
    n_mid = idx_thought_y - idx_thought_x - 1
    n_tail = n_cols - idx_thought_y - 1

    # Step 2: parse rows, recombining surplus fields from unquoted commas
    parsed = []
    n_recombined = 0
    n_dropped = 0

    for line in fixed_lines[1:]:
        parts = line.split(',')
        if len(parts) == n_cols:
            parsed.append(parts)
            continue

        n_extra = len(parts) - n_cols
        if n_extra <= 0:
            n_dropped += 1
            continue

        # Search splits: x_extras of the surplus go to Thought.x, the rest
        # to Thought.y. The split is valid if:
        #   (a) the resulting row length matches expected n_cols
        #   (b) the 12 fields between Thought.x and Thought.y parse as
        #       numeric/NA (probe ratings, RTs, accuracy)
        found = False
        for x_extras in range(0, n_extra + 1):
            y_extras = n_extra - x_extras
            tx_end = idx_thought_x + 1 + x_extras
            mid_end = tx_end + n_mid
            ty_end = mid_end + 1 + y_extras
            if ty_end + n_tail != len(parts):
                continue
            mid = parts[tx_end:mid_end]
            if all(_looks_numeric_or_na(m) for m in mid):
                thought_x = ', '.join(parts[idx_thought_x:tx_end])
                thought_y = ', '.join(parts[mid_end:ty_end])
                tail = parts[ty_end:]
                new_row = (parts[:idx_thought_x] + [thought_x] + mid
                           + [thought_y] + tail)
                if len(new_row) == n_cols:
                    parsed.append(new_row)
                    n_recombined += 1
                    found = True
                    break
        if not found:
            n_dropped += 1

    if verbose and (n_recombined > 0 or n_dropped > 0):
        print(f"  alldata parsing: recombined {n_recombined} rows with "
              f"unquoted commas in Thought.x/y, dropped {n_dropped}")

    df = pd.DataFrame(parsed, columns=header)

    # Standardize types and key fields
    if 'participant' in df.columns:
        df['subject'] = df['participant'].astype(int)
    elif 'subject' in df.columns:
        df['subject'] = df['subject'].astype(int)
    else:
        raise ValueError(
            f"No participant/subject column in alldata. Columns: {header}"
        )
    df['run'] = df['run'].astype(int)
    df['ThoughtNumber'] = df['ThoughtNumber'].astype(int)

    # Coerce numeric columns (probes, RTs, accuracy, item ratings)
    numeric_cols = (
        ['probe1', 'probe2', 'probe3', 'probe4', 'probe5', 'probe6',
         'meanRT', 'Mean_go_RT', 'AccIndex', 'NoGo_ACC', 'TotalOutlierRT']
        + [c for c in df.columns
           if c.startswith(('Q1_', 'Q2_', 'Q3_', 'Q4_'))]
        + ['dyscontrol', 'dyscontrol_imputed',
           'Q3_1_imputed', 'Q3_2_imputed', 'Q3_3_imputed']
    )
    for c in numeric_cols:
        if c in df.columns:
            df[c] = pd.to_numeric(df[c], errors='coerce')

    # Build thought_key from the in-scanner Thought.x reminder phrase
    df['thought_key'] = df['Thought.x'].apply(normalize_thought_key)

    # Sanity check: Thought.x and Thought.y should match (both are reminder
    # phrases, sourced from different upstream files)
    if 'Thought.y' in df.columns and verbose:
        thx = df['Thought.x'].apply(normalize_thought_key)
        thy = df['Thought.y'].apply(normalize_thought_key)
        both_present = thx.notna() & thy.notna() \
                & (thx != 'nan') & (thy != 'nan')
        mismatches = (thx != thy) & both_present
        if mismatches.sum() > 0:
            print(f"  Note: {mismatches.sum()} rows where Thought.x != "
                  f"Thought.y after normalization (case differences are OK)")

    # Drop the upstream R-merged prescan columns -- we re-merge in merge.py
    drop_cols = (['Thought.x', 'Thought.y']
                 + [c for c in df.columns
                    if c.startswith(('Q1_', 'Q2_', 'Q3_', 'Q4_'))]
                 + ['dyscontrol', 'dyscontrol_imputed',
                    'Q3_1_imputed', 'Q3_2_imputed', 'Q3_3_imputed'])
    df = df.drop(columns=[c for c in drop_cols if c in df.columns])

    if verbose:
        print(f"alldata: {len(df)} rows, {df['subject'].nunique()} subjects")

    return df.reset_index(drop=True)