# 07_changes_gini.R
# H3: More unequal democracies will be LESS likely to reduce CO2 emissions.
#
# IV: gini_net (SWIID disposable-income Gini; higher = more unequal).
# DVs: log_co2_total, delta_co2, pct_change_co2
# Sample: democracies (democracy_bmr == 1).
# Spec: OLS with controls, SEs clustered by country.

source(here::here("R", "00_setup.R"))
source(here::here("R", "analysis", "helpers.R"))
suppressPackageStartupMessages({
  library(dplyr); library(fixest); library(ggplot2)
})

p <- readRDS(file.path(DIR_FINAL, "panel_analysis.rds"))

p_dem <- p |> dplyr::filter(democracy_bmr == 1)
message(sprintf("Democracy sample: %d rows × %d countries.",
                nrow(p_dem), dplyr::n_distinct(p_dem$iso3c)))

results <- run_three_dvs("gini_net", p_dem)

plot_three_dvs(
  results,
  title    = "H3: Effect of income inequality (Gini net) on CO2 emissions (democracies only)",
  subtitle = "OLS with controls; SEs clustered by country. Coef = 1-point increase in gini_net.",
  out_path = file.path(DIR_DOCS, "07_changes_gini.png")
)

saveRDS(results, file.path(DIR_INTER, "results_07_changes_gini.rds"))
