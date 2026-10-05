/*==============================================================================
  PROBLEMA 2: IMSS

  Estructura del proyecto:
     data/  -> bases de datos (originales y construidas)
     prog/  -> do-files (este archivo) y el script de R de los mapas
     log/   -> log files
     papers/-> documentos generados
==============================================================================*/

*------------------------------------------------------------------------------
* 0. CONFIGURACIÓN GENERAL
*------------------------------------------------------------------------------
clear all
set more off
set varabbrev off
version 19

global root  "C:/Users/lcastillo/Music/TAREA 2"
global data  "$root/data"
global prog  "$root/prog"
global log   "$root/log"
global out   "$root/papers/output"
global imss  "$data/IMSS/IMSS"
global rscript "C:/PROGRA~1/R/R-46~1.1/bin/Rscript.exe"   // Rscript (ruta corta, sin espacios)

capture mkdir "$out"
capture mkdir "$data/construidas"

capture log close
log using "$log/P2_IMSS.log", replace text

* Estilo gráfico (mismo estilo A del Problema 1)
set scheme s2color
graph set window fontface "Times New Roman"
global c1   "31 58 104"           // azul marino
global c2   "200 112 42"          // naranja
global c3   "46 107 52"           // verde
global c4   "142 36 50"           // guinda
global gtam "medsmall"
global gfig "xsize(6.5) ysize(4.5) graphregion(color(white) margin(small)) plotregion(color(white) lcolor(none))"
global xmes "xlabel(`=tm(2000m1)'(48)`=tm(2024m1)', format(%tmCCYY) labsize($gtam) nogrid)"

* Estilo y exportación de cuadros (mismos programas del Problema 1)
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

global fuente "Fuente: elaboración propia con datos de puestos de trabajo afiliados al IMSS, 2000-2026."

* Interruptores
global corre_2_0 1                // construcción de las series desde las celdas (tarda ~40 min)
global corre_2_11 1               // control sintético (tarda varios minutos)

