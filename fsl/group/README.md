# Group-level analyses

Third-level (group) models, run as FLAME 1 mixed effects with a single-group
mean EV across 57 participants. Cluster-forming threshold z > 3.1,
cluster-corrected p < .05.

## Designs

`designs/<model>/<contrast>/design.fsf` — 42 designs, one per model and
contrast. These were constructed individually rather than generated from a
template, so they are the primary artefact and are included in full. All
specify `mixed_yn 2` (FLAME 1) and `npts 57`.

Each design reads one cope from each participant's level-2 `.gfeat`
directory. The cope number differs between models, because models differ in
how many contrasts they define and in what order. The mapping is:

| Model | Contrast | Cope |
|---|---|---|
| dyscontrolmod | ThoughtVsBaseline | 1 |
| dyscontrolmod | ThoughtdcBaseline | 2 |
| dyscontrolmod | SARTBaseline | 3 |
| dyscontrolmod | **SARTdcBaseline** | **4** |
| dyscontrolmod | ThoughtSARTdc | 5 |
| dyscontrolmod | ThoughtdcSARTdc | 6 |
| dyscontrolandeffortmods | **SARTdcBaseline** | **2** |
| ACCmod | ThoughtVsBaseline / SARTsBaseline / ThoughtVsSART / SARTACCbaseline / ThoughtSARTACC | 1 / 2 / 3 / 4 / 5 |
| dyscontrolandACCmods | ThoughtblockdcBaseline / SARTdcBaseline / SARTACCBaseline / SARTdcACC / ThoughtSARTdc | 1 / 2 / 3 / 4 / 5 |
| indivthoughtmod | same ordering as dyscontrolmod | 1-6 |
| nomod | ThoughtVsBaseline / SARTVsBaseline / ThoughtVsSART | 1 / 2 / 3 |
| PPI_PCC_DC | SARTDCPPI / SARTPPI / SARTDC_SARTPPI / SARTDC_mod | 1 / 2 / 3 / 4 |
| PPI_PCC_ACC | SARTACCPPI / SARTPPI / SARTACC_SARTPPI / SARTACC_mod | 1 / 2 / 3 / 4 |
| SARTACCcluster_PPI | SARTACCPPI / SARTPPI / SARTACC_SARTPPI / SARTACC_mod | 1 / 2 / 3 / 4 |
| PCC_PPI | TBPPI / SARTdcPPI / SARTACCPPI / SARTdcACCPPI | 1 / 2 / 3 / 4 |

Note the two rows in bold: the same contrast name maps to cope4 in
`dyscontrolmod` and cope2 in `dyscontrolandeffortmods`, because the
effort-controlled model defines five contrasts rather than six and omits the
unmodulated baselines. Both are the H3 analyses reported in the manuscript.

## A naming caveat

`dyscontrolmod/ThoughtSARTdc` reads cope5, which in
`design_template_level1_dyscontrolmod.fsf` weights `+Thoughtblock
-SARTblock` — the unmodulated difference. The dyscontrol-modulated version of
that contrast is cope6, which has its own directory
(`dyscontrolmod/ThoughtdcSARTdc`). The directory name is therefore misleading;
the cope number is the one to trust.

## Contrasts not reported

Unmodulated contrasts against implicit baseline (`ThoughtVsBaseline`,
`SARTBaseline`, `SARTsBaseline`) were run but are not interpreted in the
manuscript. With no explicit rest condition the implicit baseline is
ill-defined and these contrasts produce implausibly extensive clusters. The
same applies to the unmodulated PPI terms (`SARTPPI`, `TBPPI`).

## Other scripts here

- `summarize_feat_clusters.sh` — extracts cluster tables from thresholded maps
- `run_svc_analyses.sh` — small-volume-corrected analyses
