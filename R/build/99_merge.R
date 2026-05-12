# 99_merge.R
# Final merge of all intermediates onto the spine. Applies the authoritative
# microstate population filter (<500k median over the panel window).
#
# Output:
#   data/final/panel.rds  — R-native, preserves types
#   data/final/panel.csv  — portable
#
# Run after all upstream build scripts.

source(here::here("R", "00_setup.R"))

# ---- Load spine + all intermediates ----------------------------------------

intermediates <- c(
  "vdem", "bmr", "gwf", "personalism", "polity",
  "vparty", "emissions", "energy", "treaties",
  "controls", "swiid"
)

spine <- load_intermediate("spine")
message(sprintf("Spine: %d rows × %d iso3c × %d-%d",
                nrow(spine), dplyr::n_distinct(spine$iso3c),
                min(spine$year), max(spine$year)))

# Some intermediates may not exist (skipped scripts). Tolerate.
parts <- list()
for (name in intermediates) {
  path <- file.path(DIR_INTER, paste0(name, ".rds"))
  if (file.exists(path) && file.size(path) > 0) {
    obj <- readRDS(path)
    if (nrow(obj) > 0) {
      parts[[name]] <- obj
      message(sprintf("  %-15s: %d rows, %d cols",
                      name, nrow(obj), ncol(obj)))
    } else {
      message(sprintf("  %-15s: empty placeholder — skipping", name))
    }
  } else {
    message(sprintf("  %-15s: not found — skipping", name))
  }
}

# ---- Sequentially left-join each intermediate ------------------------------

panel <- spine
for (name in names(parts)) {
  before_rows <- nrow(panel)
  panel <- panel |>
    dplyr::left_join(parts[[name]], by = c("iso3c", "year"))
  if (nrow(panel) != before_rows) {
    warning(sprintf(
      "Row count changed after joining %s: %d → %d. Investigate duplicates.",
      name, before_rows, nrow(panel)
    ))
  }
}

# Coalesce duplicate-suffix columns from joins (e.g. vdem_country_id.x/.y)
dup_cols <- grep("\\.x$", names(panel), value = TRUE)
for (col_x in dup_cols) {
  base <- sub("\\.x$", "", col_x)
  col_y <- paste0(base, ".y")
  if (col_y %in% names(panel)) {
    panel[[base]] <- dplyr::coalesce(panel[[col_x]], panel[[col_y]])
    panel[[col_x]] <- NULL
    panel[[col_y]] <- NULL
  }
}

assert_unique_country_year(panel)

message(sprintf(
  "\nMerged panel before microstate filter: %d rows, %d columns",
  nrow(panel), ncol(panel)
))

# ---- Apply final microstate filter -----------------------------------------
# Threshold: median population over the panel window must be ≥ 500k.
# We use median (not min/max) to avoid edge effects from country-years
# with missing population.

med_pop <- panel |>
  dplyr::filter(!is.na(population)) |>
  dplyr::group_by(iso3c) |>
  dplyr::summarise(median_pop = median(population, na.rm = TRUE),
                   .groups = "drop")

microstates_final <- med_pop |>
  dplyr::filter(median_pop < MICROSTATE_POP_THRESHOLD) |>
  dplyr::pull(iso3c)

message(sprintf(
  "\nMicrostate filter: dropping %d iso3c with median population < %d",
  length(microstates_final), MICROSTATE_POP_THRESHOLD
))
if (length(microstates_final)) {
  message("  Dropped: ", paste(sort(microstates_final), collapse = ", "))
}

panel <- panel |>
  dplyr::filter(!iso3c %in% microstates_final)

# ---- Final diagnostics -----------------------------------------------------

cov <- panel |>
  dplyr::summarise(
    rows = dplyr::n(),
    iso3c = dplyr::n_distinct(iso3c),
    years_min = min(year),
    years_max = max(year),
    cols = ncol(panel)
  )
print(cov)

message("\nKey-variable coverage (% non-NA, after microstate filter):")
key_vars <- c("regimes_of_the_world", "democracy_bmr", "regime_subtype",
              "personalism_score", "polity2",
              "vparty_populist_in_govt",
              "co2_total", "share_renew_primary",
              "oil_prod_twh", "gas_prod_twh",
              "paris_ratified", "gdp_pc_ppp", "population",
              "urban_pop_pct", "gini_net")
key_vars <- intersect(key_vars, names(panel))
cov_keys <- panel |>
  dplyr::summarise(dplyr::across(dplyr::all_of(key_vars),
                                 \(x) round(100 * mean(!is.na(x)), 1)))
print(cov_keys)

# ---- Save ------------------------------------------------------------------

if (!dir.exists(DIR_FINAL)) dir.create(DIR_FINAL, recursive = TRUE)
saveRDS(panel, file.path(DIR_FINAL, "panel.rds"))
readr::write_csv(panel, file.path(DIR_FINAL, "panel.csv"))

message(sprintf(
  "\nFinal panel saved to %s/panel.{rds,csv}: %d rows × %d cols",
  DIR_FINAL, nrow(panel), ncol(panel)
))
