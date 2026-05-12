# 02_vdem.R
# Pull V-Dem data for: regime classification, continuous democracy indices,
# polarization measures, and authoritarian-institution variables.
#
# Data source: V-Dem v15 (released 2025), via the vdemdata R package.
#   remotes::install_github("vdeminstitute/vdemdata")
#
# Fallback if vdemdata install fails: place V-Dem-CY-Full+Others-v15.csv
# into data/raw/ (download from https://v-dem.net/data/the-v-dem-dataset/)
# and the script will read it from there.
#
# Variables pulled (graceful skip if any are missing in the user's version):
#   Identifiers: country_name, country_id, country_text_id, year, COWcode
#   Regime classification:
#     v2x_regime         RoW 4-cat (0=closed aut, 1=elec aut, 2=elec dem, 3=lib dem)
#     v2x_regime_amb     10-cat with ambiguous categories
#   Continuous democracy:
#     v2x_polyarchy, v2x_libdem, v2x_partipdem, v2x_delibdem, v2x_egaldem
#   Polarization:
#     v2cacamps          Political polarization (expert-coded, 1900+)
#     v2smpolsoc         Polarization of society (survey-based, 2000+; may be NA)
#   Authoritarian institutions:
#     v2lgbicam          Legislature: 0=none, 1=unicameral, 2=bicameral
#     v2lgello           Lower chamber elected (0/1)
#     v2psparban         Party ban scale (0-4; higher = more banned)
#     v2elmulpar         Multiparty elections (election-year only)
#     v2juhcind          High court independence
#     v2x_freexp_altinf  Freedom of expression + alt. info composite
#   Built-ins for downstream convenience:
#     e_polity2          V-Dem's merged Polity score (saves a step)
#
# Output: data/intermediate/vdem.rds
#   Keyed by (iso3c, year), joinable to the spine.

source(here::here("R", "00_setup.R"))

# ---- Load V-Dem ------------------------------------------------------------

vdem <- NULL

# Strategy 1: vdemdata package
if (requireNamespace("vdemdata", quietly = TRUE)) {
  message("Loading V-Dem from vdemdata package...")
  vdem <- vdemdata::vdem
} else {
  message("vdemdata package not installed.")
  message("Attempting GitHub install (requires Git)...")
  inst_ok <- tryCatch({
    if (!requireNamespace("remotes", quietly = TRUE)) {
      install.packages("remotes", repos = "https://cloud.r-project.org")
    }
    remotes::install_github("vdeminstitute/vdemdata", upgrade = "never",
                            quiet = FALSE)
    TRUE
  }, error = function(e) { message("Install failed: ", conditionMessage(e)); FALSE })

  if (inst_ok && requireNamespace("vdemdata", quietly = TRUE)) {
    vdem <- vdemdata::vdem
  }
}

# Strategy 2: CSV fallback
if (is.null(vdem)) {
  csv_candidates <- list.files(DIR_RAW,
                               pattern = "^V-Dem-CY-Full.*\\.csv$",
                               full.names = TRUE)
  if (length(csv_candidates) > 0) {
    message("Reading V-Dem from CSV: ", basename(csv_candidates[1]))
    vdem <- readr::read_csv(csv_candidates[1], show_col_types = FALSE)
  }
}

if (is.null(vdem)) {
  stop("Could not load V-Dem. Either:\n",
       "  (a) install the vdemdata package: ",
       "remotes::install_github('vdeminstitute/vdemdata'), or\n",
       "  (b) download V-Dem-CY-Full+Others-v15.csv from ",
       "https://v-dem.net/data/the-v-dem-dataset/ and place it in ",
       DIR_RAW)
}

message(sprintf("V-Dem loaded: %d rows, %d columns",
                nrow(vdem), ncol(vdem)))

# ---- Select target variables (graceful for missing ones) ------------------

