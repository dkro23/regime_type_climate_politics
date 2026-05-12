# 00_prep.R (analysis)
# Load the merged panel, apply analysis transformations, save the
# analysis-ready dataset that downstream analysis scripts will read.
#
# Transformations:
#   - log() on right-skewed continuous variables (emissions, energy levels,
#     GDP, population, area). Zero values map to NA — switch to log1p() if
#     you want to preserve them.
#   - post_cold_war: dummy = 1 for year >= 1991 (USSR dissolution).
#
# Output: data/final/panel_analysis.rds

source(here::here("R", "00_setup.R"))

p <- readRDS(file.path(DIR_FINAL, "panel.rds"))

p_analysis <- p |>
  dplyr::mutate(
    # ---- Logged DVs (right-skewed) ----
    log_co2_total   = log(co2_total),
    log_co2_pc      = log(co2_pc),
    log_co2_per_gdp = log(co2_per_gdp),
    log_ghg_total   = log(ghg_total),
    log_oil_prod    = log(oil_prod_twh),
    log_gas_prod    = log(gas_prod_twh),
    log_oil_cons    = log(oil_cons_twh),
    log_gas_cons    = log(gas_cons_twh),

    # ---- Logged controls (these should never be 0) ----
    log_gdp_pc_const    = log(gdp_pc_const),
    log_gdp_total_const = log(gdp_total_const),
    log_population      = log(population),
    log_area_km2        = log(area_km2),

    # ---- Era dummy ----
    post_cold_war = as.integer(year >= 1991)
  )

saveRDS(p_analysis, file.path(DIR_FINAL, "panel_analysis.rds"))

message(sprintf(
  "Analysis-ready panel: %d rows × %d cols. Saved to %s",
  nrow(p_analysis), ncol(p_analysis),
  file.path(DIR_FINAL, "panel_analysis.rds")
))

# Quick check on logged-DV coverage (zeros → NA after log)
loss_check <- p_analysis |>
  dplyr::summarise(
    co2_total_raw = sum(!is.na(co2_total)),
    co2_total_log = sum(!is.na(log_co2_total)),
    co2_pc_raw = sum(!is.na(co2_pc)),
    co2_pc_log = sum(!is.na(log_co2_pc)),
    co2_per_gdp_raw = sum(!is.na(co2_per_gdp)),
    co2_per_gdp_log = sum(!is.na(log_co2_per_gdp))
  )
message("Coverage before vs after log() (rows lost = zeros):")
print(loss_check)
