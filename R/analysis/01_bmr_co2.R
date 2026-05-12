# 01_bmr_co2.R
# First analysis: effect of BMR dichotomous democracy on CO2 emissions.
#
# DVs (logged): log_co2_total, log_co2_pc, log_co2_per_gdp
# IV: democracy_bmr (0/1)
# Four models per DV:
#   M1. OLS — DV ~ IV
#   M2. OLS + controls
#   M3. OLS + TWFE (country + year FE)
#   M4. OLS + TWFE + controls
#
# Controls (per project default):
#   log_gdp_pc_const, log_gdp_total_const, log_population,
#   urban_pop_pct, log_area_km2, post_cold_war
#
# TWFE notes:
#   - log_area_km2 is time-invariant → absorbed by country FE; dropped in M3/M4.
#   - post_cold_war is year-only → absorbed by year FE; dropped in M3/M4.
# SEs clustered by country in every model.
#
# Output:
#   docs/bmr_co2_models.png — side-by-side coefficient plot
#   data/intermediate/results_bmr_co2.rds — tidy estimates for inspection

source(here::here("R", "00_setup.R"))

for (pkg in c("fixest", "broom", "ggplot2")) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    install.packages(pkg, repos = "https://cloud.r-project.org")
  }
}
suppressPackageStartupMessages({
  library(dplyr)
  library(fixest)
  library(ggplot2)
})

p <- readRDS(file.path(DIR_FINAL, "panel_analysis.rds"))

# ---- Specifications --------------------------------------------------------

IV <- "democracy_bmr"
DVS <- c(
  "log_co2_total"   = "log(CO2 total)",
  "log_co2_pc"      = "log(CO2 per capita)",
  "log_co2_per_gdp" = "log(CO2 per GDP)"
)

CONTROLS_FULL <- c(
  "log_gdp_pc_const", "log_gdp_total_const", "log_population",
  "urban_pop_pct", "log_area_km2", "post_cold_war"
)
# Drop time-invariant and year-only controls from the TWFE specs.
CONTROLS_TWFE <- c(
  "log_gdp_pc_const", "log_gdp_total_const", "log_population",
  "urban_pop_pct"
)

# ---- Model runner ---------------------------------------------------------

run_four_models <- function(dv, iv, data) {
  f1 <- as.formula(sprintf("%s ~ %s", dv, iv))
  f2 <- as.formula(sprintf("%s ~ %s + %s", dv, iv,
                           paste(CONTROLS_FULL, collapse = " + ")))
  f3 <- as.formula(sprintf("%s ~ %s | iso3c + year", dv, iv))
  f4 <- as.formula(sprintf("%s ~ %s + %s | iso3c + year", dv, iv,
                           paste(CONTROLS_TWFE, collapse = " + ")))
  list(
    M1 = feols(f1, data = data, cluster = ~iso3c),
    M2 = feols(f2, data = data, cluster = ~iso3c),
    M3 = feols(f3, data = data, cluster = ~iso3c),
    M4 = feols(f4, data = data, cluster = ~iso3c)
  )
}

extract_estimate <- function(model, label, iv) {
  s <- broom::tidy(model, conf.int = TRUE)
  # fixest stores N as $nobs directly — use that instead of generic nobs()
  n <- model$nobs
  s |>
    dplyr::filter(term == iv) |>
    dplyr::transmute(
      model = label,
      estimate, conf.low, conf.high,
      n_obs = n
    )
}

# ---- Run for each DV ------------------------------------------------------

results_list <- list()
for (dv in names(DVS)) {
  models <- run_four_models(dv, IV, p)
  results_list[[dv]] <- dplyr::bind_rows(
    extract_estimate(models$M1, "1. OLS",               IV),
    extract_estimate(models$M2, "2. OLS + controls",    IV),
    extract_estimate(models$M3, "3. TWFE",              IV),
    extract_estimate(models$M4, "4. TWFE + controls",   IV)
  ) |>
    dplyr::mutate(dv_label = DVS[[dv]], .before = 1)
}

results_df <- dplyr::bind_rows(results_list) |>
  dplyr::mutate(
    dv_label = factor(dv_label, levels = unname(DVS)),
    model = factor(
      model,
      levels = c("1. OLS", "2. OLS + controls",
                 "3. TWFE", "4. TWFE + controls")
    )
  )

# ---- Caption with N observations ------------------------------------------

n_lines <- results_df |>
  dplyr::group_by(dv_label) |>
  dplyr::summarise(
    line = sprintf(
      "%s: OLS N=%d (no ctrl) / %d (ctrl); TWFE N=%d / %d",
      unique(as.character(dv_label)),
      n_obs[model == "1. OLS"],
      n_obs[model == "2. OLS + controls"],
      n_obs[model == "3. TWFE"],
      n_obs[model == "4. TWFE + controls"]
    ),
    .groups = "drop"
  ) |>
  dplyr::pull(line)

caption_text <- paste(n_lines, collapse = "\n")

# ---- Plot -----------------------------------------------------------------

plot <- ggplot(results_df,
               aes(x = model, y = estimate, color = model)) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "grey50") +
  geom_pointrange(aes(ymin = conf.low, ymax = conf.high),
                  size = 0.7, linewidth = 0.9) +
  facet_wrap(~ dv_label, scales = "free_y", ncol = 3) +
  scale_color_brewer(palette = "Dark2") +
  labs(
    title = "Effect of BMR democracy on CO2 emissions",
    subtitle = "Coefficient on democracy_bmr (0/1), 95% CI, SEs clustered by country",
    y = "Estimate (log DV scale)",
    x = NULL,
    caption = caption_text,
    color = NULL
  ) +
  theme_minimal(base_size = 11) +
  theme(
    axis.text.x = element_blank(),
    axis.ticks.x = element_blank(),
    legend.position = "bottom",
    plot.caption = element_text(hjust = 0, size = 8, family = "mono"),
    panel.spacing.x = unit(1, "lines")
  )

print(plot)

out_path <- file.path(DIR_DOCS, "bmr_co2_models.png")
ggsave(out_path, plot, width = 11, height = 5.5, dpi = 120)
message("Plot saved to: ", out_path)

# Persist tidy results for later inspection / aggregation across analyses
saveRDS(results_df, file.path(DIR_INTER, "results_bmr_co2.rds"))
message("Estimates saved to: ",
        file.path(DIR_INTER, "results_bmr_co2.rds"))
