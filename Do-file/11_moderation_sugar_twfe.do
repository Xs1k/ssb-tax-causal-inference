/*==============================================================
11_moderation_sugar_twfe.do  (v2 - CORRETTO)
Moderazione: la produzione di zucchero attenua/rafforza l'effetto
della tassa? Interazione continua in un'unica regressione TWFE
(niente split del campione, a differenza del do-file 10).
Outcome: bmi_dalys_rate (primario). Robustezza secondaria, stesso
limite Goodman-Bacon gia' discusso per il do-file 07.

CORREZIONE v2: nella v1 l'interazione era generata a mano
(ssb_tax*log_sugar_prod come variabile fissa), e "margins" non
sapeva che dipendeva da log_sugar_prod - la teneva ferma al suo
valore osservato invece di ricalcolarla ai vari livelli in at().
Risultato: il grafico usciva piatto (sbagliato), anche se il
coefficiente della regressione era corretto. Qui uso la notazione
a variabili fattoriali (i.ssb_tax##c.log_sugar_prod): Stata la
riconosce come interazione vera e "margins" la ricalcola
correttamente ad ogni livello richiesto.
Input:  panel_master.dta
==============================================================*/

cd "C:\Users\morgh\Desktop\Stata project"
clear all
set more off
capture log close
log using "ciie_project.log", append text

capture which reghdfe
if _rc != 0 {
    ssc install reghdfe, replace
}

use "panel_master.dta", clear

/*----------------------------------------------------------------
DIAGNOSTICA - distribuzione di log_sugar_prod tra i trattati
------------------------------------------------------------------*/
summarize log_sugar_prod if ssb_tax == 1, detail
count if ssb_tax == 1 & log_sugar_prod == 0

/*----------------------------------------------------------------
REGRESSIONE CON INTERAZIONE A VARIABILI FATTORIALI
- i.ssb_tax##c.log_sugar_prod espande automaticamente in:
  ssb_tax (effetto principale) + log_sugar_prod (effetto
  principale) + 1.ssb_tax#c.log_sugar_prod (interazione) - NON
  vanno aggiunti a mano, altrimenti sarebbero doppi.
------------------------------------------------------------------*/
reghdfe bmi_dalys_rate i.ssb_tax##c.log_sugar_prod log_gdp_pc edu_secondary, ///
    absorb(country_id year) vce(cluster country_id)
estimates store twfe_moderation_bmi_v2

/*----------------------------------------------------------------
EFFETTO MARGINALE A VALORI TIPICI DI log_sugar_prod
Ora margins ricalcola davvero l'interazione ad ogni livello.
------------------------------------------------------------------*/
margins, dydx(ssb_tax) at(log_sugar_prod = (0 5 10 15))
marginsplot, title("Effetto marginale di ssb_tax per livello di log_sugar_prod") ///
    xtitle("log(1+produzione zucchero)") ytitle("Effetto marginale su BMI DALYs") ///
    note("Robustezza secondaria (TWFE) - non la stima principale")
graph export "twfe_moderation_sugar_bmi_v2.png", replace width(1600)

log close
