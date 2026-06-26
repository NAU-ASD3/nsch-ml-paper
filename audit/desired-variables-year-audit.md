# Audit: levels present in some years but not others

This documents the result of auditing every variable in `desired_variables` for
factor levels that show up in some survey years and not others, requested in
NAU-ASD3/nsch#46. It also records what the 2016-2024 CAHMI crosswalk says about
each flagged variable, since the harmonized data alone can't tell you whether a
missing level is a real survey change or a harmonization artifact.

## How this was produced

Ran `check_label_consistency()` from the `nsch` package over the full
`get_clean_data(years = 2016:2024)` output. It reports, per factor variable, the
set of non-NA levels observed in each year and flags any variable whose level
set isn't identical across all years. Out of 156 factor variables, 9 came back
inconsistent. For each of the 9 I pulled the per-year frequency table and checked
the variable against the crosswalk to see what the survey instrument actually did.

The 9 sort into four groups. Only two of them point at something that needs
fixing; the rest are either expected (top-codes, continuous variables) or
cosmetic.

## Group A: top-code and binning shifts

These are numeric response boxes in the instrument (age, counts, number of
moves). They have no categorical levels at the source. The "levels" you see in
the harmonized data come from the package top-coding or bucketing the numbers,
and the bucket thresholds changed across years. The level set looks inconsistent,
but the underlying data is comparable once you collapse to the most restrictive
bucket.

- **k11q43r** (number of moves). Top-code drifts: `15 or more` early, `13 or more`
  in 2017, a `13 or 14` / `15 or more` split in 2019-2020, then `10 or more` in
  2023-2024. Decision already made with O. Lindly: collapse every year to
  `10 or more`. Tracked in NAU-ASD3/nsch-ml-paper#4.
- **a1_age** (adult 1 age). `75 or older` through 2022, `70 or older` in 2023-2024.
  Collapse to `70 or older` for comparability.
- **a2_age** (adult 2 / caregiver age). Same shift as a1_age. Collapse to
  `70 or older`.
- **hhcount** (people in household). `12 or more` in 2016, `10 or more` from 2017
  on. Collapse to `10 or more`.

All four are the same pattern as the k11q43r decision: lose a little resolution at
the top, gain cross-year comparability. None of them need a package change; the
collapse belongs in the analysis pipeline alongside the k11q43r recode.

## Group B: scheme change in 2016

- **k2q35a_1_years** (age when first told child had a condition). Numeric
  age-in-years box in the instrument every year. In 2016 the harmonized data
  carries the raw integers (1 through 14). From 2017 on it's coarse buckets
  (`0 or 1`, `13 or 14`, `15, 16 or 17`). Same variable, but 2016 needs binning to
  the later scheme before it's comparable. Bigger than a top-code collapse since
  it's a full re-bin, but the same idea: harmonize 2016 to match the buckets used
  in later years, or treat the variable as continuous and re-derive buckets
  consistently across all years.

## Group C: cosmetic label difference

- **stratum** (sampling stratum). Two categories in every year. 2016 labels them
  `Stratum 1` / `Stratum 2`; 2017 on uses `1` / `2`. The crosswalk doesn't list
  stratum at all, which fits: it's a sampling-design field, not a survey item. A
  one-line label override unifies the 2016 labels with the later ones. Low stakes,
  but worth doing so the variable reads consistently.

## Group D: the two that need attention

### k2q01_d (condition of child's teeth) is a 2016 labeling bug

The crosswalk shows the full `Excellent / Very Good / Good / Fair / Poor` scale is
present in every year from 2016 on, with `This child does not have any teeth`
added as an extra option starting in 2018. So the rating exists in 2016.

The harmonized data disagrees. In 2016, k2q01_d shows only
`This child does not have any teeth [T1 only]` (1,164 rows) and 49,048 NA. None of
the Excellent-through-Poor levels appear. From 2017 on the full scale shows up
normally. That `[T1 only]` tag on the one surviving level is the tell: the 2016
values exist but aren't getting their labels applied, so everything except that
one tagged level falls through to NA.

This isn't a meaningful absence. It's a defect in how 2016 k2q01_d gets labeled,
and it's dropping the entire 2016 teeth-condition rating from the harmonized
output. Recommend opening a package issue to fix the 2016 labeling for this
variable.

### k5q11 (difficulty getting referrals) changed its whole scale in 2018

The earlier k5q11 note (#35) framed this as one missing level. The crosswalk shows
it's more than that. In 2016-2017 the question asked "how much of a problem was it
to get referrals?" with `Not a problem / Small problem / Big problem`. From 2018
on it asked "how difficult was it to get referrals?" with `Not difficult /
Somewhat difficult / Very difficult / It was not possible to get a referral`.

So both the wording and the response scale changed: a 3-category problem scale
became a 4-category difficulty scale. The harmonized data reflects this, with
`It was not possible to get a referral` (the genuinely new option) appearing only
from 2018 and running 29 to 70 respondents a year.

The level absence is real and structural, but it sits inside a larger scale break
that affects how the variable can be used across the 2016-2017 vs 2018-2024
boundary. Keep emitting native per-year values in the package; the decision about
how to handle the scale change for modeling is an analysis call. Recommend a
separate analysis-side issue to decide how k5q11 is treated across that boundary,
including the level-to-NA vs level-separate comparison raised in #46.

## False positive

- **fpl_i1** (federal poverty level, imputed). The crosswalk lists this as an
  imputed continuous percentage derived from the income questions, with no
  categorical response options. In 2016 the harmonized data carries the full
  integer range (50 to 400) as factor levels; from 2017 on only the endpoints
  (`50 or less`, `400 or more`) are labeled. That's a representation difference in
  a continuous variable, not label drift. No action.

## Summary

| Variable | Class | Recommendation |
|---|---|---|
| k11q43r | top-code | collapse to `10 or more` (decided, nsch-ml-paper#4) |
| a1_age | top-code | collapse to `70 or older` |
| a2_age | top-code | collapse to `70 or older` |
| hhcount | top-code | collapse to `10 or more` |
| k2q35a_1_years | 2016 scheme change | re-bin 2016 to match later buckets, or re-derive consistently |
| stratum | cosmetic | label override `Stratum 1` -> `1` |
| k2q01_d | 2016 labeling bug | fix 2016 labeling (package issue) |
| k5q11 | scale change 2018 | keep native; analysis-side decision on the scale break |
| fpl_i1 | continuous | no action |

Two follow-ups come out of this: a package issue for the k2q01_d 2016 labeling
defect, and an analysis-side issue for the k5q11 scale change. The four top-code
collapses and the k2q35a_1_years re-bin fold into the same analysis recode work as
the k11q43r decision.
