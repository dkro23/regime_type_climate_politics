# Regime Type and Climate Politics

Country-year panel and analysis testing how regime type, regime subtype,
personalism, polarization, and inequality shape climate policy outcomes.

## Theoretical framing

Selectorate-theoretic. Democracies, with larger winning coalitions and
electoral accountability, have stronger incentives than autocracies to
provide public goods with diffuse, long-horizon benefits (lower emissions,
renewables build-out). Within autocracies, more institutionalized regimes
(parties, legislatures) should behave more like democracies on this margin
than personalist regimes. Within democracies, polarization and inequality
should both undermine policy ambition.

### Hypotheses

1. **H1.** Autocracies will be less likely to reduce CO₂ emissions than democracies.
2. **H2.** More institutionalized autocracies (party-based, less personalist)
   will be more likely to reduce CO₂ emissions than less institutionalized ones.
3. **H3.** More polarized and more unequal democracies will be less likely
   to reduce CO₂ emissions than less polarized and more equal democracies.

## What's in the panel

**10,807 country-years × 169 sovereign states × 1945–2024 × 114 variables.**

Sources merged into the country-year spine:

| Source | What it provides |
|---|---|
| V-Dem v15 | Regime classification (RoW), continuous democracy indices, polarization, authoritarian-institution indicators |
| Boix-Miller-Rosato | Dichotomous democracy (1800–2020) |
| Geddes-Wright-Frantz | Autocratic regime subtypes (party / military / personalist / monarchy) |
| Frantz et al. (2020) | Continuous personalism index for autocracies |
| Polity5 (via democracyData) | Polity2 score for robustness |
| V-Party | Country-year populism measures |
| OWID CO₂ + Energy | Emissions, oil/gas production & consumption, renewable shares |
| UN Treaty Collection | Paris Agreement signature/ratification |
| World Bank WDI + Maddison | GDP, population, area, urban concentration, trade, resource rents |
| SWIID (Solt) | Gini (net and market) |

See `PLAN.md` for the full source-by-source rationale and `docs/codebook.md`
for variable-level documentation.

## Repository layout

```
.
├── PLAN.md                       # scope, sources, scoping decisions
├── README.md                     # this file
├── promt.txt                     # original framing prompt
├── R/
│   ├── 00_setup.R                # packages, paths, helpers
│   ├── build/                    # data-build pipeline (01 → 99)
│   ├── analysis/                 # analysis prep + hypothesis tests
│   │   ├── 00_prep.R             # log transforms, change DVs, factor IVs
│   │   ├── helpers.R             # shared model + plot utilities
│   │   ├── 01_bmr_co2.R          # BMR × 3 CO2 metrics, 4 specs each
│   │   ├── 02_subtypes_co2.R     # regime subtype × CO2 (OLS + controls)
│   │   ├── 03_changes_bmr.R      # H1 — BMR on log/Δ/% CO2
│   │   ├── 04_changes_party_aut.R   # H2 — party autocracy
│   │   ├── 05_changes_personalism.R # H2 — personalism
│   │   ├── 06_changes_polarization.R# H3 — polarization
│   │   └── 07_changes_gini.R        # H3 — Gini net
│   └── diagnostics/              # coverage report, spine sanity check
├── data/
│   ├── raw/                      # source downloads (gitignored)
│   ├── intermediate/             # one .rds per source (gitignored)
│   └── final/                    # merged panel.{rds,csv} (gitignored)
└── docs/
    ├── codebook.md               # variable-by-variable documentation
    └── *.png                     # analysis plots
```

## Reproducing the build

1. **Install R 4.3+** and clone the repo.

2. **Download manually** (URLs aren't reliable; place each in `data/raw/`):
   - V-Dem: handled automatically by `vdemdata` GitHub package install
   - BMR, GWF, Polity, SWIID: handled automatically from `democracyData`/`fsolt` GitHub raw URLs
   - **Personalism index**: download `GWF+personalism-scores.csv` from the Frantz/Kendall-Taylor/Wright/Xu (2020) replication archive (Harvard Dataverse) into `data/raw/`
   - **SWIID**: download `swiid9_92.rda` from https://doi.org/10.7910/DVN/LM4OWF into `data/raw/`

3. **Run the build pipeline in order:**

```r
for (f in c("01_country_spine.R","02_vdem.R","03_bmr.R",
            "04_gwf_subtypes.R","05_personalism.R","06_polity.R",
            "08_vparty.R","10_emissions.R","11_energy.R",
            "16_treaties.R","18_controls.R","19_swiid.R",
            "99_merge.R")) {
  source(here::here("R","build", f))
}
```

This produces `data/final/panel.rds` and `panel.csv`.

4. **Generate the codebook + coverage report:**

```r
source(here::here("R","diagnostics","coverage_report.R"))
# Codebook is already at docs/codebook.md.
```

5. **Run analyses:**

```r
source(here::here("R","analysis","00_prep.R"))
for (f in c("01_bmr_co2.R","02_subtypes_co2.R",
            "03_changes_bmr.R","04_changes_party_aut.R",
            "05_changes_personalism.R","06_changes_polarization.R",
            "07_changes_gini.R")) {
  source(here::here("R","analysis", f))
}
```

All charts land in `docs/`, tidy estimates in `data/intermediate/`.

## Current analyses

| Script | Test | IV | Sample | Notes |
|---|---|---|---|---|
| `01_bmr_co2.R` | BMR × CO₂ levels | democracy_bmr | full | 4 specs (OLS, +ctrl, TWFE, TWFE+ctrl) × 3 DVs (level, per-cap, per-GDP) |
| `02_subtypes_co2.R` | Regime subtype × CO₂ levels | regime_subtype (democracy ref) | full | OLS+ctrl; coefficients vs. democracy baseline |
| `03_changes_bmr.R` | **H1** | democracy_bmr | full | OLS+ctrl × 3 DVs (log, Δ, %Δ) |
| `04_changes_party_aut.R` | **H2** | party_autocracy | autocracies | binary: regime_subtype == "party" |
| `05_changes_personalism.R` | **H2** | personalism_score | autocracies (1946–2010) | Frantz et al. latent_personalism |
| `06_changes_polarization.R` | **H3** | pol_polarization | democracies | V-Dem v2cacamps |
| `07_changes_gini.R` | **H3** | gini_net | democracies | SWIID disposable-income Gini |

## Scoping decisions made along the way

See `PLAN.md` §7 for the full list. Key ones:

- **Microstate filter:** drops 12 countries with median pop < 500k (incl. Iceland, Luxembourg, Malta).
- **State-system convention:** RUS continuous (includes USSR); DEU continuous; YUG/CSK/DDR/YAR/YMD added as separate iso3c codes with assigned ISO 3166-3-style values.
- **Paris Agreement only** for treaty data — UNFCCC and Kyoto skipped (pre-2000 ratification variation is small; Paris is the live regime).
- **Deferred:** Comparative Constitutions Project, PopuList, climate-laws databases, renewable investment, Ross petroleum, CCPI/EPI — easy to add later if a specific analysis requires them.

## Caveats

- Models without country fixed effects (most of analyses 02–07) mix cross-sectional and within-country variation. Treat as suggestive; cross-check with TWFE specs before drawing strong inferences.
- The personalism index is autocracy-only and ends in 2010. Post-2010 autocracy-years are NA on `regime_subtype` (autocracy portion).
- Paris ratification dates are a v1 approximation based on inline overrides — verify against UN Treaty Collection before publication.