* Deflactor: INPC mensual -> pesos de enero de 2026 (igual que el Problema 1)
use "$data/INPC/inpc_mensual_1990_2026.dta", clear
summarize inpc if anio == 2026 & mes == 1, meanonly
scalar inpc_ene26 = r(mean)
gen double defl = inpc_ene26 / inpc
rename (anio mes) (year month)
keep year month defl
tempfile defl
save `defl'


/*==============================================================================
  2.0 Construcción de las series a partir de las celdas del IMSS
  Cada renglón de las bases anuales es una celda (municipio x sexo x edad x
  rango salarial) con el número de puestos (ta), los puestos con salario
  (ta_sal) y la masa salarial diaria (masa_sal_ta). Se usan solo celdas con
  masa salarial positiva. El salario de la celda es masa / ta_sal (salario
  base de cotización diario promedio); se lleva a mensual multiplicando por
  30.4 días y a pesos de enero de 2026 con el INPC del mes.
==============================================================================*/
if $corre_2_0 {
tempfile nac mun
forvalues y = 2000/2026 {
    di as res "================  IMSS `y'  ================"
    use year month cve_entidad cve_municipio sexo ta ta_sal masa_sal_ta ///
        using "$imss/imss_`y'.dta" if masa_sal_ta > 0 & ta_sal > 0, clear
    merge m:1 year month using `defl', keep(match) nogenerate
    gen double masa_r = masa_sal_ta * 30.4 * defl          // masa mensual real
    gen double sal    = masa_r / ta_sal                     // salario mensual real de la celda

    * (a) Panel municipal por sexo: sumas
    preserve
        collapse (sum) ta ta_sal masa_r, by(year month cve_entidad cve_municipio sexo)
        capture append using `mun'
        save `mun', replace
    restore

    * (b) Serie nacional: percentiles y percentil en que cae la media
    *     (primero el total, después hombres y mujeres por separado)
    keep year month sexo ta_sal masa_r sal
    bysort year month: egen double m_g = total(masa_r)
    by year month: egen double n_g = total(ta_sal)
    gen byte bajo = (sal < m_g / n_g)
    preserve
        collapse (mean) pctil_media = bajo (p10) p10 = sal (p25) p25 = sal (p50) p50 = sal ///
                 (p75) p75 = sal (p90) p90 = sal [fw = ta_sal], by(year month)
        gen byte g = 0
        tempfile t0
        save `t0'
    restore
    keep if inlist(sexo, 1, 2)
    drop m_g n_g bajo
    bysort year month sexo: egen double m_g = total(masa_r)
    by year month sexo: egen double n_g = total(ta_sal)
    gen byte bajo = (sal < m_g / n_g)
    collapse (mean) pctil_media = bajo (p10) p10 = sal (p25) p25 = sal (p50) p50 = sal ///
             (p75) p75 = sal (p90) p90 = sal [fw = ta_sal], by(year month sexo)
    rename sexo g
    append using `t0'
    capture append using `nac'
    save `nac', replace
}

* Serie nacional: percentiles + sumas (las sumas salen del panel municipal)
use `nac', clear
tempfile nac2
save `nac2'
use `mun', clear
gen byte g = cond(sexo == 1, 1, cond(sexo == 2, 2, 0))
preserve
    collapse (sum) ta ta_sal masa_r, by(year month)
    gen byte g = 0
    tempfile tot
    save `tot'
restore
keep if inlist(g, 1, 2)
collapse (sum) ta ta_sal masa_r, by(year month g)
append using `tot'
merge 1:1 year month g using `nac2', nogenerate
gen double media = masa_r / ta_sal                          // promedio ponderado por puestos
replace pctil_media = 100 * pctil_media
gen int date = ym(year, month)
format date %tm
label define lg 0 "Total" 1 "Hombres" 2 "Mujeres", replace
label values g lg
label var ta          "Puestos de trabajo afiliados (celdas con masa salarial positiva)"
label var media       "Salario mensual promedio (pesos de enero de 2026)"
label var p50         "Salario mensual mediano (pesos de enero de 2026)"
label var pctil_media "Percentil de la distribución en que se ubica el promedio"
order date year month g
sort g date
compress
save "$data/construidas/imss_nacional_2000_2026.dta", replace

* Panel municipal
use `mun', clear
gen int date = ym(year, month)
format date %tm
order date year month cve_entidad cve_municipio sexo
sort date cve_entidad cve_municipio sexo
compress
save "$data/construidas/imss_mun_masapos_2000_2026.dta", replace
}   // fin de 2.0


/*==============================================================================
  2.1 Número de puestos de trabajo: total, hombres y mujeres
==============================================================================*/
use "$data/construidas/imss_nacional_2000_2026.dta", clear
gen double ta_m = ta / 1e6
twoway (line ta_m date if g == 0, lcolor(black) lwidth(thick)) ///
       (line ta_m date if g == 1, lcolor("$c1") lwidth(medthick)) ///
       (line ta_m date if g == 2, lcolor("$c2") lwidth(medthick) lpattern(dash)), ///
    ytitle("Millones de puestos de trabajo", size($gtam)) xtitle("Mes", size($gtam)) ///
    $xmes ylabel(, labsize($gtam) angle(horizontal) format(%9.0f) grid glcolor(gs14)) ///
    legend(order(1 "Total" 2 "Hombres" 3 "Mujeres") rows(1) size(small) position(6) region(lcolor(white))) ///
    note("Nota: puestos de trabajo afiliados en celdas con masa salarial positiva; datos mensuales, enero de 2000 a julio de 2026." ///
         "$fuente", size(small) span) $gfig
graph export "$out/Fig_2_1_imss_empleo.png", width(2400) replace


