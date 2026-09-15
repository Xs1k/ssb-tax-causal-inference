/*==============================================================
16_descriptive_stats.do
Statistiche descrittive per la sezione "Data and descriptive
statistics" delle linee guida (media, sd, min, max; confronto
trattati vs mai-trattati; distribuzioni; timeline di adozione).
Input:  panel_master.dta
Output: descriptive_table.xlsx, hist_bmi.png, adoption_timeline.png
==============================================================*/

cd "C:\Users\morgh\Desktop\Stata project"
clear all
set more off
capture log close
log using "ciie_project.log", append text

use "panel_master.dta", clear

/*----------------------------------------------------------------
TABELLA 1 - statistiche descrittive, campione intero (paese-anno)
------------------------------------------------------------------*/
tabstat bmi_dalys_rate diabetes_prev_rate gdp_pc edu_secondary ///
    total_sugar_prod, stats(n mean sd min max) columns(statistics)

/*----------------------------------------------------------------
TABELLA 2 - stesse variabili, confronto MAI-trattati vs trattati
(a livello di paese-anno; "trattati" = ssb_tax==1 in quell'anno,
quindi solo gli anni post-adozione per i paesi che adottano).
------------------------------------------------------------------*/
tabstat bmi_dalys_rate diabetes_prev_rate gdp_pc edu_secondary ///
    total_sugar_prod, by(ssb_tax) stats(n mean sd min max) columns(statistics)

/*----------------------------------------------------------------
TABELLA 3 - conteggio paesi: trattati vs mai-trattati (a livello
di paese, non paese-anno).
------------------------------------------------------------------*/
preserve
    bysort iso3: egen mai_trattato = max(ssb_tax)
    bysort iso3: keep if _n == 1
    tab mai_trattato
restore

/*----------------------------------------------------------------
GRAFICO 1 - distribuzione di bmi_dalys_rate, mai-trattati vs
trattati (kdensity sovrapposte).
------------------------------------------------------------------*/
preserve
    bysort iso3: egen mai_trattato = max(ssb_tax)
    twoway (kdensity bmi_dalys_rate if mai_trattato == 0) ///
           (kdensity bmi_dalys_rate if mai_trattato == 1), ///
        legend(order(1 "Mai trattati" 2 "Trattati (qualunque anno)")) ///
        title("Distribuzione BMI DALYs rate") ///
        xtitle("BMI DALYs per 100.000") ytitle("Densita'") ///
        note("Fonte: IHME GBD 2023. N=3.840 paese-anno, 2000-2023.")
    graph export "hist_bmi.png", replace width(1600)
restore

/*----------------------------------------------------------------
GRAFICO 2 - timeline di adozione: quanti paesi adottano ogni anno.
------------------------------------------------------------------*/
preserve
    keep if !missing(anno_adozione)
    bysort iso3: keep if _n == 1
    histogram anno_adozione, discrete frequency ///
        title("Adozioni di accisa SSB nazionale per anno") ///
        xtitle("Anno di adozione") ytitle("Numero di paesi") ///
        note("Fonte: WB Global SSB Tax Database (solo Excise, livello nazionale). N=81 paesi.")
    graph export "adoption_timeline.png", replace width(1600)
restore

/*----------------------------------------------------------------
GRAFICO 3 - correlazione GDP pc / BMI DALYs (per la sezione dati,
non e' la stima causale).
------------------------------------------------------------------*/
twoway scatter bmi_dalys_rate log_gdp_pc, msize(vsmall) mcolor(%30) ///
    title("BMI DALYs vs log PIL pro capite") ///
    xtitle("Log PIL pro capite, PPP") ytitle("BMI DALYs per 100.000") ///
    note("Ogni punto = un paese-anno, 2000-2023. Solo descrittivo, non causale.")
graph export "scatter_gdp_bmi.png", replace width(1600)

correlate bmi_dalys_rate diabetes_prev_rate log_gdp_pc edu_secondary log_sugar_prod ssb_tax

log close
