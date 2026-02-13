s2024 <- fread("NSCH_data/01_original_csv/2024/surveys.csv")
haven::write_dta(s2024[1:2], "nsch_2024e_topical.dta")
file.copy("NSCH_data/00_original_Stata/nsch_2024_topical.do", "nsch_2024_topical.do")
small_zip <- "~/R/nsch/inst/extdata/nsch_2024_topical_Stata.zip"
unlink(small_zip)
zip(small_zip, c("nsch_2024_topical.do", "nsch_2024e_topical.dta"))
NSCH_small <- "NSCH_data_small"
dir.create(NSCH_small, showWarnings = FALSE, recursive = TRUE)
unzip(small_zip, exdir=NSCH_small)


