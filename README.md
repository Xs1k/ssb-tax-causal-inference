Sugar-Sweetened Beverage Taxes and the Burden of Disease
Empirical project - Causal Inference and Impact Evaluation   
M. Tavella

Research question  
Does a national tax on sugar-sweetened beverages (SSBs) reduce the population's burden of disease from high BMI? Follow-up: does the effect extend to type 2 diabetes, does it depend on tax design (specific vs. ad valorem, tiered or not), and does a country's own sugar production moderate the effect?

Data  
Panel of 160 countries, 2000–2023 (3,840 country-year observations), merged on ISO3 codes:

WB SSB Tax Database: adoption timing and tax design  
IHME GBD 2023: BMI DALYs, diabetes prevalence  
World Bank WDI: GDP per capita, school enrollment  
FAOSTAT: sugar production  

81 treated countries, 79 never-treated.

Method  
Staggered adoption makes standard two-way fixed effects (TWFE) biased when effects build up over time (Goodman-Bacon, 2021). Main estimator: Callaway & Sant'Anna (2021) doubly-robust group-time ATT(g,t), aggregated into an overall ATT and an event-study. TWFE is reported only as a robustness check.  
Identification relies on parallel trends (tested via pre-trends), country and year fixed effects, and controls for GDP p.c., school enrollment, and sugar production.

Results  
Main ATT on BMI DALYs: 34.45 (p = 0.280), not statistically significant  
Flat, non-significant pre-trends support the identification strategy  
Result is stable across robustness checks (sample composition, tax design subgroups)  
A leave-one-out regional-diffusion instrument was built and tested but fails the exclusion restriction (used only as a diagnostic, not for 2SLS)  
Null result is best explained by limited statistical power (few early adopters, short panel), consistent with related literature (Villani et al., 2024)

Limitations  
Outcomes are modeled IHME estimates, not direct counts; treatment is binary (doesn't capture tax size); missing covariates reduce the sample from 3,840 to 2,226 obs; results generalize mainly to small/mid-income countries, not large high-income economies.

Repository structure  
├── data/           # raw panel data (and scripts to build the merged)  
├── src/            # Stata code for estimation  
├── figures/        # event-study, forest plot, adoption timeline, etc.  
├── slides/         # presentation slides (PDF)  
└── README.md  

References  
Key methodology: Callaway & Sant'Anna (2021, Journal of Econometrics); Goodman-Bacon (2021, Journal of Econometrics). Full reference list in slides/.
