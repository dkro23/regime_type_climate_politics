# 16_treaties.R
# Paris Agreement ratification panel.
#
# The Paris Agreement opened for signature on 22 April 2016 and entered
# into force on 4 November 2016. Most parties ratified in 2016. We embed
# a static lookup with the default ratification year and explicit overrides
# for late ratifiers, non-ratifiers, and the US withdrawal episode.
#
# Variables produced:
#   paris_signed        1 if country has signed the Paris Agreement (by year y)
#   paris_signed_year   year of signature (NA if never)
#   paris_ratified      1 if country had ratified by year y (accounting for withdrawal)
#   paris_ratify_year   year of first ratification (NA if never)
#   paris_withdrew      1 if country has ever withdrawn (US only as of 2024)
#
# Source: UN Treaty Collection (treaties.un.org), UNFCCC parties list, and
# UNFCCC NDC Registry. This is a v1 approximation; refine from primary
# sources for publication.
#
# Output: data/intermediate/treaties.rds

source(here::here("R", "00_setup.R"))

# ---- Default and override tables ------------------------------------------

DEFAULT_PARIS_RATIFY_YEAR <- 2016L

# Late ratifiers and special cases (verify against UN Treaty Collection
# before relying on for publication).
paris_overrides <- tibble::tribble(
  ~iso3c, ~ratify_year, ~note,
  "RUS",  2019L,        "Russia ratified 7 Oct 2019",
  "TUR",  2021L,        "Turkey ratified 7 Oct 2021 (last G20)",
  "IRQ",  2021L,        "Iraq ratified 1 Feb 2021",
  "LBY",  2021L,        "Libya ratified 12 Aug 2021",
  "ERI",  2018L,        "Eritrea ratified 7 Feb 2018",
  "YEM",  2017L,        "Yemen ratified 22 Mar 2017",
  "LBN",  2020L,        "Lebanon ratified 5 Feb 2020",
  "AGO",  2020L,        "Angola ratified 4 Sept 2020",
  "TZA",  2018L,        "Tanzania ratified 18 May 2018",
  "MMR",  2017L,        "Myanmar ratified 19 Sept 2017",
  "GNQ",  2018L,        "Equatorial Guinea ratified 30 Oct 2018",
  "TJK",  2017L,        "Tajikistan ratified 22 Mar 2017",
  "MRT",  2017L,        "Mauritania ratified 27 Feb 2017",
  "JOR",  2016L,        "Jordan ratified 4 Nov 2016",
  "ZWE",  2017L,        "Zimbabwe ratified 7 Aug 2017",
  "SOM",  2016L,        "Somalia ratified 22 Apr 2016 (early)",
  "DZA",  2016L,        "Algeria ratified 20 Oct 2016",
  "OMN",  2019L,        "Oman ratified 22 May 2019",
  "EGY",  2017L,        "Egypt ratified 29 June 2017",
  "PAK",  2016L,        "Pakistan ratified 10 Nov 2016",
  "KAZ",  2016L,        "Kazakhstan ratified 6 Dec 2016",
  "VEN",  2017L,        "Venezuela ratified 21 July 2017",
  "NIC",  2017L,        "Nicaragua ratified 23 Oct 2017"
)

# Non-ratifiers as of 2024 (signed but not ratified, or not party).
paris_non_ratifiers <- c(
  "IRN"   # Iran: signed 22 Apr 2016, has not ratified
)

# Non-signers: countries that haven't signed at all. As of 2024 this is
# essentially empty among UN members for the Paris Agreement. Holy See
# and some non-state actors are observer parties. Our microstate filter
# already removes them, so we don't enumerate here.

# US withdrawal episode
us_withdraw_year <- 2020L   # withdrawal effective 4 Nov 2020
us_rejoin_year   <- 2021L   # Biden rejoined 19 Feb 2021

# ---- Build the panel ------------------------------------------------------

spine <- load_intermediate("spine")

