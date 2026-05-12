# 03_bmr.R
# Boix-Miller-Rosato dichotomous democracy classification (1800-2020).
#
# Source: Boix, Miller, Rosato. "A complete data set of political regimes,
# 1800-2007", plus updates. Current public version covers through 2020.
#
# Access: easiest path is the `democracyData` R package by Xavier Marquez,
# which bundles BMR cleanly. Fallback: download from
# https://sites.google.com/site/mkmtwo/data and place CSV in data/raw/.
#
# Output: data/intermediate/bmr.rds with iso3c, year, democracy_bmr.

source(here::here("R", "00_setup.R"))

# ---- Load BMR ---------------------------------------------------------------

bmr <- NULL

# Strategy 1: download the .rda directly from the democracyData GitHub repo.
# Avoids installing the full democracyData package (which has hard dependencies
# that don't work on older R versions).
rda_path <- file.path(DIR_RAW, "bmr.rda")
if (!file.exists(rda_path)) {
  message("Downloading BMR .rda from democracyData GitHub repo...")
  tryCatch({
    utils::download.file(
      "https://github.com/xmarquez/democracyData/raw/master/data/bmr.rda",
      destfile = rda_path, mode = "wb", quiet = FALSE
    )
  }, error = function(e) {
    message("Download failed: ", conditionMessage(e))
  })
}
if (file.exists(rda_path)) {
  load_env <- new.env()
  load(rda_path, envir = load_env)
  obj_name <- ls(load_env)[1]
  bmr <- get(obj_name, envir = load_env)
  message("BMR loaded from ", rda_path, " (object: ", obj_name, ")")
}

# Strategy 2: CSV in data/raw (user-provided fallback)
if (is.null(bmr)) {
  csv_candidates <- list.files(DIR_RAW,
                               pattern = "^.*[Bb][Mm][Rr].*\\.csv$|^democracy.*\\.csv$",
                               full.names = TRUE)
  if (length(csv_candidates) > 0) {
    message("Reading BMR from CSV: ", basename(csv_candidates[1]))
    bmr <- readr::read_csv(csv_candidates[1], show_col_types = FALSE)
  }
}

if (is.null(bmr)) {
  stop("Could not load BMR. Either ensure network access for GitHub download, ",
       "or place a BMR CSV in ", DIR_RAW)
}

bmr <- dplyr::as_tibble(bmr)
message(sprintf("BMR loaded: %d rows, %d columns", nrow(bmr), ncol(bmr)))
message("Columns: ", paste(names(bmr), collapse = ", "))

# ---- Identify the democracy variable ---------------------------------------
# Column names differ between versions / packages. Check known candidates.

dem_col <- intersect(c("democracy", "democracy_bmr", "bmr_democracy", "dem"),
                     names(bmr))[1]
if (is.na(dem_col)) {
  stop("Could not find BMR democracy column. Available: ",
       paste(names(bmr), collapse = ", "))
}

year_col <- intersect(c("year"), names(bmr))[1]

# Map to iso3c via COW code (BMR's `cown`), falling back to GW code and
# then to country name.
name_col <- intersect(c("bmr_country", "extended_country_name",
                        "country_name", "country"), names(bmr))[1]

bmr <- bmr |>
  dplyr::mutate(
    iso3c_from_cown = if ("cown" %in% names(bmr))
        countrycode::countrycode(.data$cown, "cown", "iso3c", warn = FALSE)
      else NA_character_,
    iso3c_from_gwn  = if ("GWn" %in% names(bmr))
        countrycode::countrycode(.data$GWn, "gwn", "iso3c", warn = FALSE)
      else NA_character_,
    iso3c_from_name = if (!is.na(name_col))
        countrycode::countrycode(.data[[name_col]], "country.name", "iso3c",
                                 warn = FALSE)
      else NA_character_,
    iso3c = dplyr::coalesce(iso3c_from_cown, iso3c_from_gwn, iso3c_from_name)
  ) |>
  dplyr::select(-iso3c_from_cown, -iso3c_from_gwn, -iso3c_from_name)

