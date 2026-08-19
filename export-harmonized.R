# Generate the combined harmonized NSCH data set for 2016-2024 and write it to
# export/ as gzipped CSV, for collaborators who consume the harmonized data
# without running the pipeline themselves.
#
# Also writes PROVENANCE.txt alongside it. A CSV that has been emailed around
# carries no record of which package build produced it, so the checksum,
# version, and session are written at the same time and travel with the file.

library(data.table)

stata.dir <- "NSCH_data/00_original_Stata"
out.dir <- "export"
dir.create(out.dir, showWarnings = FALSE)

harmonized.dt <- nsch::get_clean_data(years = 2016:2024, data.path = stata.dir)

print(dim(harmonized.dt))
print(harmonized.dt[, .N, by = year][order(year)])

# Harmonization drops columns, never respondents. Check against the counts
# recorded when the raw files were converted, so a silent join or filter
# regression fails here rather than inside a file already sent to a
# collaborator. Compare with == rather than identical(): fread may type `rows`
# as double where .N gives integer, and a guard that fails on a passing check
# is a guard that gets relaxed instead of fixed.
sizes.dt <- fread("NSCH_data/01_cleanTypes_sizes.csv")
raw.rows <- sizes.dt[data_type == "surveys", .(year, raw = rows)]
check.dt <- merge(
  raw.rows, harmonized.dt[, .(got = .N), by = year], by = "year")
stopifnot(
  nrow(check.dt) == 9L,
  check.dt[, all(raw == got)])

stamp <- format(Sys.Date(), "%Y-%m-%d")
csv.gz <- file.path(
  out.dir, sprintf("nsch-harmonized-2016-2024_%s.csv.gz", stamp))

fwrite(harmonized.dt, csv.gz, compress = "gzip", na = "")

pkg.desc <- packageDescription("nsch")
writeLines(c(
  sprintf("generated:   %s", Sys.time()),
  sprintf("nsch version: %s", as.character(packageVersion("nsch"))),
  sprintf("remote sha:  %s",
          if (is.null(pkg.desc$RemoteSha)) "local install" else pkg.desc$RemoteSha),
  sprintf("rows: %d   cols: %d", nrow(harmonized.dt), ncol(harmonized.dt)),
  sprintf("md5: %s", tools::md5sum(csv.gz)),
  "",
  capture.output(sessionInfo())
), file.path(out.dir, "PROVENANCE.txt"))

cat(sprintf("wrote %s (%.1f MB)\n", csv.gz, file.size(csv.gz) / 1e6))
