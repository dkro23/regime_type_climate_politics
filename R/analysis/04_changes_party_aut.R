# 04_changes_party_aut.R
# H2: Autocracies with more institutionalized party systems will be more
#     likely to reduce CO2 emissions than less institutionalized autocracies.
#
# IV: party_autocracy (1 = regime_subtype == "party"; 0 = military / personalist
#     / monarchy / other autocracy). Democracies excluded by construction.
# DVs: log_co2_total, delta_co2, pct_change_co2
# Sample: autocracies only (party_autocracy not NA).
# Spec: OLS with controls, SEs clustered by country.

source(here::here("R", "00_setup.R"))
source(here::here("R", "analysis", "helpers.R"))
suppressPackageStartupMessages({
  library(dplyr); library(fixest); library(ggplot2)
})

p <- readRDS(file.path(DIR_FINAL, "panel_analysis.rds"))

# Restrict to autocracies (rows where party_autocracy is defined)
p_aut <- p |> dplyr::filter(!is.na(party_autocracy))
message(sprintf("Autocracy sample: %d rows × %d countries.",
                nrow(p_aut), dplyr::n_distinct(p_aut$iso3c)))

results <- run_three_dvs("party_autocracy", p_aut)

plot_three_dvs(
  results,
  title    = "H2: Effect of party-based autocracy (vs. other autocracies) on CO2",
  subtitle = "OLS with controls; SEs clustered by country. Sample: autocracies.",
  out_path = file.path(DIR_DOCS, "04_changes_party_aut.png")
)

saveRDS(results, file.path(DIR_INTER, "results_04_changes_party_aut.rds"))