/*==============================================================================
  2.2 y 2.3 Salario mensual promedio y mediano; percentil del promedio
  El promedio pondera cada celda por su número de puestos (masa / puestos);
  la mediana y los demás percentiles se calculan sobre la distribución de
  puestos (cada celda cuenta tantas veces como puestos tiene).
==============================================================================*/
twoway (line media date if g == 0, lcolor("$c1") lwidth(medthick)) ///
       (line p50   date if g == 0, lcolor("$c1") lwidth(medthick) lpattern(dash)), ///
    ytitle("Pesos mensuales (enero de 2026)", size($gtam)) xtitle("Mes", size($gtam)) ///
    $xmes ylabel(, labsize($gtam) angle(horizontal) format(%9.0fc) grid glcolor(gs14)) ///
    legend(order(1 "Promedio" 2 "Mediana") rows(1) size(small) position(6) region(lcolor(white))) ///
    note("Nota: salario base de cotización diario por 30.4 días; promedio y mediana ponderados por puestos de trabajo." ///
         "$fuente", size(small) span) $gfig
graph export "$out/Fig_2_2_imss_salario_media_mediana.png", width(2400) replace

twoway (line pctil_media date if g == 0, lcolor("$c1") lwidth(medthick)), ///
    ytitle("Percentil", size($gtam)) xtitle("Mes", size($gtam)) ///
    $xmes ylabel(60(5)80, labsize($gtam) angle(horizontal) grid glcolor(gs14)) ///
    note("Nota: porcentaje de puestos de trabajo con salario menor al salario promedio del mes." ///
         "$fuente", size(small) span) $gfig
graph export "$out/Fig_2_3_imss_percentil_promedio.png", width(2400) replace

* Resumen para el texto: promedio, mediana y percentil (julio de años seleccionados)
list year media p50 pctil_media if g == 0 & month == 7 & inlist(year, 2000, 2006, 2012, 2018, 2019, 2024, 2025, 2026), noobs separator(0)
summarize pctil_media if g == 0


/*==============================================================================
  2.4 y 2.5 Brecha salarial de género con intervalos de confianza bootstrap
  Brecha = (1 - promedio mujeres / promedio hombres) x 100.
  Intervalo al 95% por el método del percentil: en cada mes se remuestrean
  con reemplazo los municipios (bootstrap por conglomerados, 1,000
  repeticiones) y se recalcula la brecha con las sumas de masa y puestos.
==============================================================================*/
keep if inlist(g, 1, 2)
keep date g media
reshape wide media, i(date) j(g)
gen double brecha = 100 * (1 - media2 / media1)
tempfile brecha
save `brecha'

use "$data/construidas/imss_mun_masapos_2000_2026.dta", clear
keep if inlist(sexo, 1, 2)
egen long idmun = group(cve_entidad cve_municipio)
collapse (sum) ta_sal masa_r, by(date idmun sexo)
reshape wide ta_sal masa_r, i(date idmun) j(sexo)
foreach v in ta_sal1 ta_sal2 masa_r1 masa_r2 {
    replace `v' = 0 if missing(`v')
}
sort date idmun

mata:
void boot_brecha(real scalar B)
{
    real matrix D, info, X, R, S
    real colvector g, idx
    real scalar i, b, n
    D    = st_data(., ("date", "masa_r1", "ta_sal1", "masa_r2", "ta_sal2"))
    info = panelsetup(D, 1)
    R    = J(rows(info), 3, .)
    for (i = 1; i <= rows(info); i++) {
        X = panelsubmatrix(D, i, info)
        n = rows(X)
        g = J(B, 1, .)
        for (b = 1; b <= B; b++) {
            idx  = ceil(n :* runiform(n, 1))
            S    = colsum(X[idx, (2..5)])
            g[b] = 100 * (1 - (S[3] / S[4]) / (S[1] / S[2]))
        }
        _sort(g, 1)
        R[i, .] = (X[1, 1], g[ceil(0.025 * B)], g[ceil(0.975 * B)])
    }
    st_matrix("IC", R)
}
end
set seed 20261005
mata: boot_brecha(1000)
clear
svmat double IC, names(col)
rename (c1 c2 c3) (date ic_inf ic_sup)
merge 1:1 date using `brecha', nogenerate
format date %tm
save "$data/construidas/imss_brecha_genero.dta", replace

twoway (rarea ic_inf ic_sup date, color("$c1%25") lwidth(none)) ///
       (line brecha date, lcolor("$c1") lwidth(medthick)), ///
    ytitle("Brecha (% del salario de los hombres)", size($gtam)) xtitle("Mes", size($gtam)) ///
    $xmes ylabel(, labsize($gtam) angle(horizontal) format(%9.0f) grid glcolor(gs14)) ///
    legend(order(2 "Brecha salarial de género" 1 "Intervalo de confianza al 95%") rows(1) size(small) position(6) region(lcolor(white))) ///
    note("Nota: brecha = (1 - salario promedio de las mujeres / salario promedio de los hombres) x 100. Intervalo por el método del" ///
         "percentil con 1,000 remuestreos de municipios por mes." ///
         "$fuente", size(small) span) $gfig
graph export "$out/Fig_2_4_imss_brecha_genero.png", width(2400) replace
list date brecha ic_inf ic_sup if inlist(date, tm(2000m1), tm(2010m1), tm(2019m1), tm(2020m7), tm(2026m7)), noobs


/*==============================================================================
  2.6 y 2.7 Entidades: brecha de género 2026, efecto de la COVID y
  crecimiento del empleo 2012-2026
==============================================================================*/
import delimited using "$data/catalogos/ageeml_entidades.csv", clear varnames(1) encoding(utf8)
keep cve_ent nom_ent
rename cve_ent cve_entidad
replace nom_ent = "Coahuila"  if cve_entidad == 5      // nombres cortos para el cuadro
replace nom_ent = "Michoacán" if cve_entidad == 16
replace nom_ent = "Veracruz"  if cve_entidad == 30
tempfile nomes
save `nomes'

