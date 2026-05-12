# 09_populist_eu.R
# PopuList v3 — expert-classified populist, far-right, far-left, and
# Eurosceptic parties in Europe. Covers 31 European countries, ~1989-2024.
#
# Source: https://popu-list.org/, Rooduijn et al.
#
# Auto-download paths to try (URLs may rotate; user-provided file is the
# safe fallback). Place the populist.org Excel/CSV in data/raw/ with
# 'populist' in the filename.
#
# Output: data/intermediate/populist_eu.rds with iso3c, year,
# populist_in_govt_eu, populist_voteshare_eu, farright_voteshare_eu,
# farleft_voteshare_eu.

source(here::here("R", "00_setup.R"))

# ---- Locate or fetch PopuList ---------------------------------------------

pop_files <- list.files(
  DIR_RAW,
  pattern = "(?i)populist.*\\.(csv|xlsx?)$|popu-?list.*\\.(csv|xlsx?)$",
  full.names = TRUE
)

if (length(pop_files) == 0) {
  message("PopuList file not found in ", DIR_RAW, ".\n",
          "Try auto-download...")
  candidate_urls <- c(
    "https://popu-list.org/wp-content/uploads/2024/07/populist3.0.xlsx",
    "https://popu-list.org/wp-content/uploads/2023/01/populist3.0.xlsx",
    "https://popu-list.org/wp-content/uploads/2024/03/PopuList-3.0.xlsx"
  )
  dest <- file.path(DIR_RAW, "populist.xlsx")
  for (url in candidate_urls) {
    message("Trying: ", url)
    ok <- tryCatch({
      utils::download.file(url, destfile = dest, mode = "wb", quiet = TRUE)
      file.size(dest) > 5000
    }, error = function(e) FALSE)
    if (isTRUE(ok)) { message("Downloaded from: ", url); break }
    if (file.exists(dest)) file.remove(dest)
  }
  pop_files <- list.files(DIR_RAW,
                          pattern = "(?i)populist.*\\.(csv|xlsx?)$",
                          full.names = TRUE)
}

if (length(pop_files) == 0) {
  message(
    "Could not auto-download PopuList.\n",
    "To proceed:\n",
    "  1. Visit https://popu-list.org/ and download the PopuList dataset ",
    "(Excel or CSV).\n",
    "  2. Save to ", DIR_RAW, " with 'populist' in the filename.\n",
    "  3. Re-run this script."
  )
  save_intermediate(
    tibble::tibble(iso3c = character(), year = integer(),
                   populist_in_govt_eu = integer(),
                   populist_voteshare_eu = numeric()),
    "populist_eu"
  )
  quit(status = 0)
}

f <- pop_files[1]
message("Reading PopuList from: ", basename(f))

if (grepl("\\.csv$", f, ignore.case = TRUE)) {
  pl <- readr::read_csv(f, show_col_types = FALSE)
} else {
  if (!requireNamespace("readxl", quietly = TRUE))
    install.packages("readxl", repos = "https://cloud.r-project.org")
  # PopuList Excel files typically have multiple sheets; try the most
  # likely names, fall back to the first sheet with substantial data.
  sheets <- readxl::excel_sheets(f)
  message("Sheets: ", paste(sheets, collapse = ", "))
  preferred <- intersect(c("Data", "Parties", "PopuList", "Sheet1"), sheets)
  sheet <- if (length(preferred)) preferred[1] else sheets[1]
  message("Reading sheet: ", sheet)
  pl <- readxl::read_excel(f, sheet = sheet)
}
pl <- dplyr::as_tibble(pl)

message(sprintf("PopuList loaded: %d rows, %d columns", nrow(pl), ncol(pl)))
message("Columns (head 30): ",
        paste(head(names(pl), 30), collapse = ", "))

save_intermediate(pl, "populist_eu_raw")  # save raw for inspection
message("\nSaved raw PopuList to data/intermediate/populist_eu_raw.rds.\n",
        "Inspect column structure and re-run script with parsing tuned ",
        "to the actual schema.")
