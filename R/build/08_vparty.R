# 08_vparty.R
# V-Party (V-Dem's party-level dataset) → country-year populism measures.
#
# V-Party is keyed by (country, election_year, party). We aggregate to
# country-election-year, then forward-fill to all panel years up to the
# next election (capped at 10 years to avoid imputing across long gaps).
#
# Variables constructed:
#   vparty_pop_max         max populism (v2xpa_popul) across all parties with
#                          non-zero seat share in the most recent election
#   vparty_pop_govwt       seat-share-weighted mean populism among governing
#                          parties (v2pagovsup in {0, 1, 2})
#   vparty_populist_in_govt 1 if any governing party has populism > 0.5
#   vparty_populist_voteshare  total vote share of parties with populism > 0.5
#   vparty_election_year   year of the source election (so user can see
#                          whether values are fresh or carried)
#
# v2pagovsup coding (V-Party codebook):
#   0 = party leader is chief executive
#   1 = senior partner in coalition
#   2 = junior partner in coalition
#   3 = supports government externally (not in cabinet)
#   4 = opposition
#   5 = no legislative party / not in legislature
#
# Output: data/intermediate/vparty.rds

source(here::here("R", "00_setup.R"))

# ---- Load V-Party ----------------------------------------------------------

if (!requireNamespace("vdemdata", quietly = TRUE)) {
  stop("vdemdata package not installed. Install it first (see 02_vdem.R).")
}

vp <- dplyr::as_tibble(vdemdata::vparty)
message(sprintf("V-Party loaded: %d rows, %d columns", nrow(vp), ncol(vp)))

POPULISM_THRESHOLD <- 0.5
CARRY_FORWARD_MAX <- 10L

# ---- Filter and prep -------------------------------------------------------

vp_slim <- vp |>
  dplyr::select(
    country_name, country_id, country_text_id, year,
    v2xpa_popul, v2paseatshare, v2pavote, v2pagovsup
  ) |>
  dplyr::filter(year >= PANEL_YEAR_MIN, year <= PANEL_YEAR_MAX) |>
  dplyr::filter(!is.na(v2xpa_popul))  # require populism score

# Identify governing parties (in cabinet)
vp_slim <- vp_slim |>
  dplyr::mutate(
    in_govt = v2pagovsup %in% c(0, 1, 2),
    seat_w  = dplyr::coalesce(v2paseatshare, 0)
  )

# ---- Aggregate to (country, election_year) ---------------------------------

ce <- vp_slim |>
  dplyr::group_by(country_id, country_name, country_text_id, year) |>
  dplyr::summarise(
    vparty_pop_max = max(v2xpa_popul, na.rm = TRUE),
    vparty_pop_govwt = {
      gov <- v2xpa_popul[in_govt]
      w   <- seat_w[in_govt]
      if (sum(w, na.rm = TRUE) > 0)
        stats::weighted.mean(gov, w, na.rm = TRUE)
      else
        NA_real_
    },
    vparty_populist_in_govt =
      as.integer(any(in_govt & v2xpa_popul > POPULISM_THRESHOLD, na.rm = TRUE)),
    vparty_populist_voteshare =
      sum(v2pavote[v2xpa_popul > POPULISM_THRESHOLD], na.rm = TRUE),
    .groups = "drop"
  ) |>
  dplyr::rename(election_year = year) |>
  dplyr::mutate(dplyr::across(where(is.numeric),
                              \(x) ifelse(is.infinite(x), NA_real_, x)))

# ---- Map V-Party country_id to iso3c ---------------------------------------

iso_lookup <- countrycode::codelist |>
  dplyr::as_tibble() |>
  dplyr::filter(!is.na(vdem)) |>
  dplyr::select(vdem, iso3c_lookup = iso3c)

ce <- ce |>
  dplyr::left_join(iso_lookup, by = c("country_id" = "vdem")) |>
  dplyr::mutate(
    iso3c = dplyr::coalesce(
      iso3c_lookup,
      countrycode::countrycode(country_text_id, "iso3c", "iso3c",
                               warn = FALSE),
      countrycode::countrycode(country_name, "country.name", "iso3c",
                               warn = FALSE)
    ),
    # Same year-based remap as V-Dem (continuator-code convention)
    iso3c = dplyr::case_when(
      country_text_id == "CZE" & election_year <= 1992 ~ "CSK",
      country_text_id == "SRB" & election_year <= 2005 ~ "YUG",
      country_text_id == "YEM" & election_year <= 1989 ~ "YAR",
      country_text_id == "DDR"                          ~ "DDR",
      country_text_id == "XKX"                          ~ "XKX",
      country_text_id %in% c("PSE", "PSG")              ~ "PSE",
      TRUE ~ iso3c
    )
  ) |>
  dplyr::select(-iso3c_lookup) |>
  dplyr::filter(!is.na(iso3c))

# ---- Forward-fill to all panel years up to next election ------------------
# For each election, expand to (election_year, election_year+1, ...,
# min(next_election - 1, election_year + CARRY_FORWARD_MAX)). Then left-join
# onto the spine so country-years before the first election get NA.

spine <- load_intermediate("spine")

expanded <- ce |>
  dplyr::select(iso3c, election_year,
                vparty_pop_max, vparty_pop_govwt,
                vparty_populist_in_govt, vparty_populist_voteshare) |>
  dplyr::arrange(iso3c, election_year) |>
  dplyr::group_by(iso3c) |>
  dplyr::mutate(
    next_election = dplyr::lead(election_year,
                                default = max(election_year) +
                                          CARRY_FORWARD_MAX + 1L),
    end_year = pmin(next_election - 1L,
                    election_year + CARRY_FORWARD_MAX)
  ) |>
  dplyr::ungroup() |>
  dplyr::rowwise() |>
  dplyr::mutate(year_seq = list(seq.int(election_year, end_year))) |>
  tidyr::unnest(year_seq) |>
  dplyr::ungroup() |>
  dplyr::transmute(
    iso3c,
    year = as.integer(year_seq),
    vparty_pop_max,
    vparty_pop_govwt,
    vparty_populist_in_govt,
    vparty_populist_voteshare,
    vparty_election_year = as.integer(election_year)
  ) |>
  dplyr::filter(year >= PANEL_YEAR_MIN, year <= PANEL_YEAR_MAX) |>
  # Deduplicate in case of overlapping fill windows (shouldn't happen but be safe)
  dplyr::distinct(iso3c, year, .keep_all = TRUE)

fill <- spine |>
  dplyr::select(iso3c, year) |>
  dplyr::left_join(expanded, by = c("iso3c", "year"))

assert_unique_country_year(fill)

# ---- Coverage --------------------------------------------------------------

cov <- fill |>
  dplyr::summarise(
    spine_rows = dplyr::n(),
    with_pop   = sum(!is.na(vparty_pop_max)),
    pct        = round(100 * mean(!is.na(vparty_pop_max)), 1)
  )
print(cov)

message("\nPopulism distribution at country-year level:")
print(fill |>
        dplyr::filter(!is.na(vparty_pop_max)) |>
        dplyr::summarise(
          mean = round(mean(vparty_pop_max, na.rm = TRUE), 3),
          median = round(median(vparty_pop_max, na.rm = TRUE), 3),
          pct_above_0_5 = round(100 * mean(vparty_pop_max > 0.5, na.rm = TRUE), 1)
        ))

save_intermediate(fill, "vparty")