use "$data/construidas/imss_mun_masapos_2000_2026.dta", clear
* Brecha 2026 (enero a julio)
preserve
    keep if year == 2026 & inlist(sexo, 1, 2)
    collapse (sum) masa_r ta_sal, by(cve_entidad sexo)
    gen double sal = masa_r / ta_sal
    keep cve_entidad sexo sal
    reshape wide sal, i(cve_entidad) j(sexo)
    gen double brecha26 = 100 * (1 - sal2 / sal1)
    keep cve_entidad brecha26
    tempfile b26
    save `b26'
restore
* Empleo por entidad en meses clave
collapse (sum) ta, by(cve_entidad date)
keep if inlist(date, tm(2012m7), tm(2020m2), tm(2020m7), tm(2026m7))
gen str7 m = string(date, "%tmCCYY!mNN")
replace m = subinstr(m, "m", "_", .)
keep cve_entidad m ta
reshape wide ta, i(cve_entidad) j(m) string
gen double covid_corto = 100 * (ta2020_07 / ta2020_02 - 1)
gen double covid_largo = 100 * (ta2026_07 / ta2020_02 - 1)
gen double emp_12_26   = 100 * (ta2026_07 / ta2012_07 - 1)
merge 1:1 cve_entidad using `b26', nogenerate
merge 1:1 cve_entidad using `nomes', nogenerate
save "$data/construidas/imss_entidades_indicadores.dta", replace

di _n "Brecha de género 2026: menor y mayor"
sort brecha26
list nom_ent brecha26 in 1/3, noobs
list nom_ent brecha26 in -3/l, noobs
di _n "COVID: febrero 2020 a julio 2020 (caída inmediata) y a julio 2026"
sort covid_corto
list nom_ent covid_corto covid_largo in 1/5, noobs
sort covid_largo
list nom_ent covid_corto covid_largo in 1/5, noobs
di _n "Crecimiento del empleo julio 2012 - julio 2026"
gsort -emp_12_26
list nom_ent emp_12_26 in 1/5, noobs

* Cuadro por entidad
label var brecha26    "Brecha de género 2026 (%)"
label var covid_corto "Feb. 2020-jul. 2020"
label var covid_largo "Feb. 2020-jul. 2026"
label var emp_12_26   "Jul. 2012-jul. 2026"
sort nom_ent
gen int orden = _n
forvalues i = 1/`=_N' {
    label define lorden `i' "`=nom_ent[`i']'", add
}
label values orden lorden
table (orden), statistic(mean brecha26 covid_corto covid_largo emp_12_26) nototals
estilo_cuadro
collect style header orden, title(hide)
collect style cell var[brecha26 covid_corto covid_largo emp_12_26], nformat(%9.1f)
collect title "Cuadro 2.1. Entidades federativas: brecha salarial de género en 2026 y cambio porcentual del empleo formal"
exporta_cuadro, archivo("$out/Cuadro_2_1_imss_entidades") ///
    nota("Nota: brecha = (1 - salario promedio de las mujeres / salario promedio de los hombres) x 100, con los meses de enero a julio de 2026. Las tres últimas columnas son el cambio porcentual de los puestos de trabajo afiliados entre los meses indicados.") ///
    fuente("$fuente")


/*==============================================================================
  2.8 y 2.9 Cambios en empleo y salario: entidades (Stata y R) y municipios (R)
  Bases: julio de 2006 y julio de 2016; periodo final: julio de 2026.
==============================================================================*/
* ---- Entidades
use "$data/construidas/imss_mun_masapos_2000_2026.dta", clear
keep if inlist(date, tm(2006m7), tm(2016m7), tm(2026m7))
collapse (sum) ta ta_sal masa_r, by(cve_entidad year)
gen double sal = masa_r / ta_sal
keep cve_entidad year ta sal
reshape wide ta sal, i(cve_entidad) j(year)
foreach b in 2006 2016 {
    gen double demp_`b' = 100 * (ta2026 / ta`b' - 1)
    gen double dsal_`b' = 100 * (sal2026 / sal`b' - 1)
}
export delimited using "$data/construidas/imss_cambios_entidad.csv", replace
tempfile cambios_ent
save `cambios_ent'

capture grmap, activate
cd "$data/mapas"                                // grmap busca aquí el archivo de coordenadas
use "$data/mapas/entidades.dta", clear
destring CVE_ENT, generate(cve_entidad)
merge 1:1 cve_entidad using `cambios_ent', nogenerate
format demp_* dsal_* %9.1f                      // formato de las etiquetas de la leyenda
local nota_m "Fuente: elaboración propia con datos del IMSS (puestos de trabajo afiliados)."
foreach b in 2006 2016 {
    grmap demp_`b', clmethod(quantile) clnumber(5) fcolor(Blues) ocolor(white ..) osize(vthin ..) ///
        legend(position(7) size(small) region(lcolor(white))) legtitle("Cambio del empleo (%)") ///
        legstyle(2) title("Empleo", size($gtam) color(black)) name(e`b', replace) nodraw
    grmap dsal_`b', clmethod(quantile) clnumber(5) fcolor(Oranges) ocolor(white ..) osize(vthin ..) ///
        legend(position(7) size(small) region(lcolor(white))) legtitle("Cambio del salario real (%)") ///
        legstyle(2) title("Salario promedio real", size($gtam) color(black)) name(s`b', replace) nodraw
    graph combine e`b' s`b', rows(1) iscale(1) graphregion(color(white)) xsize(6.5) ysize(3.6) ///
        note("Nota: cambio porcentual entre julio de `b' y julio de 2026; quintiles. Salario mensual real en pesos de enero de 2026." ///
             "`nota_m'", size(small) span)
    graph export "$out/Fig_2_8_stata_entidades_`b'_2026.png", width(2400) replace
}
cd "$root"

