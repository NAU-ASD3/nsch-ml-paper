# Generate the combined harmonized NSCH data set for 2016-2025 and write it to
# export/ as gzipped CSV, for collaborators who consume the harmonized data
# without running the pipeline themselves.
#
# Also writes PROVENANCE.txt alongside it. A CSV that has been emailed around
# carries no record of which package build produced it, so the checksum,
# version, and session are written at the same time and travel with the file.

library(data.table)

years <- 2016:2025
stata.dir <- "NSCH_data/00_original_Stata"
out.dir <- "export"
dir.create(out.dir, showWarnings = FALSE)

harmonized.dt <- nsch::get_clean_data(years = years, data.path = stata.dir)

print(dim(harmonized.dt))
print(harmonized.dt[, .N, by = year][order(year)])

# Harmonization drops columns, never respondents. Count each year's rows in the
# raw .dta file it came from, so a silent join or filter regression fails here
# rather than inside a file already sent to a collaborator. The counts come
# from the Stata files themselves, so a year added later needs no separate
# table of sizes. Compare with == rather than identical(): the two counts can
# differ in type, and a guard that fails on a passing check is a guard that
# gets relaxed instead of fixed.
raw.rows <- rbindlist(lapply(years, function(y) {
  dta <- list.files(
    stata.dir, pattern = sprintf("^nsch_%de?_topical\\.dta$", y),
    full.names = TRUE)
  stopifnot(length(dta) == 1L)
  data.table(year = y, raw = nrow(haven::read_dta(dta, col_select = "hhid")))
}))
check.dt <- merge(
  raw.rows, harmonized.dt[, .(got = .N), by = year], by = "year", all = TRUE)
print(check.dt)
stopifnot(
  nrow(check.dt) == length(years),
  check.dt[, all(raw == got, na.rm = FALSE)])

# A column with no values in any year is a pipeline leftover, not data (the
# empty k2q35a_1_years_label column was one, until nsch 2026.11.9).
empty.cols <- names(which(vapply(
  harmonized.dt, function(x) all(is.na(x)), logical(1))))
if (length(empty.cols)) stop("columns with no values: ", toString(empty.cols))

stamp <- format(Sys.Date(), "%Y-%m-%d")
csv.gz <- file.path(out.dir, sprintf(
  "nsch-harmonized-%d-%d_%s.csv.gz", min(years), max(years), stamp))

fwrite(harmonized.dt, csv.gz, compress = "gzip", na = "")

pkg.desc <- packageDescription("nsch")
writeLines(c(
  sprintf("generated:   %s", Sys.time()),
  sprintf("nsch version: %s", as.character(packageVersion("nsch"))),
  sprintf("remote sha:  %s",
          if (is.null(pkg.desc$RemoteSha)) "local install" else pkg.desc$RemoteSha),
  sprintf("years: %d to %d", min(years), max(years)),
  sprintf("rows: %d   cols: %d", nrow(harmonized.dt), ncol(harmonized.dt)),
  sprintf("md5: %s", tools::md5sum(csv.gz)),
  "",
  capture.output(sessionInfo())
), file.path(out.dir, "PROVENANCE.txt"))

cat(sprintf("wrote %s (%.1f MB)\n", csv.gz, file.size(csv.gz) / 1e6))
