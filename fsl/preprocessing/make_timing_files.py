#!/usr/bin/env python3
"""Build FEAT three-column timing files (onset, duration, weight) from BIDS events.tsv.

Input : $TREW_DATA_ROOT/rawdata/sub-<ID>/ses-01/func/sub-<ID>_ses-01_task-PDT_run-0<N>_events.tsv
Output: $TREW_DATA_ROOT/timing/censorRT/<ID>/sub-<ID>_run-0<N>_<name>.txt

Standard library only. Reads only the public events files; no PsychoPy output.

Rules (all per run):
  * SART trials whose response time is more than 3 SD from the run mean are dropped
    ("censorRT"); trials with no response are kept.
  * A SART block's onset is its first kept trial; its duration is the sum of its kept trials.
  * Modulators are mean-centred within the run: probe 1 (dyscontrol) and probe 3 (effort) across
    thoughts; the accuracy index across kept SART trials.
  * A block with no modulator value goes to a *_missedtrials file (weight 1) and is removed from
    the modulated file. An empty file is written as "0 0 0", which FEAT accepts as an empty EV.

Usage:
  source setup_env.sh
  python3 fsl/preprocessing/make_timing_files.py                 # all subjects
  python3 fsl/preprocessing/make_timing_files.py --subjects 301  # one subject
"""
import argparse
import csv
import glob
import math
import os
import re
import statistics
import sys

MISSING = {"", "n/a", "NA", "nan", "NaN"}
REQUIRED = ["onset", "duration", "response_time", "response", "trial_type", "corr_ans",
            "thoughtNumber", "probenumber", "eventType"]
RT_SD_CUTOFF = 3.0
POST_PROBE_FIXATION = 2.0   # fixed fixation between the probe window and the next thought block


def num(x):
    return None if x is None or x.strip() in MISSING else float(x)


def isnan(x):
    return x is None or (isinstance(x, float) and math.isnan(x))


def mean(xs):
    """mean(x, na.rm = TRUE): NaN when nothing is left."""
    xs = [x for x in xs if not isnan(x)]
    return sum(xs) / len(xs) if xs else math.nan


def read_events(path):
    with open(path, newline="", encoding="utf-8-sig") as fh:
        reader = csv.reader(fh, delimiter="\t")
        header = next(reader)
        absent = [c for c in REQUIRED if c not in header]
        if absent:
            raise ValueError(f"{path}: missing columns {absent}")
        rows = []
        for lineno, r in enumerate(reader, start=2):
            if not any(r):
                continue
            if len(r) != len(header):
                raise ValueError(
                    f"{path}: line {lineno} has {len(r)} fields but the header has {len(header)}. "
                    "Rows are misaligned, so values would be read from the wrong columns.")
            rows.append(dict(zip(header, r)))
    return rows


def thought_number(r):
    v = num(r["thoughtNumber"])
    if v is None:
        raise ValueError(f"row at onset {r['onset']} ({r['eventType']}) has no thoughtNumber")
    return int(v)