* ---- Municipios (cruce de claves IMSS -> INEGI)
use "$data/construidas/imss_mun_masapos_2000_2026.dta", clear
keep if inlist(date, tm(2006m7), tm(2016m7), tm(2026m7))
merge m:1 cve_entidad cve_municipio using "$data/catalogos/imss_inegi_municipios.dta", ///
    keepusing(cvegeo zlfn) keep(master match)
tab _merge
drop _merge
collapse (sum) ta ta_sal masa_r (max) zlfn, by(cvegeo year)
gen double sal = masa_r / ta_sal
keep cvegeo zlfn year ta sal
reshape wide ta sal, i(cvegeo zlfn) j(year)
foreach b in 2006 2016 {
    gen byte muestra_`b' = (ta`b' >= 10000 & !missing(ta`b') & !missing(ta2026))
    gen double demp_`b' = 100 * (ta2026 / ta`b' - 1) if muestra_`b'
    gen double dsal_`b' = 100 * (sal2026 / sal`b' - 1) if muestra_`b'
    count if muestra_`b'
    di as res "Municipios con al menos 10,000 puestos en julio de `b': `r(N)'"
}
export delimited using "$data/construidas/imss_cambios_municipio.csv", replace

* ZLFN frente al resto (para la discusión del inciso 2.10)
foreach b in 2006 2016 {
    di _n "Base `b': ZLFN (1) frente al resto (0)"
    tabstat demp_`b' dsal_`b' [aw = ta`b'], by(zlfn) statistics(mean) format(%9.1f)
}