target_vars <- c(
  # identifiers
  "country_name", "country_id", "country_text_id", "year", "COWcode",
  # regime classification
  "v2x_regime", "v2x_regime_amb",
  # continuous democracy
  "v2x_polyarchy", "v2x_libdem", "v2x_partipdem",
  "v2x_delibdem", "v2x_egaldem",
  # polarization
  "v2cacamps", "v2smpolsoc",
  # authoritarian institutions
  "v2lgbicam", "v2lgello", "v2psparban",
  "v2elmulpar", "v2juhcind", "v2x_freexp_altinf",
  # built-ins
  "e_polity2"
)

present <- intersect(target_vars, names(vdem))
missing <- setdiff(target_vars, names(vdem))
if (length(missing)) {
  warning("V-Dem variables not found in this version (skipped): ",
          paste(missing, collapse = ", "))
}

vdem_sub <- vdem |>
  dplyr::as_tibble() |>
  dplyr::select(dplyr::all_of(present)) |>
  dplyr::filter(year >= PANEL_YEAR_MIN, year <= PANEL_YEAR_MAX)

# ---- Attach iso3c ---------------------------------------------------------
# V-Dem has its own country_text_id (3-letter codes that mostly match iso3c).
# Use countrycode to convert; fall back to V-Dem's country_id via the
# crosswalk in countrycode::codelist.

iso_from_vdem_id <- countrycode::codelist |>
  dplyr::as_tibble() |>
  dplyr::select(vdem, iso3c_match = iso3c) |>
  dplyr::filter(!is.na(vdem))

vdem_sub <- vdem_sub |>
  dplyr::left_join(iso_from_vdem_id,
                   by = c("country_id" = "vdem")) |>
  dplyr::mutate(
    iso3c = dplyr::coalesce(
      iso3c_match,
      countrycode::countrycode(country_text_id, "iso3c", "iso3c",
                               warn = FALSE),
      countrycode::countrycode(country_name, "country.name", "iso3c",
                               warn = FALSE)
    )
  ) |>
  dplyr::select(-iso3c_match)

# V-Dem v15 uses continuator-code conventions for several states that our
# spine handles as separate units:
#   V-Dem CZE 1918-1992  →  spine CSK (Czechoslovakia)
#   V-Dem CZE 1993+      →  spine CZE (Czech Republic)
#   V-Dem SRB pre-2006   →  spine YUG (Yugoslavia / Serbia-Montenegro)
#   V-Dem SRB 2006+      →  spine SRB (Serbia)
#   V-Dem YEM pre-1990   →  spine YAR (North Yemen / Yemen Arab Republic)
#   V-Dem YEM 1990+      →  spine YEM (unified Yemen)
# Apply these remappings on country_text_id before iso3c assignment.

vdem_sub <- vdem_sub |>
  dplyr::mutate(
    iso3c_remap = dplyr::case_when(
      country_text_id == "CZE" & year <= 1992  ~ "CSK",
      country_text_id == "SRB" & year <= 2005  ~ "YUG",
      country_text_id == "YEM" & year <= 1989  ~ "YAR",
      TRUE                                     ~ NA_character_
    )
  )

# Name-based overrides for entries countrycode can't map.
vdem_name_overrides <- tibble::tribble(
  ~country_name,                       ~iso3c_name_ovr,
  "German Democratic Republic",        "DDR",
  "South Yemen",                       "YMD",
  "Kosovo",                            "XKX",
  "Palestine/British Mandate",         NA_character_,    # pre-1948 mandate, outside spine
  "Palestine/Gaza",                    "PSE",
  "Palestine/West Bank",               "PSE"
)

vdem_sub <- vdem_sub |>
  dplyr::left_join(vdem_name_overrides, by = "country_name") |>
  dplyr::mutate(
    iso3c = dplyr::coalesce(iso3c_remap, iso3c_name_ovr, iso3c)
  ) |>
  dplyr::select(-iso3c_remap, -iso3c_name_ovr)

