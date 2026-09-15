/*==============================================================
03_import_clean_worldbank.do
Import e pulizia World Bank: GDP pro capite (PPP) e iscrizione
scolastica secondaria, formato wide (anni in colonna) 2000-2023.
Input:  1648742c-6cc7-4c50-9a5f-62fe3886c1b5_Data.csv
Output: controls.dta (iso3 year gdp_pc edu_secondary)
==============================================================*/

cd "C:\Users\morgh\Desktop\Stata project"
clear all
set more off
capture log close
log using "ciie_project.log", append text

/*----------------------------------------------------------------
IMPORT
- stringcols(_all): importa TUTTE le colonne come stringa, non solo
  quelle numeriche. Serve perche' le colonne anno contengono ".."
  per i missing: se Stata provasse a leggerle come numeriche,
  "..", non essendo un numero, manderebbe in errore l'import o
  costringerebbe tutta la colonna a diventare stringa comunque.
  Importarle tutte come stringa fin da subito e convertirle dopo
  aver gestito ".." e' piu' sicuro.
------------------------------------------------------------------*/
import delimited "1648742c-6cc7-4c50-9a5f-62fe3886c1b5_Data.csv", ///
    varnames(1) stringcols(_all) clear

* DIAGNOSTICA 1 - nomi delle variabili anno dopo l'import (Stata
* trasforma "2000 [YR2000]" in un nome valido, es. yr2000: verificare
* che siano esattamente yr2000...yr2023 prima di procedere, altrimenti
* il reshape sotto fallisce).
describe
count

/*----------------------------------------------------------------
RIMOZIONE RIGHE DI CODA (note e righe vuote dell'export World Bank)
Le righe vere hanno sempre un countrycode; le righe di nota/vuote no.
------------------------------------------------------------------*/
count if missing(countrycode) | countrycode == ""
list countryname if missing(countrycode) | countrycode == ""
drop if missing(countrycode) | countrycode == ""
count
* Atteso: 434 osservazioni (217 paesi x 2 serie).

/*----------------------------------------------------------------
VERIFICA SERIE PRESENTI
------------------------------------------------------------------*/
tab seriesname
tab seriescode
* Attese: esattamente due serie, "GDP per capita, PPP..." e
* "School enrollment, secondary...", 217 righe ciascuna.

/*----------------------------------------------------------------
GESTIONE MISSING (".." -> vuoto) E CONVERSIONE A NUMERICO
- foreach ... of varlist yr2000-yr2023: ripete i comandi dentro le
  graffe per ogni variabile anno, una alla volta.
- destring: converte una stringa in numero; "replace" sovrascrive
  la stessa variabile invece di crearne una nuova.
------------------------------------------------------------------*/
foreach v of varlist yr2000-yr2023 {
    replace `v' = "" if `v' == ".."
    destring `v', replace
}

* DIAGNOSTICA 2 - quante celle sono missing dopo la conversione?
* (atteso: alcune, specie per school enrollment - non tutti i paesi
* riportano il dato ogni anno - ma non deve dare errori di destring)
misstable summarize yr2000-yr2023

/*----------------------------------------------------------------
RESHAPE DA WIDE (anni in colonna) A LONG (una riga per paese-serie-anno)
- keep: mantiene solo le variabili necessarie per il reshape.
- reshape long yr, i(countrycode seriescode) j(year): trasforma le
  variabili yr2000...yr2023 in una singola variabile "yr", creando
  una nuova variabile "year" che indica a quale anno si riferisce
  ciascuna riga. i() identifica le righe originali (paese+serie).
------------------------------------------------------------------*/
keep countrycode seriescode yr2000-yr2023
reshape long yr, i(countrycode seriescode) j(year)
rename yr value

* DIAGNOSTICA 3 - dimensione attesa dopo il reshape
count
* Atteso: 434 paese-serie x 24 anni = 10,416 osservazioni.

/*----------------------------------------------------------------
DA LONG (paese-serie-anno) A WIDE (paese-anno, una colonna per serie)
- preserve/restore: la serie GDP viene isolata e salvata a parte,
  poi si torna al dataset completo per lavorare sulla serie
  iscrizione scolastica; le due serie vengono riunite con un merge
  1:1.
------------------------------------------------------------------*/
preserve
    keep if seriescode == "NY.GDP.PCAP.PP.CD"
    rename value gdp_pc
    drop seriescode
    label variable gdp_pc "PIL pro capite, PPP, $ internazionali correnti (World Bank)"
    save "temp_gdp.dta", replace
restore

keep if seriescode == "SE.SEC.ENRR"
rename value edu_secondary
drop seriescode
label variable edu_secondary "Iscrizione scuola secondaria, % lordo (World Bank)"

merge 1:1 countrycode year using "temp_gdp.dta"
* DIAGNOSTICA 4 - il merge deve abbinare perfettamente (stesse 217
* combinazioni paese in entrambe le serie): _merge deve essere
* sempre 3.
tab _merge
drop _merge

rename countrycode iso3
sort iso3 year

* DIAGNOSTICA 5 - controllo finale
isid iso3 year
count
* Atteso: 217 paesi x 24 anni = 5,208 osservazioni.

save "controls.dta", replace

erase "temp_gdp.dta"
* erase: cancella il file temporaneo, non serve piu' una volta unito.

log close
