# Audit label drift across years: for each (variable, value) in the .do
# label-define entries, check whether the description text differs across
# years. Cross-reference each drift case with the config's transform
# overrides to distinguish unhandled drift (will appear in harmonized
# output as multiple factor levels) from handled drift (transform
# overwrites with a canonical label).

library(data.table)
options(datatable.print.nrows = 1000)

nsch.src <- Sys.getenv("NSCH_SRC", unset = "../nsch")
devtools::load_all(nsch.src)

stata.dir <- "NSCH_data/00_original_Stata"
out.dir <- "verify-out"
dir.create(out.dir, showWarnings = FALSE)

config <- nsch::read_config(
  system.file("extdata", "variable-config.json", package = "nsch")
)
desired <- config$desired_variables
transforms <- config$transformations$transform
renames <- config$transformations$rename_columns
years <- 2016:2024

# --- 1. parse every .do file's define block ---------------------------
define.all <- rbindlist(lapply(years, function(y) {
  parsed <- nsch::parse_do(file.path(stata.dir, sprintf("nsch_%d_topical.do", y)))
  dt <- as.data.table(parsed$define)
  dt[, year := y]
  dt
}))

# Drop sentinel rows (.m/.n/.l/.d) — those labels are consistent by design.
sentinel.values <- paste0(".", names(nsch::na_tag_map))
define.all <- define.all[!value %in% sentinel.values]

# Restrict to variables we actually use (desired + pre-rename sources).
source.names <- unique(c(desired, names(renames)))
define.audit <- define.all[variable %in% source.names]

# --- 2. group by (variable, value), surface multi-desc cases ----------
drift <- define.audit[, .(
  n_distinct_desc = uniqueN(desc),
  unique_descs    = paste(sort(unique(desc)), collapse = " || "),
  years_per_desc  = paste(vapply(
    sort(unique(desc)),
    function(d) sprintf("%s: %s", d,
                        paste(sort(year[desc == d]), collapse = ",")),
    character(1)
  ), collapse = "  ||  ")
), by = .(variable, value)]

drift.cases <- drift[n_distinct_desc > 1]
setorder(drift.cases, variable, value)

# --- 3. determine per-year coverage by existing transform overrides ---
# A (variable, value, year) tuple is "covered" if config.transforms[[variable]]
# has that value in its `value` array AND that year in its `years` array.
# A drift case is "fully handled" if every year present in the drift is
# covered. "Partially handled" otherwise. "Unhandled" if no coverage.
classify.coverage <- function(var, val) {
  years.with.desc <- sort(unique(define.audit[
    variable == var & value == val, year
  ]))
  tr <- transforms[[var]]
  if (is.null(tr) || !(as.character(val) %in% tr$value)) {
    return(list(status = "unhandled",
                covered.years = character(0),
                uncovered.years = as.character(years.with.desc),
                override = NA_character_))
  }
  covered <- intersect(as.character(years.with.desc), tr$years)
  uncovered <- setdiff(as.character(years.with.desc), tr$years)
  status <- if (length(uncovered) == 0) "fully_handled" else "partially_handled"
  override.idx <- match(as.character(val), tr$value)
  list(status = status,
       covered.years = covered,
       uncovered.years = uncovered,
       override = tr$new_label[override.idx])
}

cov <- mapply(classify.coverage, drift.cases$variable, drift.cases$value,
              SIMPLIFY = FALSE)
drift.cases[, status          := vapply(cov, `[[`, character(1), "status")]
drift.cases[, override_label  := vapply(cov, `[[`, character(1), "override")]
drift.cases[, uncovered_years := vapply(cov, function(x)
  paste(x$uncovered.years, collapse = ","), character(1))]

# --- 4. report --------------------------------------------------------
cat("=== Label drift audit summary ===\n")
cat("Total drift cases (variable+value with >1 distinct label across years): ",
    nrow(drift.cases), "\n", sep = "")
cat("Fully handled by transform override:    ",
    sum(drift.cases$status == "fully_handled"), "\n", sep = "")
cat("Partially handled (some years covered): ",
    sum(drift.cases$status == "partially_handled"), "\n", sep = "")
cat("Unhandled:                              ",
    sum(drift.cases$status == "unhandled"), "\n\n", sep = "")

cat("=== Unhandled drift cases ===\n")
print(drift.cases[status == "unhandled",
                  .(variable, value, unique_descs)])

cat("\n=== Partially-handled drift cases ===\n")
print(drift.cases[status == "partially_handled",
                  .(variable, value, override_label, uncovered_years,
                    unique_descs)])

fwrite(drift.cases, file.path(out.dir, "label-drift-audit.csv"))
cat("\nFull audit written to ", file.path(out.dir, "label-drift-audit.csv"),
    "\n", sep = "")