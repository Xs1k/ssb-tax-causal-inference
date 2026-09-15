/*==============================================================
08_estimate_csdid_diabetes.do
Outcome secondario: prevalenza diabete tipo 2 (diabetes_prev_rate).
Stessa specifica e stimatore del do-file 06 (csdid, controllo =
mai-trattati) - unica differenza e' la variabile dipendente.
Input:  panel_master.dta
==============================================================*/

cd "C:\Users\morgh\Desktop\Stata project"
clear all
set more off
capture log close
log using "ciie_project.log", append text

capture which csdid
if _rc != 0 {
    ssc install csdid, replace
}
capture which drdid
if _rc != 0 {
    ssc install drdid, replace
}

use "panel_master.dta", clear

gen first_treat = anno_adozione
replace first_treat = 0 if missing(anno_adozione)
count if missing(first_treat)
* Atteso: 0 (stesso controllo del do-file 06).

count if !missing(diabetes_prev_rate, log_gdp_pc, log_sugar_prod)
count if !missing(diabetes_prev_rate, log_gdp_pc, edu_secondary, log_sugar_prod)
* Stesso controllo di campione del do-file 06, applicato al nuovo
* outcome: quanto costa includere edu_secondary qui?

/*----------------------------------------------------------------
STIMA CALLAWAY-SANT'ANNA - outcome: diabetes_prev_rate
Stessa specifica di controlli/gruppo di confronto del do-file 06.
------------------------------------------------------------------*/
csdid diabetes_prev_rate log_gdp_pc edu_secondary log_sugar_prod, ///
    ivar(country_id) time(year) gvar(first_treat) method(dripw)

estat simple
estat event

log close
