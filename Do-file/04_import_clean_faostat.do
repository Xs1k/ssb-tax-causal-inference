/*==============================================================
04_import_clean_faostat.do
Import e pulizia FAOSTAT: produzione di canna da zucchero e
barbabietola da zucchero, per paese-anno 2000-2023.
Input:  FAOSTAT_data_en_4-16-2026.csv
Output: faostat_sugar_clean.dta (iso3 year total_sugar_prod)
==============================================================*/

cd "C:\Users\morgh\Desktop\Stata project"
clear all
set more off
capture log close
log using "ciie_project.log", append text

import delimited "FAOSTAT_data_en_4-16-2026.csv", ///
    varnames(1) encoding("UTF-8") clear

* DIAGNOSTICA 1 - struttura del file
describe
count
tab domain
tab element
tab item
tab unit
tab flag
* Attese: un solo domain/element/unit; item con due valori (Sugar
* beet, Sugar cane); piu' flag diversi (qualita' del dato FAO).

/*----------------------------------------------------------------
GESTIONE MISSING IN "value"
- Il flag "M" ("Missing value; data cannot exist") indica che quella
  combinazione paese-item-anno non ha produzione, non un errore di
  importazione. Verifica che i missing di "value" coincidano
  ESATTAMENTE con flag=="M" prima di trattarli come 0 - un'eventuale
  mancata coincidenza segnalerebbe un problema diverso da chiarire.
------------------------------------------------------------------*/
count if missing(value)
count if flag == "M"
count if missing(value) & flag != "M"
* Atteso: quest'ultimo count deve essere 0 - se non lo e', non
* sostituire value con 0 senza aver capito perche' quelle righe
* mancano senza il flag M.

replace value = 0 if missing(value)

/*----------------------------------------------------------------
SOMMA CANNA + BARBABIETOLA PER PAESE-ANNO
- collapse (sum) ...: aggrega righe multiple (qui: i due item) in
  una sola per ogni combinazione di "by()", sommando i valori.
------------------------------------------------------------------*/
rename area location_name
collapse (sum) total_sugar_prod = value, by(location_name year)

* DIAGNOSTICA 2 - dimensione dopo l'aggregazione
count
duplicates report location_name year
isid location_name year

/*----------------------------------------------------------------
CROSSWALK location_name -> ISO3 (stessa procedura del do-file 2:
kountry from(other) stuck, poi da numerico ad alfabetico)
------------------------------------------------------------------*/
capture which kountry
if _rc != 0 {
    ssc install kountry, replace
}

