# coverage_report.R
# Generate docs/coverage.html: per-variable coverage tables and country-year
# diagnostics for the final panel.

source(here::here("R", "00_setup.R"))

for (pkg in c("htmltools", "ggplot2", "base64enc")) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    install.packages(pkg, repos = "https://cloud.r-project.org")
  }
}
library(htmltools)
library(ggplot2)

panel <- readRDS(file.path(DIR_FINAL, "panel.rds"))

# ---- Variable groupings (must match codebook.md) ---------------------------

groups <- list(
  "Identifiers and spine" = c("iso3c", "year", "country_name",
                              "cown", "cowc", "gwn", "gwc",
                              "vdem_country_id", "region", "subregion",
                              "state_status"),
  "V-Dem regime"          = c("regimes_of_the_world", "regime_row_10cat",
                              "polyarchy", "libdem", "partipdem",
                              "delibdem", "egaldem"),
  "V-Dem polarization"    = c("pol_polarization", "soc_polarization"),
  "V-Dem authoritarian institutions" =
    c("legislature_chambers", "lower_chamber_elected", "party_ban",
      "multiparty_elections", "high_court_indep", "freedom_expression",
      "polity2_vdem_merge",
      "vdem_country_name", "vdem_country_text", "vdem_cowcode"),
  "BMR"                   = c("democracy_bmr", "bmr_extended"),
  "GWF + composite subtype" =
    c("gwf_regime", "gwf_regime_raw", "gwf_party", "gwf_military",
      "gwf_personal", "gwf_monarch", "regime_subtype"),
  "Personalism (Frantz et al.)" =
    c("personalism_score", "personalism_se", "personalism_alt"),
  "Polity"                = c("polity2", "polity_durable"),
  "V-Party populism"      = c("vparty_pop_max", "vparty_pop_govwt",
                              "vparty_populist_in_govt",
                              "vparty_populist_voteshare",
                              "vparty_election_year"),
  "Emissions"             = c("co2_total", "co2_pc", "co2_per_gdp",
                              "ghg_total", "ghg_excl_lucf",
                              "methane", "nitrous_oxide",
                              "oil_co2", "gas_co2", "coal_co2",
                              "cement_co2", "flaring_co2",
                              "other_industry_co2", "co2_incl_luc"),
  "Energy: fossil"        = c("primary_energy_twh",
                              "oil_prod_twh", "oil_cons_twh",
                              "gas_prod_twh", "gas_cons_twh",
                              "coal_prod_twh", "coal_cons_twh",
                              "energy_pc"),
  "Energy: electricity"   = c("elec_gen_twh", "elec_fossil_twh",
                              "elec_renew_twh", "elec_nuclear_twh",
                              "elec_hydro_twh", "elec_solar_twh",
                              "elec_wind_twh", "elec_biofuel_twh"),
  "Energy: shares"        = c("share_fossil_primary", "share_renew_primary",
                              "share_solar_primary", "share_wind_primary",
                              "share_hydro_primary", "share_nuclear_primary",
                              "share_fossil_elec", "share_renew_elec",
                              "share_solar_elec", "share_wind_elec",
                              "share_hydro_elec", "share_nuclear_elec"),
  "Paris Agreement"       = c("paris_signed", "paris_signed_year",
                              "paris_ratified", "paris_ratify_year",
                              "paris_withdrew"),
  "Controls"              = c("gdp_pc_ppp", "gdp_pc_const", "gdp_total_const",
                              "gdp_pc_maddison",
                              "population", "area_km2",
                              "urban_pop_pct", "largest_city_pct",
                              "trade_pct_gdp", "fdi_pct_gdp",
                              "oil_rents_pct", "gas_rents_pct",
                              "fossil_rents_pct", "energy_use_pc"),
  "Inequality (SWIID)"    = c("gini_net", "gini_net_se",
                              "gini_market", "gini_market_se")
)

