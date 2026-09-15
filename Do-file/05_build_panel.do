/*==============================================================
05_build_panel.do
Costruzione del pannello finale paese-anno (2000-2023) per la
stima: outcome (IHME) + controlli (World Bank) + produzione
zucchero (FAOSTAT) + trattamento SSB (accise nazionali).
L'universo di paesi e' definito dall'outcome (175 paesi GBD): e'
il punto di partenza, tutto il resto si aggancia con merge su iso3.
Input:  bmi_dalys_clean.dta, diabetes_prev_clean.dta, controls.dta,
        faostat_sugar_clean.dta, ssbtax_treated_national.dta,
        ssbtax_clean.dta
Output: panel_master.dta
==============================================================*/

cd "C:\Users\morgh\Desktop\Stata project"
clear all
set more off
capture log close
log using "ciie_project.log", append text

/*----------------------------------------------------------------
BASE: OUTCOME PRIMARIO (BMI DALYs)
------------------------------------------------------------------*/
use "bmi_dalys_clean.dta", clear
count
isid iso3 year
* Atteso: 4,200 (175 paesi x 24 anni).

/*----------------------------------------------------------------
MERGE 1: outcome secondario (diabete)
Entrambi i file IHME vengono dallo stesso crosswalk (do-file 2):
atteso un abbinamento perfetto, _merge sempre 3.
------------------------------------------------------------------*/
merge 1:1 iso3 year using "diabetes_prev_clean.dta", keepusing(diabetes_prev_rate)
tab _merge
* Atteso: Matched (3) per tutte le 4,200 righe.
drop _merge

/*----------------------------------------------------------------
MERGE 2: controlli World Bank (GDP pc, iscrizione scolastica)
World Bank copre 217 paesi, GBD 175: atteso che alcuni paesi GBD
risultino SENZA controlli (World Bank non li copre, es. piccoli
territori) - _merge==1. Restano comunque nel pannello (usciranno
dalla regressione solo se il controllo e' effettivamente usato in
quella specifica stima); segnalati esplicitamente sotto.
------------------------------------------------------------------*/
merge 1:1 iso3 year using "controls.dta", keepusing(gdp_pc edu_secondary)
tab _merge
list iso3 location_name if _merge == 1 & year == 2010, noobs
* DIAGNOSTICA - quali paesi GBD non hanno controlli World Bank?
drop if _merge == 2
* _merge==2 sarebbero paesi World Bank senza outcome GBD: non
* rilevanti per il pannello (l'universo e' definito dall'outcome).
drop _merge

/*----------------------------------------------------------------
MERGE 3: produzione zucchero FAOSTAT
FAOSTAT copre ~162 paesi: i GBD assenti da FAOSTAT non producono
zucchero - codificati come 0, non missing (un covariato missing
farebbe sparire quei paesi dalla stima, spesso proprio paesi
mai-trattati necessari come gruppo di controllo).
------------------------------------------------------------------*/
merge 1:1 iso3 year using "faostat_sugar_clean.dta", keepusing(total_sugar_prod)
tab _merge
drop if _merge == 2
drop _merge

count if missing(total_sugar_prod)
replace total_sugar_prod = 0 if missing(total_sugar_prod)
count if missing(total_sugar_prod)
* Atteso: 0 dopo la replace.

/*----------------------------------------------------------------
MERGE 4: trattamento SSB (accise nazionali)
Questo file NON ha dimensione anno (una riga per paese trattato):
merge m:1 su iso3 soltanto. _merge==1 = mai trattati (attesi, la
maggioranza). _merge==2 = paesi nel database SSB ma assenti da GBD
(circa 14 casi: non rilevanti, privi di outcome).
------------------------------------------------------------------*/
merge m:1 iso3 using "ssbtax_treated_national.dta", ///
    keepusing(jurisdiction anno_adozione structure tiered region income_group)
tab _merge
count if _merge == 2
list iso3 jurisdiction if _merge == 2, noobs
* DIAGNOSTICA - quanti paesi accisa-SSB non hanno outcome GBD?
* (atteso: intorno a 14, caso gia' noto)
drop if _merge == 2
drop _merge

/*----------------------------------------------------------------
COSTRUZIONE TRATTAMENTO BINARIO
- ssb_tax = 1 dall'anno di adozione (incluso) in poi.
- Mai missing: i mai-trattati hanno anno_adozione missing, quindi
  la condizione "year >= anno_adozione" e' falsa (non missing) per
  loro grazie al secondo pezzo della replace sotto - verifica
  esplicita, non data per scontata.
------------------------------------------------------------------*/
gen byte ssb_tax = (year >= anno_adozione) if !missing(anno_adozione)
replace ssb_tax = 0 if missing(anno_adozione)
count if missing(ssb_tax)
* Atteso: 0. Se >0, il trattamento sta propagando missing - fermarsi
* e capire quali righe, prima di continuare.

/*----------------------------------------------------------------
ESCLUSIONE 1: adozione pre-2000 (nessun periodo pre-trattamento)
------------------------------------------------------------------*/
levelsof iso3 if anno_adozione < 2000 & !missing(anno_adozione), local(pre2000)
* Le virgolette "compound" `" "' (invece di virgolette semplici)
* servono perche' levelsof restituisce gia' ogni elemento tra
* virgolette: annidarle dentro altre virgolette semplici manda in
* errore la sintassi.
di `"Paesi esclusi per adozione pre-2000: `pre2000'"'
drop if anno_adozione < 2000 & !missing(anno_adozione)
* Atteso: esclusi 13 paesi (elenco verificato: Argentina,
* Brasile, Burkina Faso, Croazia, Figi, Paesi Bassi, Northern Mariana
* Islands, Panama, Paraguay, Peru, Samoa, Sao Tome e Principe,
* Uruguay).

/*----------------------------------------------------------------
ESCLUSIONE 2: paesi con SOLO tasse subnazionali (USA, Canada,
Micronesia - verificato nel do-file 1 che non hanno mai una riga
"National"/"Excise", quindi qui risulterebbero "mai trattati" per
costruzione anche se hanno esposizione locale reale). Esclusione
esplicita, per non lasciarli come falsi controlli puliti.
------------------------------------------------------------------*/
count if inlist(iso3, "USA", "CAN", "FSM")
drop if inlist(iso3, "USA", "CAN", "FSM")

/*----------------------------------------------------------------
VARIABILI DERIVATE PER I CONTROLLI
------------------------------------------------------------------*/
gen log_gdp_pc = log(gdp_pc)
gen log_sugar_prod = log(1 + total_sugar_prod)
label variable log_gdp_pc "Log PIL pro capite, PPP"
label variable log_sugar_prod "Log(1+produzione zucchero), tonnellate"

/*----------------------------------------------------------------
DIAGNOSTICA FINALE
------------------------------------------------------------------*/
count
* Numero di paesi trattati vs mai-trattati (a livello di paese, non
* paese-anno: bysort iso3, prendendo il massimo di ssb_tax).
preserve
    bysort iso3: egen mai_trattato = max(ssb_tax)
    bysort iso3: keep if _n == 1
    tab mai_trattato
restore

tab ssb_tax
misstable summarize gdp_pc edu_secondary log_gdp_pc log_sugar_prod bmi_dalys_rate diabetes_prev_rate
* Riporta quali variabili hanno ancora missing e quanti - normale per
* gdp_pc/edu_secondary (copertura World Bank incompleta), NON
* normale per ssb_tax o log_sugar_prod (devono essere sempre 0).

encode iso3, gen(country_id)
xtset country_id year

isid iso3 year
save "panel_master.dta", replace

log close
