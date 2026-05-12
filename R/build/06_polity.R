# 06_polity.R
# Polity5 (Center for Systemic Peace) — used as a robustness check on V-Dem
# and BMR. The 21-point polity2 score is the workhorse measure in pre-V-Dem
# CP research; including it makes findings comparable to older literature.
#
# Source: Center for Systemic Peace, http://www.systemicpeace.org
# Coverage: 1800-2018. Polity5 is no longer actively updated.
#
# Access: democracyData's `polity_pmm` .rda first, then direct CSV/SAV
# from systemicpeace.org, then user-provided file.
#
# Output: data/intermediate/polity.rds with iso3c, year, polity2, durable.

source(here::here("R", "00_setup.R"))

# ---- Load Polity5 ----------------------------------------------------------

polity <- NULL

# Strategy 1: democracyData GitHub .rda (file is named polity_pmm.rda)
rda_path <- file.path(DIR_RAW, "polity.rda")
candidate_urls <- c(
  "https://github.com/xmarquez/democracyData/raw/master/data/polity_pmm.rda",
  "https://github.com/xmarquez/democracyData/raw/master/data/polityIV.rda",
  "https://github.com/xmarquez/democracyData/raw/master/data/polity.rda",
  "https://github.com/xmarquez/democracyData/raw/master/data/PolityIV.rda"
)

if (!file.exists(rda_path)) {
  for (url in candidate_urls) {
    message("Trying: ", url)
    ok <- tryCatch({
      utils::download.file(url, destfile = rda_path, mode = "wb", quiet = TRUE)
      file.size(rda_path) > 1000
    }, error = function(e) FALSE)
    if (isTRUE(ok)) {
      message("Downloaded from: ", url); break
    } else if (file.exists(rda_path)) {
      file.remove(rda_path)
    }
  }
}

if (file.exists(rda_path)) {
  load_env <- new.env()
  load(rda_path, envir = load_env)
  obj_name <- ls(load_env)[1]
  polity <- get(obj_name, envir = load_env)
  message("Polity loaded from ", rda_path, " (object: ", obj_name, ")")
}

# Strategy 2: user-provided file
if (is.null(polity)) {
  cands <- list.files(
    DIR_RAW,
    pattern = "(?i)^p[45]v?.*\\.(csv|sav|xls|xlsx)$|polity.*\\.(csv|sav|xls|xlsx)$",
    full.names = TRUE
  )
  if (length(cands) > 0) {
    f <- cands[1]
    message("Reading Polity from: ", basename(f))
    polity <- if (grepl("\\.csv$", f, ignore.case = TRUE)) {
      readr::read_csv(f, show_col_types = FALSE)
    } else if (grepl("\\.sav$", f, ignore.case = TRUE)) {
      if (!requireNamespace("haven", quietly = TRUE))
        install.packages("haven", repos = "https://cloud.r-project.org")
      haven::read_sav(f)
    } else {
      if (!requireNamespace("readxl", quietly = TRUE))
        install.packages("readxl", repos = "https://cloud.r-project.org")
      readxl::read_excel(f)
    }
  }
}

if (is.null(polity)) {
  stop("Could not load Polity. Download p5v2018 from ",
       "http://www.systemicpeace.org/inscrdata.html and place in ", DIR_RAW)
}

polity <- dplyr::as_tibble(polity)
message(sprintf("Polity loaded: %d rows, %d columns",
                nrow(polity), ncol(polity)))
message("Columns: ", paste(names(polity), collapse = ", "))

# ---- Identify columns ------------------------------------------------------

year_col <- intersect(c("year"), names(polity))[1]
polity2_col <- intersect(c("polity2", "pmm_polity", "polity_score"),
                         names(polity))[1]
durable_col <- intersect(c("durable"), names(polity))[1]
cown_col <- intersect(c("ccode", "cowcode", "cown"), names(polity))[1]
name_col <- intersect(c("country", "country_name", "scode_name",
                        "polity_annual_country", "pmm_country",
                        "extended_country_name"), names(polity))[1]

if (is.na(polity2_col)) {
  warning("Could not find polity2 column. Available: ",
          paste(names(polity), collapse = ", "))
  save_intermediate(
    tibble::tibble(iso3c = character(), year = integer(),
                   polity2 = numeric()),
    "polity"
  )
  quit(status = 0)
}

message(sprintf("Detected: year=%s, polity2=%s, durable=%s, cown=%s, name=%s",
                year_col, polity2_col, durable_col, cown_col, name_col))

# ---- Map to iso3c ----------------------------------------------------------

polity <- polity |>
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
  )

if (!is.na(name_col)) {
  polity <- polity |>
    dplyr::mutate(
      iso3c = dplyr::case_when(
        iso3c == "CZE" & .data[[year_col]] <= 1992 ~ "CSK",
        iso3c == "SRB" & .data[[year_col]] <= 2005 ~ "YUG",
        iso3c == "YEM" & .data[[year_col]] <= 1989 ~ "YAR",
        grepl("YEMEN.*SOUTH|SOUTH.*YEMEN|PDR|PEOPLE.*YEMEN",
              .data[[name_col]], ignore.case = TRUE) ~ "YMD",
        grepl("YEMEN.*NORTH|NORTH.*YEMEN|YEMEN ARAB",
              .data[[name_col]], ignore.case = TRUE) ~ "YAR",
        grepl("GERMANY.*EAST|EAST.*GERMANY|GERMAN DEMOCRATIC",
              .data[[name_col]], ignore.case = TRUE) ~ "DDR",
        grepl("CZECHOSLOVAK", .data[[name_col]], ignore.case = TRUE) ~ "CSK",
        grepl("YUGOSLAV",    .data[[name_col]], ignore.case = TRUE) ~ "YUG",
        grepl("KOSOVO",      .data[[name_col]], ignore.case = TRUE) ~ "XKX",
        TRUE ~ iso3c
      )
    )
}

# ---- Slim, dedupe, save ----------------------------------------------------

polity_out <- polity |>
  dplyr::filter(!is.na(iso3c)) |>
  dplyr::filter(.data[[year_col]] >= PANEL_YEAR_MIN,
                .data[[year_col]] <= PANEL_YEAR_MAX) |>
  dplyr::mutate(
    # Polity uses -66, -77, -88 for interruption/interregnum/transition.
    # Convert to NA for analytical use.
    polity2_clean = ifelse(.data[[polity2_col]] %in% c(-66, -77, -88),
                           NA_real_, as.numeric(.data[[polity2_col]]))
  ) |>
  dplyr::transmute(
    iso3c,
    year = as.integer(.data[[year_col]]),
    polity2 = polity2_clean,
    polity_durable = if (!is.na(durable_col))
                       as.integer(.data[[durable_col]]) else NA_integer_
  ) |>
  dplyr::distinct(iso3c, year, .keep_all = TRUE) |>
  dplyr::arrange(iso3c, year)

assert_unique_country_year(polity_out)

# Coverage check
spine <- load_intermediate("spine")
joined <- spine |> dplyr::left_join(polity_out, by = c("iso3c", "year"))
cov <- joined |>
  dplyr::summarise(
    spine_rows = dplyr::n(),
    with_polity2 = sum(!is.na(polity2)),
    pct = round(100 * mean(!is.na(polity2)), 1)
  )
print(cov)

save_intermediate(polity_out, "polity")
