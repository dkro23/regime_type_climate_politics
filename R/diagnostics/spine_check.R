# spine_check.R
# Quick verification of the country-year spine: state-system splits,
# regional coverage, and a few smell tests. Run after 01_country_spine.R.

suppressPackageStartupMessages(library(dplyr))

sp <- readRDS(file.path(here::here(), "data", "intermediate", "spine.rds"))

cat("== State-system check: years present ==\n")
check_iso <- function(iso) {
  yrs <- sp |> filter(iso3c == iso) |> pull(year)
  if (length(yrs) == 0) {
    cat(sprintf("  %s: NOT IN SPINE\n", iso))
  } else {
    cat(sprintf("  %s: %d-%d (n=%d)\n", iso, min(yrs), max(yrs), length(yrs)))
  }
}
for (i in c(
  "SUN", "RUS",                  # USSR / Russia
  "YUG", "SRB", "MNE", "HRV",    # Yugoslavia / successors
  "CSK", "CZE", "SVK",           # Czechoslovakia / successors
  "DEU", "DDR",                  # Germanys
  "YEM", "YMD",                  # Yemens
  "SDN", "SSD",                  # Sudan / South Sudan
  "TLS", "ERI",                  # late 20th c. independence
  "XKX", "PSE",                  # contested status (added manually)
  "TWN"                          # Taiwan
)) check_iso(i)

cat("\n== Coverage by region ==\n")
print(sp |> count(region))

cat("\n== ID coverage (non-NA share) ==\n")
sp |>
  summarise(
    cown_pct  = round(mean(!is.na(cown))  * 100, 1),
    gwn_pct   = round(mean(!is.na(gwn))   * 100, 1),
    vdem_pct  = round(mean(!is.na(vdem_country_id)) * 100, 1)
  ) |>
  print()

cat("\n== Year coverage (countries per year, sample) ==\n")
sp |>
  filter(year %in% c(1945, 1960, 1980, 1991, 2000, 2024)) |>
  count(year) |>
  print()