preserve
    contract location_name
    drop _freq

    kountry location_name, from(other) stuck
    rename _ISO3N_ iso3n_num
    kountry iso3n_num, from(iso3n) to(iso3c)
    rename _ISO3C_ iso3

    * DIAGNOSTICA 3 - paesi non mappati automaticamente
    count if missing(iso3)
    list location_name if missing(iso3)

    * Correzioni manuali note (stessa lista del do-file 2 - un
    * sottoinsieme di questi 8 potrebbe non comparire qui, se
    * FAOSTAT non copre quel paese: nessun problema, il "replace"
    * semplicemente non trova righe da cambiare).
    replace iso3 = "BOL" if location_name == "Bolivia (Plurinational State of)"
    replace iso3 = "CPV" if location_name == "Cabo Verde"
    replace iso3 = "CIV" if location_name == "Côte d'Ivoire"
    replace iso3 = "SWZ" if location_name == "Eswatini"
    replace iso3 = "MNP" if location_name == "Northern Mariana Islands"
    replace iso3 = "TKL" if location_name == "Tokelau"
    replace iso3 = "TUR" if location_name == "Türkiye"
    replace iso3 = "VEN" if location_name == "Venezuela (Bolivarian Republic of)"

    /*--------------------------------------------------------------
    CORREZIONI SPECIFICHE DI FAOSTAT (nomenclatura FAO, diversa da
    quella GBD/IHME usata nel do-file 2 - da qui in poi sono paesi
    NON nella lista dell'8 gia' nota).
    "Sudan (former)" copre 2000-2011 (Sudan pre-scissione dal Sud
    Sudan, include quindi territorio oggi sud-sudanese); "Sudan" da
    sola copre 2012-2023. Il Sud Sudan non ha mai una riga propria
    in questo file (probabilmente non coltiva canna/barbabietola).
    Entrambi mappati su SDN per continuita' del pannello: scelta
    esplicita, non neutra - la produzione "sudanese" prima del 2011
    include territorio oggi sud-sudanese.
    --------------------------------------------------------------*/
    replace iso3 = "TWN" if location_name == "China, Taiwan Province of"
    replace iso3 = "CZE" if location_name == "Czechia"
    replace iso3 = "NLD" if location_name == "Netherlands (Kingdom of the)"
    replace iso3 = "MKD" if location_name == "North Macedonia"
    replace iso3 = "REU" if location_name == "Réunion"
    replace iso3 = "SDN" if location_name == "Sudan (former)"
    replace iso3 = "SDN" if location_name == "Sudan"
    replace iso3 = "GBR" if location_name == "United Kingdom of Great Britain and Northern Ireland"

    /*--------------------------------------------------------------
    "China" (aggregato FAO) = "China, mainland" + "China, Taiwan
    Province of", verificato esattamente per piu' anni: non e'
    un'entita' a se', e' un totale. Tenendo Taiwan separato (TWN),
    includere anche "China" duplicherebbe la sua produzione.
    "China" viene esclusa dal crosswalk (restera' "China, mainland"
    su CHN); le sue righe nel dataset principale non trovano un iso3
    al merge e vengono scartate piu' sotto, esplicitamente.
    --------------------------------------------------------------*/
    drop if location_name == "China"

    * DIAGNOSTICA 4 - restano paesi senza iso3 dopo le correzioni note?
    count if missing(iso3)
    list location_name if missing(iso3)
    * Se questa lista non e' vuota, FAOSTAT usa un nome diverso da
    * quelli gia' noti (es. "Turkey" invece di "Türkiye") - va
    * aggiunta una correzione mirata prima di proseguire.

    * NOTA: isid iso3 non e' applicabile qui, perche' "Sudan"/"Sudan
    * (former)" e "Serbia"/"Serbia and Montenegro" mappano volutamente
    * allo stesso codice pur essendo nomi diversi - scissioni di stato
    * a meta' pannello, senza sovrapposizione di anni (verificato).
    * Verifica che gli UNICI iso3 duplicati siano questi due casi
    * noti, non un errore.
    duplicates tag iso3, gen(dup_iso3)
    list location_name iso3 if dup_iso3 > 0, noobs
    * Atteso: solo Sudan/Sudan (former) e Serbia/Serbia and
    * Montenegro. Se compare altro, e' un errore di mappatura da
    * correggere prima di proseguire.
    drop dup_iso3

    keep location_name iso3
    save "faostat_iso3_xwalk.dta", replace
restore

merge m:1 location_name using "faostat_iso3_xwalk.dta"
* Senza nogen qui: l'obiettivo e' individuare le righe senza iso3.
tab _merge
list location_name year if _merge == 1, noobs
* Atteso: solo le 24 righe "China" (l'aggregato escluso sopra, una
* per anno) risultano _merge==1 (non abbinate). Se compare altro,
* investigare prima di scartare.
drop if _merge == 1
drop _merge

keep iso3 year total_sugar_prod
label variable total_sugar_prod "Produzione canna+barbabietola da zucchero, tonnellate (FAOSTAT)"
sort iso3 year

* DIAGNOSTICA 5 - dato che Sudan/Sudan (former) condividono l'iso3
* ma coprono anni diversi e non sovrapposti (2000-2011 vs 2012-2023),
* il pannello finale deve comunque avere una sola riga per iso3-anno.
* Verifica esplicita, non data per scontata.
isid iso3 year

save "faostat_sugar_clean.dta", replace

* Nota: questo file copre SOLO i paesi presenti in FAOSTAT (~162).
* Il completamento a 0 per i paesi assenti dal file (nessun record,
* non "record con valore mancante") avviene nel do-file di merge
* del pannello finale, non qui - e' li' che viene unito l'universo
* completo dei paesi.

log close
