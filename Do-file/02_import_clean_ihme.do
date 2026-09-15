/*==============================================================
02_import_clean_ihme.do
Import e pulizia dei due file IHME GBD 2023: DALYs da alto BMI
(outcome primario) e prevalenza diabete tipo 2 (outcome secondario).
Input:  IHME-GBD_2023_DATA-c78fb2cf-1.csv   (BMI DALYs)
        IHME-GBD_2023_DATA-dc6dbc98-1.csv   (diabetes)
Output: bmi_dalys_clean.dta, diabetes_prev_clean.dta,
        location_iso3_xwalk.dta
==============================================================*/

cd "C:\Users\morgh\Desktop\Stata project"
clear all
set more off
capture log close
log using "ciie_project.log", append text

/*----------------------------------------------------------------
INSTALLAZIONE kountry (se non gia' presente)
kountry e' un comando scritto da utenti (non nativo di Stata) che
converte nomi di paese in codici ISO3. Serve perche' i file IHME
usano nomi ("Myanmar", "Turkiye") e non codici ISO3.
- capture: esegue il comando ma non interrompe il do-file se fallisce
  (utile per "non reinstallare se gia' installato").
------------------------------------------------------------------*/
capture which kountry
if _rc != 0 {
    ssc install kountry, replace
}

/*==================================================================
PARTE 1 - BMI DALYs (outcome primario)
==================================================================*/
import delimited "IHME-GBD_2023_DATA-c78fb2cf-1.csv", ///
    varnames(1) encoding("UTF-8") clear

* DIAGNOSTICA 1 - dimensioni e variabili chiave gia' filtrate a monte?
describe
count
tab measure_name
tab cause_name
tab rei_name
tab metric_name
tab age_name
tab sex_name
* Attesa: ogni tab mostra UN solo valore (il file e' gia' filtrato
* su DALYs, All causes, High body-mass index, Rate, Age-standardized,
* Both) - se compare piu' di un valore, e' necessario un "keep if"
* per restringere il campione prima di proseguire.

count if missing(val)
* Attesa: 0. Se >0, i missing vanno capiti (paese-anno senza stima?)

* 175 paesi attesi (dal controllo effettuato in precedenza) per 24
* anni (2000-2023) = 4,200 osservazioni.
duplicates report location_id year
isid location_id year

/*----------------------------------------------------------------
COSTRUZIONE CROSSWALK location_id -> ISO3
- kountry lavora sul TESTO del nome paese (from(other)), quindi va
  applicato una sola volta, qui, sul file 1. Il file 2 riutilizzera'
  questo stesso crosswalk agganciandosi su location_id (un codice
  numerico, non un testo: non risente di problemi di codifica).
------------------------------------------------------------------*/
preserve
    contract location_id location_name
    * contract: riduce il dataset a una riga per ogni combinazione
    * unica di location_id/location_name (qui, una riga per paese).
    drop _freq

    * kountry non accetta from(other) insieme a to() nella stessa
    * chiamata: from(other) fa solo "fuzzy matching" del nome contro
    * il suo dizionario interno e produce NAMES_STD (nome
    * standardizzato), senza codice. Il secondo passaggio riparte da
    * NAMES_STD con from(country) - nome gia' standard, non piu'
    * "libero" - che invece SI puo' combinare con to() per ottenere
    * il codice ISO3 alfabetico.
    * L'opzione "stuck" e' quella che mancava: senza, from(other)
    * produce solo un nome standardizzato (NAMES_STD); con "stuck",
    * produce direttamente il codice ISO3 NUMERICO (_ISO3N_), poi
    * convertito in alfabetico con un secondo passaggio.
    kountry location_name, from(other) stuck
    rename _ISO3N_ iso3n_num
    kountry iso3n_num, from(iso3n) to(iso3c)
    rename _ISO3C_ iso3

    * DIAGNOSTICA 2 - quanti paesi kountry non riesce a mappare?
    count if missing(iso3)
    list location_name if missing(iso3)

    /*--------------------------------------------------------------
    CORREZIONI MANUALI NOTE
    kountry fallisce sui nomi in forma lunga ONU per questi paesi
    specifici. Correzione esplicita, indipendentemente da cosa abbia
    prodotto kountry (anche se avesse azzeccato uno di questi per
    caso, sovrascrivere con il codice corretto e verificato non fa
    danno).
    --------------------------------------------------------------*/
    replace iso3 = "BOL" if location_name == "Bolivia (Plurinational State of)"
    replace iso3 = "CPV" if location_name == "Cabo Verde"
    replace iso3 = "CIV" if location_name == "Côte d'Ivoire"
    replace iso3 = "SWZ" if location_name == "Eswatini"
    replace iso3 = "MNP" if location_name == "Northern Mariana Islands"
    replace iso3 = "TKL" if location_name == "Tokelau"
    replace iso3 = "TUR" if location_name == "Türkiye"
    replace iso3 = "VEN" if location_name == "Venezuela (Bolivarian Republic of)"

    * DIAGNOSTICA 3 - dopo le correzioni manuali, restano paesi senza iso3?
    count if missing(iso3)
    list location_name if missing(iso3)
    * Se questa lista non e' vuota, servono altre correzioni manuali
    * mirate (stesso principio delle 8 sopra) prima di proseguire.

    isid iso3
    * Se fallisce: due nomi diversi mappano sullo stesso ISO3 (o
    * uno manca) - da correggere prima di salvare il crosswalk.

    keep location_id location_name iso3
    save "location_iso3_xwalk.dta", replace
