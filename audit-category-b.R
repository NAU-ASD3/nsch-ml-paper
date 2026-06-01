library(data.table)

## For each Category B transform, compare:
## 1. The transform's source values + intended new_labels (from config)
## 2. The .do define entries for each year (from cleanTypes_csv)
## This identifies which years have the "early" encoding that the transform
## targets vs the "late" encoding the transform doesn't apply to.

config.path <- system.file("extdata", "variable-config.json", package = "nsch")
config <- nsch::read_config(config.path)

cat.b <- c("k2q01_d", "hospitaler", "arrangehc", "athomehc",
           "a1_relation", "a2_relation", "hcability", "k8q30")

all.years <- 2016:2024

## Load define.csv for each year (skip years with no file on disk).
define.by.year <- list()
for (yr in all.years) {
  path <- sprintf("NSCH_data/01_cleanTypes_csv/%d/define.csv", yr)
  if (file.exists(path)) {
    define.by.year[[as.character(yr)]] <- fread(path)
  }
}

for (var.name in cat.b) {
  cat("\n========================================\n")
  cat(var.name, "\n")
  cat("========================================\n")
  entry <- config$transformations$transform[[var.name]]
  cat("Config years:    ", paste(entry$years, collapse = ", "), "\n")
  cat("Config values:   ", paste(entry$value, collapse = ", "), "\n")
  cat("Config new_value:", paste(entry$new_value, collapse = ", "), "\n")
  cat("Config new_label:", paste(entry$new_label, collapse = " | "), "\n\n")

  for (yr.char in names(define.by.year)) {
    d <- define.by.year[[yr.char]]
    rows <- d[variable == var.name]
    if (nrow(rows) == 0) {
      cat(sprintf("  %s: [variable not in define]\n", yr.char))
    } else {
      real.rows <- rows[!grepl("^\\.", value)]
      cat(sprintf("  %s:\n", yr.char))
      for (i in seq_len(nrow(real.rows))) {
        cat(sprintf("    %s = %s\n", real.rows$value[i], real.rows$desc[i]))
      }
    }
  }
}
