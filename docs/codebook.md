# Panel Codebook

Country-year panel for the "regime type and climate politics" project.
Built by the scripts in `R/build/`; final file at `data/final/panel.rds`.

**Coverage:** 10,807 country-years × 169 sovereign states × 1945–2024 × 114 variables.

Variables are documented below by source group. For provenance and download
URLs, see the corresponding `R/build/NN_*.R` script.

---

## 1. Identifiers and spine metadata

Built by `R/build/01_country_spine.R`.

| Variable | Type | Description |
|---|---|---|
| `iso3c` | character | ISO 3166-1 alpha-3, primary key (country dimension). Historical states use ISO 3166-3 codes (YUG, CSK, DDR, YAR, YMD). Kosovo as `XKX`, Palestine as `PSE`. |
| `year` | integer | Calendar year, 1945–2024. Primary key (time dimension). |
| `country_name` | character | English country name (from `countrycode::codelist_panel`). |
| `cown` | integer | Correlates of War numeric code. NA for historical/manual additions where COW has no code. |
| `cowc` | character | COW alpha code. |
| `gwn` | integer | Gleditsch-Ward numeric code. |
| `gwc` | character | G-W alpha code. |
| `vdem_country_id` | integer | V-Dem internal country ID (`country_id`). |
| `region` | character | World Bank 8-region grouping (e.g., "Sub-Saharan Africa"). |
| `subregion` | character | Finer UN sub-region (e.g., "Eastern Africa"). |
| `state_status` | character | How the row entered the spine: `iso3c_member` (codelist_panel COW/GW member), `iso3c_member_extended` (forward-filled 2021–2024), `historical_state` (codelist_panel iso3c-NA row with our assigned code), `manual_addition` (XKX, PSE). |

**State-system conventions used (see also `01_country_spine.R`):**

- `RUS` continuous 1945–2024, representing both USSR (1945–1991) and Russia (1992+). No separate `SUN` code.
- `DEU` continuous, representing FRG (1949–1989) and unified Germany (1990+); 1945–1948 occupation years are present but `cown` is NA.
- `YUG` covers Yugoslavia 1945–2006 (SFRY → FRY → Serbia-Montenegro); `SRB` starts 2006.
- `CSK` covers Czechoslovakia 1945–1992; `CZE`/`SVK` start 1993.
- `YAR` (North Yemen) 1945–1990 and `YMD` (South Yemen) 1967–1989; `YEM` (unified) starts 1990.
- `DDR` (East Germany) 1949–1990.
- Single-year overlaps exist at transition points (YUG/SRB in 2006, YEM/YAR in 1990) — by design.

---

## 2. V-Dem v15 regime variables

Built by `R/build/02_vdem.R`. Source: V-Dem Institute, dataset v15 (2025).

### 2.1 Regime classification

| Variable | Type | Range / Values | Description |
|---|---|---|---|
| `regimes_of_the_world` | integer | 0–3 | V-Dem's Regimes of the World (RoW) classification. **0** = Closed autocracy; **1** = Electoral autocracy; **2** = Electoral democracy; **3** = Liberal democracy. V-Dem variable `v2x_regime`. |
| `regime_row_10cat` | integer | 0–9 | 10-category RoW with ambiguous-classification cells. `v2x_regime_amb`. |

### 2.2 Continuous democracy indices

All bounded [0, 1]; higher = more democratic.

