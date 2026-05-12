# 18_controls.R
# Control variables: GDP per capita, population, area, urban concentration,
# trade openness, energy per capita. Sourced primarily from World Bank WDI
# via the `WDI` R package; Maddison Project Database for pre-1960 GDP.
#
# Output: data/intermediate/controls.rds

source(here::here("R", "00_setup.R"))

if (!requireNamespace("WDI", quietly = TRUE)) {
  install.packages("WDI", repos = "https://cloud.r-project.org")
}

# ---- WDI indicators to pull -----------------------------------------------

wdi_indicators <- c(
  gdp_pc_ppp        = "NY.GDP.PCAP.PP.KD",      # GDP per cap PPP, constant 2017 USD
  gdp_pc_const      = "NY.GDP.PCAP.KD",         # GDP per cap, constant 2015 USD
  gdp_total_const   = "NY.GDP.MKTP.KD",         # GDP total, constant 2015 USD
  population        = "SP.POP.TOTL",            # Total population
  area_km2          = "AG.LND.TOTL.K2",         # Land area km^2
  urban_pop_pct     = "SP.URB.TOTL.IN.ZS",      # Urban % of total population
  largest_city_pct  = "EN.URB.MCTY.TL.ZS",      # Population in largest city, % of urban
  trade_pct_gdp     = "NE.TRD.GNFS.ZS",         # Trade % of GDP
  fdi_pct_gdp       = "BX.KLT.DINV.WD.GD.ZS",   # FDI net inflows % of GDP
  oil_rents_pct     = "NY.GDP.PETR.RT.ZS",      # Oil rents % of GDP
  gas_rents_pct     = "NY.GDP.NGAS.RT.ZS",      # Gas rents % of GDP
  fossil_rents_pct  = "NY.GDP.TOTL.RT.ZS",      # Total natural resource rents % of GDP
  energy_use_pc     = "EG.USE.PCAP.KG.OE"       # Energy use kg of oil eq per cap
)

raw_path <- file.path(DIR_RAW, "wdi_controls.rds")

if (!file.exists(raw_path)) {
  message("Downloading WDI indicators (this may take a minute)...")
  wdi_raw <- WDI::WDI(
    country = "all",
    indicator = wdi_indicators,
    start = 1960L,           # WDI's earliest year
    end = PANEL_YEAR_MAX,
    extra = TRUE
  )
  saveRDS(wdi_raw, raw_path)
} else {
  message("Using cached WDI data at ", raw_path)
  wdi_raw <- readRDS(raw_path)
}
wdi_raw <- dplyr::as_tibble(wdi_raw)
message(sprintf("WDI loaded: %d rows, %d columns",
                nrow(wdi_raw), ncol(wdi_raw)))

# ---- Map iso3c, filter --------------------------------------------------

# WDI's iso3c column should already exist via the extra = TRUE flag.
iso_col <- intersect(c("iso3c", "iso3"), names(wdi_raw))[1]
year_col <- intersect(c("year"), names(wdi_raw))[1]

if (is.na(iso_col)) {
  wdi_raw <- wdi_raw |>
    dplyr::mutate(
      iso3c = countrycode::countrycode(country, "country.name", "iso3c",
                                       warn = FALSE)
    )
  iso_col <- "iso3c"
}

controls <- wdi_raw |>
  dplyr::filter(!is.na(.data[[iso_col]])) |>
  dplyr::filter(.data[[year_col]] >= PANEL_YEAR_MIN,
                .data[[year_col]] <= PANEL_YEAR_MAX) |>
  dplyr::rename(iso3c = !!iso_col, year = !!year_col) |>
  dplyr::mutate(
    iso3c = dplyr::case_when(
      iso3c == "CZE" & year <= 1992 ~ "CSK",
      iso3c == "SRB" & year <= 2005 ~ "YUG",
      iso3c == "YEM" & year <= 1989 ~ "YAR",
      TRUE ~ iso3c
    )
  ) |>
  dplyr::select(iso3c, year,
                dplyr::any_of(names(wdi_indicators))) |>
  dplyr::distinct(iso3c, year, .keep_all = TRUE) |>
  dplyr::arrange(iso3c, year)