# Identify countries to include (those that should plausibly be parties).
# We use spine iso3c codes that exist as of 2024.
countries_2024 <- spine |>
  dplyr::filter(year == 2024) |>
  dplyr::pull(iso3c) |>
  unique()

# Historical states (YUG, CSK, DDR, YAR, YMD) cannot be Paris parties
# (the agreement was opened in 2016, after they dissolved). Their rows
# should have paris_ratified = NA.

# Default ratify year by iso3c
ratify_lookup <- tibble::tibble(iso3c = countries_2024) |>
  dplyr::left_join(paris_overrides, by = "iso3c") |>
  dplyr::mutate(
    ratify_year = dplyr::case_when(
      iso3c %in% paris_non_ratifiers ~ NA_integer_,
      is.na(ratify_year)             ~ DEFAULT_PARIS_RATIFY_YEAR,
      TRUE                           ~ ratify_year
    ),
    signed_year = pmin(ratify_year, 2016L, na.rm = TRUE)  # signed at or before ratification; most signed Apr 22 2016
  )

# Build paris_ratified panel, with USA withdrawal handled.
build_paris_rows <- function(iso, ratify_y, signed_y) {
  if (is.na(ratify_y) && is.na(signed_y)) {
    return(tibble::tibble(
      iso3c = iso, year = PANEL_YEAR_MIN:PANEL_YEAR_MAX,
      paris_signed = 0L, paris_signed_year = NA_integer_,
      paris_ratified = 0L, paris_ratify_year = NA_integer_,
      paris_withdrew = 0L
    ))
  }
  yrs <- PANEL_YEAR_MIN:PANEL_YEAR_MAX
  signed <- as.integer(yrs >= signed_y)
  ratified <- if (is.na(ratify_y)) integer(length(yrs)) else
                as.integer(yrs >= ratify_y)
  if (iso == "USA") {
    in_withdrawal <- yrs == us_withdraw_year
    ratified <- ifelse(in_withdrawal, 0L, ratified)
  }
  tibble::tibble(
    iso3c = iso,
    year = yrs,
    paris_signed = signed,
    paris_signed_year = if (is.na(signed_y)) NA_integer_ else as.integer(signed_y),
    paris_ratified = ratified,
    paris_ratify_year = if (is.na(ratify_y)) NA_integer_ else as.integer(ratify_y),
    paris_withdrew = as.integer(iso == "USA" & yrs >= us_withdraw_year)
  )
}

panel_rows <- purrr::pmap_dfr(
  list(ratify_lookup$iso3c,
       ratify_lookup$ratify_year,
       ratify_lookup$signed_year),
  build_paris_rows
)

# Pre-2016 rows should have paris_* as NA (Paris Agreement didn't exist yet)
treaties <- spine |>
  dplyr::select(iso3c, year) |>
  dplyr::left_join(panel_rows, by = c("iso3c", "year")) |>
  dplyr::mutate(
    paris_signed = ifelse(year < 2016, NA_integer_, paris_signed),
    paris_ratified = ifelse(year < 2016, NA_integer_, paris_ratified),
    paris_withdrew = ifelse(year < 2016, NA_integer_, paris_withdrew)
  )

assert_unique_country_year(treaties)

# ---- Diagnostics ----------------------------------------------------------

cov <- treaties |>
  dplyr::filter(year >= 2016) |>
  dplyr::group_by(year) |>
  dplyr::summarise(
    n_parties_signed = sum(paris_signed, na.rm = TRUE),
    n_parties_ratified = sum(paris_ratified, na.rm = TRUE),
    .groups = "drop"
  )
print(cov)

message(sprintf(
  "Paris ratification snapshot 2024: %d signed, %d ratified, %d withdrew (out of %d countries).",
  sum(treaties$paris_signed[treaties$year == 2024], na.rm = TRUE),
  sum(treaties$paris_ratified[treaties$year == 2024], na.rm = TRUE),
  sum(treaties$paris_withdrew[treaties$year == 2024], na.rm = TRUE),
  length(unique(treaties$iso3c[treaties$year == 2024]))
))

save_intermediate(treaties, "treaties")