def build_run(rows):
    of = lambda t: [r for r in rows if r["eventType"] == t]

    # ---- SART trials, with RT outliers removed ----------------------------------------
    sart = [dict(onset=num(r["onset"]),
                 duration=num(r["duration"]) if num(r["duration"]) is not None else math.nan,
                 rt=num(r["response_time"]), ttype=r["trial_type"],
                 corr=num(r["corr_ans"]), tn=thought_number(r)) for r in of("SART")]
    rts = [t["rt"] for t in sart if t["rt"] is not None]
    m_rt = sum(rts) / len(rts) if rts else math.nan
    sd_rt = statistics.stdev(rts) if len(rts) > 1 else math.nan
    keep = [t for t in sart if t["rt"] is None or isnan(sd_rt)
            or not (t["rt"] > m_rt + RT_SD_CUTOFF * sd_rt or t["rt"] < m_rt - RT_SD_CUTOFF * sd_rt)]
    thoughts = sorted({t["tn"] for t in keep})

    # ---- accuracy index: nogo accuracy / mean go RT, centred over kept trials --------
    acc = {}
    for th in thoughts:
        nogo = [t["corr"] for t in keep if t["tn"] == th and t["ttype"] == "nogo"]
        go_rt = mean([t["rt"] for t in keep if t["tn"] == th and t["ttype"] == "go"])
        nogo_acc = math.nan if (not nogo or any(c is None for c in nogo)) else sum(nogo) / len(nogo)
        ok = not isnan(nogo_acc) and not isnan(go_rt) and go_rt != 0
        acc[th] = nogo_acc / (go_rt * 100) * 100 if ok else math.nan
    acc_mean = mean([acc[t["tn"]] for t in keep])
    acc_c = {th: acc[th] - acc_mean for th in thoughts}

    # ---- probe ratings, mean-centred across thoughts ------------------------------------
    probes = of("ThoughtProbe")
    rating = {(thought_number(r), int(num(r["probenumber"]))): num(r["response"]) for r in probes}
    probe_thoughts = sorted({thought_number(r) for r in probes})

    def centred(pn):
        vals = {th: rating.get((th, pn)) for th in probe_thoughts}
        m = mean(list(vals.values()))
        return {th: (None if v is None else v - m) for th, v in vals.items()}

    dys, eff = centred(1), centred(3)

    # ---- EVs ----------------------------------------------------------------------------
    sart_blocks = []
    for th in thoughts:
        tr = [t for t in keep if t["tn"] == th]
        sart_blocks.append((th, tr[0]["onset"], sum(t["duration"] for t in tr)))
    thought_blocks = sorted((thought_number(r), num(r["onset"]), num(r["duration"])) for r in of("Thoughtblock"))

    def split(blocks, mod):
        """-> (modulated rows, missed rows with weight 1)"""
        good, missed = [], []
        for th, on, du in blocks:
            v = mod.get(th)
            (missed if isnan(v) else good).append((on, du, 1.0) if isnan(v) else (on, du, v))
        return good, missed

    ev = {}
    ev["thoughtblock"] = [(on, du, 1.0) for _, on, du in thought_blocks]
    ev["SART"] = [(on, du, 1.0) for _, on, du in sart_blocks]
    ev["Thoughtblock_dyscontrolmod"], ev["Thoughts_dyscontrolmod_missedtrials"] = split(thought_blocks, dys)
    ev["SART_dyscontrolmod"], ev["SART_dyscontrolmod_missedtrials"] = split(sart_blocks, dys)
    ev["SART_effortmod"], ev["SART_effortmod_missedtrials"] = split(sart_blocks, eff)
    ev["SART_ACCmod"], ev["SART_ACC_missedtrials"] = split(sart_blocks, acc_c)

    # probe period: from the Reflect screen to the fixed fixation before the next thought block.
    # The "Fixation" row in events.tsv marks when a participant finished early, which is not
    # the end of the window, so the end is the next block onset minus POST_PROBE_FIXATION.
    # For the last thought of a run there is no next block: the Fixation row onset is used,
    # which is exact only if the participant used the whole window.
    fixation = {thought_number(r): num(r["onset"]) for r in of("Fixation")}
    last_end = {}
    for r in probes:
        end = num(r["onset"]) + (num(r["duration"]) or 0.0)
        last_end[thought_number(r)] = max(end, last_end.get(thought_number(r), -math.inf))
    block_onsets = sorted(num(r["onset"]) for r in of("Thoughtblock"))
    reflects = sorted(of("Reflect"), key=lambda r: num(r["onset"]))
    window = {}
    for r in reflects:
        th, on = thought_number(r), num(r["onset"])
        later = [b for b in block_onsets if b > on]
        if later:
            window[th] = later[0] - POST_PROBE_FIXATION - on
    typical = statistics.median(window.values()) if window else None
    pb = []
    for r in reflects:
        th, on = thought_number(r), num(r["onset"])
        if th in window:
            dur = window[th]
        elif typical is not None:
            dur = typical      # last thought of the run: no next block, so use the run's typical window
        else:
            end = fixation.get(th, last_end.get(th))
            if end is None:
                continue
            dur = end - on
        pb.append((on, dur, 1.0))
    ev["thoughtprobeblock"] = pb
    return ev


def fmt(x):
    return f"{x:.15g}"


def write_ev(path, rows):
    with open(path, "w") as fh:
        if not rows:
            fh.write("0 0 0\n")
        for on, du, mod in rows:
            fh.write(f"{fmt(on)} {fmt(du)} {fmt(mod)}\n")


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--root", default=os.environ.get("TREW_DATA_ROOT"), help="data root (default $TREW_DATA_ROOT)")
    ap.add_argument("--out", help="output folder (default <root>/timing/censorRT)")
    ap.add_argument("--subjects", nargs="*", help="subject IDs, e.g. 301 302 (default: all in rawdata)")
    ap.add_argument("--runs", nargs="*", type=int, default=[1, 2, 3])
    ap.add_argument("--task", default="PDT")
    a = ap.parse_args()
    if not a.root:
        sys.exit("Set TREW_DATA_ROOT (source setup_env.sh) or pass --root")
    out_root = a.out or os.path.join(a.root, "timing", "censorRT")
    subjects = a.subjects or sorted(re.sub(r"\D", "", os.path.basename(p))
                                    for p in glob.glob(os.path.join(a.root, "rawdata", "sub-*")))
    n_ok, errors = 0, []
    for s in subjects:
        for run in a.runs:
            ev_file = os.path.join(a.root, "rawdata", f"sub-{s}", "ses-01", "func",
                                   f"sub-{s}_ses-01_task-{a.task}_run-0{run}_events.tsv")
            if not os.path.exists(ev_file):
                continue
            try:
                ev = build_run(read_events(ev_file))
            except Exception as e:
                errors.append(f"sub-{s} run-0{run}: {e}")
                continue
            d = os.path.join(out_root, s)
            os.makedirs(d, exist_ok=True)
            for name, rows in ev.items():
                write_ev(os.path.join(d, f"sub-{s}_run-0{run}_{name}.txt"), rows)
            n_ok += 1
    print(f"wrote timing files for {n_ok} subject-runs into {out_root}")
    for e in errors:
        print("ERROR", e, file=sys.stderr)
    sys.exit(1 if errors else 0)


if __name__ == "__main__":
    main()
