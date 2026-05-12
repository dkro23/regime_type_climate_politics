# helpers.R
# Shared utilities for the OLS-with-controls analyses on the three CO2 DVs:
#   log_co2_total, delta_co2, pct_change_co2.
#
# Each of scripts 03-07 sources this file and calls:
#   results <- run_three_dvs(iv, data)
#   plot_three_dvs(results, title, subtitle, out_path)
#
# Requires: dplyr, fixest, broom, ggplot2 already loaded by caller.

CONTROLS_FULL <- c(
  "log_gdp_pc_const", "log_gdp_total_const", "log_population",
  "urban_pop_pct", "log_area_km2", "post_cold_war"
)

DV_LABELS <- c(
  "log_co2_total"  = "log(CO2 total)",
  "delta_co2"      = "Δ CO2 (Mt, y-o-y)",
  "pct_change_co2" = "% change CO2 (y-o-y)"
)

# Run one OLS-with-controls model per DV. Returns a tidy table with one row
# per DV containing the coefficient on `iv` with its 95% CI and N.
run_three_dvs <- function(iv, data) {
  out <- list()
  for (dv in names(DV_LABELS)) {
    f <- as.formula(sprintf(
      "%s ~ %s + %s", dv, iv, paste(CONTROLS_FULL, collapse = " + ")
    ))
    m <- fixest::feols(f, data = data, cluster = ~iso3c)
    s <- broom::tidy(m, conf.int = TRUE) |>
      dplyr::filter(term == iv) |>
      dplyr::transmute(
        iv = term, estimate, std.error, conf.low, conf.high,
        n_obs = m$nobs
      )
    s$dv_label <- DV_LABELS[[dv]]
    out[[dv]] <- s
  }
  dplyr::bind_rows(out) |>
    dplyr::mutate(dv_label = factor(dv_label, levels = unname(DV_LABELS)))
}

# Plot the three coefficients (one per DV) with 95% CIs. Free y-scale per
# panel because the DVs are on different units (log, Mt, %).
plot_three_dvs <- function(results, title, subtitle, out_path) {
  caption_text <- results |>
    dplyr::distinct(dv_label, n_obs) |>
    dplyr::mutate(line = sprintf("%s: N = %d", dv_label, n_obs)) |>
    dplyr::pull(line) |>
    paste(collapse = "  |  ")

  p <- ggplot2::ggplot(
        results,
        ggplot2::aes(x = dv_label, y = estimate, color = dv_label)
      ) +
    ggplot2::geom_hline(yintercept = 0,
                        linetype = "dashed", color = "grey50") +
    ggplot2::geom_pointrange(
      ggplot2::aes(ymin = conf.low, ymax = conf.high),
      size = 0.7, linewidth = 0.9
    ) +
    ggplot2::facet_wrap(~ dv_label, scales = "free", ncol = 3) +
    ggplot2::scale_color_brewer(palette = "Dark2") +
    ggplot2::labs(
      title = title,
      subtitle = subtitle,
      y = "Coefficient (95% CI)",
      x = NULL,
      caption = caption_text,
      color = NULL
    ) +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(
      axis.text.x  = ggplot2::element_blank(),
      axis.ticks.x = ggplot2::element_blank(),
      legend.position = "none",
      plot.caption = ggplot2::element_text(hjust = 0.5, size = 8,
                                           family = "mono"),
      panel.spacing.x = ggplot2::unit(1, "lines")
    )

  print(p)
  ggplot2::ggsave(out_path, p, width = 11, height = 5.5, dpi = 120)
  message("Plot saved to: ", out_path)
  invisible(p)
}
