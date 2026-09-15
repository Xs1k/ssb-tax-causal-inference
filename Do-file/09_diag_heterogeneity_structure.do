/*==============================================================
09_diag_heterogeneity_structure.do
DIAGNOSTICA (nessuna stima) - prima di costruire l'eterogeneita' per
struttura della tassa e' necessario conoscere il numero di
osservazioni per categoria: con soli 81 paesi trattati, una
struttura con pochi paesi darebbe una csdid per sottogruppo troppo
rumorosa per essere interpretabile.
Input:  panel_master.dta
==============================================================*/

cd "C:\Users\morgh\Desktop\Stata project"
clear all
set more off
capture log close
log using "ciie_project.log", append text

use "panel_master.dta", clear

/*----------------------------------------------------------------
Livello PAESE (non paese-anno): un trattato conta una volta sola.
------------------------------------------------------------------*/
preserve
    keep if !missing(anno_adozione)
    bysort iso3: keep if _n == 1

    tab structure, missing
    tab tiered, missing
    tab structure tiered, missing
restore

log close
