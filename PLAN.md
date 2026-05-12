# Regime Type and Climate Politics — Data Build Plan

**Goal:** Construct a country-year panel dataset (1945–2024) suitable for testing how regime type and political variables shape climate change politics, with DVs covering emissions, renewable energy (share + investment), fossil-fuel (oil/gas) production and consumption, and participation in international climate agreements.

**Theoretical framing the panel needs to support:** Core hypothesis is selectorate-theoretic — democracies, with larger winning coalitions and electoral accountability, have stronger incentives than autocracies to provide public goods (emissions reductions, renewables) with diffuse, long-horizon benefits. The panel must let the user (a) test the binary democracy/autocracy contrast, (b) disaggregate autocracies by subtype + institutional features (legislatures, parties, personalism), and (c) disaggregate democracies by polarization, populist party strength, and populist incumbency.

**Decisions locked in (from initial scoping):**

- Country scope: **global, excluding microstates** (population threshold: < 500,000 in any panel year → drop)
- Temporal scope: **single panel, 1945–2024**; DVs are `NA` before the underlying regime/data exists (e.g., UNFCCC ratification is `NA` before 1992)
- Populism: **both** PopuList (Europe) and V-Party (global), kept as separate variables; methodological seam documented
- Language: **R**

---

## 1. Conceptual variable map

### 1.1 Dependent variables (climate politics)

**Primary DVs (from user prompt):** carbon emissions, renewable energy investment, renewable share of energy consumption/production, oil and gas production/consumption, international climate agreement participation.

| Construct | Variable name(s) | Source | Coverage |
|---|---|---|---|
| **Emissions** | `co2_total`, `co2_pc`, `ghg_total`, `ghg_pc` | PRIMAP-hist v2.5 (or OWID/GCB) | 1850–2023 |
| Emissions intensity | `co2_per_gdp`, `co2_per_energy` | OWID / IEA | 1965–2023 |
| **Renewable share — primary energy** | `share_renew_primary`, `share_renew_excl_hydro` | OWID / Energy Institute Statistical Review | 1965–2024 |
| **Renewable share — electricity** | `share_renew_elec`, `share_solarwind_elec` | Ember Yearly Electricity Data + IEA | 1985–2024 |
| Renewable generation (level) | `renew_gen_twh`, `solar_gen_twh`, `wind_gen_twh` | Ember + Energy Institute | 1965–2024 |
| **Renewable investment** | `renew_invest_usd`, `renew_invest_pct_gdp` | IRENA Public Finance / BNEF (where licensed); REN21 | 2004+ (uneven) |
| **Oil production / consumption** | `oil_prod_kbd`, `oil_cons_kbd` | Energy Institute Statistical Review (formerly BP) + EIA | 1965–2024 |
| **Natural gas production / consumption** | `gas_prod_bcm`, `gas_cons_bcm` | Energy Institute + EIA | 1970–2024 |
| Fossil-fuel value & dependence (alt) | `oil_rents_pct_gdp`, `gas_rents_pct_gdp`, `fossil_rents_pct_gdp` | WDI; Ross Petroleum Dataset | 1932/1970–present |
| Domestic climate laws (count, cumulative) | `n_climate_laws`, `cum_climate_laws` | Climate Change Laws of the World (Grantham/LSE) | ~1990–2024 |
| Policy count by sector / instrument | `n_mitigation_policies`, `n_adaptation_policies` | Climate Policy Database (NewClimate) | 1990–2024 |
| **UNFCCC ratification** | `unfccc_ratified`, `unfccc_ratify_date`, `unfccc_annex` | UN Treaty Collection | 1992+ |
| **Kyoto Protocol** | `kyoto_signed`, `kyoto_ratified`, `kyoto_ratify_date` | UNFCCC | 1997+ |
| **Paris Agreement** | `paris_signed`, `paris_ratified`, `paris_ratify_date` | UNFCCC | 2015+ |
| NDC submission | `ndc_submitted`, `ndc_first_date`, `ndc_revisions` | Climate Watch | 2015+ |
| Climate performance (composite, alt outcome) | `ccpi_score`, `ccpi_rank` | CCPI (Germanwatch/NewClimate) | 2005+, ~60 countries |
| Environmental performance (broader, alt) | `epi_score` | Yale EPI | 2002+ biennial → annualize |

### 1.2 Independent variables (regime + politics)

