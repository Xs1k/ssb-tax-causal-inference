/*==============================================================
13_sensitivity_subnational.do
Sensitivita' 2: cosa cambia se USA/Canada/Micronesia (paesi con
tasse SOLO subnazionali) non vengono esclusi? Nel do-file 05 sono
stati tolti per non farli entrare come falsi "mai-trattati puliti",
dato che hanno esposizione locale reale non catturata dal
trattamento nazionale. Qui vengono reintrodotti come mai-trattati,
per verificare se l'ATT si sposta.
Ripete la pipeline del do-file 05 saltando SOLO l'esclusione 2.
Input:  bmi_dalys_clean.dta, diabetes_prev_clean.dta, controls.dta,
        faostat_sugar_clean.dta, ssbtax_treated_national.dta
Output: panel_sens_subnational.dta
==============================================================*/

cd "C:\Users\morgh\Desktop\Stata project"
clear all
set more off
capture log close
log using "ciie_project.log", append text

use "bmi_dalys_clean.dta", clear
isid iso3 year

merge 1:1 iso3 year using "diabetes_prev_clean.dta", keepusing(diabetes_prev_rate)
drop _merge

merge 1:1 iso3 year using "controls.dta", keepusing(gdp_pc edu_secondary)
drop if _merge == 2
drop _merge

merge 1:1 iso3 year using "faostat_sugar_clean.dta", keepusing(total_sugar_prod)
drop if _merge == 2
drop _merge
replace total_sugar_prod = 0 if missing(total_sugar_prod)

merge m:1 iso3 using "ssbtax_treated_national.dta", ///
    keepusing(jurisdiction anno_adozione structure tiered region income_group)
drop if _merge == 2
drop _merge

gen byte ssb_tax = (year >= anno_adozione) if !missing(anno_adozione)
replace ssb_tax = 0 if missing(anno_adozione)
count if missing(ssb_tax)

/*----------------------------------------------------------------
ESCLUSIONE pre-2000 (identica al do-file 05 - non e' oggetto di
questa sensitivita').
------------------------------------------------------------------*/
drop if anno_adozione < 2000 & !missing(anno_adozione)

/*----------------------------------------------------------------
NIENTE esclusione USA/CAN/FSM qui - e' il punto di questa
sensitivita'. Non avendo mai una riga National/Excise, restano
mai-trattati (ssb_tax=0 sempre) per costruzione, senza bisogno
di codice aggiuntivo.
------------------------------------------------------------------*/
count if inlist(iso3, "USA", "CAN", "FSM")
* Quante osservazioni rientrano (atteso: 3 paesi x 24 anni = 72).

gen log_gdp_pc = log(gdp_pc)
gen log_sugar_prod = log(1 + total_sugar_prod)

encode iso3, gen(country_id)
xtset country_id year
isid iso3 year
save "panel_sens_subnational.dta", replace

/*----------------------------------------------------------------
STIMA - stessa specifica del do-file 06.
------------------------------------------------------------------*/
gen first_treat = anno_adozione
replace first_treat = 0 if missing(anno_adozione)

csdid bmi_dalys_rate log_gdp_pc edu_secondary log_sugar_prod, ///
    ivar(country_id) time(year) gvar(first_treat) method(dripw)
estat simple

di "Confronto: ATT baseline (do-file 06, senza USA/CAN/FSM) = 34.45 (p=0.280) vs ATT sopra (con USA/CAN/FSM come mai-trattati)"

log close
