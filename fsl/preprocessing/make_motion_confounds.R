#!/usr/bin/env Rscript
# Create motion confound files from fMRIPrep output for use as FEAT confound EVs.
#
# Usage:
#   Rscript make_motion_confounds.R <subject> <run>
#   Rscript make_motion_confounds.R 303 1
#
# Writes:
#   sub-<subject>_ses-01_motion_confound_run-0<run>.txt
#   into the subject's fMRIPrep func directory.
#
# Output format: whitespace-separated numeric matrix, one row per volume,
# no header, no row names, no NA values. This is what FEAT expects from a
# confound EV file.
#
# Columns: 24 motion parameters (6 rigid-body + derivatives + squares),
# then one binary spike regressor per censored volume.
#
# ---------------------------------------------------------------------------
# CHANGES FROM THE PREVIOUS VERSION
#
# 1. The spike regressors are now taken from `censors`, where the loop builds
#    them. The previous version grepped "motion_outlier" out of `d`, which is
#    fMRIPrep's own outlier columns (motion_outlier00, motion_outlier01, ...)
#    created with fMRIPrep's thresholds, not ours. The regressors written to
#    file were therefore never the ones this script computed, and the count
#    printed at the end (from `censors`) did not match the file contents.
#
# 2. "n/a" entries are converted to 0. fMRIPrep writes "n/a" in the first row
#    of every derivative and squared-derivative column; left as-is these are
#    read as character strings and written to the file as text.
#
# 3. The header row is no longer written. write.table defaults to
#    col.names=TRUE, which put a line of quoted column names at the top of a
#    file FEAT reads as a numeric matrix.
#
# 4. Thresholds are set in one place at the top.
# ---------------------------------------------------------------------------

# ======================= settings ==========================================
FD_THRESHOLD   <- 0.6     # framewise displacement, mm
USE_DVARS      <- FALSE   # set TRUE to also censor on std_dvars
DVARS_THRESHOLD <- 3      # only used if USE_DVARS is TRUE
SESSION        <- 'ses-01'
TASK           <- 'PDT'
DATA_ROOT      <- '${TREW_DATA_ROOT}/preprocessed/'
# ===========================================================================

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2) {
  stop("Usage: Rscript make_motion_confounds.R <subject> <run>", call. = FALSE)
}
subject <- args[1]
run     <- args[2]

func_dir <- file.path(DATA_ROOT, paste0('sub-', subject), SESSION, 'func')
if (!dir.exists(func_dir)) {
  stop(paste("No such directory:", func_dir), call. = FALSE)
}
setwd(func_dir)

base_run      <- paste0('sub-', subject, '_', SESSION, '_task-', TASK,
                        '_run-0', run)
confound_file <- paste0(base_run, '_desc-confounds_timeseries.tsv')
if (!file.exists(confound_file)) {
  stop(paste("No such file:", file.path(func_dir, confound_file)),
       call. = FALSE)
}

d <- read.table(confound_file, sep = "\t", header = TRUE,
                na.strings = c("n/a", "NA", ""), stringsAsFactors = FALSE)

# ---- spike detection -------------------------------------------------------
fd <- suppressWarnings(as.numeric(as.character(d$framewise_displacement)))
if (USE_DVARS) {
  dv <- suppressWarnings(as.numeric(as.character(d$std_dvars)))
  is_spike <- (!is.na(fd) & fd >= FD_THRESHOLD) |
              (!is.na(dv) & dv >= DVARS_THRESHOLD)
} else {
  is_spike <- !is.na(fd) & fd >= FD_THRESHOLD
}
spike_idx <- which(is_spike)
n_spikes  <- length(spike_idx)

# One regressor per censored volume: a single 1 at that volume, 0 elsewhere.
if (n_spikes > 0) {
  spike_mat <- matrix(0, nrow = nrow(d), ncol = n_spikes)
  for (k in seq_len(n_spikes)) {
    spike_mat[spike_idx[k], k] <- 1
  }
  colnames(spike_mat) <- paste0('spike', sprintf('%03d', seq_len(n_spikes)))
} else {
  spike_mat <- NULL
}

# ---- motion parameters -----------------------------------------------------
motion_cols <- c(grep('^trans', names(d), value = TRUE),
                 grep('^rot',   names(d), value = TRUE))
if (length(motion_cols) == 0) {
  stop("No trans*/rot* columns found in the confounds file.", call. = FALSE)
}
motion <- d[, motion_cols, drop = FALSE]

# Coerce to numeric and zero out NAs (fMRIPrep's "n/a" in the first row of
# derivative and squared-derivative columns).
motion[] <- lapply(motion, function(x)
  suppressWarnings(as.numeric(as.character(x))))
n_na <- sum(is.na(motion))
motion[is.na(motion)] <- 0

# ---- assemble and write ----------------------------------------------------
mot_vars <- if (is.null(spike_mat)) motion else cbind(motion, spike_mat)

outfile <- paste0('sub-', subject, '_', SESSION,
                  '_motion_confound_run-0', run, '.txt')
write.table(mot_vars, outfile,
            sep = " ", row.names = FALSE, col.names = FALSE,
            quote = FALSE)

# ---- report ----------------------------------------------------------------
# Printed counts now describe what is actually in the file.
cat(subject, 'run', run,
    '| spikes:', n_spikes,
    '| motion cols:', ncol(motion),
    '| total cols:', ncol(mot_vars),
    '| rows:', nrow(mot_vars),
    '| NAs zeroed:', n_na, '\n')