**Primary IVs (from user prompt):** dichotomous democracy/autocracy; regime subtype (democracy, one-party, personalist, military, monarchy); presence of authoritarian institutions (constitution, legislature, parties); personalism score; democracy-internal variation via polarization and populist party strength/incumbency.

| Construct | Variable name(s) | Source | Coverage |
|---|---|---|---|
| **Dichotomous regime** | `democracy_bmr` (Boix-Miller-Rosato), `democracy_vdem` (RoW dichotomized at electoral-democracy threshold) | BMR (1800–2020); V-Dem RoW | 1800–2020 / 1789–2024 |
| Master regime classification (4-cat) | `regimes_of_the_world` (closed/electoral autocracy, electoral/liberal democracy) | V-Dem v15 (`v2x_regime`) | 1789–2024 |
| Continuous democracy | `polyarchy`, `libdem`, `partipdem`, `delibdem`, `egaldem` | V-Dem v15 | 1789–2024 |
| **Regime subtype (5-cat across democracies + autocracies)** | `regime_subtype` (democracy, one-party, personalist, military, monarchy) | GWF + extensions; cross-checked with Wahman-Teorell-Hadenius | 1946–~2020 |
| **Authoritarian institutions** | `has_legislature`, `legislature_elected`, `has_parties`, `multi_party_legal`, `has_written_constitution` | V-Dem (`v2lglopst`, `v2lgbicam`, `v2psparban`, `v2elparlel`); CCP (Comparative Constitutions Project) for constitutions | 1789–2024 / 1789–2020 |
| **Personalism score (continuous)** | `personalism_score` | Frantz/Kendall-Taylor/Wright/Geddes (2020) Personalism Index | 1946–2010 (extended in subsequent updates) |
| **Personalist regime (binary)** | `personalist_gwf` | GWF | 1946+ |
| Polity score (robustness) | `polity2` | Polity5 | 1800–2018 |
| Polarization | `pol_polarization` (V-Dem `v2cacamps`), `soc_polarization` (`v2smpolsoc`) | V-Dem | 1900–2024 |
| Party system populism (global) | `vparty_pop_max`, `vparty_pop_govwt`, `vparty_populist_in_govt` | V-Party (V-Dem) | varies, mostly 1970+ |
| Party system populism (Europe) | `populist_in_govt_eu`, `populist_voteshare_eu`, `populist_seatshare_eu` | The PopuList v3 + ParlGov | 1989+ Europe |
| Elections held | `election_year`, `election_type` | NELDA / V-Dem | 1945+ |
| Regime durability | `regime_durability` | Polity5 / GWF | 1945+ |

### 1.3 Controls

User-specified controls: area, population, urban concentration, GDP per capita, plus standard others.

| Construct | Variable name(s) | Source |
|---|---|---|
| **GDP per capita (PPP), GDP total** | `gdp_pc`, `gdp_total` | Maddison Project (long history) + WDI |
| **Population** | `population` | UN WPP 2024 |
| **Land area** | `area_km2` | WDI `AG.LND.TOTL.K2` |
| **Urban concentration** | `urban_pop_pct` (urban % of total), `largest_city_pct_urban` (population in largest city as % of urban) | WDI `SP.URB.TOTL.IN.ZS`, `EN.URB.MCTY.TL.ZS` |
| **Income inequality** | `gini_net`, `gini_market` (post- and pre-redistribution), with SEs | SWIID v9.x (Solt) | 1960+, broad coverage |
| Trade openness | `trade_pct_gdp` | WDI |
| Energy use per capita | `energy_pc` | WDI / IEA |
| Region, sub-region | `region`, `sub_region` | UN M49 |
| Climate vulnerability (optional) | `nd_gain_score` | Notre Dame ND-GAIN | 1995+ |

---

## 2. Country spine

### 2.1 Source

V-Dem country list as the primary spine (broadest CP coverage), augmented with any ISO-3166 sovereign states V-Dem omits. Cross-walked to:

- `iso3c` — primary key
- `cown` (Correlates of War code)
- `vdem_country_id`
- `gw_id` (Gleditsch-Ward, for state-system continuity)

### 2.2 Microstate exclusion rule

Drop country-years where UN WPP population < 500,000. This drops ~30 microstates (Andorra, Antigua, Dominica, Liechtenstein, Marshall Islands, Monaco, Nauru, Palau, Saint Kitts, Saint Vincent, San Marino, Seychelles, Tuvalu, Vatican, etc.) but retains states like Iceland, Malta, Bahamas, Suriname, Cape Verde, Belize.

