# 02_subtypes_co2.R
# Effect of regime subtype on CO2 emissions, relative to democracy.
#
# IV: regime_subtype (factor; democracy as reference)
#   levels: democracy, party, military, personalist, monarchy, other_autocracy
# DVs: log_co2_total, log_co2_pc, log_co2_per_gdp
# Specification: OLS with controls (no TWFE this analysis).
#   Controls: log_gdp_pc_const, log_gdp_total_const, log_population,
#             urban_pop_pct, log_area_km2, post_cold_war
#   SEs clustered by country.
#
# Output:
#   docs/subtypes_co2_models.png
#   data/intermediate/results_subtypes_co2.rds

source(here::here("R", "00_setup.R"))

for (pkg in c("fixest", "broom", "ggplot2")) {
  if (!requireNamespace(pkg, quietly = TRUE))
    install.packages(pkg, repos = "https://cloud.r-project.org")
}
suppressPackageStartupMessages({
  library(dplyr)
  library(fixest)
  library(ggplot2)
})

p <- readRDS(file.path(DIR_FINAL, "panel_analysis.rds"))

# ---- Set up regime_subtype factor with democracy as reference --------------

SUBTYPE_LEVELS <- c("democracy", "party", "military",
                    "personalist", "monarchy", "other_autocracy")
p$regime_subtype <- factor(p$regime_subtype, levels = SUBTYPE_LEVELS)

CONTROLS_FULL <- c(
  "log_gdp_pc_const", "log_gdp_total_const", "log_population",
  "urban_pop_pct", "log_area_km2", "post_cold_war"
)

DVS <- c(
  "log_co2_total"   = "log(CO2 total)",
  "log_co2_pc"      = "log(CO2 per capita)",
  "log_co2_per_gdp" = "log(CO2 per GDP)"
)

# ---- Run one model per DV --------------------------------------------------

run_model <- function(dv, data) {
  f <- as.formula(sprintf("%s ~ regime_subtype + %s", dv,
                          paste(CONTROLS_FULL, collapse = " + ")))
  fixest::feols(f, data = data, cluster = ~iso3c)
}

results_list <- list()
for (dv in names(DVS)) {
  m <- run_model(dv, p)
  s <- broom::tidy(m, conf.int = TRUE) |>
    dplyr::filter(grepl("^regime_subtype", term)) |>
    dplyr::transmute(
      subtype = sub("^regime_subtype", "", term),
      estimate, conf.low, conf.high,
      n_obs = m$nobs
    )
  s$dv_label <- DVS[[dv]]
  results_list[[dv]] <- s
}

results_df <- dplyr::bind_rows(results_list) |>
  dplyr::mutate(
    dv_label = factor(dv_label, levels = unname(DVS)),
    subtype = factor(
      subtype,
      levels = c("party", "military", "personalist",
                 "monarchy", "other_autocracy")
    )
  )

# Caption: N is constant per DV in a single-model spec
caption_text <- results_df |>
  dplyr::distinct(dv_label, n_obs) |>
  dplyr::mutate(line = sprintf("%s: N = %d", dv_label, n_obs)) |>
  dplyr::pull(line) |>
  paste(collapse = "  |  ")

# ---- Plot ------------------------------------------------------------------

plot <- ggplot(results_df,
               aes(x = subtype, y = estimate, color = subtype)) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "grey50") +
  geom_pointrange(aes(ymin = conf.low, ymax = conf.high),
                  size = 0.7, linewidth = 0.9) +
  facet_wrap(~ dv_label, scales = "free_y", ncol = 3) +
  scale_color_brewer(palette = "Dark2") +
  labs(
    title = "Effect of autocratic subtype on CO2 emissions (vs. democracy)",
    subtitle = "OLS with controls; SEs clustered by country. Dashed line = democracy baseline.",
    y = "Coefficient (log DV scale, relative to democracy)",
    x = NULL,
    caption = caption_text,
    color = NULL
  ) +
  theme_minimal(base_size = 11) +
  theme(
    axis.text.x = element_blank(),
    axis.ticks.x = element_blank(),
    legend.position = "bottom",
    plot.caption = element_text(hjust = 0.5, size = 8, family = "mono"),
    panel.spacing.x = unit(1, "lines")
  )

print(plot)

out_path <- file.path(DIR_DOCS, "subtypes_co2_models.png")
ggsave(out_path, plot, width = 11, height = 5.5, dpi = 120)
message("Plot saved to: ", out_path)

saveRDS(results_df, file.path(DIR_INTER, "results_subtypes_co2.rds"))
message("Estimates saved to: ",
        file.path(DIR_INTER, "results_subtypes_co2.rds"))