# Sanity: ensure every panel column appears in some group
all_in_groups <- unique(unlist(groups))
missing_from_groups <- setdiff(names(panel), all_in_groups)
unknown_in_groups <- setdiff(all_in_groups, names(panel))
if (length(missing_from_groups)) {
  message("Panel columns not in any group (will be appended): ",
          paste(missing_from_groups, collapse = ", "))
  groups[["Other"]] <- missing_from_groups
}
if (length(unknown_in_groups)) {
  message("Group entries not in panel (skipped): ",
          paste(unknown_in_groups, collapse = ", "))
}

# ---- Per-variable coverage stats -------------------------------------------

var_stats <- function(varname) {
  x <- panel[[varname]]
  n_non_na <- sum(!is.na(x))
  pct <- round(100 * n_non_na / nrow(panel), 1)
  if (n_non_na == 0) {
    return(tibble::tibble(
      variable = varname, n_non_na = 0L, pct_non_na = 0,
      first_year = NA_integer_, last_year = NA_integer_,
      n_countries = 0L
    ))
  }
  yrs <- panel$year[!is.na(x)]
  isos <- panel$iso3c[!is.na(x)]
  tibble::tibble(
    variable = varname,
    n_non_na = n_non_na,
    pct_non_na = pct,
    first_year = min(yrs, na.rm = TRUE),
    last_year  = max(yrs, na.rm = TRUE),
    n_countries = dplyr::n_distinct(isos)
  )
}

# ---- HTML rendering helpers ------------------------------------------------

table_to_html <- function(df) {
  rows <- vapply(seq_len(nrow(df)), function(i) {
    cells <- vapply(df[i, ], function(v) {
      paste0("<td>", if (is.na(v)) "—" else as.character(v), "</td>")
    }, character(1))
    paste0("<tr>", paste(cells, collapse = ""), "</tr>")
  }, character(1))
  header <- paste0("<tr>",
                   paste0("<th>", names(df), "</th>", collapse = ""),
                   "</tr>")
  paste0('<table class="cov">',
         "<thead>", header, "</thead>",
         "<tbody>", paste(rows, collapse = ""), "</tbody>",
         "</table>")
}

# ---- Build per-group sections ----------------------------------------------

group_sections <- character()
for (grp_name in names(groups)) {
  vars <- intersect(groups[[grp_name]], names(panel))
  if (!length(vars)) next
  tbl <- dplyr::bind_rows(lapply(vars, var_stats))
  group_sections <- c(group_sections,
                      sprintf("<h3>%s</h3>", grp_name),
                      table_to_html(tbl))
}

# ---- Overall stats ---------------------------------------------------------

overall <- tibble::tibble(
  rows = nrow(panel),
  iso3c = dplyr::n_distinct(panel$iso3c),
  years = paste0(min(panel$year), "-", max(panel$year)),
  columns = ncol(panel)
)

# ---- Country counts per year (for the year-coverage line plot) ------------

yearly <- panel |>
  dplyr::group_by(year) |>
  dplyr::summarise(
    n_countries = dplyr::n_distinct(iso3c),
    n_with_polyarchy = sum(!is.na(polyarchy)),
    n_with_co2_total = sum(!is.na(co2_total)),
    n_with_gdp_pc_ppp = sum(!is.na(gdp_pc_ppp)),
    n_with_gini_net = sum(!is.na(gini_net)),
    .groups = "drop"
  )

yearly_long <- yearly |>
  tidyr::pivot_longer(
    cols = -year, names_to = "series", values_to = "n"
  ) |>
  dplyr::mutate(
    series = factor(
      series,
      levels = c("n_countries", "n_with_polyarchy",
                 "n_with_co2_total", "n_with_gdp_pc_ppp",
                 "n_with_gini_net"),
      labels = c("Countries in spine", "V-Dem polyarchy",
                 "CO2 total", "GDP per cap (PPP)",
                 "Gini (net)")
    )
  )