# BMR uses continuator codes; apply same year-based remap as V-Dem.
bmr <- bmr |>
  dplyr::mutate(
    iso3c = dplyr::case_when(
      iso3c == "CZE" & .data[[year_col]] <= 1992 ~ "CSK",
      iso3c == "SRB" & .data[[year_col]] <= 2005 ~ "YUG",
      iso3c == "YEM" & .data[[year_col]] <= 1989 ~ "YAR",
      grepl("YEMEN.*SOUTH|SOUTH.*YEMEN|YEMEN.*PEOPLE|PEOPLE.*YEMEN|PDR YEMEN",
            .data[[name_col]], ignore.case = TRUE) ~ "YMD",
      grepl("YEMEN.*NORTH|NORTH.*YEMEN|YEMEN ARAB",
            .data[[name_col]], ignore.case = TRUE) ~ "YAR",
      grepl("GERMANY.*EAST|EAST.*GERMANY|GERMAN DEMOCRATIC",
            .data[[name_col]], ignore.case = TRUE) ~ "DDR",
      grepl("CZECHOSLOVAK",
            .data[[name_col]], ignore.case = TRUE) ~ "CSK",
      grepl("YUGOSLAV",
            .data[[name_col]], ignore.case = TRUE) ~ "YUG",
      grepl("KOSOVO",
            .data[[name_col]], ignore.case = TRUE) ~ "XKX",
      TRUE ~ iso3c
    )
  )

# ---- Trim to panel window, dedupe, save ------------------------------------

bmr_out <- bmr |>
  dplyr::filter(!is.na(iso3c)) |>
  dplyr::filter(.data[[year_col]] >= PANEL_YEAR_MIN,
                .data[[year_col]] <= PANEL_YEAR_MAX) |>
  dplyr::transmute(
    iso3c,
    year = as.integer(.data[[year_col]]),
    democracy_bmr = as.integer(.data[[dem_col]])
  ) |>
  dplyr::distinct(iso3c, year, .keep_all = TRUE) |>
  dplyr::arrange(iso3c, year)

# Forward-fill 2021-2024: BMR ends in 2020. No major regime changes likely
# to flip democracy/autocracy in that window for most countries, but flag
# this with an indicator.
last_year_bmr <- max(bmr_out$year)
message(sprintf("BMR data extends to %d", last_year_bmr))

if (last_year_bmr < PANEL_YEAR_MAX) {
  fill_rows <- bmr_out |>
    dplyr::group_by(iso3c) |>
    dplyr::filter(year == max(year)) |>
    dplyr::ungroup() |>
    tidyr::uncount(PANEL_YEAR_MAX - year, .id = "offset") |>
    dplyr::mutate(year = year + as.integer(offset)) |>
    dplyr::select(iso3c, year, democracy_bmr) |>
    dplyr::mutate(bmr_extended = TRUE)

  bmr_out <- bmr_out |>
    dplyr::mutate(bmr_extended = FALSE) |>
    dplyr::bind_rows(fill_rows) |>
    dplyr::arrange(iso3c, year)
} else {
  bmr_out$bmr_extended <- FALSE
}

assert_unique_country_year(bmr_out)

# ---- Coverage check against spine ------------------------------------------

spine <- load_intermediate("spine")
joined <- spine |>
  dplyr::left_join(bmr_out, by = c("iso3c", "year"))

cov_summary <- joined |>
  dplyr::summarise(
    spine_rows    = dplyr::n(),
    with_bmr      = sum(!is.na(democracy_bmr)),
    pct_with_bmr  = round(100 * mean(!is.na(democracy_bmr)), 1)
  )
print(cov_summary)

# Spine iso3c codes with no BMR coverage
no_cov <- spine |>
  dplyr::anti_join(bmr_out, by = "iso3c") |>
  dplyr::distinct(iso3c, country_name)
if (nrow(no_cov) > 0) {
  message("\nSpine iso3c codes with no BMR rows:")
  print(no_cov)
}

save_intermediate(bmr_out, "bmr")