### 2.3 State system handling

- **Pre/post unifications & breakups treated as separate units:**
  - USSR (1945–1991) → Russia + 14 successor states (1992+)
  - Yugoslavia → SFRY (1945–1991), FRY/Serbia-Montenegro (1992–2006), then Serbia, Montenegro, Croatia, Slovenia, Bosnia, Macedonia/N. Macedonia, Kosovo
  - Czechoslovakia (1945–1992) → Czech Republic + Slovakia (1993+)
  - East Germany + West Germany (1949–1990) → unified Germany (1990+)
  - Yemen (split 1967–1990, unified 1990+)
  - Sudan / South Sudan (2011 split)
- New independent states added when independent: Eritrea (1993), East Timor (2002), South Sudan (2011), Montenegro (2006), Kosovo (2008, with note on contested status)
- Document handling explicitly in `R/build/01_country_spine.R`

---

## 3. Proposed file layout

```
regime_type_climate_politics/
├── PLAN.md                          # this file
├── README.md                        # written after build is functional
├── regime_type_climate_politics.Rproj
├── R/
│   ├── 00_setup.R                  # packages, paths, helpers
│   ├── build/
│   │   ├── 01_country_spine.R      # spine + crosswalks + microstate filter
│   │   ├── 02_vdem.R               # V-Dem regime, polarization, auth-institutions
│   │   ├── 03_bmr.R                # Boix-Miller-Rosato dichotomous democracy
│   │   ├── 04_gwf_subtypes.R       # regime subtypes (5-cat) + personalist binary
│   │   ├── 05_personalism.R        # Frantz et al. continuous personalism index
│   │   ├── 06_polity.R             # Polity5 robustness
│   │   # 07_ccp.R                  # Comparative Constitutions Project — DEFERRED (see §7)
│   │   ├── 08_vparty.R             # global populism aggregation
│   │   # 09_populist_eu.R          # PopuList — DEFERRED (V-Party covers Europe)
│   │   ├── 10_emissions.R          # PRIMAP-hist + OWID
│   │   ├── 11_energy.R             # OWID energy: oil, gas, coal, renewables
│   │   # 12_renew_invest.R         # DEFERRED — use renew generation growth as proxy
│   │   # 13_ross_petroleum.R       # DEFERRED — OWID covers 1965+; ask if pre-1965 needed
│   │   # 14_climate_laws.R         # DEFERRED — domestic-policy DBs out of scope
│   │   # 15_climate_policy_db.R    # DEFERRED — domestic-policy DBs out of scope
│   │   ├── 16_treaties.R           # Paris Agreement ratification (UNFCCC/Kyoto deferred)
│   │   # 17_indices.R              # DEFERRED — CCPI/EPI narrow coverage, overlap with other DVs
│   │   ├── 18_controls.R           # WDI (incl. area, urban), Maddison, UN WPP
│   │   ├── 19_swiid.R              # SWIID Gini (net + market)
│   │   └── 99_merge.R              # joins everything → final panel
│   ├── diagnostics/
│   │   ├── coverage_report.R       # country-year coverage per variable
│   │   └── descriptives.R
│   └── analysis/                    # populated later
├── data/
│   ├── raw/                         # downloaded source files (gitignored)
│   ├── intermediate/                # one .rds per source
│   └── final/
│       └── panel.rds / panel.csv    # the deliverable
└── docs/
    ├── codebook.md                  # variable definitions + sources
    └── coverage.html                # auto-generated coverage report
```

---

## 4. Source-by-source notes

### 4.1 V-Dem

- **Access:** `vdemdata` R package (`remotes::install_github("vdeminstitute/vdemdata")`) or direct CSV download from v-dem.net (~1.2 GB for full v15)
- **License:** Free for academic use, citation required
- **Key vars:** `v2x_regime` (RoW), `v2x_polyarchy`, `v2x_libdem`, `v2x_partipdem`, `v2cacamps`, `v2smpolsoc`, `e_polity2` (their built-in Polity merge)
- **Caveats:** Uses VDem country IDs; some states not in COW system (e.g., Palestine, Somaliland) — decide whether to include

### 4.2 Geddes-Wright-Frantz (regime subtypes + personalist binary)

