#!/usr/bin/env Rscript
# Build FEAT-ready motion confound files from fMRIPrep's confounds timeseries.
#
# Writes one file per subject/run containing:
#   - the 24 standard motion parameters (6 translations/rotations, their
#     derivatives, and the squares of both)
#   - one binary spike regressor per volume exceeding FD_THRESHOLD
#
# Usage:
#   Rscript extract_motion_confounds.R <subject> <run> [preproc_dir]
#
#   subject      numeric subject ID, e.g. 303
#   run          run number, 1-3
#   preproc_dir  optional; defaults to $TREW_DATA_ROOT/preprocessed, or
#                ../../data/preprocessed relative to this script
#
# --------------------------------------------------------------------------
# NOTE ON A CORRECTED BUG
#
# An earlier version of this script computed spike regressors into a local
# data frame but then selected `motion_outlier` columns from fMRIPrep's own
# confounds table, which contains differently-defined outlier columns
# (fMRIPrep flags FD > 0.6 OR std_dvars > 1.5). The written confound files
# therefore used fMRIPrep's outliers rather than the intended FD >= 0.6
# spikes, while the spike count printed to stdout was computed from the
# correct local data frame -- so the discrepancy was not visible in the logs.
#
# The selection now reads from the same data frame the spikes are written
# into, and the count is reported from that same frame.
# --------------------------------------------------------------------------

args <- commandArgs(trailingOnly = TRUE)

if (length(args) < 2) {
  stop("Usage: extract_motion_confounds.R <subject> <run> [preproc_dir]",
       call. = FALSE)
}

subject <- args[1]
run     <- args[2]

# Resolve the preprocessed directory: explicit argument, then environment,
# then a path relative to this script.
if (length(args) >= 3) {
  preproc_dir <- args[3]
} else if (nzchar(Sys.getenv("TREW_DATA_ROOT"))) {
  preproc_dir <- file.path(Sys.getenv("TREW_DATA_ROOT"), "preprocessed")
} else {
  this_file <- sub("^--file=", "",
                   grep("^--file=", commandArgs(FALSE), value = TRUE)[1])
  script_dir <- if (is.na(this_file)) "." else dirname(this_file)
  preproc_dir <- normalizePath(
    file.path(script_dir, "..", "..", "data", "preprocessed"),
    mustWork = FALSE
  )
}

# --- Parameters -------------------------------------------------------------
FD_THRESHOLD <- 0.6

# fMRIPrep's own outlier definition also uses DVARS. We censor on FD alone,
# matching the preregistration. Set to TRUE to add a DVARS criterion.
USE_DVARS      <- FALSE
DVARS_THRESHOLD <- 3

# --- Load -------------------------------------------------------------------
func_dir <- file.path(preproc_dir, paste0("sub-", subject), "ses-01", "func")
infile <- file.path(
  func_dir,
  sprintf("sub-%s_ses-01_task-PDT_run-%02d_desc-confounds_timeseries.tsv",
          subject, as.integer(run))
)

if (!file.exists(infile)) {
  stop("Confounds file not found: ", infile, call. = FALSE)
}

d <- read.table(infile, sep = "\t", header = TRUE)

# --- Identify spike volumes -------------------------------------------------
fd    <- suppressWarnings(as.numeric(as.character(d$framewise_displacement)))
dvars <- suppressWarnings(as.numeric(as.character(d$std_dvars)))

# fMRIPrep leaves the first volume's FD and DVARS as n/a; treat as 0 rather
# than NA so it is never flagged and never propagates NA into the design.
fd[is.na(fd)]       <- 0
dvars[is.na(dvars)] <- 0

is_spike <- fd >= FD_THRESHOLD
if (USE_DVARS) {
  is_spike <- is_spike | (dvars >= DVARS_THRESHOLD)
}
spike_idx <- which(is_spike)

# --- Build the spike regressor matrix ---------------------------------------
# One column per spike volume, 1 at that volume and 0 elsewhere.
n_vols <- nrow(d)
if (length(spike_idx) > 0) {
  spikes <- matrix(0, nrow = n_vols, ncol = length(spike_idx))
  for (j in seq_along(spike_idx)) {
    spikes[spike_idx[j], j] <- 1
  }
  colnames(spikes) <- paste0("spike", seq_along(spike_idx))
  spikes <- as.data.frame(spikes)
} else {
  spikes <- NULL
}

# --- Assemble the 24 motion parameters --------------------------------------
motion_cols <- c(
  grep("^trans", names(d), value = TRUE),
  grep("^rot",   names(d), value = TRUE)
)
# Exclude anything fMRIPrep names with a motion_outlier prefix; spikes here
# are computed locally above.
motion_cols <- motion_cols[!grepl("motion_outlier", motion_cols)]

mot_vars <- d[, motion_cols, drop = FALSE]
for (cc in names(mot_vars)) {
  mot_vars[[cc]] <- suppressWarnings(as.numeric(as.character(mot_vars[[cc]])))
  mot_vars[[cc]][is.na(mot_vars[[cc]])] <- 0
}

# Spikes are appended to the locally computed matrix -- NOT selected from `d`.
out <- if (is.null(spikes)) mot_vars else cbind(mot_vars, spikes)

# --- Write ------------------------------------------------------------------
# FEAT expects a whitespace-delimited matrix with no header and no row names.
outfile <- file.path(
  func_dir,
  sprintf("sub-%s_ses-01_motion_confound_run-%02d.txt",
          subject, as.integer(run))
)
write.table(out, outfile, sep = " ",
            row.names = FALSE, col.names = FALSE, quote = FALSE)

# --- Report -----------------------------------------------------------------
# Counted from the same object that was written.
n_spikes <- if (is.null(spikes)) 0 else ncol(spikes)
cat(sprintf("sub-%s run %s: %d volumes, %d motion parameters, %d spikes (%.1f%%)\n",
            subject, run, n_vols, ncol(mot_vars), n_spikes,
            100 * n_spikes / n_vols))
