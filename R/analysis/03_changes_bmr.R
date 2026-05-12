# 03_changes_bmr.R
# H1: Autocracies will be less likely to reduce CO2 emissions than democracies.
#
# IV: democracy_bmr (0/1)
# DVs: log_co2_total, delta_co2, pct_change_co2
# Spec: OLS with controls, SEs clustered by country. Full sample.

source(here::here("R", "00_setup.R"))
source(here::here("R", "analysis", "helpers.R"))
suppressPackageStartupMessages({
  library(dplyr); library(fixest); library(ggplot2)
})

p <- readRDS(file.path(DIR_FINAL, "panel_analysis.rds"))

results <- run_three_dvs("democracy_bmr", p)

plot_three_dvs(
  results,
  title    = "H1: Effect of BMR democracy on CO2 emissions",
  subtitle = "OLS with controls; SEs clustered by country. Full sample.",
  out_path = file.path(DIR_DOCS, "03_changes_bmr.png")
)

saveRDS(results, file.path(DIR_INTER, "results_03_changes_bmr.rds"))
