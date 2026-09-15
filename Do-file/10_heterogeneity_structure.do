/*==============================================================
10_heterogeneity_structure.do
Eterogeneita' per struttura della tassa (Specific vs Ad valorem;
Mixed escluso dalla csdid di sottogruppo, n=12 troppo piccolo per
essere affidabile) e per presenza di scaglioni (tiered).
Outcome: bmi_dalys_rate (primario). Due approcci:
  (A) csdid separata per sottogruppo - evidenza principale,
      confronto sempre contro il pool di mai-trattati.
  (B) TWFE con interazioni - test formale della differenza,
      robustezza secondaria (stesso limite Goodman-Bacon del 07).
Input:  panel_master.dta
==============================================================*/

cd "C:\Users\morgh\Desktop\Stata project"
clear all
set more off
capture log close
log using "ciie_project.log", append text

use "panel_master.dta", clear

gen first_treat = anno_adozione
replace first_treat = 0 if missing(anno_adozione)

/*==================================================================
(A) csdid PER SOTTOGRUPPO
==================================================================*/

/*----------------------------------------------------------------
A1 - Specific (35 paesi trattati) vs mai-trattati
------------------------------------------------------------------*/
preserve
    keep if structure == "Specific" | missing(anno_adozione)
    count
    count if !missing(anno_adozione)
    * Atteso: 35 trattati.
    csdid bmi_dalys_rate log_gdp_pc edu_secondary log_sugar_prod, ///
        ivar(country_id) time(year) gvar(first_treat) method(dripw)
    estat simple
restore

/*----------------------------------------------------------------
A2 - Ad valorem (34 paesi trattati) vs mai-trattati
------------------------------------------------------------------*/
preserve
    keep if structure == "Ad valorem" | missing(anno_adozione)
    count
    count if !missing(anno_adozione)
    * Atteso: 34 trattati.
    csdid bmi_dalys_rate log_gdp_pc edu_secondary log_sugar_prod, ///
        ivar(country_id) time(year) gvar(first_treat) method(dripw)
    estat simple
restore

/*----------------------------------------------------------------
A3 - Tiered = 1 (47 paesi trattati) vs mai-trattati
------------------------------------------------------------------*/
preserve
    keep if tiered == 1 | missing(anno_adozione)
    count
    count if !missing(anno_adozione)
    * Atteso: 47 trattati.
    csdid bmi_dalys_rate log_gdp_pc edu_secondary log_sugar_prod, ///
        ivar(country_id) time(year) gvar(first_treat) method(dripw)
    estat simple
restore

/*----------------------------------------------------------------
A4 - Tiered = 0 (34 paesi trattati) vs mai-trattati
------------------------------------------------------------------*/
preserve
    keep if tiered == 0 | missing(anno_adozione)
    count
    count if !missing(anno_adozione)
    * Atteso: 34 trattati.
    csdid bmi_dalys_rate log_gdp_pc edu_secondary log_sugar_prod, ///
        ivar(country_id) time(year) gvar(first_treat) method(dripw)
    estat simple
restore

/*==================================================================
(B) TWFE CON INTERAZIONI - test formale della differenza
==================================================================*/

/*----------------------------------------------------------------
B1 - struttura: confronto tra sole struttura via
(structure=="...") funziona anche se structure e' stringa vuota
per i mai-trattati - non c'e' rischio di missing numerico qui.
------------------------------------------------------------------*/
gen ssb_specific  = ssb_tax * (structure == "Specific")
gen ssb_advalorem = ssb_tax * (structure == "Ad valorem")
gen ssb_mixed     = ssb_tax * (structure == "Mixed")

reghdfe bmi_dalys_rate ssb_specific ssb_advalorem ssb_mixed ///
    log_gdp_pc edu_secondary log_sugar_prod, ///
    absorb(country_id year) vce(cluster country_id)
estimates store twfe_structure_bmi
lincom ssb_specific - ssb_advalorem
* Test differenza Specific vs Ad valorem.

/*----------------------------------------------------------------
B2 - tiered: (tiered==1) vale 0 anche se tiered e' missing (i
mai-trattati), la comparazione con "==" non propaga missing come
farebbe una disuguaglianza.
------------------------------------------------------------------*/
gen ssb_tiered1 = ssb_tax * (tiered == 1)
gen ssb_tiered0 = ssb_tax * (tiered == 0)
* NB: per i mai-trattati sia ssb_tiered1 sia ssb_tiered0 sono 0
* (ssb_tax=0), quindi non c'e' overlap/doppio conteggio.

reghdfe bmi_dalys_rate ssb_tiered1 ssb_tiered0 ///
    log_gdp_pc edu_secondary log_sugar_prod, ///
    absorb(country_id year) vce(cluster country_id)
estimates store twfe_tiered_bmi
lincom ssb_tiered1 - ssb_tiered0
* Test differenza tiered vs non-tiered.

log close