- **Access:** Original 1946–2010 dataset from Barbara Geddes' replication archive
- **Extension:** Several published extensions to ~2020 exist (e.g., Frantz et al.); I'll check what's most current and document choice
- **Key vars:** Regime type (personalist, military, single-party, monarchy, plus hybrids), regime start/end years; binary `personalist` indicator
- **Caveats:** Coding stops at most-recent extension; for democracies, GWF is `NA` — combine with V-Dem RoW to produce a 5-category `regime_subtype` covering the full sample (democracy / one-party / personalist / military / monarchy)

### 4.2a Frantz-Kendall-Taylor-Wright-Geddes Personalism Index

- **Access:** Replication archive for Frantz, Kendall-Taylor, Wright & Geddes (2020), "Personalization of Power and Mass Uprisings in Dictatorships" / "How Personalism Erodes Civil Liberties." Continuous 0–1 index built from ~8 indicators (e.g., loyalist appointments, custom paramilitaries, party founded by leader).
- **Coverage:** 1946–2010 in original; check for newer extension. Autocracies only — democracies coded `NA`.
- **Key var:** `personalism_score` (continuous), plus component indicators if useful.
- **Caveats:** Time horizon may end before panel does; consider whether to forward-fill within unchanged regime spells, or leave `NA`. Recommendation: leave `NA` and document, since personalization is a process variable.

### 4.2b Boix-Miller-Rosato dichotomous democracy

- **Access:** sites.google.com/site/mkmtwo/data — current version covers 1800–2020
- **Use:** Time-tested binary democracy/autocracy measure for the headline democracy/autocracy contrast in user's framework. Complements V-Dem RoW (which has its own dichotomization rule).
- **Key var:** `democracy_bmr` (binary)

### 4.2c Comparative Constitutions Project

- **Access:** comparativeconstitutionsproject.org — Characteristics of National Constitutions (CCP-CNC) dataset
- **Use:** Authoritarian-institutions IVs that aren't already in V-Dem — e.g., whether a written constitution exists, whether legislatures are mandated, term limits. V-Dem has most of what we need on legislatures and parties; CCP fills gaps and provides constitutional-rule-of-law variables.
- **Coverage:** 1789–2020
- **Caveats:** Constitution-level data; map to country-year by treating constitution-in-force as the unit.

### 4.3 V-Party

- **Access:** Bundled with V-Dem, separate file (`V-Party_full.csv`)
- **Key vars:** `v2xpa_popul` (populism index, 0–1), `v2pariglef` (left-right), `v2elvotsh` (vote share), `v2elseatshare`
- **Aggregation to country-year:**
  - `vparty_pop_max` = max populism score among parties with ≥5% vote share
  - `vparty_pop_govwt` = seat-share-weighted populism among governing parties
  - `vparty_populist_in_govt` = 1 if any governing party has populism > 0.5 (threshold to be sensitivity-tested)
- **Caveats:** Coverage is election-year sparse → carry-forward between elections

### 4.4 PopuList

- **Access:** populist.org, v3 published 2024, covers 31 European countries, parties classified back to ~1989
- **License:** CC-BY
- **Merge with ParlGov for vote/seat shares:** ParlGov has elections + cabinets for European democracies, harmonized party IDs
- **Key vars:** `populist_voteshare_eu`, `populist_in_govt_eu`, `farright_voteshare`, `farleft_voteshare`
- **Caveats:** Europe-only — these vars will be `NA` for non-European countries by construction. Document the seam vs. V-Party clearly.

### 4.4a Energy Institute Statistical Review of World Energy

- **Access:** energyinst.org/statistical-review — annual, free CSV download (took over from BP in 2023)
- **License:** Free for non-commercial use with attribution
- **Use:** Long, harmonized series for **oil production/consumption** (kbd, since 1965), **natural gas production/consumption** (bcm, since 1970), **renewable generation by source** (since 1965), primary energy by fuel
- **Coverage:** ~80 countries with full data, plus aggregates for the rest of world (so panel-level coverage is uneven for small/poor countries pre-1990)
- **Caveats:** "Other Africa," "Other Asia Pacific" residuals — those countries appear as missing, not zero. Don't impute.

### 4.4b U.S. Energy Information Administration (EIA) International

- **Access:** eia.gov/international — bulk downloads in CSV/API
- **Use:** Cross-validation with Energy Institute; broader country coverage for oil/gas (some smaller producers covered here but not in EI), and 1980+ generally available
- **Key vars:** Crude oil production, consumption; natural gas dry production, consumption; electricity generation by source

