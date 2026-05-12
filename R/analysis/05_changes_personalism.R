# 05_changes_personalism.R
# H2 (cont.): More personalist autocracies will be LESS likely to reduce
#     CO2 emissions than less personalist autocracies.
#
# IV: personalism_score (continuous, Frantz et al. latent_personalism).
#     Defined for autocracies only.
# DVs: log_co2_total, delta_co2, pct_change_co2
# Sample: country-years with non-NA personalism_score (autocracies, ~1946-2010).
# Spec: OLS with controls, SEs clustered by country.

source(here::here("R", "00_setup.R"))
source(here::here("R", "analysis", "helpers.R"))
suppressPackageStartupMessages({
  library(dplyr); library(fixest); library(ggplot2)
})

p <- readRDS(file.path(DIR_FINAL, "panel_analysis.rds"))

p_aut <- p |> dplyr::filter(!is.na(personalism_score))
message(sprintf("Personalism sample: %d rows × %d countries (range %d-%d).",
                nrow(p_aut), dplyr::n_distinct(p_aut$iso3c),
                min(p_aut$year), max(p_aut$year)))

results <- run_three_dvs("personalism_score", p_aut)

plot_three_dvs(
  results,
  title    = "H2: Effect of personalism on CO2 emissions (autocracies only)",
  subtitle = "OLS with controls; SEs clustered by country. Coef = 1-unit increase in latent_personalism (~0-1 range).",
  out_path = file.path(DIR_DOCS, "05_changes_personalism.png")
)

saveRDS(results, file.path(DIR_INTER, "results_05_changes_personalism.rds"))