restore

/*----------------------------------------------------------------
APPLICAZIONE CROSSWALK E SALVATAGGIO BMI DALYs
------------------------------------------------------------------*/
merge m:1 location_id using "location_iso3_xwalk.dta", ///
    keepusing(iso3) nogen
* nogen: non crea la variabile _merge, perche' atteso un
* abbinamento perfetto (il crosswalk viene proprio da questo file).
* Se il merge fallisse silenziosamente (osservazioni perse), il
* count sotto lo rivelerebbe.
count
count if missing(iso3)

keep iso3 location_name year val
rename val bmi_dalys_rate
label variable bmi_dalys_rate "DALYs da alto BMI, tasso std per 100k (IHME GBD 2023)"
save "bmi_dalys_clean.dta", replace

/*==================================================================
PARTE 2 - Prevalenza diabete tipo 2 (outcome secondario)
==================================================================*/
import delimited "IHME-GBD_2023_DATA-dc6dbc98-1.csv", ///
    varnames(1) encoding("UTF-8") clear

* DIAGNOSTICA 4 - stessa logica del file 1
describe
count
tab measure_name
tab cause_name
tab metric_name
tab age_name
tab sex_name
count if missing(val)
isid location_id year

/*----------------------------------------------------------------
VERIFICA DI COERENZA CON IL FILE 1 (controllo esplicito: le
codifiche dei due file IHME divergono?)
- Confronto dell'INSIEME di location_id: deve essere identico a
  quello del file 1 (stessi 175 paesi).
- iso3 viene agganciato tramite location_id (numerico, non risente
  di encoding) invece di essere ricalcolato con kountry su questo
  file: un'eventuale codifica diversa del nome testuale ("Cote
  d'Ivoire" vs "Côte d'Ivoire") emerge dal confronto di
  location_name dopo il merge, senza propagarsi in un secondo giro
  di kountry.
------------------------------------------------------------------*/
* Il nome-paese COSI' COM'E' STATO IMPORTATO in questo file viene
* rinominato prima del merge, per poterlo confrontare con quello del
* file 1 (portato dal crosswalk) senza conflitti di nomi tra master
* e using.
rename location_name location_name_file2

merge m:1 location_id using "location_iso3_xwalk.dta", ///
    keepusing(iso3 location_name)
* Qui SENZA nogen: l'obiettivo e' individuare, tramite _merge,
* eventuali location_id del file 2 assenti nel crosswalk (costruito
* sul file 1).
* "location_name" portata dal crosswalk è quella del file 1.
rename location_name location_name_file1

tab _merge
list location_id location_name_file2 if _merge != 3, noobs
* Atteso: _merge==3 per tutte le 4,200 righe. Se compaiono paesi con
* _merge==1 o 2, i due file non coprono esattamente gli stessi paesi.

* DIAGNOSTICA 5 - verifica esplicita di un caso noto: i due
* file IHME divergono nella scrittura dei nomi accentati?
count if location_name_file1 != location_name_file2 & _merge == 3
list location_name_file1 location_name_file2 ///
    if location_name_file1 != location_name_file2 & _merge == 3, noobs
* Se questo conteggio e' >0, il file 2 ha importato quei nomi con una
* codifica diversa dal file 1 - va corretto (di solito basta un
* ri-import con encoding esplicito, o ustrnormalize). Non e' un
* problema comunque, perche' l'aggancio avviene su location_id
* (numerico) e non sul nome: l'iso3 resta corretto in ogni caso.

drop if _merge != 3
drop _merge

keep iso3 location_name_file1 year val
rename val diabetes_prev_rate
rename location_name_file1 location_name
label variable diabetes_prev_rate "Prevalenza diabete tipo 2, tasso std per 100k (IHME GBD 2023)"
save "diabetes_prev_clean.dta", replace

log close
