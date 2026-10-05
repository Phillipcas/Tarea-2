/*==============================================================================
  PROBLEMA 6: IMPUTACIÓN DE INGRESOS NO REPORTADOS Y POBREZA LABORAL

  Fuente: ENOE 2005-I a 2026-II (sin 2020-II), todas las edades, entrevistas
  completas y residentes habituales. Se sigue el programa oficial de
  CONEVAL/INEGI para la pobreza laboral (data/pobreza_laboral) y el artículo
  de Campos-Vázquez (2013) para la imputación.
==============================================================================*/

*------------------------------------------------------------------------------
* 0. CONFIGURACIÓN GENERAL
*------------------------------------------------------------------------------
clear all
set more off
set varabbrev off
version 19

global root "C:/Users/lcastillo/Music/TAREA 2"
global data "$root/data"
global prog "$root/prog"
global log  "$root/log"
global out  "$root/papers/output"
global enoe "$data/ENOE/ENOE"
global rscript "C:/PROGRA~1/R/R-46~1.1/bin/Rscript.exe"

capture log close
log using "$log/P6_imputacion.log", replace text

set scheme s2color
graph set window fontface "Times New Roman"
global c1   "31 58 104"
global c2   "200 112 42"
global c3   "46 107 52"
global c4   "142 36 50"
global c5   "120 120 120"
global gtam "medsmall"
global gfig "xsize(6.5) ysize(4.5) graphregion(color(white) margin(small)) plotregion(color(white) lcolor(none))"
global xq   "xlabel(`=tq(2005q1)'(8)`=tq(2025q1)', format(%tqCCYY) labsize($gtam) nogrid)"
global fte  "Fuente: elaboración propia con datos de la ENOE (INEGI), 2005-2026."

