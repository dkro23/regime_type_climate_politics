# 11_energy.R
# Oil, gas, coal production and consumption + renewables share, from
# Our World in Data energy dataset (aggregates Energy Institute Statistical
# Review of World Energy, Ember Yearly Electricity, and IEA where licensed).
#
# Source: https://github.com/owid/energy-data
#
# Energy unit conventions in this output:
#   *_consumption / *_production in TWh (OWID's standard for primary energy)
#   electricity series in TWh
#   shares in %
#
# Output: data/intermediate/energy.rds

source(here::here("R", "00_setup.R"))

raw_path <- file.path(DIR_RAW, "owid-energy-data.csv")
if (!file.exists(raw_path)) {
  message("Downloading OWID energy dataset...")
  utils::download.file(
    "https://github.com/owid/energy-data/raw/master/owid-energy-data.csv",
    destfile = raw_path, mode = "wb"
  )
}

en <- readr::read_csv(raw_path, show_col_types = FALSE) |>
  dplyr::as_tibble()
message(sprintf("OWID energy loaded: %d rows, %d columns",
                nrow(en), ncol(en)))

# ---- Variables to extract --------------------------------------------------
# Primary energy is in TWh in this dataset. For oil/gas we keep both
# production and consumption series. For renewables we keep both the
# share of primary energy and share of electricity.

target_vars <- c(
  "iso_code", "country", "year",
  # primary energy totals
  "primary_energy_consumption",
  # fossil-fuel production / consumption (TWh)
  "oil_consumption",      "oil_production",
  "gas_consumption",      "gas_production",
  "coal_consumption",     "coal_production",
  # electricity generation by source (TWh)
  "electricity_generation",
  "fossil_electricity", "renewables_electricity",
  "nuclear_electricity", "hydro_electricity",
  "solar_electricity", "wind_electricity",
  "biofuel_electricity",
  # shares in primary energy
  "fossil_share_energy", "renewables_share_energy",
  "solar_share_energy", "wind_share_energy", "hydro_share_energy",
  "nuclear_share_energy",
  # shares in electricity
  "fossil_share_elec", "renewables_share_elec",
  "solar_share_elec", "wind_share_elec", "hydro_share_elec",
  "nuclear_share_elec",
  # convenience: per-capita
  "energy_per_capita"
)

present <- intersect(target_vars, names(en))
missing <- setdiff(target_vars, names(en))
if (length(missing)) {
  message("OWID energy variables not found (skipped): ",
          paste(missing, collapse = ", "))
}
en <- en |> dplyr::select(dplyr::all_of(present))

# ---- Filter, map iso3c, historical-state remap ----------------------------

en <- en |>
  dplyr::filter(!is.na(iso_code)) |>
  dplyr::filter(year >= PANEL_YEAR_MIN, year <= PANEL_YEAR_MAX) |>
  dplyr::mutate(
    iso3c = dplyr::case_when(
      iso_code == "CZE" & year <= 1992 ~ "CSK",
      iso_code == "SRB" & year <= 2005 ~ "YUG",
      iso_code == "YEM" & year <= 1989 ~ "YAR",
      grepl("South Yemen|Yemen.*Demo", country, ignore.case = TRUE) ~ "YMD",
      grepl("East Germany|German Democratic", country,
            ignore.case = TRUE) ~ "DDR",
      grepl("Czechoslovakia", country, ignore.case = TRUE) ~ "CSK",
      grepl("Yugoslavia", country, ignore.case = TRUE) ~ "YUG",
      TRUE ~ iso_code
    )
  )

# Drop OWID region aggregates (codes like OWID_WRL, OWID_EUR, etc.)
en <- en |>
  dplyr::filter(!grepl("^OWID_", iso3c))

# ---- Rename to project-standard naming ------------------------------------

energy <- en |>
  dplyr::rename(
    primary_energy_twh        = dplyr::any_of("primary_energy_consumption"),
    oil_cons_twh              = dplyr::any_of("oil_consumption"),
    oil_prod_twh              = dplyr::any_of("oil_production"),
    gas_cons_twh              = dplyr::any_of("gas_consumption"),
    gas_prod_twh              = dplyr::any_of("gas_production"),
    coal_cons_twh             = dplyr::any_of("coal_consumption"),
    coal_prod_twh             = dplyr::any_of("coal_production"),
    elec_gen_twh              = dplyr::any_of("electricity_generation"),
    elec_fossil_twh           = dplyr::any_of("fossil_electricity"),
    elec_renew_twh            = dplyr::any_of("renewables_electricity"),
    elec_nuclear_twh          = dplyr::any_of("nuclear_electricity"),
    elec_hydro_twh            = dplyr::any_of("hydro_electricity"),
    elec_solar_twh            = dplyr::any_of("solar_electricity"),
    elec_wind_twh             = dplyr::any_of("wind_electricity"),
    elec_biofuel_twh          = dplyr::any_of("biofuel_electricity"),
    share_fossil_primary      = dplyr::any_of("fossil_share_energy"),
    share_renew_primary       = dplyr::any_of("renewables_share_energy"),
    share_solar_primary       = dplyr::any_of("solar_share_energy"),
    share_wind_primary        = dplyr::any_of("wind_share_energy"),
    share_hydro_primary       = dplyr::any_of("hydro_share_energy"),
    share_nuclear_primary     = dplyr::any_of("nuclear_share_energy"),
    share_fossil_elec         = dplyr::any_of("fossil_share_elec"),
    share_renew_elec          = dplyr::any_of("renewables_share_elec"),
    share_solar_elec          = dplyr::any_of("solar_share_elec"),
    share_wind_elec           = dplyr::any_of("wind_share_elec"),
    share_hydro_elec          = dplyr::any_of("hydro_share_elec"),
    share_nuclear_elec        = dplyr::any_of("nuclear_share_elec"),
    energy_pc                 = dplyr::any_of("energy_per_capita")
  ) |>
  dplyr::select(-iso_code, -country) |>
  dplyr::distinct(iso3c, year, .keep_all = TRUE) |>
  dplyr::arrange(iso3c, year)

assert_unique_country_year(energy)

# ---- Coverage diagnostics --------------------------------------------------

spine <- load_intermediate("spine")
joined <- spine |> dplyr::left_join(energy, by = c("iso3c", "year"))
cov <- joined |>
  dplyr::summarise(
    spine_rows = dplyr::n(),
    with_oil_prod  = sum(!is.na(oil_prod_twh)),
    with_gas_prod  = sum(!is.na(gas_prod_twh)),
    with_renew_pri = sum(!is.na(share_renew_primary)),
    with_renew_el  = sum(!is.na(share_renew_elec)),
    pct_oil_prod   = round(100 * mean(!is.na(oil_prod_twh)), 1),
    pct_renew_pri  = round(100 * mean(!is.na(share_renew_primary)), 1)
  )
print(cov)

save_intermediate(energy, "energy")
