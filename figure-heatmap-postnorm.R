library(data.table)
library(ggplot2)
library(nsch)

## Generate post-normalization heatmaps for selected variables.
## Counterpart to figure-heatmap-response-prop-over-years.R, which
## shows the *pre-normalization* state per year from the raw .dta files.

config.path <- system.file("extdata", "variable-config.json", package = "nsch")
data.path <- "NSCH_data/00_original_Stata"

cat("Running pipeline...\n")
clean.dt <- nsch::get_clean_data(
  config.path = config.path,
  data.path = data.path
)
cat("Done.", nrow(clean.dt), "rows x", ncol(clean.dt), "cols\n")
cat("Years:", paste(sort(unique(clean.dt[["year"]])), collapse = ", "), "\n\n")

make_heatmap <- function(dt, var.name, title = NULL, out.path = NULL) {
  if (!(var.name %in% names(dt))) {
    stop("Variable '", var.name, "' not in harmonized data")
  }
  
  counts <- dt[, .N, by = .(year, level = as.character(get(var.name)))]
  counts[is.na(level), level := "(NA)"]
  counts[, prop := N / sum(N), by = year]
  
  if (is.factor(dt[[var.name]])) {
    lev <- c(levels(dt[[var.name]]), "(NA)")
  } else {
    lev <- sort(unique(counts$level))
  }
  counts[, level := factor(level, levels = rev(lev))]
  
  p <- ggplot(counts, aes(x = factor(year), y = level, fill = prop)) +
    geom_tile(color = "grey80") +
    geom_text(aes(label = ifelse(prop > 0,
                                 sprintf("%.3f", prop),
                                 "")),
              size = 3) +
    scale_fill_gradient(low = "white", high = "steelblue",
                        limits = c(0, 1), na.value = "grey90") +
    labs(
      title = if (is.null(title)) paste0("Post-normalization: ", var.name) else title,
      x = "Year",
      y = "Harmonized factor level",
      fill = "Proportion"
    ) +
    theme_minimal(base_size = 11) +
    theme(panel.grid = element_blank())
  
  if (!is.null(out.path)) {
    ggsave(out.path, p, width = 12, height = 5, dpi = 120)
    cat("Saved:", out.path, "\n")
  }
  invisible(p)
}

print_distribution <- function(dt, var.name) {
  cat(sprintf("\n=== HARMONIZED %s PROPORTIONS BY YEAR ===\n\n", var.name))
  d <- dt[, .N, by = .(year, level = as.character(get(var.name)))]
  d[is.na(level), level := "(NA)"]
  d[, prop := N / sum(N), by = year]
  wide <- dcast(d, level ~ year, value.var = "prop", fill = 0)
  print(wide)
  
  cat(sprintf("\n=== HARMONIZED %s COUNTS BY YEAR ===\n\n", var.name))
  wide.counts <- dcast(d, level ~ year, value.var = "N", fill = 0L)
  print(wide.counts)
}

## --- 1. k5q11 (998-remap exemplar; the original review request) ---
make_heatmap(clean.dt, "k5q11",
             title = "Post-normalization: k5q11 (need referral / difficulty)",
             out.path = "figure-heatmap-response-prop-over-years-k5q11-postnorm.png")
print_distribution(clean.dt, "k5q11")

## --- 2. family (NEW transform in PR #36, renamed from family_r 2017-2024) ---
make_heatmap(clean.dt, "family",
             title = "Post-normalization: family (single-father/grandparent -> other relation)",
             out.path = "figure-heatmap-response-prop-over-years-family-postnorm.png")
print_distribution(clean.dt, "family")

## --- 3. k4q02_r (rename + 8->7 remap; exercises both rules) ---
make_heatmap(clean.dt, "k4q02_r",
             title = "Post-normalization: k4q02_r (place usually goes for sick care)",
             out.path = "figure-heatmap-response-prop-over-years-k4q02_r-postnorm.png")
print_distribution(clean.dt, "k4q02_r")

## --- 4. k4q20r (998-remap spot-check on a different question type) ---
make_heatmap(clean.dt, "k4q20r",
             title = "Post-normalization: k4q20r (number of well-child visits)",
             out.path = "figure-heatmap-response-prop-over-years-k4q20r-postnorm.png")
print_distribution(clean.dt, "k4q20r")

## --- 5. hospitaler (4->3 category collapse; different transform pattern) ---
make_heatmap(clean.dt, "hospitaler",
             title = "Post-normalization: hospitaler (hospital visits, 2-or-more collapsed)",
             out.path = "figure-heatmap-response-prop-over-years-hospitaler-postnorm.png")
print_distribution(clean.dt, "hospitaler")

cat("\nAll five heatmaps generated.\n")