# ---- Handle multi-row Palestine -------------------------------------------
# V-Dem has separate Palestine/Gaza and Palestine/West Bank entries that both
# map to PSE. Aggregate to a single PSE-year by population-weighted mean if
# population is available, else simple mean. For now: simple mean — this is
# imperfect; documented for the user to revisit.

dup_check <- vdem_sub |>
  dplyr::filter(!is.na(iso3c)) |>
  dplyr::count(iso3c, year) |>
  dplyr::filter(n > 1L)

if (nrow(dup_check) > 0) {
  message(sprintf("Aggregating %d duplicate iso3c-year rows (e.g. PSE).",
                  nrow(dup_check)))
  numeric_cols <- vdem_sub |>
    dplyr::select(dplyr::where(is.numeric)) |>
    dplyr::select(-dplyr::any_of(c("year", "country_id", "COWcode"))) |>
    names()
  vdem_sub <- vdem_sub |>
    dplyr::filter(!is.na(iso3c)) |>
    dplyr::group_by(iso3c, year) |>
    dplyr::summarise(
      country_name = dplyr::first(country_name),
      country_id   = dplyr::first(country_id),
      country_text_id = dplyr::first(country_text_id),
      COWcode      = dplyr::first(COWcode),
      dplyr::across(dplyr::all_of(numeric_cols), \(x) mean(x, na.rm = TRUE)),
      .groups = "drop"
    )
} else {
  vdem_sub <- dplyr::filter(vdem_sub, !is.na(iso3c))
}

# NaN-from-mean cleanup (mean of all-NA = NaN)
vdem_sub <- vdem_sub |>
  dplyr::mutate(dplyr::across(dplyr::where(is.numeric),
                              \(x) ifelse(is.nan(x), NA_real_, x)))

# ---- Coverage check against spine -----------------------------------------

spine <- load_intermediate("spine")
joined <- spine |>
  dplyr::left_join(vdem_sub, by = c("iso3c", "year"))

covered <- joined |>
  dplyr::summarise(
    spine_rows         = dplyr::n(),
    with_vdem          = sum(!is.na(v2x_polyarchy)),
    pct_with_vdem      = round(100 * mean(!is.na(v2x_polyarchy)), 1)
  )
print(covered)

# Which spine iso3c codes have no V-Dem coverage at all?
no_cov <- spine |>
  dplyr::anti_join(vdem_sub, by = "iso3c") |>
  dplyr::distinct(iso3c, country_name)
if (nrow(no_cov) > 0) {
  message("\nSpine iso3c codes with no V-Dem rows:")
  print(no_cov)
}

assert_unique_country_year(vdem_sub)

# Rename to project-standard names
vdem_out <- vdem_sub |>
  dplyr::rename(
    vdem_country_name  = country_name,
    vdem_country_id    = country_id,
    vdem_country_text  = country_text_id,
    vdem_cowcode       = dplyr::any_of("COWcode"),
    regimes_of_the_world = dplyr::any_of("v2x_regime"),
    regime_row_10cat   = dplyr::any_of("v2x_regime_amb"),
    polyarchy          = dplyr::any_of("v2x_polyarchy"),
    libdem             = dplyr::any_of("v2x_libdem"),
    partipdem          = dplyr::any_of("v2x_partipdem"),
    delibdem           = dplyr::any_of("v2x_delibdem"),
    egaldem            = dplyr::any_of("v2x_egaldem"),
    pol_polarization   = dplyr::any_of("v2cacamps"),
    soc_polarization   = dplyr::any_of("v2smpolsoc"),
    legislature_chambers = dplyr::any_of("v2lgbicam"),
    lower_chamber_elected = dplyr::any_of("v2lgello"),
    party_ban          = dplyr::any_of("v2psparban"),
    multiparty_elections = dplyr::any_of("v2elmulpar"),
    high_court_indep   = dplyr::any_of("v2juhcind"),
    freedom_expression = dplyr::any_of("v2x_freexp_altinf"),
    polity2_vdem_merge = dplyr::any_of("e_polity2")
  )

save_intermediate(vdem_out, "vdem")
