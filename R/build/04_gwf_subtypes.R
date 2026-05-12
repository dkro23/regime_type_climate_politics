# 04_gwf_subtypes.R
# Geddes-Wright-Frantz autocratic regimes (1946-2010), used to build
# a 5-category regime_subtype variable: democracy / party / military /
# personalist / monarchy.
#
# Source: Geddes, Wright, Frantz. "Autocratic Breakdown and Regime
# Transitions: A New Data Set" (2014). Dataset version 1.2.
#   sites.psu.edu/dictators
#
# Easiest access: GWF.rda from xmarquez/democracyData GitHub repo, same
# pattern we used for BMR. Falls back to user-provided file in data/raw/.
#
# Output: data/intermediate/gwf.rds with iso3c, year, gwf_regime,
# gwf_personalist, gwf_party, gwf_military, gwf_monarch indicators, plus
# the assembled 5-cat regime_subtype that combines GWF (autocracies) with
# V-Dem RoW (democracies).

source(here::here("R", "00_setup.R"))

# ---- Load GWF ---------------------------------------------------------------

gwf <- NULL

# Try several plausible filenames in the democracyData repo.
rda_path <- file.path(DIR_RAW, "GWF.rda")
candidate_urls <- c(
  "https://github.com/xmarquez/democracyData/raw/master/data/GWF.rda",
  "https://github.com/xmarquez/democracyData/raw/master/data/gwf.rda",
  "https://github.com/xmarquez/democracyData/raw/master/data/GWFtscs.rda",
  "https://github.com/xmarquez/democracyData/raw/master/data/gwf_all.rda"
)

if (!file.exists(rda_path)) {
  for (url in candidate_urls) {
    message("Trying: ", url)
    ok <- tryCatch({
      utils::download.file(url, destfile = rda_path, mode = "wb", quiet = TRUE)
      file.size(rda_path) > 1000
    }, error = function(e) FALSE)
    if (isTRUE(ok)) {
      message("Downloaded from: ", url)
      break
    } else if (file.exists(rda_path)) {
      file.remove(rda_path)
    }
  }
}

if (file.exists(rda_path)) {
  load_env <- new.env()
  load(rda_path, envir = load_env)
  obj_name <- ls(load_env)[1]
  gwf <- get(obj_name, envir = load_env)
  message("GWF loaded from ", rda_path, " (object: ", obj_name, ")")
}

# Fallback: any GWF csv/dta the user has placed in data/raw
if (is.null(gwf)) {
  csv_candidates <- list.files(DIR_RAW,
                               pattern = "(?i)gwf.*\\.(csv|dta)$",
                               full.names = TRUE)
  if (length(csv_candidates) > 0) {
    f <- csv_candidates[1]
    message("Reading GWF from: ", basename(f))
    if (grepl("\\.csv$", f, ignore.case = TRUE)) {
      gwf <- readr::read_csv(f, show_col_types = FALSE)
    } else if (grepl("\\.dta$", f, ignore.case = TRUE)) {
      if (!requireNamespace("haven", quietly = TRUE))
        install.packages("haven", repos = "https://cloud.r-project.org")
      gwf <- haven::read_dta(f)
    }
  }
}

if (is.null(gwf)) {
  stop("Could not load GWF. Download the Autocratic Regimes 1.2 dataset ",
       "from https://sites.psu.edu/dictators/ (or get the Stata file from ",
       "the replication archive) and place it in ", DIR_RAW)
}

gwf <- dplyr::as_tibble(gwf)
message(sprintf("GWF loaded: %d rows, %d columns", nrow(gwf), ncol(gwf)))
message("Columns: ", paste(names(gwf), collapse = ", "))

# ---- Identify columns -------------------------------------------------------

# Year column
year_col <- intersect(c("year"), names(gwf))[1]

# Regime type column (varies by version)
regime_col <- intersect(c("gwf_regimetype", "gwf_regime", "regimetype",
                          "gwf_full_regimetype"),
                        names(gwf))[1]

# Country identifier
cown_col <- intersect(c("cowcode", "cown", "ccode"), names(gwf))[1]
name_col <- intersect(c("gwf_country", "country", "country_name"), names(gwf))[1]

# Sanity check what we found
message(sprintf("Detected columns: year=%s, regime=%s, cown=%s, name=%s",
                year_col, regime_col, cown_col, name_col))

# ---- Map to iso3c -----------------------------------------------------------

