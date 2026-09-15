/*==============================================================
15_build_regional_iv.do
Costruzione dello strumento di diffusione regionale (leave-one-out)
e verifica di plausibilita': (A) rilevanza - lo strumento predice
l'adozione propria? (B) falsificazione - tra i mai-trattati, lo
strumento predice comunque il LORO outcome? Se si', e' un segnale
che la diffusione regionale capta shock regionali condivisi (dieta,
cultura, commercio) e non solo il canale fiscale - violazione della
restrizione di esclusione. Questo e' un controllo di plausibilita',
non la stima principale.
Input:  panel_master.dta, un_region_xwalk.dta
Output: panel_master_iv.dta
==============================================================*/

cd "C:\Users\morgh\Desktop\Stata project"
clear all
set more off
capture log close
log using "ciie_project.log", append text

/*----------------------------------------------------------------
FIX REGIONI MANCANTI (stesso caso gia' incontrato in fase di import)
------------------------------------------------------------------*/
use "un_region_xwalk.dta", clear
replace un_region = "Oceania" if iso3 == "TKL"
replace un_region = "Asia"    if iso3 == "TWN"
count if missing(un_region)
* Atteso: 0.
save "un_region_xwalk.dta", replace

/*----------------------------------------------------------------
MERGE NEL PANNELLO
------------------------------------------------------------------*/
use "panel_master.dta", clear
merge m:1 iso3 using "un_region_xwalk.dta", keepusing(un_region)
tab _merge
* Atteso: Matched (3) per tutte le 3,840 righe (160 paesi, tutti
* nel crosswalk appena costruito).
drop _merge

/*----------------------------------------------------------------
COSTRUZIONE STRUMENTO LEAVE-ONE-OUT
- region_total: quanti paesi nella stessa regione-anno (= dimensione
  regione, costante nel tempo essendo il pannello bilanciato).
- region_taxed: quanti di quei paesi hanno ssb_tax=1 in quell'anno.
- spatial_diff: quota di ALTRI paesi della regione gia' tassati
  quell'anno (si sottrae il paese stesso da numeratore e
  denominatore - "leave-one-out").
------------------------------------------------------------------*/
bysort un_region year: egen region_total = count(iso3)
bysort un_region year: egen region_taxed = total(ssb_tax)
gen spatial_diff = (region_taxed - ssb_tax) / (region_total - 1)

count if missing(spatial_diff)
summarize spatial_diff, detail
* DIAGNOSTICA - atteso: 0 missing, valori in [0,1]. Se region_total-1
* fosse 0 per qualche regione lo strumento sarebbe missing/infinito -
* gia' escluso dalla diagnostica del do-file 14 (Oceania=15/16).

save "panel_master_iv.dta", replace

/*==================================================================
(A) RILEVANZA - lo strumento predice l'adozione propria?
Regressione lineare a fini diagnostici (non e' il first-stage 2SLS
formale, che richiederebbe una struttura event-study dedicata):
ssb_tax su spatial_diff, con effetti fissi paese e anno.
==================================================================*/
reghdfe ssb_tax spatial_diff, absorb(country_id year) vce(cluster country_id)
* Un coefficiente positivo e significativo indica che l'adozione
* nella propria regione precede/accompagna l'adozione propria -
* condizione necessaria (non sufficiente) per uno strumento valido.

/*==================================================================
(B) FALSIFICAZIONE - tra i MAI-TRATTATI, lo strumento predice il
LORO outcome (dove ssb_tax e' sempre 0, quindi nessun canale fiscale
diretto possibile)? Se sì, l'esclusione e' sospetta.
==================================================================*/
preserve
    bysort iso3: egen mai_trattato_max = max(ssb_tax)
    keep if mai_trattato_max == 0
    count
    * Quanti paesi-anno mai-trattati restano per questo test?

    reghdfe bmi_dalys_rate spatial_diff log_gdp_pc edu_secondary log_sugar_prod, ///
        absorb(country_id year) vce(cluster country_id)
    * Se spatial_diff risulta significativo QUI, dove non puo' agire
    * tramite la tassa propria (sempre 0), e' un segnale di violazione
    * dell'esclusione - lo strumento cattura altro (shock regionali
    * condivisi), non solo diffusione della policy.
restore

log close
