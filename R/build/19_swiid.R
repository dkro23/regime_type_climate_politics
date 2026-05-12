# 19_swiid.R
# SWIID (Standardized World Income Inequality Database) by Frederick Solt.
# Country-year Gini estimates of disposable (net) and market income inequality,
# harmonized from many primary sources via multiple imputation.
#
# Source: Solt, Frederick. The Standardized World Income Inequality Database.
# Harvard Dataverse, current version: https://doi.org/10.7910/DVN/LM4OWF
#
# We use the "summary" file (point estimate + SE per country-year) rather
# than the 100-imputation full set. That's sufficient for v1 panel
# regressions; the user can substitute the full multiple imputations later
# if they want proper uncertainty propagation.
#
# Output: data/intermediate/swiid.rds

source(here::here("R", "00_setup.R"))

# ---- Locate / download SWIID summary ---------------------------------------
# Solt hosts the SWIID summary on his GitHub (fsolt/swiid) and Harvard Dataverse.
# The github raw URL is stable; the Dataverse file UID rotates with versions.

swiid_path <- file.path(DIR_RAW, "swiid_summary.rds")
candidate_urls <- c(
  "https://github.com/fsolt/swiid/raw/master/data/swiid_summary.rda",
  "https://github.com/fsolt/swiid/raw/master/data/swiid9_8_summary.rda",
  "https://github.com/fsolt/swiid/raw/master/data/swiid9_7_summary.rda",
  "https://github.com/fsolt/swiid/raw/main/data/swiid_summary.rda"
)

# Helper: extract the summary data.frame from a SWIID .rda. The .rda
# typically contains two objects: `swiid` (list of 100 imputations) and
# `swiid_summary` (a single data.frame with point estimates and SEs).
load_swiid_rda <- function(path) {
  load_env <- new.env()
  load(path, envir = load_env)
  objs <- ls(load_env)
  pref <- intersect(c("swiid_summary", "summary", "swiid"), objs)
  if (length(pref) == 0) pref <- objs
  for (n in pref) {
    obj <- get(n, envir = load_env)
    if (is.data.frame(obj) ||
        inherits(obj, "draws_summary") ||
        inherits(obj, "tbl_df")) {
      return(as.data.frame(obj))
    }
  }
  NULL
}

swiid <- NULL

if (!file.exists(swiid_path)) {
  rda_path <- file.path(DIR_RAW, "swiid_summary.rda")
  for (url in candidate_urls) {
    message("Trying: ", url)
    ok <- tryCatch({
      utils::download.file(url, destfile = rda_path, mode = "wb", quiet = TRUE)
      file.size(rda_path) > 5000
    }, error = function(e) FALSE)
    if (isTRUE(ok)) { message("Downloaded from: ", url); break }
    if (file.exists(rda_path)) file.remove(rda_path)
  }
  if (file.exists(rda_path)) {
    swiid <- load_swiid_rda(rda_path)
    if (!is.null(swiid)) saveRDS(swiid, swiid_path)
  }
} else {
  swiid <- readRDS(swiid_path)
}

# Fallback: user-provided file
if (is.null(swiid)) {
  cands <- list.files(DIR_RAW,
                      pattern = "(?i)swiid.*\\.(csv|rds|rda)$",
                      full.names = TRUE)
  if (length(cands)) {
    f <- cands[1]
    message("Reading SWIID from: ", basename(f))
    swiid <- if (grepl("\\.csv$", f, ignore.case = TRUE)) {
      readr::read_csv(f, show_col_types = FALSE)
    } else if (grepl("\\.rds$", f, ignore.case = TRUE)) {
      readRDS(f)
    } else {
      load_swiid_rda(f)
    }
  }
}

if (is.null(swiid)) {
  message("Could not load SWIID. Download from ",
          "https://github.com/fsolt/swiid or ",
          "https://doi.org/10.7910/DVN/LM4OWF and place ",
          "swiid_summary.rda in ", DIR_RAW)
  save_intermediate(
    tibble::tibble(iso3c = character(), year = integer(),
                   gini_net = numeric(), gini_market = numeric()),
    "swiid"
  )
  quit(status = 0)
}

