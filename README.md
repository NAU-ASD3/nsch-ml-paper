# nsch-ml-paper

Interpretable machine learning analyses of NSCH data.

## 8 Feb 2026

[NSCH_data.R](NSCH_data.R) downloads data from NSCH web site.
After running this script, you should have
- `NSCH_data/00_original_Stata/` original Stata data files)
- `NSCH_data/01_original_csv/` converted to CSV
- `NSCH_data/01_original_sizes.csv` meta data for each file (number of rows and columns).

[figure-heatmap-response-prop-over-years.R](figure-heatmap-response-prop-over-years.R) creates heat maps for checking consistency of response proportions across years, inspired by [my previous analysis of Vince’s data](https://github.com/tdhock/2024-01-ml-for-autism/tree/main?tab=readme-ov-file#10-oct-2024).

![autism](figure-heatmap-response-prop-over-years-autism.png)

The figure above shows that the Autism response proportions are consistent across years.

![family](figure-heatmap-response-prop-over-years-family.png)

The figure above shows that the Family Structure response choices changed in 2017.

![interest curiosity](figure-heatmap-response-prop-over-years-interest_curiosity.png)

The figure above shows that the Family Structure response choices changed in 2018.
After combining the years, we should re-run this analysis to confirm consistency across years, for these variables, and others.
It also computes a table of counts of rows and columns of survey data in each year.

```r
> surveys_meta[, .(year, rows, cols)]
    year  rows  cols
1:  2016 50212   432
2:  2017 21599   436
3:  2018 30530   447
4:  2019 29433   448
5:  2020 42777   447
6:  2021 50892   462
7:  2022 54103   484
8:  2023 55162   456
9:  2024 51375   457
```

## Related work

* https://github.com/tdhock/2024-01-ml-for-autism
* https://github.com/NAU-ASD3/nsch
* https://github.com/vas235/ASD3-machine-learning-prep