### 4.4c Ember Yearly Electricity Data

- **Access:** ember-climate.org/data — CSV download
- **Use:** Best free source for **electricity generation by technology** including renewables, with deeper country coverage than Energy Institute
- **Coverage:** 1985+ for OECD; 2000+ for broader global coverage
- **Key vars:** Electricity generation TWh by source (coal, gas, oil, nuclear, hydro, solar, wind, bioenergy, other renewables)

### 4.4d IRENA Public Investment / REN21 (renewable investment)

- **Access:** IRENA Public Finance for Renewables database (irena.org/Statistics); REN21 Global Status Report appendices
- **Coverage:** 2004+ patchy, more reliable from ~2013
- **Caveats:** Renewable-investment data is the **most fragile** DV in this panel:
  - BNEF has the gold-standard series but is paywalled
  - IRENA covers public finance flows specifically, not total investment
  - Cross-country comparability is weak before ~2013
  - Recommend treating as a secondary/auxiliary DV; document gaps
- **Decision needed:** Whether to include given coverage limits — see §7 open questions

### 4.4e Ross Petroleum Dataset (long-run oil/gas)

- **Access:** Michael L. Ross's Petroleum Dataset (Harvard Dataverse), country-year 1932–2014
- **Use:** Extends oil/gas production back before 1965; useful if user wants pre-1965 emissions/political-economy controls. Has oil & gas value, production, and rents.
- **Coverage:** 1932–2014 — for post-2014 use Energy Institute / EIA / WDI rents.

### 4.5 PRIMAP-hist (emissions)

- **Access:** Zenodo, current version v2.5 (or v2.6 if released by build date)
- **License:** CC-BY 4.0
- **Format:** Long CSV by country / sector / gas
- **Selection:** Total GHG (KYOTOGHG-AR6 GWPs), CO₂, CH₄, N₂O — sector M.0.EL (national total excl. LULUCF) + with-LULUCF variant for sensitivity
- **Caveats:** Estimates differ from country self-reports; PRIMAP "country-reported" prioritizes UNFCCC submissions where available

### 4.6 Climate Change Laws of the World (Grantham/LSE)

- **Access:** climate-laws.org has bulk CSV download
- **License:** CC-BY-NC
- **Construction:** Each row is one law/policy with country, year passed, type (legislative/executive), topic. Aggregate to:
  - `n_climate_laws_year` (laws passed in year y)
  - `cum_climate_laws` (cumulative count up to y)
  - Subdivisions by mitigation/adaptation, by sector
- **Caveats:** Coverage of older legislation depends on retrospective coding; treat 1990s data with caution. Litigation cases also in DB — exclude.

### 4.7 Climate Policy Database (NewClimate)

- **Access:** climatepolicydatabase.org, CSV export
- **License:** CC-BY
- **Use:** Cross-validation with CCLW; finer-grained policy instrument types

### 4.8 UNFCCC / Kyoto / Paris / NDCs

- **Access:** UN Treaty Collection (treaties.un.org) and unfccc.int parties pages; Climate Watch (climatewatchdata.org) has clean CSV exports of NDC submission dates and ratification statuses
- **Construction:** Treaty join is by country × year:
  - `unfccc_ratified[c, y]` = 1 if c had ratified UNFCCC by year y, else 0; `NA` before 1992
  - Same pattern for Kyoto (1997+), Paris (2015+)
  - `unfccc_annex` = Annex I / Annex II / Non-Annex (time-invariant for most)

### 4.9 CCPI / EPI

- **Use:** Composite indices, narrower country coverage. Useful as alternative DVs and for robustness, not for the main panel.

### 4.10 Controls

- **WDI:** `WDI` R package
- **Maddison:** `maddison` R package (or direct download)
- **UN WPP:** `wpp2024` R package or direct CSV

---

## 5. Merging strategy

1. Build country spine (1945–2024 × ~165 countries after microstate filter ≈ 13,000 country-years)
2. For each source, produce a tidy intermediate keyed by `iso3c × year` in `data/intermediate/`
3. Master `99_merge.R` does sequential `left_join`s onto the spine
4. Country-code reconciliation: use `countrycode::countrycode()` plus a hand-maintained crosswalk for edge cases (Kosovo, Taiwan, pre-unification Germanies/Yemens, etc.) in `R/build/01_country_spine.R`
5. Final panel saved as both `.rds` (R-native, preserves types) and `.csv` (portable)