* Programas de cuadros (iguales a los problemas anteriores)
capture program drop estilo_cuadro
program define estilo_cuadro
    syntax [, SIZE(integer 9)]
    collect style header result, level(hide)
    collect style cell border_block, border(right, pattern(nil))
    collect style cell cell_type[column-header corner], font(, bold) shading(background(D9D9D9))   // formato C: encabezado gris y en negrita
    collect style cell cell_type[column-header], halign(center)
    collect style cell, font("Times New Roman", size(`size'))
    capture noisily collect style title, font("Times New Roman", size(10))
end
capture program drop exporta_cuadro
program define exporta_cuadro
    syntax, ARchivo(string) NOta(string) FUente(string)
    collect export "`archivo'.xlsx", replace
    putdocx clear
    putdocx begin, font("Times New Roman", 10)
    putdocx collect
    putdocx paragraph
    putdocx text ("`nota'"), font("Times New Roman", 8)
    putdocx paragraph
    putdocx text ("`fuente'"), font("Times New Roman", 8)
    putdocx save "`archivo'.docx", replace
end

* Interruptores
global corre_base  1        // construcción de la base de personas (lectura de ENOE_todas)
global corre_imput 1        // imputaciones (hot-deck y mediana + ruido, 5 repeticiones)
global corre_sc    1        // control sintético con la ENOE
global M 5                  // número de imputaciones múltiples
set seed 20261005


/*==============================================================================
  6.0 Base de personas (todas las edades) para todos los trimestres
==============================================================================*/
if $corre_base {
use cd_a ent con v_sel n_hog h_mud n_ren tipo mes_cal ca anio_enoe trimestre_enoe ///
    fac r_def c_res clase1 clase2 eda sex anios_esc emp_ppal pos_ocu hrsocup ingocup ///
    p6b2 p6c p6_9 p6a3 salario t_loc mun cve_mun ///
    using "$enoe/ENOE_todas.dta" if r_def == 0 & inlist(c_res, 1, 3), clear
drop r_def c_res
foreach v in p6b2 p6c p6_9 p6a3 salario t_loc mun cve_mun tipo mes_cal ca emp_ppal pos_ocu {
    capture confirm string variable `v'
    if !_rc destring `v', replace force
}
replace mun = cve_mun if missing(mun) & !missing(cve_mun)
drop cve_mun
rename (anio_enoe trimestre_enoe) (anio trimestre)
gen int dateq = yq(anio, trimestre)
format dateq %tq
egen long hid = group(dateq cd_a ent con v_sel n_hog h_mud tipo mes_cal ca), missing
compress
save "$data/construidas/p6_enoe_personas.dta", replace
}

use "$data/construidas/p6_enoe_personas.dta", clear

* Definiciones del programa oficial de CONEVAL/INEGI
gen byte ocupado = (clase1 == 1 & clase2 == 1)
recode p6b2 (999998 999999 = .)
gen byte sinpago = (missing(p6b2) & (p6_9 == 9 | p6a3 == 3))
gen byte remun   = ocupado & !sinpago                     // ocupado con remuneración
gen byte nodecl  = remun & missing(p6b2)                  // no declara monto de ingreso
gen byte conrango = nodecl & inrange(p6c, 1, 7)           // pero sí su rango de salarios mínimos
gen byte formal  = (emp_ppal == 2) if remun
gen byte edg     = cond(anios_esc < 6, 1, cond(anios_esc < 9, 2, cond(anios_esc < 12, 3, cond(anios_esc < 16, 4, 5)))) if !missing(anios_esc) & anios_esc != 99
label define ledg 1 "Menos de primaria" 2 "Primaria" 3 "Secundaria" 4 "Preparatoria" 5 "Universidad", replace
label values edg ledg
gen byte rural = (t_loc == 4)
gen byte eg    = cond(eda < 25, 1, cond(eda < 35, 2, cond(eda < 45, 3, cond(eda < 55, 4, 5))))

* Ingreso con el programa oficial (recuperación por rangos de salarios mínimos)
gen double ing_of = p6b2
replace ing_of = 0 if ocupado == 0
replace ing_of = 0 if sinpago
replace ing_of = 0.5 * salario if missing(p6b2) & p6c == 1
replace ing_of = 1   * salario if missing(p6b2) & p6c == 2
replace ing_of = 1.5 * salario if missing(p6b2) & p6c == 3
replace ing_of = 2.5 * salario if missing(p6b2) & p6c == 4
replace ing_of = 4   * salario if missing(p6b2) & p6c == 5
replace ing_of = 7.5 * salario if missing(p6b2) & p6c == 6
replace ing_of = 10  * salario if missing(p6b2) & p6c == 7
gen byte mv = (missing(ing_of) & ocupado == 1)

* Líneas de pobreza extrema por ingresos (CONEVAL) y deflactor trimestral
preserve
    import delimited using "$data/pobreza_laboral/lpei_trimestral_2005_2026.csv", clear
    gen int dateq = yq(anio, trimestre)
    keep dateq lpei_urbano lpei_rural
    tempfile lp
    save `lp'
    use "$data/INPC/inpc_mensual_1990_2026.dta", clear
    summarize inpc if anio == 2026 & mes == 1, meanonly
    local base = r(mean)
    gen byte trimestre = ceil(mes / 3)
    collapse (mean) inpc, by(anio trimestre)
    gen int dateq = yq(anio, trimestre)
    gen double defl = `base' / inpc
    keep dateq defl
    tempfile dq
    save `dq'
restore


/*==============================================================================
  6.2 Trabajadores que no reportan ingresos
==============================================================================*/
preserve
    keep if remun
    gen byte hombre = (sex == 1)
    * Serie total y por grupos (porcentaje de ocupados remunerados que no declara monto)
    collapse (mean) nodecl [pw = fac], by(dateq)
    tempfile t0
    save `t0'
restore
preserve
    keep if remun
    collapse (mean) nd = nodecl [pw = fac], by(dateq formal)
    reshape wide nd, i(dateq) j(formal)
    rename (nd0 nd1) (nd_informal nd_formal)
    tempfile t1
    save `t1'
restore
preserve
    keep if remun & !missing(edg)
    collapse (mean) nd = nodecl [pw = fac], by(dateq edg)
    reshape wide nd, i(dateq) j(edg)
    tempfile t2
    save `t2'
restore
preserve
    keep if remun
    collapse (mean) nd = nodecl [pw = fac], by(dateq sex)
    reshape wide nd, i(dateq) j(sex)
    rename (nd1 nd2) (nd_hombre nd_mujer)
    tempfile t3
    save `t3'
restore
preserve
    keep if nodecl
    collapse (mean) conrango [pw = fac], by(dateq)
    tempfile t4
    save `t4'
restore
preserve
    use `t0', clear
    foreach f in t1 t2 t3 t4 {
        merge 1:1 dateq using ``f'', nogenerate
    }
    foreach v of varlist nodecl nd_* nd1-nd5 conrango {
        replace `v' = 100 * `v'
    }
    tsset dateq
    tsfill
    save "$data/construidas/p6_noreporte.dta", replace
    list dateq nodecl nd_formal nd_informal nd5 conrango if inlist(dateq, tq(2005q1), tq(2010q1), tq(2015q1), tq(2019q1), tq(2023q1), tq(2026q2)), noobs

    local op "$xq ylabel(, labsize($gtam) angle(horizontal) format(%9.0f) grid glcolor(gs14)) ytitle(Porcentaje, size($gtam)) xtitle(Trimestre, size($gtam)) graphregion(color(white)) plotregion(color(white) lcolor(none))"
    twoway (line nodecl dateq, lcolor("$c1") lwidth(medthick) cmissing(n)) ///
           (line conrango dateq, lcolor("$c2") lwidth(medthick) lpattern(dash) cmissing(n)), ///
        `op' legend(order(1 "Ocupados remunerados que no declaran su ingreso" 2 "De ellos: sí declaran su rango de salarios mínimos") ///
        rows(2) size(small) position(6) region(lcolor(white))) ///
        note("Nota: ocupados con remuneración (se excluye a quienes no reciben pago); porcentajes ponderados con el factor de expansión." ///
             "Sin dato en 2020-II (ETOE)." "$fte", size(small) span) $gfig
    graph export "$out/Fig_6_2_noreporte_total.png", width(2400) replace

    * paneles: años cada 10, leyendas de dos renglones (mismo alto de gráfica) y título del eje y solo en el primero
    local opg "xlabel(`=tq(2005q1)'(40)`=tq(2025q1)', format(%tqCCYY) labsize($gtam) nogrid) ylabel(0(10)60, labsize($gtam) angle(horizontal) format(%9.0f) grid glcolor(gs14)) xtitle(Trimestre, size($gtam)) graphregion(color(white)) plotregion(color(white) lcolor(none))"
    twoway (line nd_formal dateq, lcolor("$c1") lwidth(medthick) cmissing(n)) (line nd_informal dateq, lcolor("$c2") lwidth(medthick) lpattern(dash) cmissing(n)), ///
        title("Formalidad", size($gtam) color(black)) `opg' ytitle(Porcentaje, size($gtam)) ///
        legend(order(1 "Formal" 2 "Informal") rows(2) size(small) region(lcolor(white))) name(g1, replace) nodraw
    twoway (line nd1 dateq, lcolor("$c5") cmissing(n)) (line nd2 dateq, lcolor("$c3") cmissing(n)) (line nd3 dateq, lcolor("$c2") cmissing(n)) ///
           (line nd4 dateq, lcolor("$c4") cmissing(n)) (line nd5 dateq, lcolor("$c1") lwidth(medthick) cmissing(n)), ///
        title("Escolaridad", size($gtam) color(black)) `opg' ytitle("") ///
        legend(order(1 "< Prim." 2 "Primaria" 3 "Secund." 4 "Prepa." 5 "Univ.") cols(3) size(small) region(lcolor(white))) name(g2, replace) nodraw
    twoway (line nd_hombre dateq, lcolor("$c1") lwidth(medthick) cmissing(n)) (line nd_mujer dateq, lcolor("$c2") lwidth(medthick) lpattern(dash) cmissing(n)), ///
        title("Sexo", size($gtam) color(black)) `opg' ytitle("") ///
        legend(order(1 "Hombres" 2 "Mujeres") rows(2) size(small) region(lcolor(white))) name(g3, replace) nodraw
    graph combine g1 g2 g3, rows(1) iscale(0.8) graphregion(color(white)) xsize(6.5) ysize(3.4) ///
        note("Nota: porcentaje de ocupados remunerados que no declaran el monto de su ingreso, por grupo; ponderado con el factor de expansión." ///
             "Escolaridad: menos de primaria, primaria, secundaria, preparatoria y universidad completas. Sin dato en 2020-II (ETOE)." ///
             "$fte", size(vsmall) span)
    graph export "$out/Fig_6_2_noreporte_grupos.png", width(2400) replace
restore

* ¿Es aleatoria la no respuesta? Características de quienes declaran y no declaran (III trimestre)
preserve
    keep if remun & inlist(dateq, tq(2005q3), tq(2025q3))
    gen byte mujer = (sex == 2)
    gen byte universidad = (edg == 5)
    gen byte tcompleto = (hrsocup >= 35)
    gen byte anio_c = cond(dateq == tq(2005q3), 1, 2)
    label define lanio_c 1 "2005-III" 2 "2025-III", replace
    label values anio_c lanio_c
    label define lnodecl 0 "Declara" 1 "No declara", replace
    label values nodecl lnodecl
    label var eda         "Edad"
    label var mujer       "Mujer"
    label var formal      "Formal"
    label var rural       "Rural"
    label var tcompleto   "Tiempo completo (35 horas o más)"
    label var universidad "Universidad"
    table (var) (anio_c nodecl) [aw = fac], statistic(mean eda mujer formal rural tcompleto universidad) nototals
    estilo_cuadro
    collect style header anio_c nodecl, title(hide)
    collect style cell, nformat(%9.2f)
    collect title "Cuadro 6.1. Características de los ocupados remunerados según declaren o no su ingreso"
    exporta_cuadro, archivo("$out/Cuadro_6_1_enoe_no_declaran") ///
        nota("Nota: medias ponderadas con el factor de expansión; ocupados con remuneración en el tercer trimestre de cada año.") ///
        fuente("$fte")
    logit nodecl eda mujer formal rural tcompleto i.edg [pw = fac] if dateq == tq(2025q3)
restore


/*==============================================================================
  6.4 Pobreza laboral con el programa oficial (por trimestre, nacional y entidad)
==============================================================================*/
merge m:1 dateq using `lp', keep(match) nogenerate
merge m:1 dateq using `dq', keep(match) nogenerate
gen byte rururb = !inrange(t_loc, 1, 3)
gen byte tamh = 1
save "$data/construidas/p6_enoe_personas_def.dta", replace

preserve
    collapse (sum) tamh ing_of mv (mean) rururb fac ent mun lpei_urbano lpei_rural defl, by(hid dateq)
    drop if mv > 0                                         // hogares con ingresos faltantes (programa oficial)
    gen double factorp = fac * tamh
    gen byte pobre = (ing_of / tamh < cond(rururb == 0, lpei_urbano, lpei_rural))
    gen double ilpc = ing_of / tamh * defl
    save "$data/construidas/p6_hogares_oficial.dta", replace
    collapse (mean) pl = pobre ilpc [pw = factorp], by(dateq)
    replace pl = 100 * pl
    save "$data/construidas/p6_pl_replica.dta", replace
restore

* Comparación con la serie oficial publicada
use "$data/construidas/p6_pl_replica.dta", clear
merge 1:1 dateq using "$data/pobreza_laboral/pl_nacional_trimestral_2005_2026.dta", keepusing(pl_nacional ilpc_nacional) nogenerate
list dateq pl pl_nacional if inlist(dateq, tq(2005q1), tq(2010q1), tq(2016q1), tq(2020q1), tq(2024q1), tq(2026q2)), noobs
correlate pl pl_nacional
save "$data/construidas/p6_pl_replica.dta", replace

* Pobreza multidimensional (ENIGH, CONEVAL) nacional y por entidad
use anio ent factor pobreza using "$data/ENIGH/ENIGH/pobreza_panel_2016_2024.dta", clear
preserve
    collapse (mean) pobreza [pw = factor], by(anio)
    replace pobreza = 100 * pobreza
    gen int dateq = yq(anio, 3)
    save "$data/construidas/p6_pobreza_enigh_nacional.dta", replace
    list, noobs
restore
collapse (mean) pobreza [pw = factor], by(anio ent)
replace pobreza = 100 * pobreza
save "$data/construidas/p6_pobreza_enigh_entidad.dta", replace

* Pobreza laboral por entidad (programa oficial) para la dispersión y los mapas
use "$data/construidas/p6_hogares_oficial.dta", clear
collapse (mean) pl = pobre [pw = factorp], by(dateq ent)
replace pl = 100 * pl
gen int anio = year(dofq(dateq))
gen byte trim = quarter(dofq(dateq))
save "$data/construidas/p6_pl_entidad.dta", replace
preserve
    keep if trim == 2 & inlist(anio, 2006, 2016, 2026)
    keep ent anio pl
    reshape wide pl, i(ent) j(anio)
    export delimited using "$data/construidas/p6_pl_entidad_mapas.csv", replace
restore

* Figura: series de tiempo (últimos 10 años)
use "$data/construidas/p6_pl_replica.dta", clear
merge 1:1 dateq using "$data/construidas/p6_pobreza_enigh_nacional.dta", keepusing(pobreza) nogenerate   // mismo renglón por trimestre (sin cortes en la línea)
keep if dateq >= tq(2016q1)
twoway (line pl dateq, lcolor("$c1") lwidth(medthick) cmissing(n) sort) ///
       (connected pobreza dateq, lcolor("$c2") mcolor("$c2") msymbol(O) lwidth(medthick) sort), ///
    ytitle("Porcentaje de la población", size($gtam)) xtitle("Trimestre", size($gtam)) ///
    xlabel(`=tq(2016q1)'(8)`=tq(2026q1)', format(%tqCCYY) labsize($gtam) nogrid) ///
    ylabel(20(10)50, labsize($gtam) angle(horizontal) grid glcolor(gs14)) ///
    legend(order(1 "Pobreza laboral (ENOE, trimestral)" 2 "Pobreza multidimensional (ENIGH)") rows(1) size(small) position(6) region(lcolor(white))) ///
    note("Nota: pobreza laboral: ingreso laboral per cápita del hogar menor a la línea de pobreza extrema por ingresos" ///
         "(programa INEGI/CONEVAL). La pobreza multidimensional de la ENIGH se ubica en el tercer trimestre de cada año de levantamiento." ///
         "Fuente: elaboración propia con datos de la ENOE y la ENIGH (INEGI) y CONEVAL.", size(small) span) $gfig
