library(data.table)
library(RJSONIO)
library(readxl)

## --- Paths ---
## Crosswalk location is overridable via the NSCH_CROSSWALK env var; the
## default is the copy tracked in this repo under reference/.
config.path <- system.file("extdata", "variable-config.json", package = "nsch")
crosswalk.path <- Sys.getenv(
  "NSCH_CROSSWALK",
  unset = "reference/nsch_crosswalk_2016-present_cahmi_7-23-25.xlsx")
data.path <- "NSCH_data/00_original_Stata"

all.years <- c("2016", "2017", "2018", "2019", "2020",
               "2021", "2022", "2023", "2024")

## --- Load crosswalk ---
## The crosswalk sheet has no header row; question/response columns for
## each year sit at fixed offsets (q at 5,7,9,...; r at 6,8,10,...).
raw <- as.data.table(read_excel(crosswalk.path, sheet = 1, col_names = FALSE))
year.q.col <- stats::setNames(seq(5L, 21L, by = 2L), all.years)
year.r.col <- stats::setNames(seq(6L, 22L, by = 2L), all.years)

## Accumulate rows in a list and bind once, rather than rbind-in-loop.
crosswalk.rows <- vector("list", nrow(raw))
for (i in 6:nrow(raw)) {
  v <- raw[[1]][i]
  if (!is.na(v) && nchar(trimws(v)) > 0) {
    row <- list(variable = trimws(v))
    for (y in all.years) {
      q <- raw[[year.q.col[[y]]]][i]
      r <- raw[[year.r.col[[y]]]][i]
      row[[paste0(y, "_q")]] <- if (is.na(q)) NA_character_ else trimws(q)
      row[[paste0(y, "_r")]] <- if (is.na(r)) NA_character_ else trimws(r)
    }
    crosswalk.rows[[i]] <- as.data.table(row)
  }
}
crosswalk <- rbindlist(crosswalk.rows, fill = TRUE)
crosswalk[, var.upper := toupper(variable)]
cat("Crosswalk: ", nrow(crosswalk), " variables\n")

## present.years(): which years a crosswalk row has a question entry for.
present.years <- function(cw.row) {
  q.vals <- unlist(cw.row[1, paste0(all.years, "_q"), with = FALSE])
  all.years[!is.na(q.vals)]
}

## --- Load config ---
config <- nsch::read_config(config.path)
transforms <- config$transformations$transform
renames <- config$transformations$rename_columns
merges <- config$transformations$merge_columns
desired <- config$desired_variables

## --- Audit each transform ---
cat("\n========================================\n")
cat("TRANSFORMS AUDIT\n")
cat("========================================\n")
for (var.name in names(transforms)) {
  entry <- transforms[[var.name]]
  config.years <- entry$years
  cw <- crosswalk[var.upper == toupper(var.name)]
  if (nrow(cw) == 0) {
    cat(sprintf("\n%-20s  [NOT IN CROSSWALK — derived variable?]\n", var.name))
  } else {
    present <- present.years(cw)
    missing.from.config <- setdiff(present, config.years)
    unexpected.in.config <- setdiff(config.years, present)
    if (length(missing.from.config) == 0 && length(unexpected.in.config) == 0) {
      cat(sprintf("\n%-20s  [OK]  years=%s\n",
                  var.name, paste(config.years, collapse = ",")))
    } else {
      cat(sprintf("\n%-20s  [MISMATCH]\n", var.name))
      cat(sprintf("  config years: %s\n", paste(config.years, collapse = ", ")))
      cat(sprintf("  present in crosswalk: %s\n", paste(present, collapse = ", ")))
      if (length(missing.from.config) > 0) {
        cat(sprintf("  ** missing from config: %s **\n",
                    paste(missing.from.config, collapse = ", ")))
      }
      if (length(unexpected.in.config) > 0) {
        cat(sprintf("  unexpected in config: %s\n",
                    paste(unexpected.in.config, collapse = ", ")))
      }
    }
  }
}

## --- Audit each rename ---
cat("\n\n========================================\n")
cat("RENAMES AUDIT\n")
cat("========================================\n")
for (old.name in names(renames)) {
  entry <- renames[[old.name]]
  new.name <- entry$new_name
  config.years <- entry$years
  cw.old <- crosswalk[var.upper == toupper(old.name)]
  cw.new <- crosswalk[var.upper == toupper(new.name)]
  cat(sprintf("\n%s -> %s\n", old.name, new.name))
  cat(sprintf("  config years: %s\n", paste(config.years, collapse = ", ")))
  if (nrow(cw.old) > 0) {
    old.present <- present.years(cw.old)
    cat(sprintf("  %s present in: %s\n", old.name, paste(old.present, collapse = ", ")))
    miss <- setdiff(old.present, config.years)
    if (length(miss) > 0) {
      cat(sprintf("  ** %s exists in years %s not in config **\n",
                  old.name, paste(miss, collapse = ", ")))
    }
  } else {
    cat(sprintf("  %s [not in crosswalk]\n", old.name))
  }
  if (nrow(cw.new) > 0) {
    new.present <- present.years(cw.new)
    cat(sprintf("  %s present in: %s\n", new.name, paste(new.present, collapse = ", ")))
  }
}

## --- Audit each merge ---
cat("\n\n========================================\n")
cat("MERGES AUDIT\n")
cat("========================================\n")
for (out.name in names(merges)) {
  entry <- merges[[out.name]]
  config.years <- entry$years
  pref <- entry$column_preferred
  fall <- entry$column_fallback
  cat(sprintf("\n%s <- %s | %s\n", out.name, pref, fall))
  cat(sprintf("  config years: %s\n", paste(config.years, collapse = ", ")))
  for (col in c(pref, fall)) {
    cw <- crosswalk[var.upper == toupper(col)]
    if (nrow(cw) > 0) {
      cat(sprintf("  %s present in: %s\n", col, paste(present.years(cw), collapse = ", ")))
    } else {
      cat(sprintf("  %s [not in crosswalk]\n", col))
    }
  }
}

## --- Audit desired_variables coverage ---
cat("\n\n========================================\n")
cat("DESIRED VARIABLES COVERAGE\n")
cat("========================================\n")
rename.targets <- vapply(renames, function(e) e$new_name, character(1))
merge.targets <- names(merges)
for (var.name in desired) {
  if (var.name != "year") {  # year is always present
    cw <- crosswalk[var.upper == toupper(var.name)]
    via.rename <- var.name %in% rename.targets
    via.merge <- var.name %in% merge.targets
    if (nrow(cw) > 0) {
      present <- present.years(cw)
      if (!"2024" %in% present && !via.rename && !via.merge) {
        cat(sprintf("** %-20s — missing from 2024, no rename/merge fallback **\n", var.name))
      }
    } else if (!via.rename && !via.merge) {
      cat(sprintf("   %-20s — not in crosswalk (likely derived: state, weight, etc.)\n", var.name))
    }
  }
}

cat("\n\nAudit complete.\n")
