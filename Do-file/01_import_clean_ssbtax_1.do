/*==============================================================
01_import_clean_ssbtax.do
Import e pulizia del World Bank Global SSB Tax Database.
Input:  SSB-Tax-Database-Aug23.csv (raw, mai modificato a mano)
Output: ssbtax_clean.dta
==============================================================*/

cd "C:\Users\morgh\Desktop\Stata project"
clear all
set more off
capture log close
log using "ciie_project.log", replace text

/*----------------------------------------------------------------
IMPORT
- import delimited: legge un file CSV in Stata.
- varnames(1): la prima riga del file contiene i nomi delle variabili.
- bindquote(strict): tratta il contenuto tra virgolette come un unico
  campo anche se contiene virgole al suo interno (es. la colonna
  "rate" e' testo libero pieno di virgole: "25% on beverages,
  17% on..."). Senza questa opzione Stata spezzerebbe quei campi in
  colonne sbagliate, disallineando l'intera riga.
- encoding("UTF-8"): forza la codifica dei caratteri, cruciale per
  nomi con accenti/caratteri speciali (Cote d'Ivoire, Turkiye).
------------------------------------------------------------------*/
import delimited "SSB-Tax-Database-Aug23.csv", ///
    varnames(1) bindquote(strict) encoding("UTF-8") clear

* DIAGNOSTICA 1 - quante osservazioni/variabili sono state importate?
describe
count

/*----------------------------------------------------------------
RIMOZIONE RIGHE VUOTE
Il file ha centinaia di righe (e colonne) vuote in coda, artefatto
di un export da Excel. Le righe con dati veri hanno sempre un valore
in "jurisdiction"; le altre no.
------------------------------------------------------------------*/
count if missing(jurisdiction)
drop if missing(jurisdiction)
count
* Atteso: circa 130 righe rimaste con dati veri.

/*----------------------------------------------------------------
PULIZIA level
- trim(stringa): rimuove spazi bianchi iniziali/finali. Il task
  segnala spazi residui in questa variabile (es. "National " con
  spazio finale verrebbe trattato come categoria diversa da
  "National" nei tab/merge).
------------------------------------------------------------------*/
replace level = trim(level)
tab level, missing
* Controlla: le categorie (National, City/County, State/Province)
* devono comparire pulite, senza duplicati quasi-identici.

/*----------------------------------------------------------------
PULIZIA country_code verso ISO3
- Il Peru ha "PERU" invece del codice ISO3 "PER": correzione
  esplicita (non e' un errore generico, e' un caso noto).
------------------------------------------------------------------*/
replace country_code = "PER" if country_code == "PERU"

describe country_code
* Se il tipo mostrato e' strL invece di str#, la variabile non puo'
* essere usata come chiave di merge cosi' com'e': va ricreata come
* stringa a lunghezza fissa, operazione svolta comunque qui sotto
* per sicurezza.
gen str3 iso3 = trim(country_code)
count if length(iso3) != 3
list jurisdiction country_code iso3 if length(iso3) != 3
* Se questa lista non e' vuota, i codici anomali vanno corretti
* esplicitamente uno per uno (come fatto sopra per il Peru), non
* scartati automaticamente.

/*----------------------------------------------------------------
TIERED FLAG
Almeno un paese ha "tiered" mancante invece di 0.
Nessuna imputazione automatica: verifica preliminare del caso specifico.
------------------------------------------------------------------*/
list jurisdiction iso3 tiered if missing(tiered)

/*----------------------------------------------------------------
COLONNE VUOTE RESIDUE (v46-v86)
Artefatto dello stesso export Excel: verifica che siano
davvero vuote su tutte le righe rimaste prima di eliminarle.
- rownonmiss(): conta, riga per riga, quanti valori NON mancanti
  ci sono tra le variabili elencate.
------------------------------------------------------------------*/
egen byte righe_con_dati = rownonmiss(v46-v86)
count if righe_con_dati > 0
* Se il conteggio e' 0, le colonne sono vuote su tutte le righe e
* possono essere eliminate senza perdita di informazione.
drop righe_con_dati
drop v46-v86

/*----------------------------------------------------------------
DUPLICATI SU LIVELLO NAZIONALE
119 righe "National" ma il database dovrebbe avere 117 paesi unici:
almeno 2 paesi hanno piu' di una riga nazionale (probabili revisioni
di legge). La specifica prevede di tenere la PRIMA data di adozione,
ma prima e' necessario verificare cosa contengono davvero questi duplicati.
- duplicates tag: crea una variabile con quante volte ricorre la
  combinazione indicata (qui iso3, solo tra le righe National).
------------------------------------------------------------------*/
duplicates tag iso3 if level == "National", gen(dup_national)
list jurisdiction iso3 year_imp level structure rate ///
    if dup_national > 0 & level == "National", ///
    noobs abbreviate(15)
* Verifica duplicati: controllo per distinguere revisioni legislative 
* successive da errori di tracciamento.

/*----------------------------------------------------------------
DEFINIZIONE TRATTAMENTO: SOLO ACCISE (instrument == "Excise")
Tra le righe "National" convivono tre tipi di misura fiscale:
- Excise: accisa vera, colpisce la produzione/vendita interna.
- Import: dazio doganale, colpisce solo le bevande importate.
- VAT/GST: adeguamento di un'imposta generale sui consumi.
Dazio e IVA non sono "tasse SSB" nel senso sanitario del termine e
la loro presenza generava i duplicati visti sopra (New Caledonia,
Vanuatu). Il trattamento primario e' ristretto alle sole accise.
------------------------------------------------------------------*/
tab instrument if level == "National"

preserve
    keep if level == "National" & instrument == "Excise"

    * isid: verifica che iso3 identifichi in modo univoco le righe.
    * Se non fosse cosi', il comando si interrompe con un errore
    * invece di lasciar passare un duplicato non notato.
    isid iso3

    keep iso3 jurisdiction year_imp structure tiered region income_group
    rename year_imp anno_adozione
    label variable anno_adozione "Anno di adozione dell'accisa SSB nazionale"
    save "ssbtax_treated_national.dta", replace
    describe
    count
    * Atteso: 104 osservazioni, una per paese.
restore
* preserve/restore: mette da parte lo stato attuale del dataset
* (132 righe, tutti gli strumenti), fa le modifiche dentro il
* blocco per costruire la tabella dei soli paesi trattati, la
* salva, poi ripristina il dataset completo per continuare sotto.

/*----------------------------------------------------------------
SALVATAGGIO
------------------------------------------------------------------*/
save "ssbtax_clean.dta", replace

log close
