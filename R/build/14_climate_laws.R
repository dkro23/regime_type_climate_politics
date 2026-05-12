# 14_climate_laws.R
# Climate Change Laws of the World (Grantham/LSE).
#
# Source: https://climate-laws.org/ — bulk CSV export contains every law
# and policy in the database with country, year passed, instrument type
# (legislative / executive), topic (mitigation/adaptation/DRM/etc.), sector.
#
# Aggregated to country-year:
#   n_climate_laws_year   # new climate laws/policies passed in year y
#   cum_climate_laws      # running total to year y
#   n_mitigation_year     # new mitigation policies in year y
#   n_adaptation_year     # new adaptation policies in year y
#   cum_mitigation
#   cum_adaptation
#
# Output: data/intermediate/climate_laws.rds

source(here::here("R", "00_setup.R"))

# ---- Download / locate -----------------------------------------------------

raw_path <- file.path(DIR_RAW, "climate-laws.csv")
if (!file.exists(raw_path)) {
  message("Downloading Climate Change Laws of the World...")
  candidate_urls <- c(
    "https://climate-laws.org/cclw-laws-export.csv",
    "https://climate-laws.org/api/laws/export.csv",
    "https://www.climate-laws.org/cclw-laws-export.csv"
  )
  for (url in candidate_urls) {
    message("Trying: ", url)
    ok <- tryCatch({
      utils::download.file(url, destfile = raw_path, mode = "wb", quiet = TRUE)
      file.size(raw_path) > 5000
    }, error = function(e) FALSE)
    if (isTRUE(ok)) { message("Downloaded from: ", url); break }
    if (file.exists(raw_path)) file.remove(raw_path)
  }
}

if (!file.exists(raw_path)) {
  message(
    "Could not auto-download CCLW. To proceed:\n",
    "  1. Visit https://climate-laws.org/\n",
    "  2. Find the bulk CSV export (usually under 'Data' or 'Download').\n",
    "  3. Save as ", raw_path, "\n",
    "  4. Re-run this script."
  )
  save_intermediate(
    tibble::tibble(iso3c = character(), year = integer(),
                   n_climate_laws_year = integer(),
                   cum_climate_laws = integer()),
    "climate_laws"
  )
  quit(status = 0)
}

ccl <- readr::read_csv(raw_path, show_col_types = FALSE) |>
  dplyr::as_tibble()
message(sprintf("CCLW loaded: %d rows, %d columns", nrow(ccl), ncol(ccl)))
message("Columns (head 25): ",
        paste(head(names(ccl), 25), collapse = ", "))

# ---- Identify needed columns ----------------------------------------------

year_col <- intersect(c("year", "date_passed", "first_event_date"),
                      names(ccl))[1]
country_col <- intersect(c("country", "country_name", "geography"),
                         names(ccl))[1]
iso_col <- intersect(c("iso", "iso3", "iso3c", "country_iso",
                       "geography_iso"), names(ccl))[1]
type_col <- intersect(c("type", "instrument_type", "law_type",
                        "document_type"), names(ccl))[1]
topic_col <- intersect(c("topic", "topics", "responses",
                         "categories", "frameworks"), names(ccl))[1]

# Save raw for inspection — final aggregation may need column-specific tuning
# once we see the actual schema.
save_intermediate(ccl, "climate_laws_raw")
message("\nSaved raw CCLW to data/intermediate/climate_laws_raw.rds.")
message(sprintf("Detected columns: year=%s, country=%s, iso=%s, type=%s, topic=%s",
                year_col, country_col, iso_col, type_col, topic_col))

# ---- If we have year + country, do basic aggregation ----------------------

if (!is.na(year_col) && (!is.na(country_col) || !is.na(iso_col))) {
  agg <- ccl |>
    dplyr::mutate(
      year_passed = suppressWarnings(as.integer(
        substr(as.character(.data[[year_col]]), 1, 4)
      ))
    ) |>
    dplyr::filter(!is.na(year_passed),
                  year_passed >= 1900, year_passed <= PANEL_YEAR_MAX) |>
    dplyr::mutate(
      iso3c = dplyr::coalesce(
        if (!is.na(iso_col)) as.character(.data[[iso_col]]) else NA_character_,
        if (!is.na(country_col)) countrycode::countrycode(
            .data[[country_col]], "country.name", "iso3c", warn = FALSE
        ) else NA_character_
      )
    ) |>
    dplyr::filter(!is.na(iso3c))

  by_iso_year <- agg |>
    dplyr::count(iso3c, year_passed, name = "n_climate_laws_year") |>
    dplyr::rename(year = year_passed)

  # Expand to all panel years per iso3c, cumulate
  spine <- load_intermediate("spine")
  laws <- spine |>
    dplyr::select(iso3c, year) |>
    dplyr::left_join(by_iso_year, by = c("iso3c", "year")) |>
    dplyr::mutate(
      n_climate_laws_year = dplyr::coalesce(n_climate_laws_year, 0L)
    ) |>
    dplyr::group_by(iso3c) |>
    dplyr::arrange(year) |>
    dplyr::mutate(cum_climate_laws = cumsum(n_climate_laws_year)) |>
    dplyr::ungroup() |>
    dplyr::arrange(iso3c, year)

  assert_unique_country_year(laws)

  cov <- laws |>
    dplyr::summarise(
      spine_rows = dplyr::n(),
      with_any_law = sum(cum_climate_laws > 0),
      total_laws = max(cum_climate_laws),
      first_law_year = min(year[n_climate_laws_year > 0])
    )
  print(cov)

  save_intermediate(laws, "climate_laws")
} else {
  message("Could not identify year/country columns in CCLW. ",
          "Inspect data/intermediate/climate_laws_raw.rds and re-run with ",
          "explicit column names.")
}