graph export "$out/Fig_6_4_series_pobreza.png", width(2400) replace

* Figura: dispersión por entidad y año (ENOE en x, ENIGH en y)
use "$data/construidas/p6_pl_entidad.dta", clear
keep if trim == 3 & inlist(anio, 2016, 2018, 2020, 2022, 2024)
merge 1:1 anio ent using "$data/construidas/p6_pobreza_enigh_entidad.dta", keep(match) nogenerate
correlate pl pobreza
local r : display %4.2f r(rho)
regress pobreza pl
local b : display %4.2f _b[pl]
twoway (scatter pobreza pl, mcolor("$c1%60") msymbol(O) msize(small)) ///
       (lfit pobreza pl, lcolor("$c2") lwidth(medthick)), ///
    ytitle("Pobreza multidimensional, ENIGH (%)", size($gtam)) xtitle("Pobreza laboral, ENOE (%)", size($gtam)) ///
    xlabel(, labsize($gtam) nogrid) ylabel(, labsize($gtam) angle(horizontal) grid glcolor(gs14)) ///
    legend(order(1 "Entidad y año" 2 "Ajuste lineal") rows(1) size(small) position(6) region(lcolor(white))) ///
    note("Nota: 32 entidades en 2016, 2018, 2020, 2022 y 2024; pobreza laboral del tercer trimestre de cada año." ///
         "Correlación = `r'; pendiente del ajuste lineal = `b'." ///
         "Fuente: elaboración propia con datos de la ENOE y la ENIGH (INEGI) y CONEVAL.", size(small) span) $gfig
