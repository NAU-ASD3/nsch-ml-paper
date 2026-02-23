library(data.table)
remotes::install_github("NAU-ASD3/nsch@get_years_csv")
if(FALSE){
  unlink("NSCH_data", recursive=TRUE)
}
(size_dt <- get_years_csv("NSCH_data", verbose=TRUE))
dcast(size_dt, year ~ data_type, value.var=c("rows", "cols"))