---

## 6. Coverage diagnostics (built-in)

`R/diagnostics/coverage_report.R` produces an HTML report with:

- Country-year coverage heatmap per variable
- Counts of non-`NA` country-years by variable, by decade
- List of countries with < 50% coverage on any DV
- Seam diagnostics: e.g., where V-Party and PopuList disagree on European populism

This is essential — it's what makes the panel honest about what's actually usable for any given regression.

---

## 7. Open questions / decisions still to make

1. **GWF extension source.** I'll survey published extensions of Geddes-Wright-Frantz post-2010 and pick one — happy to flag the choice for sign-off before merging.
2. **Personalism index extension.** The Frantz et al. (2020) personalism index ends in 2010 in the original paper. Newer working papers extend it but the "official" version may differ. Choices: (a) use original through 2010, leave 2011+ as `NA`; (b) use most recent extension (will document author + date); (c) construct our own extension from V-Dem indicators that approximate the index. Recommend (b) if a published extension exists, else (a).
3. **Renewable investment scope.** Coverage is patchy and proprietary BNEF is the best series. Options: (a) include IRENA + REN21 only (free, partial), with clear caveats; (b) drop the variable and rely on `renew_gen_twh` growth rates as a proxy for investment; (c) try to get BNEF access via institutional license. Recommend (a) + (b) jointly: include IRENA, but treat generation growth as the primary "investment-like" outcome.
4. **Oil/gas data source priority.** Energy Institute (free, ~80 countries) vs. EIA (free, broader coverage, slightly different methodology). Recommend **EIA as primary** for breadth, Energy Institute as secondary/cross-check. Pre-1980 fall back to Ross.
5. **Kosovo, Taiwan, Palestine.** Include with notes on contested status, or exclude? Default proposal: **include** (research interest > diplomatic recognition); document in spine script.
6. **Annex I dummy as moderator.** Worth including `unfccc_annex` as an interaction term in DVs — flagging because it's both a DV-component and a structural moderator.
7. **Treaty DVs as `NA` vs `0` pre-treaty.** Plan: `NA` before treaty exists, `0` once it exists but country hasn't ratified, `1` once ratified. This matters for survival models vs. linear models. Confirm OK.
8. **Carry-forward window for V-Party.** Default 5 years between elections; longer windows risk imputing populism into regime transitions. Sensitivity test.
9. **Reproducibility approach.** Plain R scripts vs. `targets` pipeline vs. lightweight `renv` only. Recommendation: **`renv` for package versions + plain scripts** to start; can migrate to `targets` if rebuild speed becomes an issue.
10. **Comparative Constitutions Project (deferred).** CCP would add constitutional age and de jure institutional content. Deferred from v1 because V-Dem already covers legislature presence, elected lower chamber, party ban, multiparty elections, and judicial constraints — these cover ~95% of "authoritarian institutions" in the framework. Add CCP later if constitutional-age or specific institutional-content variables are needed for analyses.

---

## 8. Estimated effort and order

| Step | Est. time | Dependencies |
|---|---|---|
| Spine + crosswalks | 1 session | none |
| V-Dem (regime, polarization, auth-institutions) | 1 session | spine |
| BMR + GWF + Personalism + CCP | 1 session | spine, V-Dem |
| Polity, V-Party, PopuList | 1 session | spine, V-Dem |
| Emissions (PRIMAP) | 0.5 session | spine |
| Energy: oil, gas, renewables (EI + EIA + Ember + Ross) | 1.5 sessions | spine |
| Renewable investment (IRENA + REN21) | 0.5 session | spine |
| Climate laws (CCLW + CPDB) | 1 session | spine |
| Treaties (UNFCCC/Kyoto/Paris/NDC) | 1 session | spine |
| Indices (CCPI, EPI, ND-GAIN) | 0.5 session | spine |
| Controls (WDI inc. area+urban, Maddison, WPP) | 0.5 session | spine |
| Merge + coverage report | 1 session | all above |
| Codebook | 0.5 session | merge |

Total ≈ 10–11 working sessions to a v1 panel + diagnostics.

---

**Please review and flag:** any sources to add/drop, the open questions in §7, and whether the file layout matches how you'd like to work in this repo.