swiid <- dplyr::as_tibble(swiid)
message(sprintf("SWIID loaded: %d rows, %d columns",
                nrow(swiid), ncol(swiid)))
message("Columns: ", paste(names(swiid), collapse = ", "))

# ---- Identify columns -----------------------------------------------------

year_col <- intersect(c("year"), names(swiid))[1]
net_col   <- intersect(c("gini_disp", "gini_net", "gini_disposable"),
                       names(swiid))[1]
net_se    <- intersect(c("gini_disp_se", "gini_net_se",
                         "gini_disposable_se", "se_gini_disp"), names(swiid))[1]
mkt_col   <- intersect(c("gini_mkt", "gini_market"), names(swiid))[1]
mkt_se    <- intersect(c("gini_mkt_se", "gini_market_se", "se_gini_mkt"),
                       names(swiid))[1]
country_col <- intersect(c("country", "country_name"), names(swiid))[1]

message(sprintf("Detected: year=%s, gini_net=%s, gini_market=%s, country=%s",
                year_col, net_col, mkt_col, country_col))

# ---- Map iso3c, slim ------------------------------------------------------

swiid_out <- swiid |>
  dplyr::mutate(
    iso3c = countrycode::countrycode(.data[[country_col]],
                                     "country.name", "iso3c", warn = FALSE)
  ) |>
  dplyr::filter(!is.na(iso3c)) |>
  dplyr::filter(.data[[year_col]] >= PANEL_YEAR_MIN,
                .data[[year_col]] <= PANEL_YEAR_MAX) |>
  dplyr::mutate(
    iso3c = dplyr::case_when(
      iso3c == "CZE" & .data[[year_col]] <= 1992 ~ "CSK",
      iso3c == "SRB" & .data[[year_col]] <= 2005 ~ "YUG",
      iso3c == "YEM" & .data[[year_col]] <= 1989 ~ "YAR",
      grepl("CZECHOSLOVAK", .data[[country_col]], ignore.case = TRUE) ~ "CSK",
      grepl("YUGOSLAV",    .data[[country_col]], ignore.case = TRUE) ~ "YUG",
      grepl("GERMAN.*DEMO", .data[[country_col]], ignore.case = TRUE) ~ "DDR",
      grepl("YEMEN.*ARAB|NORTH.*YEMEN", .data[[country_col]], ignore.case = TRUE) ~ "YAR",
      grepl("SOUTH.*YEMEN|YEMEN.*PEOP", .data[[country_col]], ignore.case = TRUE) ~ "YMD",
      TRUE ~ iso3c
    )
  ) |>
  dplyr::transmute(
    iso3c,
    year = as.integer(.data[[year_col]]),
    gini_net      = if (!is.na(net_col)) as.numeric(.data[[net_col]]) else NA_real_,
    gini_net_se   = if (!is.na(net_se))  as.numeric(.data[[net_se]])  else NA_real_,
    gini_market   = if (!is.na(mkt_col)) as.numeric(.data[[mkt_col]]) else NA_real_,
    gini_market_se= if (!is.na(mkt_se))  as.numeric(.data[[mkt_se]])  else NA_real_
  ) |>
  dplyr::distinct(iso3c, year, .keep_all = TRUE) |>
  dplyr::arrange(iso3c, year)

assert_unique_country_year(swiid_out)

# ---- Coverage --------------------------------------------------------------

spine <- load_intermediate("spine")
joined <- spine |> dplyr::left_join(swiid_out, by = c("iso3c", "year"))
cov <- joined |>
  dplyr::summarise(
    spine_rows = dplyr::n(),
    with_net   = sum(!is.na(gini_net)),
    with_mkt   = sum(!is.na(gini_market)),
    pct_net    = round(100 * mean(!is.na(gini_net)), 1),
    pct_mkt    = round(100 * mean(!is.na(gini_market)), 1)
  )
print(cov)

save_intermediate(swiid_out, "swiid")
