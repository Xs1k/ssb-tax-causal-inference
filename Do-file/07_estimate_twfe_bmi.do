/*==============================================================
07_estimate_twfe_bmi.do
Confronto di robustezza: TWFE statico e dinamico (event-study),
outcome primario BMI DALYs. NON e' la stima principale (lo e'
csdid, do-file 06) - serve a mostrare quanto ci si allontana
usando lo stimatore "naive" che il disegno originale sconsigliava
per via dell'adozione scaglionata (Goodman-Bacon).
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
capture which coefplot
if _rc != 0 {
    ssc install coefplot, replace
}

use "panel_master.dta", clear

/*----------------------------------------------------------------
TWFE STATICO
- absorb(country_id year): effetti fissi paese e anno (assorbiti,
  non stimati esplicitamente - piu' efficiente di dummy esplicite).
- vce(cluster country_id): errori standard clusterizzati per paese,
  standard in panel con trattamento a livello di paese.
------------------------------------------------------------------*/
reghdfe bmi_dalys_rate ssb_tax log_gdp_pc edu_secondary log_sugar_prod, ///
    absorb(country_id year) vce(cluster country_id)
estimates store twfe_static_bmi

di "Confronto: ATT csdid (do-file 06) = 34.45 (p=0.280) vs coefficiente TWFE su ssb_tax sopra"
* Se i due numeri divergono molto, e' un segnale di eterogeneita'
* di effetto nel tempo che il TWFE statico maschera (Goodman-Bacon) -
* motivo per cui csdid resta la stima principale, non questa.

/*----------------------------------------------------------------
TWFE DINAMICO (EVENT-STUDY)
- event_time: anni relativi all'adozione (missing per mai-trattati).
- Coda accorciata a +-6 anni (oltre, pochissime osservazioni per
  cella, come visto nell'event-study di csdid con SE enormi su
  Tp19-Tp22): endpoint "binnati", cioe' tutto cio' che e' oltre la
  finestra viene messo nell'ultimo bin invece di essere scartato.
- ev_6 omesso (t=-1, l'anno prima dell'adozione) come riferimento.
------------------------------------------------------------------*/
gen event_time = year - anno_adozione
replace event_time = -6 if event_time < -6 & !missing(event_time)
replace event_time =  6 if event_time >  6 & !missing(event_time)

tab event_time
* DIAGNOSTICA - quante osservazioni per anno-evento? Celle piccole
* alle code (-6, +6) danno stime meno precise li'.

gen et = event_time + 7
forvalues k = 1/13 {
    gen ev_`k' = (et == `k')
    replace ev_`k' = 0 if missing(event_time)
}
* ev_6 = t-1 (omesso, riferimento); ev_7 = t0 (anno di adozione).

reghdfe bmi_dalys_rate ev_1-ev_5 ev_7-ev_13 log_gdp_pc edu_secondary log_sugar_prod, ///
    absorb(country_id year) vce(cluster country_id)
estimates store twfe_event_bmi

coefplot twfe_event_bmi, keep(ev_*) vertical yline(0) ///
    xlabel(1 "-6" 2 "-5" 3 "-4" 4 "-3" 5 "-2" 6 "-1" 7 "0" ///
           8 "+1" 9 "+2" 10 "+3" 11 "+4" 12 "+5" 13 "+6") ///
    title("TWFE event-study: BMI DALYs") ///
    xtitle("Anni relativi all'adozione") ///
    note("Confronto di robustezza - non la stima principale (csdid)")
graph export "twfe_event_study_bmi.png", replace width(1600)

log close
