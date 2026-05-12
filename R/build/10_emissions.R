# 10_emissions.R
# Carbon and GHG emissions, plus fuel-specific decomposition.
#
# Source: Our World in Data CO2 and GHG dataset, which aggregates PRIMAP-hist,
# Global Carbon Project, EDGAR, and BP/Energy Institute into a single tidy
# country-year file. Stable GitHub URL.
#   https://github.com/owid/co2-data
#
# Extracted variables (project-standard names):
#   co2_total       Mt CO2 (Global Carbon Project)
#   co2_pc          tonnes per capita
#   co2_per_gdp     kg per $ GDP (constant 2010 USD)
#   ghg_total       total GHG inc. LULUCF (Mt CO2-eq)
#   ghg_excl_lucf   GHG excl. LULUCF
#   methane         Mt CO2-eq
#   nitrous_oxide   Mt CO2-eq
#   oil_co2         from oil combustion
#   gas_co2         from gas combustion
#   coal_co2        from coal combustion
#   cement_co2      from cement production
#   flaring_co2     from gas flaring
#
# Output: data/intermediate/emissions.rds

source(here::here("R", "00_setup.R"))

# ---- Download / load -------------------------------------------------------

raw_path <- file.path(DIR_RAW, "owid-co2-data.csv")

if (!file.exists(raw_path)) {
  message("Downloading OWID CO2 dataset from GitHub...")
  utils::download.file(
    "https://github.com/owid/co2-data/raw/master/owid-co2-data.csv",
    destfile = raw_path, mode = "wb"
  )
}

co2 <- readr::read_csv(raw_path, show_col_types = FALSE) |>
  dplyr::as_tibble()
message(sprintf("OWID emissions loaded: %d rows, %d columns",
                nrow(co2), ncol(co2)))

# ---- Pick variables we want -----------------------------------------------

target_vars <- c(
  "iso_code", "country", "year",
  "co2", "co2_per_capita", "co2_per_gdp",
  "total_ghg", "total_ghg_excluding_lucf",
  "methane", "nitrous_oxide",
  "oil_co2", "gas_co2", "coal_co2",
  "cement_co2", "flaring_co2", "other_industry_co2",
  "co2_including_luc"
)
present <- intersect(target_vars, names(co2))
missing <- setdiff(target_vars, names(co2))
if (length(missing)) {
  message("OWID variables not found (skipped): ",
          paste(missing, collapse = ", "))
}

co2 <- co2 |> dplyr::select(dplyr::all_of(present))

# ---- Map to iso3c ----------------------------------------------------------
# OWID's iso_code is generally iso3c. Aggregate "regions" (World, Asia, etc.)
# have NA iso_code — drop them.

co2 <- co2 |>
  dplyr::filter(!is.na(iso_code)) |>
  dplyr::filter(year >= PANEL_YEAR_MIN, year <= PANEL_YEAR_MAX)

# Year-based historical-state remap (OWID uses continuator codes by default).
co2 <- co2 |>
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

# OWID typically has explicit rows for "Yugoslavia", "Czechoslovakia",
# "East Germany", "USSR" — they show up with iso_code = OWID_XXX. The
# country-name grep above maps them to the historical iso3c codes used in
# our spine. Any duplicates (e.g. OWID has both "Germany" and "East Germany"
# with overlapping years in DDR) are handled by distinct() with .keep_all.

# ---- Rename to project-standard ------------------------------------------

emissions <- co2 |>
  dplyr::rename(
    co2_total      = dplyr::any_of("co2"),
    co2_pc         = dplyr::any_of("co2_per_capita"),
    co2_per_gdp_   = dplyr::any_of("co2_per_gdp"),
    ghg_total      = dplyr::any_of("total_ghg"),
    ghg_excl_lucf  = dplyr::any_of("total_ghg_excluding_lucf"),
    methane_       = dplyr::any_of("methane"),
    nitrous_oxide_ = dplyr::any_of("nitrous_oxide"),
    oil_co2_       = dplyr::any_of("oil_co2"),
    gas_co2_       = dplyr::any_of("gas_co2"),
    coal_co2_      = dplyr::any_of("coal_co2"),
    cement_co2_    = dplyr::any_of("cement_co2"),
    flaring_co2_   = dplyr::any_of("flaring_co2"),
    other_industry_co2_ = dplyr::any_of("other_industry_co2"),
    co2_incl_luc   = dplyr::any_of("co2_including_luc")
  ) |>
  # Drop trailing underscores
  dplyr::rename_with(\(x) sub("_$", "", x))

# Slim, dedupe, save
emissions <- emissions |>
  dplyr::select(-iso_code, -country) |>
  dplyr::distinct(iso3c, year, .keep_all = TRUE) |>
  dplyr::arrange(iso3c, year)

assert_unique_country_year(emissions)

# ---- Coverage check --------------------------------------------------------

spine <- load_intermediate("spine")
joined <- spine |> dplyr::left_join(emissions, by = c("iso3c", "year"))
cov <- joined |>
  dplyr::summarise(
    spine_rows = dplyr::n(),
    with_co2   = sum(!is.na(co2_total)),
    pct_co2    = round(100 * mean(!is.na(co2_total)), 1),
    with_ghg   = sum(!is.na(ghg_total)),
    pct_ghg    = round(100 * mean(!is.na(ghg_total)), 1)
  )
print(cov)

save_intermediate(emissions, "emissions")
