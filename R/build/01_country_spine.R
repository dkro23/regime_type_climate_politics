# 01_country_spine.R
# Build the country-year spine for the panel: 1945-2024.
#
# Approach:
#   1. Use countrycode::codelist_panel for iso3c-keyed states, filtering to
#      years where the state was actually a member of the COW or G-W state
#      system (cown OR gwn non-NA). This automatically truncates late-
#      independence states (Eritrea, East Timor, Namibia, post-Soviet,
#      Yugoslav successors, Czechoslovak successors).
#   2. Add historical states (Yugoslavia, Czechoslovakia, East Germany,
#      North Yemen, South Yemen) as separate units with assigned iso3c codes
#      using ISO 3166-3 / informal conventions. codelist_panel includes
#      these as iso3c-NA rows with cown/gwn filled.
#   3. Manually add Kosovo (XKX, 2008+) and Palestine (PSE, 1994+).
#   4. Apply a preliminary microstate filter; refined later via WDI population.
#
# State-system conventions used (documented for downstream consistency):
#   - RUS treated as continuator of USSR (1945-2024 continuous). For analyses
#     that need to distinguish USSR (regime change in 1991), use V-Dem or
#     GWF regime-transition flags rather than splitting iso3c.
#   - DEU treated as continuous 1945-2024. The 1945-1948 occupation period
#     and 1949-1989 West Germany are both DEU. DDR 1949-1990 added separately.
#   - YEM (unified) restricted to 1990+ via cown filter; YAR (North) and
#     YMD (South) added as historical states.
#   - SRB restricted to 2006+ via gwn filter; YUG covers 1945-2006
#     (SFRY 1945-1991, FRY 1992-2003, Serbia-Montenegro 2003-2006).
#
# Output: data/intermediate/spine.rds
#   Columns: iso3c, year, country_name, cown, cowc, gwn, gwc,
#            vdem_country_id, region, subregion, state_status

source(here::here("R", "00_setup.R"))

# ---- Step 1: iso3c-keyed states from codelist_panel ------------------------

panel_iso <- countrycode::codelist_panel |>
  dplyr::as_tibble() |>
  dplyr::filter(year >= PANEL_YEAR_MIN, year <= PANEL_YEAR_MAX) |>
  dplyr::filter(!is.na(iso3c)) |>
  dplyr::filter(!is.na(cown) | !is.na(gwn)) |>  # actual state-system membership
  dplyr::mutate(state_status = "iso3c_member") |>
  dplyr::select(
    iso3c, year,
    country_name = country.name.en,
    cown, cowc, gwn, gwc,
    vdem_country_id = vdem,
    region, subregion = region23,
    state_status
  )

# ---- Step 1b: forward-fill 2020-2024 ---------------------------------------
# countrycode v1.8.0's codelist_panel populates cown/gwn only through 2020,
# so the membership filter above leaves a 2021-2024 gap for currently-extant
# states. No state dissolutions occurred in that window, so we forward-fill
# the most recent year's metadata for any iso3c whose last covered year is
# 2020. This is flagged with state_status = "iso3c_member_extended" so it can
# be inspected and reverted when countrycode releases an update.

last_year_per_iso <- panel_iso |>
  dplyr::group_by(iso3c) |>
  dplyr::summarise(last_year = max(year), .groups = "drop")

extension_rows <- panel_iso |>
  dplyr::semi_join(
    dplyr::filter(last_year_per_iso, last_year < PANEL_YEAR_MAX),
    by = "iso3c"
  ) |>
  dplyr::group_by(iso3c) |>
  dplyr::filter(year == max(year)) |>
  dplyr::ungroup()

extension_expanded <- extension_rows |>
  tidyr::uncount(PANEL_YEAR_MAX - year, .id = "offset") |>
  dplyr::mutate(year = year + as.integer(offset)) |>
  dplyr::select(-offset) |>
  dplyr::mutate(state_status = "iso3c_member_extended")

panel_iso <- dplyr::bind_rows(panel_iso, extension_expanded)


# Pull rows with iso3c-NA but valid state-system codes, assign iso3c codes,
# and bound to the years each state actually existed.

# Spec table: which historical states to include and their year bounds.
historical_specs <- tibble::tribble(
  ~iso3c, ~country_match,                ~start_year, ~end_year,
  "YUG",  "Yugoslavia",                  1945L,       2006L,
  "CSK",  "Czechoslovakia",              1945L,       1992L,
  "DDR",  "German Democratic Republic",  1949L,       1990L,
  "YAR",  "Yemen Arab Republic",         1945L,       1990L,
  "YMD",  "Yemen People's Republic",     1967L,       1989L
)

