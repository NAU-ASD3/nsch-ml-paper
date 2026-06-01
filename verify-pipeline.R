# End-to-end verification of the nsch package on real 2016-2024 .dta data.
# Loads the sibling nsch package source directly (via NSCH_SRC, default
# ../nsch) so the working tree is exercised without an install step.

library(data.table)
library(ggplot2)

nsch.src <- Sys.getenv("NSCH_SRC", unset = "../nsch")
out.dir <- "verify-out"
dir.create(out.dir, showWarnings = FALSE)
rds.path <- file.path(out.dir, "combined.rds")

devtools::load_all(nsch.src)
config <- nsch::read_config(
  system.file("extdata", "variable-config.json", package = "nsch")
)
years <- 2016:2024

if (file.exists(rds.path)) {
  message("[", Sys.time(), "] using cached ", rds.path, " (delete to re-run)")
  combined <- readRDS(rds.path)
} else {
  message("[", Sys.time(), "] get_clean_data() over ", paste(range(years), collapse = "–"))
  combined <- nsch::get_clean_data(years = years)
  saveRDS(combined, rds.path)
}
message("[", Sys.time(), "] combined: ", nrow(combined), " rows × ", ncol(combined), " cols")

# --- artifact 1: row counts (raw vs harmonized) -------------------------
sizes <- fread("NSCH_data/01_cleanTypes_sizes.csv")
raw.rows  <- sizes[, .(year, raw_n = rows)]
harm.rows <- combined[, .(harmonized_n = .N), by = year][order(year)]
row.counts <- raw.rows[harm.rows, on = "year"]
row.counts[, match := raw_n == harmonized_n]
fwrite(row.counts, file.path(out.dir, "row-counts.csv"))
print(row.counts)

# --- artifact 2: post-norm heatmaps for the 5 rename/merge columns ------
rename.merge.vars <- c("family", "diabetes", "eyedoctor", "k4q02_r", "sleep")
for (v in intersect(rename.merge.vars, names(combined))) {
  dt <- combined[, .(n = .N), by = c("year", v)]
  dt[, prop := n / sum(n), by = year]
  setnames(dt, v, "level")
  dt[, level := factor(level, levels = rev(sort(unique(as.character(level)))))]
  p <- ggplot(dt, aes(factor(year), level, fill = prop)) +
    geom_tile() +
    geom_text(aes(label = scales::percent(prop, 0.1)), size = 3) +
    scale_fill_viridis_c(labels = scales::percent) +
    labs(x = "Year", y = v,
         title = paste0("Post-normalization: ", v),
         subtitle = "end-to-end harmonization, 2016–2024") +
    theme_minimal()
  ggsave(file.path(out.dir, paste0("verify-heatmap-", v, ".png")),
         p, width = 11, height = 5, dpi = 150)
  message("  wrote verify-heatmap-", v, ".png")
}

# --- artifact 3: schema check -------------------------------------------
desired <- config$desired_variables
schema <- data.table(
  variable = desired,
  present  = desired %in% names(combined)
)
schema[present == TRUE, class := vapply(
  variable, function(v) class(combined[[v]])[1], character(1)
)]
fwrite(schema, file.path(out.dir, "schema.csv"))
message("Schema summary:")
print(schema[, .N, by = .(present, class)][order(-N)])
missing.vars <- schema[present == FALSE, variable]
if (length(missing.vars)) {
  message("Missing from combined: ", paste(missing.vars, collapse = ", "))
}

# --- artifact 4: NA rates for the 13 998-remap variables ----------------
remap.vars <- c("k4q20r", "dentistvisit", "bestforchild", "discussopt",
                "k5q11", "k5q20_r", "k5q21", "k5q31_r",
                "k5q40", "k5q41", "k5q42", "k5q43", "k5q44")
na.rates <- combined[, lapply(.SD, function(x) round(mean(is.na(x)), 4)),
                     by = year,
                     .SDcols = intersect(remap.vars, names(combined))]
fwrite(na.rates, file.path(out.dir, "na-rates-998remap.csv"))
print(na.rates)

message("[", Sys.time(), "] done — artifacts in ", normalizePath(out.dir))