* ---- Mapas en R (entidades y municipios)
shell $rscript "$prog/P2_mapas.R"


/*==============================================================================
  2.11 Control sintético: salario mínimo e IVA en la ZLFN (inicia en 2019)
  Unidad tratada: la ZLFN (suma de sus municipios). Donadores: las 31
  entidades sin sus municipios de la ZLFN (Baja California queda fuera
  porque todos sus municipios pertenecen a la zona). Periodo: enero de 2015
  a julio de 2026 (último mes disponible). Variables: índice de empleo e
  índice del salario promedio real (septiembre de 2018 = 100).
==============================================================================*/
if $corre_2_11 {
use "$data/construidas/imss_mun_masapos_2000_2026.dta", clear
keep if inrange(date, tm(2015m1), tm(2026m7))
merge m:1 cve_entidad cve_municipio using "$data/catalogos/imss_inegi_municipios.dta", ///
    keepusing(zlfn) keep(master match) nogenerate
replace zlfn = 0 if missing(zlfn)
gen byte unidad = cond(zlfn == 1, 33, cve_entidad)
drop if unidad == 2
drop if missing(unidad)
collapse (sum) ta ta_sal masa_r, by(unidad date)
bysort unidad: gen int nmeses = _N
tab unidad if nmeses < 139                      // unidades sin los 139 meses (se excluyen)
keep if nmeses == 139                           // panel balanceado: enero 2015 a julio 2026
drop nmeses
gen double sal = masa_r / ta_sal
foreach v in ta sal {
    bysort unidad (date): egen double base = total(`v' * (date == tm(2018m9)))   // base: septiembre de 2018, como en Campos-Vázquez et al. (2020)
    gen double i_`v' = 100 * `v' / base
    drop base
}
label define lunidad 33 "ZLFN", replace
label values unidad lunidad
tsset unidad date
save "$data/construidas/imss_panel_zlfn.dta", replace

* Especificaciones candidatas (rezagos de la variable de resultado)
local pre "`=tm(2015m1)'(1)`=tm(2018m12)'"
local sp1  "Y(`=tm(2015m1)') Y(`=tm(2016m1)') Y(`=tm(2017m1)') Y(`=tm(2018m1)') Y(`=tm(2018m12)')"
local sp2  "Y(`=tm(2015m1)'(1)`=tm(2015m12)') Y(`=tm(2016m1)'(1)`=tm(2016m12)') Y(`=tm(2017m1)'(1)`=tm(2017m12)') Y(`=tm(2018m1)'(1)`=tm(2018m12)')"
local sp3  "Y(`=tm(2018m3)') Y(`=tm(2018m6)') Y(`=tm(2018m10)') Y(`=tm(2018m12)')"
local sp4  "Y(`=tm(2015m6)') Y(`=tm(2016m6)') Y(`=tm(2017m6)') Y(`=tm(2018m6)') Y(`=tm(2018m12)')"
local sp5  "Y(`=tm(2015m6)') Y(`=tm(2015m12)') Y(`=tm(2016m6)') Y(`=tm(2016m12)') Y(`=tm(2017m6)') Y(`=tm(2017m12)') Y(`=tm(2018m6)') Y(`=tm(2018m12)')"
local sp6  "Y(`pre') Y(`=tm(2018m12)')"
local sp7  "Y(`=tm(2017m1)'(1)`=tm(2017m12)') Y(`=tm(2018m1)'(1)`=tm(2018m12)') Y(`=tm(2018m12)')"
local sp8  "Y(`=tm(2016m12)') Y(`=tm(2017m12)') Y(`=tm(2018m12)')"
local sp9  "Y(`=tm(2015m3)') Y(`=tm(2015m9)') Y(`=tm(2016m3)') Y(`=tm(2016m9)') Y(`=tm(2017m3)') Y(`=tm(2017m9)') Y(`=tm(2018m3)') Y(`=tm(2018m8)') Y(`=tm(2018m12)')"
local sp10 "Y(`=tm(2018m1)') Y(`=tm(2018m4)') Y(`=tm(2018m7)') Y(`=tm(2018m10)') Y(`=tm(2018m12)')"
local sp11 "Y(`=tm(2015m1)'(1)`=tm(2016m12)') Y(`=tm(2017m1)'(1)`=tm(2018m12)')"
local sp12 "Y(`=tm(2015m12)') Y(`=tm(2016m12)') Y(`=tm(2017m12)') Y(`=tm(2018m6)') Y(`=tm(2018m12)')"
local desc1  "Enero de cada año y dic. 2018"
local desc2  "Promedios anuales 2015-2018"
local desc3  "Marzo, junio, octubre y diciembre 2018"
local desc4  "Junio de cada año y dic. 2018"
local desc5  "Semestral 2015-2018"
local desc6  "Promedio del periodo previo y dic. 2018"
local desc7  "Promedios 2017 y 2018 y dic. 2018"
local desc8  "Diciembre 2016, 2017 y 2018"
local desc9  "Marzo y sept. 2015-2017, mar. y ago. 2018, dic. 2018"
local desc10 "Enero, abril, julio y octubre 2018 y dic. 2018"
local desc11 "Promedios bienales 2015-2016 y 2017-2018"
local desc12 "Diciembre 2015-2017, jun. y dic. 2018"

tempname pf
tempfile res
postfile `pf' str3 var int espec str60 desc double(rmspe efecto pval) using `res', replace
foreach v in ta sal {
    * Paso 1: RMSPE previo de las 12 especificaciones
    local lista ""
    forvalues k = 1/12 {
        local preds = subinstr("`sp`k''", "Y(", "i_`v'(", .)
        quietly synth i_`v' `preds', trunit(33) trperiod(`=tm(2019m1)')
        local rm`k' = el(e(RMSPE), 1, 1)
        local lista "`lista' `=string(`rm`k'', "%012.6f")':`k'"
        di as txt "`v' especificación `k': RMSPE previo = " %6.3f `rm`k''
    }
    * Paso 2: las 10 de menor RMSPE, con valor p por placebos
    local orden : list sort lista
    local n = 0
    foreach par of local orden {
        local ++n
        if `n' > 10 continue
        local k = substr("`par'", strpos("`par'", ":") + 1, .)
        local preds = subinstr("`sp`k''", "Y(", "i_`v'(", .)
        foreach x in lead effect pre_rmspe post_rmspe i_`v'_synth {
            capture drop `x'                    // una por una: capture drop con lista no borra nada si falta alguna
        }
        synth_runner i_`v' `preds', trunit(33) trperiod(`=tm(2019m1)') gen_vars
        local p = e(pval_joint_post)
        summarize effect if unidad == 33 & date >= tm(2019m1), meanonly
        post `pf' ("`v'") (`k') ("`desc`k''") (`rm`k'') (r(mean)) (`p')
        if `n' == 1 {
            * Modelo elegido (menor RMSPE): se guardan la serie sintética y los placebos
            preserve
                keep unidad date i_`v' i_`v'_synth effect
                rename (i_`v' i_`v'_synth effect) (obs sint efecto)
                gen str3 var = "`v'"
                tempfile elegido_`v'
                save `elegido_`v''
            restore
            local mejor_`v' = `k'
        }
    }
}
postclose `pf'

use `res', clear
save "$data/construidas/imss_sc_modelos.dta", replace
list, noobs separator(10)