| Variable | V-Dem code | Description |
|---|---|---|
| `polyarchy` | `v2x_polyarchy` | Electoral democracy (Dahl's polyarchy). |
| `libdem` | `v2x_libdem` | Liberal democracy (polyarchy + rule of law + checks). |
| `partipdem` | `v2x_partipdem` | Participatory democracy. |
| `delibdem` | `v2x_delibdem` | Deliberative democracy. |
| `egaldem` | `v2x_egaldem` | Egalitarian democracy. |

### 2.3 Polarization

| Variable | V-Dem code | Range | Description |
|---|---|---|---|
| `pol_polarization` | `v2cacamps` | 0–4 | Political polarization across society. Expert-coded, 1900+. Higher = more polarized into mutually antagonistic camps. |
| `soc_polarization` | `v2smpolsoc` | 0–4 | Societal polarization (survey-based). 2000+ for most countries; NA before. |

### 2.4 Authoritarian-institution indicators

| Variable | V-Dem code | Values | Description |
|---|---|---|---|
| `legislature_chambers` | `v2lgbicam` | 0/1/2 | 0 = no legislature; 1 = unicameral; 2 = bicameral. |
| `lower_chamber_elected` | `v2lgello` | 0/1 | Is the lower chamber directly elected? |
| `party_ban` | `v2psparban` | 0–4 | Higher = more parties banned (0 = no restrictions, 4 = all banned). |
| `multiparty_elections` | `v2elmulpar` | 0–4 | Quality of multiparty competition in elections. |
| `high_court_indep` | `v2juhcind` | 0–4 | High court independence from the executive. |
| `freedom_expression` | `v2x_freexp_altinf` | 0–1 | Freedom of expression and alternative information. |

### 2.5 Built-ins

| Variable | V-Dem code | Description |
|---|---|---|
| `polity2_vdem_merge` | `e_polity2` | V-Dem's merged Polity score (saves a separate Polity download for sensitivity). |
| `vdem_country_name`, `vdem_country_text`, `vdem_cowcode` | various | V-Dem's own country identifiers; useful for round-tripping joins back to V-Dem. |

---

## 3. Boix-Miller-Rosato (BMR)

Built by `R/build/03_bmr.R`. Source: Boix, Miller & Rosato. Dichotomous democracy classification, 1800–2020.

| Variable | Type | Values | Description |
|---|---|---|---|
| `democracy_bmr` | integer | 0/1 | 1 = democracy, 0 = autocracy. Threshold-based on free and contested elections plus suffrage. |
| `bmr_extended` | logical | TRUE/FALSE | TRUE if the row was forward-filled from 2020 (BMR's data endpoint). Use to filter out projections if needed. |

---

## 4. Geddes-Wright-Frantz (GWF) autocratic subtypes

Built by `R/build/04_gwf_subtypes.R`. Source: Geddes, Wright & Frantz, "Autocratic Breakdown and Regime Transitions" (2014), dataset v1.2.

GWF covers autocracies only. Democracies have NA for the GWF-specific variables.

| Variable | Type | Values | Description |
|---|---|---|---|
| `gwf_regime_raw` | character | many | Original GWF coding string including hybrids (e.g., "party-personal", "military-personal"). |
| `gwf_regime` | character | personalist / military / party / monarchy / other_autocracy | Collapsed dominant type. Priority order for hybrids: personalist > military > party > monarchy. |
| `gwf_party`, `gwf_military`, `gwf_personal`, `gwf_monarch` | integer | 0/1 | Component indicators (a hybrid can be 1 on multiple). |
| `regime_subtype` | character | democracy / personalist / military / party / monarchy / other_autocracy / NA | **Composite 5-cat regime type** combining V-Dem RoW (for democracies, RoW ≥ 2) and GWF (for autocracies). The headline subtype variable for analyses. NA for autocracy-years post-2010 (GWF coverage ends). |

---

## 5. Personalism index

Built by `R/build/05_personalism.R`. Source: Frantz, Kendall-Taylor, Wright & Xu (2020), "Personalization of Power and Mass Uprisings in Dictatorships," *British Journal of Political Science*.

Continuous personalism scores for autocracies only (NA for democracies).

| Variable | Type | Range | Description |
|---|---|---|---|
| `personalism_score` | numeric | ~0–1 | Latent personalism index (`latent_personalism`). Built from 8 indicators of leader power concentration (loyalist appointments, custom paramilitaries, party founded by leader, etc.). |
| `personalism_se` | numeric | ≥0 | Standard error from the IRT model. |
| `personalism_alt` | numeric | ~0–1 | Alternative score from 2-parameter logistic IRT (`pers_2pl`). Use as robustness check. |

---

## 6. Polity

Built by `R/build/06_polity.R`. Source: Center for Systemic Peace (Polity5), via `democracyData`'s `polity_pmm` (Marquez-modified for missingness).

| Variable | Type | Range | Description |
|---|---|---|---|
| `polity2` | integer | −10 to +10 | Polity composite score. Higher = more democratic. Values of −66, −77, −88 (interruption/interregnum/transition) converted to NA. |
| `polity_durable` | integer | ≥0 | Years since last regime change. NA in this version (full Polity5 has it; `polity_pmm` doesn't). |

---

## 7. V-Party (country-year populism)

Built by `R/build/08_vparty.R`. Source: V-Party (V-Dem). Election-keyed; aggregated to country-year via forward-fill up to 10 years past the most recent election.

| Variable | Type | Range | Description |
|---|---|---|---|
| `vparty_pop_max` | numeric | 0–1 | Maximum populism (V-Party `v2xpa_popul`) among parties in the most recent election. |
| `vparty_pop_govwt` | numeric | 0–1 | Seat-share-weighted mean populism among governing parties (`v2pagovsup` ∈ {0,1,2}). |
| `vparty_populist_in_govt` | integer | 0/1 | 1 if any governing party has populism > 0.5. |
| `vparty_populist_voteshare` | numeric | 0–100 | Total vote share of parties with populism > 0.5. |
| `vparty_election_year` | integer | year | Year of the source election. Use to detect carry-forward staleness. |

**Threshold note:** populism cutoff of 0.5 is conventional but arbitrary; re-derive from `vparty_pop_max` if you want a different threshold.

---

## 8. Emissions

Built by `R/build/10_emissions.R`. Source: Our World in Data CO2 dataset (aggregates PRIMAP-hist, Global Carbon Project, EDGAR).

All emission quantities are in **million tonnes (Mt) of CO2-equivalent**, except where noted.

### 8.1 Aggregate emissions

| Variable | Description |
|---|---|
| `co2_total` | Total CO2 emissions (Mt CO2). Excludes LULUCF. |
| `co2_incl_luc` | CO2 including land-use change. |
| `co2_pc` | CO2 per capita (tonnes). |
| `co2_per_gdp` | CO2 per dollar GDP (kg/$). |
| `ghg_total` | Total GHG emissions (Mt CO2-eq). |
| `ghg_excl_lucf` | Total GHG excluding LULUCF. |
| `methane` | Methane emissions (Mt CO2-eq). |
| `nitrous_oxide` | N2O emissions (Mt CO2-eq). |

### 8.2 By fuel

| Variable | Description |
|---|---|
| `oil_co2` | CO2 from oil combustion. |
| `gas_co2` | CO2 from natural gas combustion. |
| `coal_co2` | CO2 from coal combustion. |
| `cement_co2` | CO2 from cement production. |
| `flaring_co2` | CO2 from gas flaring. |
| `other_industry_co2` | CO2 from other industrial sources. |

---

## 9. Energy

Built by `R/build/11_energy.R`. Source: Our World in Data energy dataset (aggregates Energy Institute Statistical Review + Ember + IEA).

Primary energy and fuel quantities are in **TWh** (OWID convention). Electricity totals in **TWh**. Shares in **%**.

### 9.1 Primary energy

| Variable | Description |
|---|---|
| `primary_energy_twh` | Total primary energy consumption. |
| `energy_pc` | Energy use per capita (kWh). |

### 9.2 Fossil-fuel production and consumption

| Variable | Description |
|---|---|
| `oil_prod_twh` | Oil production (TWh). |
| `oil_cons_twh` | Oil consumption (TWh). |
| `gas_prod_twh` | Natural gas production (TWh). |
| `gas_cons_twh` | Natural gas consumption (TWh). |
| `coal_prod_twh` | Coal production (TWh). |
| `coal_cons_twh` | Coal consumption (TWh). |

### 9.3 Electricity generation by source (TWh)

| Variable | Description |
|---|---|
| `elec_gen_twh` | Total electricity generation. |
| `elec_fossil_twh` | From fossil sources (coal + gas + oil). |
| `elec_renew_twh` | From renewables (hydro + solar + wind + bio + other). |
| `elec_nuclear_twh` | Nuclear. |
| `elec_hydro_twh`, `elec_solar_twh`, `elec_wind_twh`, `elec_biofuel_twh` | By individual source. |

### 9.4 Shares in primary energy (%)

| Variable | Description |
|---|---|
| `share_fossil_primary` | Fossil-fuel share of primary energy. |
| `share_renew_primary` | Renewables share of primary energy (includes hydro). |
| `share_solar_primary`, `share_wind_primary`, `share_hydro_primary`, `share_nuclear_primary` | By individual source. |

### 9.5 Shares in electricity (%)

| Variable | Description |
|---|---|
| `share_fossil_elec` | Fossil share of electricity. |
| `share_renew_elec` | Renewables share of electricity. |
| `share_solar_elec`, `share_wind_elec`, `share_hydro_elec`, `share_nuclear_elec` | By individual source. |

---

## 10. Paris Agreement

Built by `R/build/16_treaties.R`. Source: UN Treaty Collection (manually curated ratification years). v1 approximation — verify against `treaties.un.org` before publication.

`paris_*` variables are NA before 2016 (the agreement opened for signature on 22 April 2016 and entered into force on 4 November 2016).

| Variable | Type | Description |
|---|---|---|
| `paris_signed` | integer (0/1) | 1 if country had signed the Paris Agreement by year y. |
| `paris_signed_year` | integer | Year of signature (mostly 2016). |
| `paris_ratified` | integer (0/1) | 1 if country was a party in year y. Accounts for the US withdrawal episode (USA = 0 in 2020, = 1 in 2021+). |
| `paris_ratify_year` | integer | Year of first ratification. NA for non-ratifiers. |
| `paris_withdrew` | integer (0/1) | 1 from the year of withdrawal onward (USA only as of 2024). Use with `paris_ratified` to detect the withdrawal-then-rejoin episode. |

**Iran**: signed 22 April 2016, has not ratified — `paris_signed` = 1, `paris_ratified` = 0 throughout.

---

## 11. Controls (WDI + Maddison)

Built by `R/build/18_controls.R`. Source: World Bank WDI (1960+) and Maddison Project Database 2020 (long-run GDP).

| Variable | WDI / Maddison code | Description |
|---|---|---|
| `gdp_pc_ppp` | `NY.GDP.PCAP.PP.KD` | GDP per capita, PPP, constant 2017 international $. |
| `gdp_pc_const` | `NY.GDP.PCAP.KD` | GDP per capita, constant 2015 USD. |
| `gdp_total_const` | `NY.GDP.MKTP.KD` | GDP total, constant 2015 USD. |
| `gdp_pc_maddison` | Maddison `cgdppc` | Maddison long-run real GDP per capita (2011 USD). Use for pre-1960 years. |
| `population` | `SP.POP.TOTL` | Total population (raw). |
| `area_km2` | `AG.LND.TOTL.K2` | Land area (km²). Time-invariant for most countries. |
| `urban_pop_pct` | `SP.URB.TOTL.IN.ZS` | Urban population as % of total. |
| `largest_city_pct` | `EN.URB.MCTY.TL.ZS` | Population in largest city as % of urban population. Higher = more urban concentration. |
| `trade_pct_gdp` | `NE.TRD.GNFS.ZS` | Trade (exports + imports) as % of GDP. |
| `fdi_pct_gdp` | `BX.KLT.DINV.WD.GD.ZS` | Net FDI inflows as % of GDP. |
| `oil_rents_pct` | `NY.GDP.PETR.RT.ZS` | Oil rents as % of GDP. |
| `gas_rents_pct` | `NY.GDP.NGAS.RT.ZS` | Natural-gas rents as % of GDP. |
| `fossil_rents_pct` | `NY.GDP.TOTL.RT.ZS` | Total natural-resource rents as % of GDP (oil + gas + coal + minerals + forest). |
| `energy_use_pc` | `EG.USE.PCAP.KG.OE` | Energy use per capita (kg of oil equivalent). |

---

## 12. Inequality (SWIID)

Built by `R/build/19_swiid.R`. Source: Solt, *Standardized World Income Inequality Database*, v9.9.2.

Estimates are point estimates from Solt's multiple-imputation procedure with their standard errors. For uncertainty-propagation analyses, use the full 100-imputation set (also in the SWIID download).

| Variable | Type | Range | Description |
|---|---|---|---|
| `gini_net` | numeric | ~20–70 | Gini of disposable (post-tax-and-transfer) income. |
| `gini_net_se` | numeric | ≥0 | Standard error. |
| `gini_market` | numeric | ~25–70 | Gini of market (pre-redistribution) income. |
| `gini_market_se` | numeric | ≥0 | Standard error. |

Redistribution can be derived as `gini_market − gini_net`.

---

## Coverage notes

- **Microstate filter applied:** countries with median population < 500,000 over the panel window are dropped. As of v1 this drops 12 iso3c (BHS, BLZ, BRB, BRN, CPV, ISL, LUX, MDV, MLT, SLB, SUR, WSM). Edit `MICROSTATE_POP_THRESHOLD` in `R/00_setup.R` to change.
- **Climate DVs are NA before they make sense:** `paris_*` NA before 2016, `share_renew_*` typically NA before 1965 (Energy Institute coverage start).
- **GWF / personalism end in 2010.** Post-2010 autocracy-years have NA `regime_subtype` for the autocracy portion; V-Dem RoW provides a 4-cat fallback. See `regimes_of_the_world` for full coverage.
- **BMR ends in 2020** and is forward-filled to 2024 (see `bmr_extended`); a country experiencing a regime change in 2021–2024 will be mis-coded by BMR but caught by V-Dem RoW.

See `docs/coverage.html` (generated by `R/diagnostics/coverage_report.R`) for variable-by-variable coverage tables and a country-year heatmap.