graph export "$out/Fig_6_4_dispersion_pobreza.png", width(2400) replace

* Mapas en R (pobreza laboral por entidad, 2006, 2016 y 2026)
shell $rscript "$prog/P6_mapas.R"


/*==============================================================================
  6.5 Réplica de Campos-Vázquez (2013), 2005-2026: imputación de ingresos
  (1) Hot-deck con bootstrap bayesiano aproximado (Rubin y Schenker, 1986)
  (2) Mediana del grupo más ruido normal (mediana + DE x N(0,1))
  Receptores: ocupados remunerados que no declaran monto. Donadores: ocupados
  remunerados con ingreso declarado positivo. Celdas: trimestre x rango de
  salarios mínimos (si lo declaró) x sexo x edad x escolaridad x formalidad x
  rural; si una celda no tiene donadores se usa una celda más amplia.
  5 imputaciones múltiples; los resultados son el promedio de las 5.
==============================================================================*/
if $corre_imput {
use "$data/construidas/p6_enoe_personas_def.dta", clear
gen long pid = _n
* Rango de salarios mínimos de los donadores (mismas categorías que p6c)
gen double razon = p6b2 / salario if remun & p6b2 > 0 & !missing(p6b2)
gen byte rng = .
replace rng = 1 if razon <= 1
replace rng = 3 if razon > 1 & razon <= 2
replace rng = 4 if razon > 2 & razon <= 3
replace rng = 5 if razon > 3 & razon <= 5
replace rng = 6 if razon > 5 & razon <= 10
replace rng = 7 if razon > 10 & !missing(razon)
replace rng = p6c if nodecl & inrange(p6c, 1, 7)
replace rng = 3 if rng == 2                                  // "1 salario mínimo" se agrupa con 1 a 2
replace rng = 0 if nodecl & missing(rng)
gen byte don = remun & p6b2 > 0 & !missing(p6b2)
gen byte rec = nodecl
replace edg = 0 if missing(edg)
replace formal = 0 if missing(formal)
tempfile trabajo
keep if don | rec
keep pid dateq rng sex eg edg formal rural don rec p6b2
save `trabajo'

capture program drop imputa
program define imputa
    * Asigna a los receptores sin valor un donador de la misma celda (hot-deck con ABB)
    * o la mediana + ruido de la celda. Argumentos: variables de celda y método.
    syntax varlist, METodo(string) GEN(name)
    tempvar cel u rk n0 j pool
    egen long `cel' = group(`varlist'), missing
    gen double `u' = runiform()
    sort `cel' don `u'
    by `cel' don: gen long `rk' = _n if don
    by `cel': egen long `n0' = total(don)
    if "`metodo'" == "hotdeck" {
        * Paso 1 (ABB): la posición j del "pool" de cada celda recibe un donador al azar
        gen long `pool' = ceil(runiform() * `n0') if don
        * Paso 2: cada receptor sin valor elige una posición j del pool
        gen long `j' = ceil(runiform() * `n0') if rec & missing(`gen') & `n0' > 0
        preserve
            keep if don
            keep `cel' `rk' `pool' p6b2
            tempfile D
            save `D'
            rename (`rk' `pool') (`j' donr)
            keep `cel' `j' donr
            tempfile A
            save `A'
            use `D', clear
            rename (`rk' p6b2) (donr valor)
            keep `cel' donr valor
            tempfile B
            save `B'
        restore
        merge m:1 `cel' `j' using `A', keep(master match) nogenerate     // posición -> donador del pool
        merge m:1 `cel' donr using `B', keep(master match) nogenerate    // donador -> su ingreso
        replace `gen' = valor if rec & missing(`gen') & !missing(valor)
        drop donr valor
    }
    else {
        tempvar med sd
        by `cel': egen double `med' = median(cond(don, p6b2, .))
        by `cel': egen double `sd'  = sd(cond(don, p6b2, .))
        replace `sd' = 0 if missing(`sd')
        tempvar z
        gen double `z' = `med' + `sd' * rnormal() if rec & missing(`gen') & `n0' > 0
        forvalues k = 1/5 {
            replace `z' = `med' + `sd' * rnormal() if rec & missing(`gen') & `n0' > 0 & `z' <= 0
        }
        replace `z' = `med' if rec & missing(`gen') & `n0' > 0 & `z' <= 0
        replace `gen' = `z' if rec & missing(`gen') & !missing(`z')
    }
end

forvalues m = 1/$M {
    foreach met in hotdeck mediana {
        use `trabajo', clear
        gen double imp = .
        * Con rango de salarios mínimos: primero dentro del mismo rango
        imputa dateq rng sex eg edg formal rural, metodo(`met') gen(imp)
        imputa dateq rng sex edg formal, metodo(`met') gen(imp)
        * Sin rango (o sin donador en su rango): celdas sin la variable de rango
        imputa dateq sex eg edg formal rural, metodo(`met') gen(imp)
        imputa dateq sex edg formal, metodo(`met') gen(imp)
        imputa dateq edg, metodo(`met') gen(imp)
        count if rec & missing(imp)
        di as txt "`met' `m': receptores sin imputar = " r(N)
        keep if rec
        keep pid imp
        rename imp imp_`met'_`m'
        tempfile i_`met'_`m'
        save `i_`met'_`m''
    }
}

* Ingreso del hogar, pobreza laboral e ingreso laboral per cápita con cada imputación
use dateq hid tamh ocupado sinpago p6b2 nodecl rururb fac lpei_urbano lpei_rural defl ///
    using "$data/construidas/p6_enoe_personas_def.dta", clear
gen long pid = _n                                          // mismo orden que al construir las imputaciones
tempname pf
tempfile res
postfile `pf' str10 metodo byte m int dateq double(pl ilpc) using `res', replace
forvalues m = 1/$M {
    foreach met in hotdeck mediana {
        preserve
            merge 1:1 pid using `i_`met'_`m'', keep(master match) nogenerate
            gen double ing = cond(ocupado == 0 | sinpago, 0, p6b2)
            replace ing = imp_`met'_`m' if nodecl
            replace ing = 0 if missing(ing)                    // menos del 1% sin donador
            collapse (sum) tamh ing (mean) rururb fac lpei_urbano lpei_rural defl, by(hid dateq)
            gen double factorp = fac * tamh
            gen byte pobre = (ing / tamh < cond(rururb == 0, lpei_urbano, lpei_rural))
            gen double ilpc = ing / tamh * defl
            collapse (mean) pobre ilpc [pw = factorp], by(dateq)
            forvalues i = 1/`=_N' {
                post `pf' ("`met'") (`m') (dateq[`i']) (100 * pobre[`i']) (ilpc[`i'])
            }
        restore
    }
}
postclose `pf'
use `res', clear
collapse (mean) pl ilpc, by(metodo dateq)
reshape wide pl ilpc, i(dateq) j(metodo) string
merge 1:1 dateq using "$data/construidas/p6_pl_replica.dta", keepusing(pl pl_nacional ilpc_nacional) nogenerate
merge 1:1 dateq using `dq', keep(master match) nogenerate
gen double ilpc_of = ilpc_nacional * defl
tsset dateq
tsfill
save "$data/construidas/p6_imputacion_resultados.dta", replace
list dateq pl_nacional plhotdeck plmediana ilpc_of ilpchotdeck ilpcmediana if inlist(dateq, tq(2005q1), tq(2012q3), tq(2019q1), tq(2026q2)), noobs
}

use "$data/construidas/p6_imputacion_resultados.dta", clear
* 2023-IV no está en la serie publicada descargada: se usa la réplica (idéntica en los demás trimestres)
merge 1:1 dateq using "$data/construidas/p6_pl_replica.dta", keepusing(ilpc) keep(master match) nogenerate
replace pl_nacional = pl if missing(pl_nacional) & !missing(pl)
replace ilpc_of = ilpc if missing(ilpc_of) & !missing(ilpc)
local op "$xq ylabel(, labsize($gtam) angle(horizontal) grid glcolor(gs14)) xtitle(Trimestre, size($gtam))"
twoway (line pl_nacional dateq, lcolor(black) lwidth(medthick) cmissing(n)) ///
       (line plhotdeck dateq, lcolor("$c1") lwidth(medthick) lpattern(dash) cmissing(n)) ///
       (line plmediana dateq, lcolor("$c2") lwidth(medthick) lpattern(shortdash) cmissing(n)), ///
    ytitle("Porcentaje de la población en pobreza laboral", size($gtam)) `op' ///
    legend(order(1 "Oficial (INEGI/CONEVAL)" 2 "Hot-deck" 3 "Mediana del grupo + ruido") rows(1) size(small) position(6) region(lcolor(white))) ///
    note("Nota: con imputación se asigna ingreso a los ocupados remunerados que no lo declaran (5 imputaciones múltiples) y no se" ///
         "excluye ningún hogar; la cifra oficial recupera ingresos por rangos de salarios mínimos y excluye hogares con ingresos faltantes." ///
         "El dato oficial de 2023-IV, ausente en la serie publicada, proviene de la réplica del programa oficial." ///
         "$fte", size(small) span) $gfig
graph export "$out/Fig_6_5_pobreza_laboral_imputacion.png", width(2400) replace
twoway (line ilpc_of dateq, lcolor(black) lwidth(medthick) cmissing(n)) ///
       (line ilpchotdeck dateq, lcolor("$c1") lwidth(medthick) lpattern(dash) cmissing(n)) ///
       (line ilpcmediana dateq, lcolor("$c2") lwidth(medthick) lpattern(shortdash) cmissing(n)), ///
    ytitle("Pesos mensuales por persona (enero de 2026)", size($gtam)) `op' ylabel(, format(%9.0fc)) ///
    legend(order(1 "Oficial (INEGI/CONEVAL)" 2 "Hot-deck" 3 "Mediana del grupo + ruido") rows(1) size(small) position(6) region(lcolor(white))) ///
    note("Nota: ingreso laboral per cápita del hogar, promedio ponderado por personas, en pesos de enero de 2026 (INPC del trimestre)." ///
         "El dato oficial de 2023-IV, ausente en la serie publicada, proviene de la réplica del programa oficial." ///
         "$fte", size(small) span) $gfig
graph export "$out/Fig_6_5_ingreso_laboral_pc_imputacion.png", width(2400) replace


/*==============================================================================
  6.8 Control sintético con la ENOE: pobreza laboral y tasas de ocupación
  Tratada: ZLFN (municipios del decreto); donadores: 31 entidades sin sus
  municipios de la ZLFN (Baja California queda fuera). Trimestral, 2015-I a
  2026-II; el 2020-II (sin levantamiento) se interpola linealmente.
  Tasa de ocupación = ocupados / población de 15 años o más.
==============================================================================*/
if $corre_sc {
import delimited using "$data/zlfn/zlfn_municipios.csv", clear varnames(1)
keep cvegeo
destring cvegeo, replace
gen byte zlfn = 1
tempfile z
save `z'

use dateq hid ent mun eda sex ocupado fac using "$data/construidas/p6_enoe_personas_def.dta" if dateq >= tq(2015q1), clear
gen long cvegeo = ent * 1000 + mun
merge m:1 cvegeo using `z', keep(master match) nogenerate
replace zlfn = 0 if missing(zlfn)
gen byte unidad = cond(zlfn == 1, 33, ent)
drop if unidad == 2
gen byte p15 = (eda >= 15 & eda <= 98)
gen byte oc_h = ocupado if sex == 1 & p15
gen byte oc_m = ocupado if sex == 2 & p15
gen byte oc   = ocupado if p15
collapse (mean) t_oc = oc t_oc_h = oc_h t_oc_m = oc_m [pw = fac], by(unidad dateq)
tempfile tasas
save `tasas'
* Pobreza laboral por unidad (programa oficial)
use hid dateq ent mun using "$data/construidas/p6_enoe_personas_def.dta" if dateq >= tq(2015q1), clear
bysort hid: keep if _n == 1
gen long cvegeo = ent * 1000 + mun
merge m:1 cvegeo using `z', keep(master match) nogenerate
keep hid zlfn
replace zlfn = 0 if missing(zlfn)
merge 1:1 hid using "$data/construidas/p6_hogares_oficial.dta", keep(match) keepusing(dateq ent pobre factorp) nogenerate
gen byte unidad = cond(zlfn == 1, 33, ent)
drop if unidad == 2
collapse (mean) pl = pobre [pw = factorp], by(unidad dateq)
merge 1:1 unidad dateq using `tasas', nogenerate
foreach v in pl t_oc t_oc_h t_oc_m {
    replace `v' = 100 * `v'
}
tsset unidad dateq
tsfill
foreach v in pl t_oc t_oc_h t_oc_m {
    by unidad: ipolate `v' dateq, gen(i_`v')
    replace `v' = i_`v' if missing(`v')
    drop i_`v'
}
label define lunidad 33 "ZLFN", replace
label values unidad lunidad
save "$data/construidas/p6_panel_zlfn.dta", replace

local sp1  "Y(`=tq(2015q1)') Y(`=tq(2016q1)') Y(`=tq(2017q1)') Y(`=tq(2018q1)') Y(`=tq(2018q4)')"
local sp2  "Y(`=tq(2015q1)'(1)`=tq(2015q4)') Y(`=tq(2016q1)'(1)`=tq(2016q4)') Y(`=tq(2017q1)'(1)`=tq(2017q4)') Y(`=tq(2018q1)'(1)`=tq(2018q4)')"
local sp3  "Y(`=tq(2018q1)') Y(`=tq(2018q2)') Y(`=tq(2018q3)') Y(`=tq(2018q4)')"
local sp4  "Y(`=tq(2015q3)') Y(`=tq(2016q3)') Y(`=tq(2017q3)') Y(`=tq(2018q3)') Y(`=tq(2018q4)')"
local sp5  "Y(`=tq(2015q2)') Y(`=tq(2015q4)') Y(`=tq(2016q2)') Y(`=tq(2016q4)') Y(`=tq(2017q2)') Y(`=tq(2017q4)') Y(`=tq(2018q2)') Y(`=tq(2018q4)')"
local sp6  "Y(`=tq(2015q1)'(1)`=tq(2018q4)') Y(`=tq(2018q4)')"
local sp7  "Y(`=tq(2017q1)'(1)`=tq(2017q4)') Y(`=tq(2018q1)'(1)`=tq(2018q4)') Y(`=tq(2018q4)')"
local sp8  "Y(`=tq(2016q4)') Y(`=tq(2017q4)') Y(`=tq(2018q4)')"
local sp9  "Y(`=tq(2015q1)'(1)`=tq(2016q4)') Y(`=tq(2017q1)'(1)`=tq(2018q4)')"
local sp10 "Y(`=tq(2017q1)') Y(`=tq(2017q3)') Y(`=tq(2018q1)') Y(`=tq(2018q3)') Y(`=tq(2018q4)')"
local sp11 "Y(`=tq(2015q4)') Y(`=tq(2016q4)') Y(`=tq(2017q4)') Y(`=tq(2018q2)') Y(`=tq(2018q4)')"
local sp12 "Y(`=tq(2016q1)'(1)`=tq(2018q4)')"
local desc1  "I de cada año y 2018-IV"
local desc2  "Promedios anuales 2015-2018"
local desc3  "Trimestres de 2018"
local desc4  "III de cada año y 2018-IV"
local desc5  "II y IV de cada año"
local desc6  "Promedio del periodo previo y 2018-IV"
local desc7  "Promedios 2017 y 2018 y 2018-IV"
local desc8  "IV de 2016, 2017 y 2018"
local desc9  "Promedios bienales 2015-2016 y 2017-2018"
local desc10 "I y III de 2017 y 2018, y 2018-IV"
local desc11 "IV de 2015-2017, 2018-II y 2018-IV"
local desc12 "Promedio 2016-2018"

tempname pf
tempfile res
postfile `pf' str8 var int espec str60 desc double(rmspe efecto pval) using `res', replace
foreach v in pl t_oc t_oc_h t_oc_m {
    local lista ""
    forvalues k = 1/12 {
        local preds = subinstr("`sp`k''", "Y(", "`v'(", .)
        quietly synth `v' `preds', trunit(33) trperiod(`=tq(2019q1)')
        local rm`k' = el(e(RMSPE), 1, 1)
        local lista "`lista' `=string(`rm`k'', "%012.6f")':`k'"
    }
    local orden : list sort lista
    local n = 0
    foreach par of local orden {
        local ++n
        if `n' > 10 continue
        local k = substr("`par'", strpos("`par'", ":") + 1, .)
        local preds = subinstr("`sp`k''", "Y(", "`v'(", .)
        foreach x in lead effect pre_rmspe post_rmspe `v'_synth {
            capture drop `x'                    // una por una: capture drop con lista no borra nada si falta alguna
        }
        synth_runner `v' `preds', trunit(33) trperiod(`=tq(2019q1)') gen_vars
        local p = e(pval_joint_post)
        summarize effect if unidad == 33 & dateq >= tq(2019q1), meanonly
        post `pf' ("`v'") (`k') ("`desc`k''") (`rm`k'') (r(mean)) (`p')
        if `n' == 1 {
            preserve
                keep unidad dateq `v' `v'_synth effect
                rename (`v' `v'_synth effect) (obs sint efecto)
                gen str8 var = "`v'"
                tempfile e_`v'
                save `e_`v''
            restore
        }
    }
}
postclose `pf'
use `res', clear
save "$data/construidas/p6_sc_modelos.dta", replace
bysort var (rmspe): gen byte rango = _n
gen byte variable = cond(var == "pl", 1, cond(var == "t_oc", 2, cond(var == "t_oc_h", 3, 4)))
label define lvariable 1 "Pobreza laboral" 2 "Tasa de ocupación" 3 "Tasa de ocupación, hombres" 4 "Tasa de ocupación, mujeres", replace
label values variable lvariable
label var rmspe  "RMSPE previo"
label var efecto "Efecto promedio"
label var pval   "Valor p"
gen int modelo = 100 * variable + rango                     // renglón: rango y especificación
forvalues i = 1/`=_N' {
    label define lmodelo `=modelo[`i']' "`=rango[`i']'. `=desc[`i']'", add
}
label values modelo lmodelo
table (variable modelo) (), statistic(mean rmspe efecto pval) nototals
estilo_cuadro
collect style header variable modelo, title(hide)
collect style cell var[rmspe efecto], nformat(%9.2f)
collect style cell var[pval], nformat(%9.3f)
collect title "Cuadro 6.2. ZLFN: control sintético con la ENOE, 10 especificaciones con menor RMSPE previo por variable"
exporta_cuadro, archivo("$out/Cuadro_6_2_enoe_control_sintetico") ///
    nota("Nota: variables en puntos porcentuales. RMSPE previo: 2015-I a 2018-IV. Efecto promedio: diferencia promedio entre la ZLFN y su control sintético de 2019-I a 2026-II. Valor p: proporción de placebos (31 entidades) con cociente RMSPE posterior / previo mayor o igual al de la ZLFN. Rango 1 = especificación elegida.") ///
    fuente("$fte")

use `e_pl', clear
foreach v in t_oc t_oc_h t_oc_m {
    append using `e_`v''
}
format dateq %tq
save "$data/construidas/p6_sc_elegido.dta", replace
local xsc "xlabel(`=tq(2015q1)'(8)`=tq(2025q1)', format(%tqCCYY) labsize(small) nogrid) xline(`=tq(2019q1)', lcolor(gs8) lpattern(dash))"
local k = 0
foreach v in pl t_oc t_oc_h t_oc_m {
    local ++k
    local tit : word `k' of "Pobreza laboral" "Tasa de ocupación" "Ocupación de hombres" "Ocupación de mujeres"
    twoway (line obs dateq if unidad == 33 & var == "`v'", lcolor("$c1") lwidth(medthick)) ///
           (line sint dateq if unidad == 33 & var == "`v'", lcolor("$c2") lwidth(medthick) lpattern(dash)), ///
        title("`tit'", size(medsmall) color(black)) ytitle("Porcentaje", size(small) margin(r=2)) xtitle("") ///
        `xsc' ylabel(, labsize(small) angle(horizontal) grid glcolor(gs14)) ///
        legend(order(1 "ZLFN" 2 "ZLFN sintética") rows(1) size(small) region(lcolor(white))) ///
        graphregion(color(white)) plotregion(color(white) lcolor(none)) name(t`k', replace) nodraw
    local pl ""
    levelsof unidad if unidad != 33 & var == "`v'", local(us)
    foreach u of local us {
        local pl `pl' (line efecto dateq if unidad == `u' & var == "`v'", lcolor(gs12) lwidth(thin))
    }
    twoway `pl' (line efecto dateq if unidad == 33 & var == "`v'", lcolor("$c1") lwidth(thick)), ///
        title("`tit'", size(medsmall) color(black)) ytitle("Diferencia (puntos)", size(small) margin(r=2)) xtitle("") ///
        `xsc' ylabel(, labsize(small) angle(horizontal) grid glcolor(gs14)) yline(0, lcolor(gs6)) ///
        legend(order(`=wordcount("`us'") + 1' "ZLFN" 1 "Placebos") rows(1) size(small) region(lcolor(white))) ///
        graphregion(color(white)) plotregion(color(white) lcolor(none)) name(p`k', replace) nodraw
}
graph combine t1 t2 t3 t4, rows(2) iscale(0.8) graphregion(color(white)) xsize(6.5) ysize(5.5) ///
    note("Nota: especificación con menor RMSPE previo para cada variable; la línea vertical marca 2019-I." "$fte", size(vsmall) span)
graph export "$out/Fig_6_8_enoe_zlfn_sintetico.png", width(2400) replace
graph combine p1 p2 p3 p4, rows(2) iscale(0.8) graphregion(color(white)) xsize(6.5) ysize(5.5) ///
    note("Nota: diferencia entre cada unidad y su control sintético; en gris, las 31 entidades usadas como placebo." "$fte", size(vsmall) span)
graph export "$out/Fig_6_8_enoe_zlfn_placebos.png", width(2400) replace
}

log close