plot_yearly <- ggplot(yearly_long,
                      aes(x = year, y = n, color = series)) +
  geom_line(linewidth = 0.9) +
  scale_color_brewer(palette = "Dark2") +
  labs(title = "Countries with data per year, by variable",
       x = NULL, y = "Number of countries",
       color = NULL) +
  theme_minimal(base_size = 11) +
  theme(legend.position = "bottom")

# Save plot to PNG and embed as base64 in HTML
plot_path <- file.path(DIR_DOCS, "coverage_yearly.png")
if (!dir.exists(DIR_DOCS)) dir.create(DIR_DOCS, recursive = TRUE)
ggsave(plot_path, plot_yearly, width = 9, height = 5, dpi = 100)
plot_b64 <- base64enc::base64encode(plot_path)
plot_img <- sprintf('<img src="data:image/png;base64,%s" alt="Yearly coverage"/>',
                    plot_b64)

# ---- Country-level coverage table (top 15 highest, 15 lowest) -------------

per_iso_cov <- panel |>
  dplyr::group_by(iso3c) |>
  dplyr::summarise(
    pct_co2 = round(100 * mean(!is.na(co2_total)), 1),
    pct_regime = round(100 * mean(!is.na(regimes_of_the_world)), 1),
    pct_gdp = round(100 * mean(!is.na(gdp_pc_ppp)), 1),
    pct_gini = round(100 * mean(!is.na(gini_net)), 1),
    .groups = "drop"
  ) |>
  dplyr::mutate(
    pct_overall = round((pct_co2 + pct_regime + pct_gdp + pct_gini) / 4, 1)
  ) |>
  dplyr::arrange(dplyr::desc(pct_overall))

top_iso <- head(per_iso_cov, 15)
bot_iso <- tail(per_iso_cov, 15) |> dplyr::arrange(pct_overall)

# ---- Assemble the HTML ----------------------------------------------------

css <- "
body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
       max-width: 1100px; margin: 2em auto; padding: 0 1em; color: #222; }
h1 { border-bottom: 2px solid #333; padding-bottom: 0.2em; }
h2 { color: #1f4e79; margin-top: 2em; border-bottom: 1px solid #ccc;
     padding-bottom: 0.2em; }
h3 { color: #2e75b6; margin-top: 1.5em; }
table.cov { border-collapse: collapse; margin: 0.5em 0 1.5em 0; width: 100%;
            font-size: 0.92em; }
table.cov th, table.cov td { border: 1px solid #ddd; padding: 4px 8px;
                             text-align: left; }
table.cov th { background: #f0f4f8; }
table.cov tbody tr:nth-child(even) { background: #fafbfc; }
img { max-width: 100%; height: auto; }
.summary-table { font-size: 1em; width: auto; }
.summary-table td { padding: 6px 16px; }
"

html_body <- paste(
  '<h1>Panel coverage report</h1>',
  sprintf('<p><em>Generated %s from data/final/panel.rds.</em></p>',
          format(Sys.time(), "%Y-%m-%d %H:%M %Z")),
  '<h2>Overall</h2>',
  table_to_html(overall),
  '<h2>Countries with data per year</h2>',
  plot_img,
  '<h2>Per-variable coverage</h2>',
  paste(group_sections, collapse = "\n"),
  '<h2>Country-level coverage (top &amp; bottom 15)</h2>',
  '<p>Mean of % non-NA across four headline variables: CO2 total, V-Dem regime, GDP per cap (PPP), Gini (net).</p>',
  '<h3>Highest coverage</h3>', table_to_html(top_iso),
  '<h3>Lowest coverage</h3>', table_to_html(bot_iso),
  sep = "\n"
)

html_doc <- sprintf(
  '<!DOCTYPE html><html><head><meta charset="utf-8">
   <title>Panel coverage report</title><style>%s</style></head>
   <body>%s</body></html>',
  css, html_body
)

out_path <- file.path(DIR_DOCS, "coverage.html")
writeLines(html_doc, out_path, useBytes = TRUE)
message("Wrote ", out_path)
