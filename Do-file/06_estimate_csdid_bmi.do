/*==============================================================
06_estimate_csdid_bmi.do
Stima principale: Callaway-Sant'Anna (csdid), outcome primario
BMI DALYs. Gruppo di confronto = mai-trattati (default di csdid).
Input:  panel_master.dta
==============================================================*/

cd "C:\Users\morgh\Desktop\Stata project"
clear all
set more off
capture log close
log using "ciie_project.log", append text

/*----------------------------------------------------------------
INSTALLAZIONE PACCHETTI
csdid non e' nativo di Stata; drdid e' una dipendenza (i metodi
"doubly robust" che csdid usa sotto al cofano).
------------------------------------------------------------------*/
capture which csdid
if _rc != 0 {
    ssc install csdid, replace
}
capture which drdid
if _rc != 0 {
    ssc install drdid, replace
}

use "panel_master.dta", clear

/*----------------------------------------------------------------
VARIABILE DI GRUPPO (gvar) PER csdid
csdid richiede un "anno di primo trattamento" con 0 (non missing)
per i mai-trattati - e' cosi' che il comando li riconosce come
gruppo di controllo permanente.
------------------------------------------------------------------*/
gen first_treat = anno_adozione
replace first_treat = 0 if missing(anno_adozione)
count if missing(first_treat)
* Atteso: 0.

tab first_treat
* DIAGNOSTICA - quanti paesi per ogni coorte di adozione? Coorti
* piccole (pochi paesi per anno) danno stime evento-per-evento
* rumorose: criticita' nota dello stimatore con coorti sottili.

/*----------------------------------------------------------------
DIAGNOSTICA CAMPIONE: quanto costa includere edu_secondary?
edu_secondary ha ~35% di missing nel pannello - verifica di quanto
si riduce il campione utilizzabile PRIMA di lanciare la stima, per
sapere cosa aspettarsi.
------------------------------------------------------------------*/
count if !missing(bmi_dalys_rate, log_gdp_pc, log_sugar_prod)
count if !missing(bmi_dalys_rate, log_gdp_pc, edu_secondary, log_sugar_prod)
* Verifica dell'impatto sul campione: 
* quantificazione del drop di osservazioni dovuto ai valori mancanti 
* in edu_secondary.


/*----------------------------------------------------------------
STIMA CALLAWAY-SANT'ANNA
- ivar: identificativo panel (paese).
- time: variabile tempo (anno).
- gvar: coorte di trattamento (0 = mai trattato).
- method(dripw): stimatore doubly-robust (default consigliato).
- Gruppo di confronto: default di csdid - da verificare con
  "help csdid" che sia "never-treated" come da specifica del design
  (opzione "notyet" lo cambierebbe in "not-yet-treated": non
  utilizzata, si mantiene il default).
------------------------------------------------------------------*/
csdid bmi_dalys_rate log_gdp_pc edu_secondary log_sugar_prod, ///
    ivar(country_id) time(year) gvar(first_treat) method(dripw)

* Aggregazione ATT "semplice" (media pesata di tutti gli ATT(g,t))
estat simple

* Aggregazione event-study (effetto per anni relativi all'adozione)
estat event

log close
