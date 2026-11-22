#!/usr/bin/env python3
"""Trim a three-run level-2 (fixed-effects) design to the runs a subject actually has.

  python3 trim_level2_runs.py 1,2 < design.fsf > design_trimmed.fsf

The level-2 templates are written for three level-1 inputs (run1-run3). A subject with a run
excluded (for example sub-303, run 3) needs a design with fewer inputs. This keeps the inputs
whose path contains /run<N>_ for the requested runs, renumbers them from 1, sets npts and
multiple to the new count, and drops the matching EV and group-membership lines. With all
three runs it returns the template unchanged.
"""
import re
import sys


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    runs = [int(x) for x in sys.argv[1].split(",") if x.strip()]
    if len(runs) < 2:
        sys.exit(f"need at least two runs for a level-2 design, got {runs}")
    lines = sys.stdin.read().split("\n")

    # which template input belongs to which run
    input_run = {}
    for ln in lines:
        m = re.match(r'^set feat_files\((\d+)\) ".*/run(\d+)_', ln)
        if m:
            input_run[int(m.group(1))] = int(m.group(2))
    if not input_run:
        sys.exit("no 'set feat_files(N)' lines with a /run<N>_ path found: not a level-2 template?")
    missing = [r for r in runs if r not in input_run.values()]
    if missing:
        sys.exit(f"template has no input for run(s) {missing}")
    keep = [i for i in sorted(input_run) if input_run[i] in runs]
    new_index = {old: new for new, old in enumerate(keep, start=1)}
    n = len(keep)

    def block_ok(i):
        return i >= 1 and lines[i - 1].startswith("#") and i + 1 < len(lines) and lines[i + 1] == ""

    out, i = [], 0
    drop = set()
    for i, ln in enumerate(lines):
        m = re.match(r"^set feat_files\((\d+)\) ", ln)
        e = re.match(r"^set fmri\(evg(\d+)\.1\) ", ln)
        g = re.match(r"^set fmri\(groupmem\.(\d+)\) ", ln)
        if m or e or g:
            if not block_ok(i):
                sys.exit(f"line {i + 1}: expected '# comment', 'set ...', blank; layout not recognised")
            idx = int((m or e or g).group(1))
            if (m and idx not in new_index) or ((e or g) and idx > n):
                drop.update({i - 1, i, i + 1})
    for i, ln in enumerate(lines):
        if i in drop:
            continue
        m = re.match(r"^set feat_files\((\d+)\) (.*)$", ln)
        if m:
            new = new_index[int(m.group(1))]
            ln = f"set feat_files({new}) {m.group(2)}"
            out[-1] = re.sub(r"\(\d+\)\s*$", f"({new})", out[-1])      # the comment above it
        ln = re.sub(r"^set fmri\(npts\) \d+", f"set fmri(npts) {n}", ln)
        ln = re.sub(r"^set fmri\(multiple\) \d+", f"set fmri(multiple) {n}", ln)
        out.append(ln)
    text = "\n".join(out)
    if len(re.findall(r"^set feat_files\(", text, flags=re.M)) != n:
        sys.exit("internal check failed: wrong number of inputs after trimming")
    sys.stdout.write(text)


if __name__ == "__main__":
    main()