gwf <- gwf |>
  dplyr::mutate(
    iso3c = dplyr::coalesce(
      if (!is.na(cown_col)) countrycode::countrycode(.data[[cown_col]],
                                                     "cown", "iso3c",
                                                     warn = FALSE)
        else NA_character_,
      if (!is.na(name_col)) countrycode::countrycode(.data[[name_col]],
                                                     "country.name", "iso3c",
                                                     warn = FALSE)
        else NA_character_
    )
  ) |>
  dplyr::mutate(
    iso3c = dplyr::case_when(
      iso3c == "CZE" & .data[[year_col]] <= 1992 ~ "CSK",
      iso3c == "SRB" & .data[[year_col]] <= 2005 ~ "YUG",
      iso3c == "YEM" & .data[[year_col]] <= 1989 ~ "YAR",
      !is.na(name_col) & grepl("YEMEN.*SOUTH|SOUTH.*YEMEN|YEMEN.*PEOPLE|PDR",
                               .data[[name_col]], ignore.case = TRUE) ~ "YMD",
      !is.na(name_col) & grepl("YEMEN.*NORTH|NORTH.*YEMEN|YEMEN ARAB",
                               .data[[name_col]], ignore.case = TRUE) ~ "YAR",
      !is.na(name_col) & grepl("GERMANY.*EAST|EAST.*GERMANY|GERMAN DEMOCRATIC",
                               .data[[name_col]], ignore.case = TRUE) ~ "DDR",
      !is.na(name_col) & grepl("CZECHOSLOVAK", .data[[name_col]],
                               ignore.case = TRUE) ~ "CSK",
      !is.na(name_col) & grepl("YUGOSLAV", .data[[name_col]],
                               ignore.case = TRUE) ~ "YUG",
      TRUE ~ iso3c
    )
  )

# ---- Recode to 4-category GWF regime ----------------------------------------
# GWF has many hybrid categories (e.g., "party-personal", "military-personal").
# We collapse to dominant type, following the convention of using the FIRST
# component of hybrid types when assigning a binary indicator for each type.

if (!is.na(regime_col)) {
  rtype <- tolower(as.character(gwf[[regime_col]]))
  gwf <- gwf |>
    dplyr::mutate(
      gwf_regime_raw = .data[[regime_col]],
      gwf_party      = as.integer(grepl("party",       rtype)),
      gwf_military   = as.integer(grepl("military",    rtype)),
      gwf_personal   = as.integer(grepl("personal",    rtype)),
      gwf_monarch    = as.integer(grepl("monarch",     rtype)),
      # Dominant 4-cat: prefer personalism > military > party > monarchy
      # for hybrid cases, since personalization tends to drive policy.
      # User can re-derive any other ordering from the binary indicators.
      gwf_regime = dplyr::case_when(
        gwf_personal == 1L  ~ "personalist",
        gwf_military == 1L  ~ "military",
        gwf_party    == 1L  ~ "party",
        gwf_monarch  == 1L  ~ "monarchy",
        grepl("warlord|provisional|foreign", rtype) ~ "other_autocracy",
        TRUE ~ NA_character_
      )
    )
}

# ---- Slim and dedupe --------------------------------------------------------

gwf_out <- gwf |>
  dplyr::filter(!is.na(iso3c)) |>
  dplyr::filter(.data[[year_col]] >= PANEL_YEAR_MIN,
                .data[[year_col]] <= PANEL_YEAR_MAX) |>
  dplyr::transmute(
    iso3c,
    year = as.integer(.data[[year_col]]),
    gwf_regime,
    gwf_regime_raw,
    gwf_party, gwf_military, gwf_personal, gwf_monarch
  ) |>
  dplyr::distinct(iso3c, year, .keep_all = TRUE) |>
  dplyr::arrange(iso3c, year)

assert_unique_country_year(gwf_out)

# ---- Build 5-cat regime_subtype combining GWF + V-Dem RoW -------------------
# For democracies (V-Dem RoW >= 2), code as "democracy". For autocracies,
# use GWF's classification. For autocracy-years missing from GWF (post-2010
# or pre-coding), leave NA so the user can decide whether to forward-fill
# from last GWF observation.

spine <- load_intermediate("spine")
vdem  <- load_intermediate("vdem")

regime_subtype_tbl <- spine |>
  dplyr::select(iso3c, year) |>
  dplyr::left_join(
    vdem |> dplyr::select(iso3c, year, regimes_of_the_world),
    by = c("iso3c", "year")
  ) |>
  dplyr::left_join(gwf_out, by = c("iso3c", "year")) |>
  dplyr::mutate(
    regime_subtype = dplyr::case_when(
      regimes_of_the_world %in% c(2, 3) ~ "democracy",
      !is.na(gwf_regime)                ~ gwf_regime,
      TRUE                              ~ NA_character_
    )
  ) |>
  dplyr::select(iso3c, year, regime_subtype)

# Merge subtype back onto gwf_out for the unified intermediate
gwf_final <- spine |>
  dplyr::select(iso3c, year) |>
  dplyr::left_join(gwf_out, by = c("iso3c", "year")) |>
  dplyr::left_join(regime_subtype_tbl, by = c("iso3c", "year"))

# ---- Coverage diagnostics ---------------------------------------------------

cov <- gwf_final |>
  dplyr::summarise(
    spine_rows         = dplyr::n(),
    with_gwf_regime    = sum(!is.na(gwf_regime)),
    with_regime_subtype = sum(!is.na(regime_subtype)),
    pct_subtype        = round(100 * mean(!is.na(regime_subtype)), 1)
  )
print(cov)

message("\nRegime subtype distribution:")
print(gwf_final |>
        dplyr::filter(!is.na(regime_subtype)) |>
        dplyr::count(regime_subtype) |>
        dplyr::mutate(pct = round(100 * n / sum(n), 1)))

save_intermediate(gwf_final, "gwf")