# ---- Maddison Project Database for pre-1960 GDP ----------------------------
# Maddison provides long-run real GDP per capita estimates back to 1820+.
# For our 1945+ panel, useful primarily for 1945-1960 where WDI is sparse.
# Download from a stable Bolt-Maddison mirror; fall back to WDI-only if
# unavailable.

maddison_url <- "https://www.rug.nl/ggdc/historicaldevelopment/maddison/data/mpd2020.xlsx"
maddison_path <- file.path(DIR_RAW, "maddison_mpd2020.xlsx")
maddison_loaded <- FALSE

if (!file.exists(maddison_path)) {
  message("Trying to fetch Maddison Project Database 2020...")
  tryCatch({
    utils::download.file(maddison_url, destfile = maddison_path,
                         mode = "wb", quiet = TRUE)
  }, error = function(e) message("Maddison download failed: ",
                                  conditionMessage(e)))
}

if (file.exists(maddison_path) && file.size(maddison_path) > 5000) {
  if (!requireNamespace("readxl", quietly = TRUE))
    install.packages("readxl", repos = "https://cloud.r-project.org")
  mad <- tryCatch({
    sheets <- readxl::excel_sheets(maddison_path)
    full_sheet <- intersect(c("Full data", "Data"), sheets)[1]
    if (is.na(full_sheet)) full_sheet <- sheets[2]
    readxl::read_excel(maddison_path, sheet = full_sheet)
  }, error = function(e) NULL)

  if (!is.null(mad)) {
    mad <- dplyr::as_tibble(mad)
    cgdppc_col <- intersect(c("gdppc", "cgdppc", "rgdpnapc"), names(mad))[1]
    countrycode_col <- intersect(c("countrycode", "country_code"),
                                 names(mad))[1]
    year_col_m <- intersect(c("year"), names(mad))[1]
    if (!is.na(cgdppc_col) && !is.na(year_col_m)) {
      mad <- mad |>
        dplyr::filter(.data[[year_col_m]] >= PANEL_YEAR_MIN,
                      .data[[year_col_m]] <= PANEL_YEAR_MAX) |>
        dplyr::mutate(
          iso3c = if (!is.na(countrycode_col))
                    .data[[countrycode_col]]
                  else
                    countrycode::countrycode(country, "country.name", "iso3c",
                                             warn = FALSE)
        ) |>
        dplyr::filter(!is.na(iso3c)) |>
        dplyr::transmute(
          iso3c,
          year = as.integer(.data[[year_col_m]]),
          gdp_pc_maddison = as.numeric(.data[[cgdppc_col]])
        ) |>
        dplyr::distinct(iso3c, year, .keep_all = TRUE)
      maddison_loaded <- TRUE
      message(sprintf("Maddison loaded: %d rows", nrow(mad)))
    }
  }
}

if (maddison_loaded) {
  controls <- controls |>
    dplyr::left_join(mad, by = c("iso3c", "year"))
}

assert_unique_country_year(controls)

# ---- Coverage diagnostics --------------------------------------------------

spine <- load_intermediate("spine")
joined <- spine |> dplyr::left_join(controls, by = c("iso3c", "year"))
cov <- joined |>
  dplyr::summarise(
    spine_rows  = dplyr::n(),
    with_gdp    = sum(!is.na(gdp_pc_ppp) | !is.na(gdp_pc_const)),
    with_pop    = sum(!is.na(population)),
    with_area   = sum(!is.na(area_km2)),
    with_urban  = sum(!is.na(urban_pop_pct)),
    with_trade  = sum(!is.na(trade_pct_gdp)),
    pct_gdp     = round(100 * mean(!is.na(gdp_pc_ppp) | !is.na(gdp_pc_const)), 1),
    pct_pop     = round(100 * mean(!is.na(population)), 1),
    pct_urban   = round(100 * mean(!is.na(urban_pop_pct)), 1)
  )
print(cov)

save_intermediate(controls, "controls")