# Extract historical-state rows from codelist_panel by exact country.name.en match.
# Drop the NA iso3c column from codelist_panel before the join so the assigned
# iso3c from historical_specs survives without name collision.
panel_hist <- countrycode::codelist_panel |>
  dplyr::as_tibble() |>
  dplyr::filter(is.na(iso3c)) |>
  dplyr::select(-iso3c) |>
  dplyr::filter(country.name.en %in% historical_specs$country_match) |>
  dplyr::filter(!is.na(cown) | !is.na(gwn)) |>
  dplyr::inner_join(historical_specs,
                    by = c("country.name.en" = "country_match")) |>
  dplyr::filter(year >= start_year, year <= end_year) |>
  dplyr::mutate(state_status = "historical_state") |>
  dplyr::select(
    iso3c,
    year,
    country_name = country.name.en,
    cown, cowc, gwn, gwc,
    vdem_country_id = vdem,
    region, subregion = region23,
    state_status
  )

# Sanity check: every historical state we asked for should be present.
hist_present <- unique(panel_hist$iso3c)
hist_missing <- setdiff(historical_specs$iso3c, hist_present)
if (length(hist_missing) > 0) {
  warning("Historical states not found in codelist_panel: ",
          paste(hist_missing, collapse = ", "))
}

# ---- Step 3: manual additions (Kosovo, Palestine) --------------------------
# Reasons documented in PLAN.md §7. Region values pulled from codelist
# (static) where available.

manual_specs <- tibble::tribble(
  ~iso3c, ~country_name, ~start_year, ~end_year, ~region_override,            ~subregion_override,
  "XKX",  "Kosovo",      2008L,       2024L,     "Europe & Central Asia",     "Southern Europe",
  "PSE",  "Palestine",   1994L,       2024L,     "Middle East & North Africa", "Western Asia"
)

# Static codelist may have iso3c for some manual states (e.g., PSE). Use it
# when present, fall back to the explicit override.
codelist_static <- countrycode::codelist |>
  dplyr::as_tibble() |>
  dplyr::select(iso3c, region_static = region, subregion_static = region23) |>
  dplyr::filter(!is.na(iso3c))

panel_manual <- manual_specs |>
  dplyr::rowwise() |>
  dplyr::mutate(year = list(seq.int(start_year, end_year))) |>
  tidyr::unnest(year) |>
  dplyr::ungroup() |>
  dplyr::left_join(codelist_static, by = "iso3c") |>
  dplyr::transmute(
    iso3c, year, country_name,
    cown = NA_real_, cowc = NA_character_,
    gwn = NA_real_, gwc = NA_character_,
    vdem_country_id = NA_real_,
    region    = dplyr::coalesce(region_static, region_override),
    subregion = dplyr::coalesce(subregion_static, subregion_override),
    state_status = "manual_addition"
  )

# Drop rows where the manual addition duplicates an existing row.
panel_manual <- panel_manual |>
  dplyr::anti_join(
    dplyr::bind_rows(panel_iso, panel_hist) |> dplyr::select(iso3c, year),
    by = c("iso3c", "year")
  )

# ---- Step 4: combine, dedup, microstate filter -----------------------------

spine <- dplyr::bind_rows(panel_iso, panel_hist, panel_manual) |>
  dplyr::distinct(iso3c, year, .keep_all = TRUE) |>
  dplyr::arrange(iso3c, year)

# Preliminary microstate filter (refined after WDI loads in 18_controls.R).
MICROSTATES_PRELIM <- c(
  "AND", "ATG", "DMA", "FSM", "GRD", "KIR", "KNA", "LCA", "LIE",
  "MCO", "MHL", "NRU", "PLW", "SMR", "STP", "SYC", "TON", "TUV",
  "VAT", "VCT", "VUT"
)
spine <- spine |> dplyr::filter(!iso3c %in% MICROSTATES_PRELIM)

assert_unique_country_year(spine)

# ---- Diagnostics -----------------------------------------------------------

n_countries <- dplyr::n_distinct(spine$iso3c)
n_rows      <- nrow(spine)
year_range  <- range(spine$year)

message(sprintf(
  "Spine: %d country-years across %d distinct iso3c, %d-%d.",
  n_rows, n_countries, year_range[1], year_range[2]
))

message("\nState-status breakdown:")
spine |>
  dplyr::count(state_status) |>
  print()

message("\nKey state-system splits — years present:")
key_check <- c(
  "RUS", "SUN",                              # USSR / Russia
  "YUG", "SRB", "MNE", "HRV", "SVN", "BIH",  # Yugoslavia / successors
  "CSK", "CZE", "SVK",                       # Czechoslovakia / successors
  "DEU", "DDR",                              # Germanys
  "YEM", "YAR", "YMD",                       # Yemens
  "SDN", "SSD",                              # Sudan / South Sudan
  "TLS", "ERI", "NAM",                       # Late-independence states
  "XKX", "PSE", "TWN"                        # Contested / manual
)
for (i in key_check) {
  yrs <- spine |> dplyr::filter(iso3c == i) |> dplyr::pull(year)
  if (length(yrs) == 0) {
    message(sprintf("  %s: NOT IN SPINE", i))
  } else {
    message(sprintf("  %s: %d-%d (n=%d)", i, min(yrs), max(yrs), length(yrs)))
  }
}

# ---- Save ------------------------------------------------------------------

save_intermediate(spine, "spine")