* Cuadro de modelos
gen byte rango = .
bysort var (rmspe): replace rango = _n
gen byte variable = cond(var == "ta", 1, 2)
label define lvariable 1 "Empleo" 2 "Salario promedio real", replace
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
collect title "Cuadro 2.2. ZLFN: control sintético, 10 especificaciones con menor RMSPE previo por variable"
exporta_cuadro, archivo("$out/Cuadro_2_2_imss_control_sintetico") ///
    nota("Nota: variables en índice (septiembre de 2018 = 100). RMSPE: raíz del error cuadrático medio de predicción en enero de 2015 a diciembre de 2018. Efecto promedio: diferencia promedio entre la ZLFN y su control sintético de enero de 2019 a julio de 2026, en puntos del índice. Valor p: proporción de placebos (31 entidades) con cociente RMSPE posterior / previo mayor o igual al de la ZLFN. Rango 1 = especificación elegida.") ///
    fuente("$fuente")
preserve
    keep if rango <= 10
    gen str80 especificacion = desc
    keep variable rango especificacion
    list, noobs separator(10)
restore

* Figuras: ZLFN frente a su control sintético y placebos (modelo elegido)
use `elegido_ta', clear
append using `elegido_sal'
format date %tm
save "$data/construidas/imss_sc_elegido.dta", replace
local xsc "xlabel(`=tm(2015m1)'(24)`=tm(2025m1)', format(%tmCCYY) labsize($gtam) nogrid) xline(`=tm(2019m1)', lcolor(gs8) lpattern(dash))"
foreach v in ta sal {
    local tit = cond("`v'" == "ta", "Empleo", "Salario promedio real")
    twoway (line obs  date if unidad == 33 & var == "`v'", lcolor("$c1") lwidth(medthick)) ///
           (line sint date if unidad == 33 & var == "`v'", lcolor("$c2") lwidth(medthick) lpattern(dash)), ///
        title("`tit'", size($gtam) color(black)) ytitle("Índice (sep. 2018 = 100)", size($gtam)) xtitle("") ///
        `xsc' ylabel(, labsize($gtam) angle(horizontal) grid glcolor(gs14)) ///
        legend(order(1 "ZLFN" 2 "ZLFN sintética") rows(1) size(small) region(lcolor(white))) ///
        graphregion(color(white)) plotregion(color(white) lcolor(none)) name(t_`v', replace) nodraw
    local pl ""
    levelsof unidad if unidad != 33 & var == "`v'", local(us)
    foreach u of local us {
        local pl `pl' (line efecto date if unidad == `u' & var == "`v'", lcolor(gs12) lwidth(thin))
    }
    twoway `pl' (line efecto date if unidad == 33 & var == "`v'", lcolor("$c1") lwidth(thick)), ///
        title("`tit'", size($gtam) color(black)) ytitle("Diferencia con el sintético (puntos)", size($gtam)) xtitle("") ///
        `xsc' ylabel(, labsize($gtam) angle(horizontal) grid glcolor(gs14)) yline(0, lcolor(gs6)) ///
        legend(order(`=wordcount("`us'") + 1' "ZLFN" 1 "Placebos (entidades)") rows(1) size(small) region(lcolor(white))) ///
        graphregion(color(white)) plotregion(color(white) lcolor(none)) name(p_`v', replace) nodraw
}
graph combine t_ta t_sal, rows(1) iscale(1) graphregion(color(white)) xsize(6.5) ysize(3.6) ///
    note("Nota: especificación con menor RMSPE previo para cada variable; la línea vertical marca enero de 2019. El pico de mayo de 2026" ///
         "en el empleo sintético proviene de un aumento atípico y transitorio de los registros de Hidalgo (+18% mensual, revertido en junio)." ///
         "$fuente", size(small) span)
graph export "$out/Fig_2_11_imss_zlfn_sintetico.png", width(2400) replace
graph combine p_ta p_sal, rows(1) iscale(1) graphregion(color(white)) xsize(6.5) ysize(3.6) ///
    note("Nota: diferencia entre cada unidad y su control sintético; en gris, las 31 entidades usadas como placebo." ///
         "$fuente", size(small) span)
graph export "$out/Fig_2_11_imss_zlfn_placebos.png", width(2400) replace
}   // fin de 2.11

log close
