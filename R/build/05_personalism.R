# 05_personalism.R
# Continuous personalism index for autocracies, from Frantz, Kendall-Taylor,
# Wright, and Geddes. The index is built from ~8 indicators capturing
# concentration of power in the leader (loyalist appointments, custom
# paramilitaries, party founded by leader, etc.) — a graded alternative to
# GWF's binary `gwf_personal` indicator.
#
# Source: Frantz, E., Kendall-Taylor, A., Wright, J., & Xu, X. (2020).
# "Personalization of Power and Mass Uprisings in Dictatorships." British
# Journal of Political Science. Replication data on Harvard Dataverse.
#
# Download path (verify current DOI before relying on it):
#   https://dataverse.harvard.edu/dataset.xhtml?persistentId=doi:10.7910/DVN/UYEQRG
# Or check Joe Wright's data page at https://sites.psu.edu/jaw1/data/
#
# Place the personalism index file in data/raw/. The script accepts:
#   - CSV named like *personalism*.csv or *pid*.csv
#   - DTA named like *personalism*.dta or *pid*.dta
#
# Output: data/intermediate/personalism.rds with iso3c, year,
# personalism_score (continuous), and component indicators if present.

source(here::here("R", "00_setup.R"))

# ---- Locate the personalism file -------------------------------------------

pers_files <- list.files(
  DIR_RAW,
  pattern = "(?i)(personal|^pid).*\\.(csv|dta|rda)$",
  full.names = TRUE
)

if (length(pers_files) == 0) {
  message(
    "Personalism index file not found in ", DIR_RAW, ".\n\n",
    "To proceed:\n",
    "  1. Go to the replication archive for Frantz, Kendall-Taylor, Wright,\n",
    "     Xu (2020) on Harvard Dataverse. Search for ",
    "'Personalization of Power and Mass Uprisings in Dictatorships'.\n",
    "  2. Download the country-year personalism index file ",
    "(continuous 0-1 score).\n",
    "  3. Save into ", DIR_RAW, " with 'personalism' or 'pid' in the filename.\n",
    "  4. Re-run this script.\n\n",
    "Alternative: check Joe Wright's data page at ",
    "https://sites.psu.edu/jaw1/data/ for an updated version."
  )
  # Soft exit: write an empty intermediate so downstream merge tolerates absence.
  empty_personalism <- tibble::tibble(
    iso3c = character(),
    year = integer(),
    personalism_score = numeric()
  )
  save_intermediate(empty_personalism, "personalism")
  message("\nWrote empty personalism.rds as placeholder. ",
          "Download the file and re-run to populate.")
  quit(status = 0)
}

f <- pers_files[1]
message("Reading personalism from: ", basename(f))

pers <- if (grepl("\\.csv$", f, ignore.case = TRUE)) {
  readr::read_csv(f, show_col_types = FALSE)
} else if (grepl("\\.dta$", f, ignore.case = TRUE)) {
  if (!requireNamespace("haven", quietly = TRUE))
    install.packages("haven", repos = "https://cloud.r-project.org")
  haven::read_dta(f)
} else {
  load_env <- new.env()
  load(f, envir = load_env)
  get(ls(load_env)[1], envir = load_env)
}
pers <- dplyr::as_tibble(pers)

message(sprintf("Personalism loaded: %d rows, %d columns",
                nrow(pers), ncol(pers)))
message("Columns: ", paste(names(pers), collapse = ", "))

# ---- Identify columns -------------------------------------------------------
# The Frantz et al. dataset uses different column names across versions.
# Probe for known patterns.

year_col <- intersect(c("year"), names(pers))[1]
# Primary score: latent_personalism (latent variable model).
# Alt: pers_2pl (IRT 2-parameter logistic).
score_col <- intersect(
  c("latent_personalism", "pers_2pl",
    "personalism", "personalism_index", "personal_score", "pers_index",
    "x_personal", "personalism_score"),
  names(pers)
)[1]
score_se_col <- intersect(c("pers_se_2pl"), names(pers))[1]
score_alt_col <- intersect(c("pers_2pl"), names(pers))[1]
if (!is.na(score_alt_col) && identical(score_col, score_alt_col)) {
  score_alt_col <- NA_character_  # don't double-count
}
cown_col <- intersect(c("cowcode", "cown", "ccode", "cow"), names(pers))[1]
name_col <- intersect(c("country", "country_name", "gwf_country"),
                      names(pers))[1]

if (is.na(score_col)) {
  warning("Could not identify personalism-score column. ",
          "Inspect names(pers) and adjust this script. ",
          "Saving an empty file.")
  save_intermediate(
    tibble::tibble(iso3c = character(), year = integer(),
                   personalism_score = numeric()),
    "personalism"
  )
  quit(status = 0)
}

message(sprintf("Detected: year=%s, score=%s, cown=%s, name=%s",
                year_col, score_col, cown_col, name_col))

# ---- Map to iso3c (with the spine's historical-state convention) -----------

pers <- pers |>
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
  pers <- pers |>
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
        TRUE ~ iso3c
      )
    )
}

# ---- Slim and save ---------------------------------------------------------

pers_out <- pers |>
  dplyr::filter(!is.na(iso3c)) |>
  dplyr::filter(.data[[year_col]] >= PANEL_YEAR_MIN,
                .data[[year_col]] <= PANEL_YEAR_MAX) |>
  dplyr::transmute(
    iso3c,
    year = as.integer(.data[[year_col]]),
    personalism_score = as.numeric(.data[[score_col]]),
    personalism_se    = if (!is.na(score_se_col))
                          as.numeric(.data[[score_se_col]]) else NA_real_,
    personalism_alt   = if (!is.na(score_alt_col))
                          as.numeric(.data[[score_alt_col]]) else NA_real_
  ) |>
  dplyr::distinct(iso3c, year, .keep_all = TRUE) |>
  dplyr::arrange(iso3c, year)

assert_unique_country_year(pers_out)

# Coverage diagnostic
spine <- load_intermediate("spine")
joined <- spine |> dplyr::left_join(pers_out, by = c("iso3c", "year"))
cov <- joined |>
  dplyr::summarise(
    spine_rows = dplyr::n(),
    with_pers  = sum(!is.na(personalism_score)),
    pct        = round(100 * mean(!is.na(personalism_score)), 1)
  )
print(cov)

save_intermediate(pers_out, "personalism")
