"""
Loaders and helpers for BIDS-format _events.tsv files.

The events.tsv files in this dataset contain both per-trial rows (go/nogo
SART trials, with a `trial_type` column) and per-block rows (Thoughtblock,
ThoughtProbe, etc., flagged by an `eventType` column). This module provides
two utilities used across notebooks:

- load_events_tsv: read one run's events.tsv into a DataFrame
- block_event_rows: aggregate rows into per-block summaries (one row per
  Thoughtblock or SART block, with onset/duration/thoughtNumber)
"""
from __future__ import annotations

from pathlib import Path

import pandas as pd

from config import DATA_ROOT, SESSION, TASK


def load_events_tsv(subject, run):
    """Load BIDS events.tsv for one (subject, run).

    Parameters
    ----------
    subject : int or str
        Subject ID, e.g. 302 or '302'.
    run : int or str
        Run number; accepted as int (1, 2, 3) or zero-padded string
        ('01', '02', '03').

    Returns
    -------
    pandas.DataFrame or None
        The events table, or None if the file does not exist.
    """
    run_str = f'{int(run):02d}'
    p = (DATA_ROOT / 'rawdata' / f'sub-{subject}' / SESSION / 'func'
         / f'sub-{subject}_{SESSION}_task-{TASK}_run-{run_str}_events.tsv')
    if not p.exists():
        return None
    return pd.read_csv(p, sep='\t')


def block_event_rows(events_df):
    """Aggregate an events DataFrame into one row per block.

    Each Thoughtblock has its own row in events.tsv (eventType=='Thoughtblock').
    SART trials are aggregated to per-block summaries by grouping on
    thoughtNumber: onset = first trial onset, duration = last trial
    offset minus first trial onset.

    Parameters
    ----------
    events_df : pandas.DataFrame or None
        As returned by `load_events_tsv`. Pass None to get an empty list back.

    Returns
    -------
    list of dict
        One dict per block, with keys: condition, onset, duration,
        thoughtNumber, thought.
    """
    if events_df is None:
        return []

    blocks = []
    if 'eventType' in events_df.columns:
        tb = events_df[events_df['eventType'] == 'Thoughtblock']
        for _, r in tb.iterrows():
            blocks.append({
                'condition': 'Thoughtblock',
                'onset': r['onset'],
                'duration': r['duration'],
                'thoughtNumber': int(r['thoughtNumber']),
                'thought': r.get('Thought', ''),
            })

    # SART blocks: aggregate trials by thoughtNumber
    sart = events_df[events_df['trial_type'].isin(['go', 'nogo'])]
    if 'thoughtNumber' in sart.columns:
        for tn, g in sart.groupby('thoughtNumber'):
            onset = g['onset'].min()
            offset = (g['onset'] + g['duration']).max()
            duration = offset - onset
            blocks.append({
                'condition': 'SART',
                'onset': onset,
                'duration': duration,
                'thoughtNumber': int(tn),
                'thought': g['Thought'].iloc[0] if 'Thought' in g.columns else '',
            })
    return blocks