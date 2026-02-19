get_years_csv <- function(data_dir, verbose=FALSE){
  original_Stata <- file.path(data_dir, "00_original_Stata")
  dir.create(original_Stata, showWarnings = FALSE, recursive = TRUE)
  csv_dir <- file.path(data_dir, "01_original_csv")
  index_dt <- nsch::get_nsch_index(file.path(original_Stata, "datasets.html"))
  size_dt_list <- list()
  for(year_i in 1:nrow(index_dt)){
    index_row <- index_dt[year_i]
    nsch::get_year(index_row$url, original_Stata)
    year_dt <- nsch::Stata2csv_year(
      index_row$year, original_Stata, csv_dir,
      verbose=TRUE)
    size_dt_list[[year_i]] <- data.table(
      index_row, year_dt)
  }
  size_dt <- rbindlist(size_dt_list)
  sizes.csv <- file.path(data_dir, "01_original_sizes.csv")
  data.table::fwrite(size_dt, sizes.csv)
  size_dt
}

library(data.table)
remotes::install_github("NAU-ASD3/nsch@Stata2csv_year")
if(FALSE){
  unlink("NSCH_data", recursive=TRUE)
}
(size_dt <- get_years_csv("NSCH_data", verbose=TRUE))
dcast(size_dt, year ~ data_type, value.var=c("rows", "cols"))

