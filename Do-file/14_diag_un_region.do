/*==============================================================
14_diag_un_region.do
DIAGNOSTICA (nessuna stima) - primo passo verso la IV di diffusione
regionale. kountry non ha un'opzione per le regioni World Bank
(limite noto del comando): l'unica classificazione geografica
disponibile e' geo(un), a livello di continente, usata qui per tutti
i 160 paesi del pannello (non solo i trattati - la "region" gia'
presente in panel_master arriva dal file SSB-tax ed e' popolata SOLO
per i trattati, inutilizzabile qui).
Verifica delle dimensioni delle celle regione-anno PRIMA di
costruire lo strumento: una regione con un solo paese darebbe un
denominatore leave-one-out pari a zero (regione_totale - 1 = 0).
Input:  panel_master.dta
Output: un_region_xwalk.dta
==============================================================*/

cd "C:\Users\morgh\Desktop\Stata project"
clear all
set more off
capture log close
log using "ciie_project.log", append text

capture which kountry
if _rc != 0 {
    ssc install kountry, replace
}

use "panel_master.dta", clear
keep iso3
duplicates drop
count
* Atteso: 160 paesi.

kountry iso3, from(iso3c) geo(un)
rename GEO un_region

list iso3 if missing(un_region), noobs
* DIAGNOSTICA - quali paesi kountry non riesce a classificare?
* Vanno risolti a mano (come i casi gia' visti in fase di import),
* non lasciati missing.

tab un_region, missing
* DIAGNOSTICA - quanti paesi per continente? Celle piccole
* (specialmente Oceania) sono il rischio principale per il
* denominatore leave-one-out.

save "un_region_xwalk.dta", replace

log close
