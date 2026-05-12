# 00_setup.R
# Loaded at the top of every build script. Sets paths, loads core packages,
# defines small helpers used across the build.
#
# Usage at the top of a build script:
#   source(here::here("R", "00_setup.R"))

# ---- Packages ---------------------------------------------------------------

required_packages <- c(
  "here",          # project-relative paths
  "dplyr",         # data manipulation
  "tidyr",         # pivots
  "readr",         # fast csv io
  "purrr",         # functional helpers
  "stringr",       # string helpers
  "tibble",        # tibbles
  "countrycode"    # country code crosswalks + state-system panel
)

install_if_missing <- function(pkgs) {
  to_install <- setdiff(pkgs, rownames(installed.packages()))
  if (length(to_install)) {
    message("Installing missing packages: ", paste(to_install, collapse = ", "))
    install.packages(to_install, repos = "https://cloud.r-project.org")
  }
}

install_if_missing(required_packages)
invisible(lapply(required_packages, library, character.only = TRUE))

# ---- Paths ------------------------------------------------------------------

PROJ        <- here::here()
DIR_RAW     <- file.path(PROJ, "data", "raw")
DIR_INTER   <- file.path(PROJ, "data", "intermediate")
DIR_FINAL   <- file.path(PROJ, "data", "final")
DIR_DOCS    <- file.path(PROJ, "docs")

# ---- Panel scope ------------------------------------------------------------

PANEL_YEAR_MIN <- 1945L
PANEL_YEAR_MAX <- 2024L
MICROSTATE_POP_THRESHOLD <- 500000L

# ---- Helpers ----------------------------------------------------------------

# Save an intermediate object as .rds with a consistent naming scheme.
save_intermediate <- function(obj, name) {
  stopifnot(is.character(name), length(name) == 1L)
  path <- file.path(DIR_INTER, paste0(name, ".rds"))
  saveRDS(obj, path)
  message(sprintf("Saved %d rows to %s", nrow(obj), path))
  invisible(path)
}

# Read an intermediate previously saved by save_intermediate().
load_intermediate <- function(name) {
  path <- file.path(DIR_INTER, paste0(name, ".rds"))
  if (!file.exists(path)) {
    stop("Intermediate not found: ", path,
         "\nDid you run the upstream build script?")
  }
  readRDS(path)
}

# Fail loudly if a country-year keyed table has duplicates.
assert_unique_country_year <- function(df,
                                       country_col = "iso3c",
                                       year_col = "year") {
  dups <- df |>
    dplyr::count(.data[[country_col]], .data[[year_col]]) |>
    dplyr::filter(n > 1L)
  if (nrow(dups) > 0) {
    print(utils::head(dups, 10))
    stop(sprintf("Duplicate %s-%s pairs found (showing up to 10).",
                 country_col, year_col))
  }
  invisible(df)
}
