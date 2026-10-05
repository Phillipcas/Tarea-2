/*==============================================================================
  PROBLEMA 5: ESTIMACIÓN NO PARAMÉTRICA DE DENSIDADES (kdensity)

  ENIGH: ingreso corriente per cápita del hogar (Problema 1, inciso 1.11),
         2016-2024, en pesos de enero de 2026, ponderado por personas.
  ENOE:  ingreso laboral per cápita del hogar, trimestre II de 2016, 2018,
         2022 y 2024 (en 2020 no hay trimestre II: se usa el III).
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
global log  "$root/log"
global out  "$root/papers/output"
global enoe "$data/ENOE/ENOE"

capture log close
log using "$log/P5_no_parametricos.log", replace text

set scheme s2color
graph set window fontface "Times New Roman"
global gtam "medsmall"
global gfig "xsize(6.5) ysize(4.5) graphregion(color(white) margin(small)) plotregion(color(white) lcolor(none))"
* Una línea por año: del más antiguo (claro) al más reciente (oscuro)
global col2016 "150 170 205"
global col2018 "100 130 180"
global col2020 "200 112 42"
global col2022 "46 107 52"
global col2024 "31 58 104"
global fte_enigh "Fuente: elaboración propia con datos de la ENIGH (INEGI), 2016-2024."
global fte_enoe  "Fuente: elaboración propia con datos de la ENOE (INEGI), trimestre II (2020: trimestre III)."

* Programa: densidades por año en una rejilla común y gráfica con una línea por año.
* Todos los años usan el MISMO ancho de banda h (regla de Silverman calculada una vez con
* los años juntos), para que las diferencias entre curvas no vengan del suavizamiento.
* En la nota, el texto @H se sustituye por el valor de h.
capture program drop dens_anios
program define dens_anios
    syntax varname [aweight], ANIOS(numlist) RANGO(numlist min=2 max=2) XTItulo(string) ///
        ARchivo(string) NOta(string asis) [XFormato(string) YFormato(string) XLAbel(string) HFormato(string)]
    if "`xformato'" == "" local xformato "%9.0fc"
    if "`yformato'" == "" local yformato "%9.0g"
    if "`hformato'" == "" local hformato "%9.3f"
    local lo : word 1 of `rango'
    local hi : word 2 of `rango'
    local lista : subinstr local anios " " ",", all
    quietly kdensity `varlist' [`weight'`exp'] if inlist(year, `lista'), nograph   // h común (años juntos)
    local h = r(bwidth)
    local hs : display `hformato' `h'
    local hs = strtrim("`hs'")
    di as res "`varlist': ancho de banda común h = `hs'"
    local nota : subinstr local nota "@H" "`hs'", all
    local plots ""
    local leg ""
    local k = 0
    foreach a of local anios {
        local ++k
        capture drop x`a' d`a'
        gen double x`a' = `lo' + (`hi' - `lo') * (_n - 1) / 399 in 1/400     // rejilla de 400 puntos
        kdensity `varlist' [`weight'`exp'] if year == `a', at(x`a') generate(d`a') bwidth(`h') nograph
        local plots `plots' (line d`a' x`a', lcolor("${col`a'}") lwidth(medthick))
        local lab = cond(`a' == 2020 & strpos("`archivo'", "enoe"), "2020 (T-III)", "`a'")
        local leg `leg' `k' "`lab'"
    }
    twoway `plots', ytitle("Densidad", size($gtam) margin(r=2)) xtitle("`xtitulo'", size($gtam)) ///
        xlabel(`xlabel', labsize($gtam) format(`xformato') nogrid) ylabel(, labsize($gtam) angle(horizontal) format(`yformato') grid glcolor(gs14)) ///
        legend(order(`leg') rows(1) size(small) position(6) region(lcolor(white))) ///
        note(`nota', size(small) span) $gfig graphregion(margin(2 6 2 2))
    graph export "`archivo'", width(2400) replace
end


/*==============================================================================
  5.2 ENIGH: densidad del ingreso per cápita y de su logaritmo
==============================================================================*/
use year ingpc w_pers using "$data/construidas/enigh_ingpc_hogares_1992_2024.dta" if year >= 2016, clear
gen double ln_ingpc = ln(ingpc) if ingpc > 0
count if ingpc <= 0
tabstat ingpc [aw = w_pers], by(year) statistics(p1 p50 mean p95 p99) format(%12.0fc)
summarize ingpc [aw = w_pers], detail

dens_anios ingpc [aw = w_pers], anios(2016 2018 2020 2022 2024) rango(0 30000) ///
    xtitulo("Ingreso corriente per cápita mensual (pesos de enero de 2026)") ///
    archivo("$out/Fig_5_2_enigh_densidad_ingreso.png") yformato(%9.5f) hformato(%9.0fc) ///
    nota("Nota: núcleo de Epanechnikov; h común = @H pesos (regla de Silverman con los cinco años juntos); ponderado por personas." ///
         "Se grafica hasta 30,000 pesos (cerca del percentil 97); los ingresos mayores sí entran en la estimación. Por la asimetría," ///
         "la regla de Silverman tiende a sobresuavizar; cerca de cero la curva se subestima por el borde del soporte." ///
         "$fte_enigh")

dens_anios ln_ingpc [aw = w_pers], anios(2016 2018 2020 2022 2024) rango(5 12) ///
    xtitulo("Logaritmo del ingreso corriente per cápita mensual") ///
    archivo("$out/Fig_5_2_enigh_densidad_log_ingreso.png") xformato(%3.0f) yformato(%3.1f) xlabel(5(1)12) ///
    nota("Nota: núcleo de Epanechnikov; h común = @H (regla de Silverman con los cinco años juntos); ponderado por personas." ///
         "Hogares con ingreso positivo; se grafica el rango de 5 a 12 (148 a 162,755 pesos), que contiene a casi toda la población." ///
         "$fte_enigh")

* Estadísticos para el texto: moda, media y mediana del logaritmo por año
foreach a in 2016 2018 2020 2022 2024 {
    quietly summarize ln_ingpc [aw = w_pers] if year == `a', detail
    di as txt "`a': media log = " %5.3f r(mean) "  mediana log = " %5.3f r(p50) "  asimetría = " %5.3f r(skewness)
    quietly summarize ingpc [aw = w_pers] if year == `a', detail
    di as txt "      nivel: media = " %9.0fc r(mean) "  mediana = " %9.0fc r(p50) "  asimetría = " %6.2f r(skewness)
}


/*==============================================================================
  5.3 Ancho de banda y kernel (ENIGH 2024, logaritmo del ingreso)
==============================================================================*/
keep if year == 2024 & !missing(ln_ingpc)
kdensity ln_ingpc [aw = w_pers], nograph
local h = r(bwidth)
di as res "Ancho de banda de Silverman (Epanechnikov): " %6.4f `h'
local hbig   = 4 * `h'
local hsmall = `h' / 8
foreach v in base big small gau rect {
    capture drop x_`v' d_`v'
}
gen double x_base = 5 + 7 * (_n - 1) / 499 in 1/500                 // rejilla común de 500 puntos entre 5 y 12
foreach v in big small gau rect {
    gen double x_`v' = x_base
}
kdensity ln_ingpc [aw = w_pers], at(x_base)  bwidth(`h')      generate(d_base) nograph
kdensity ln_ingpc [aw = w_pers], at(x_big)   bwidth(`hbig')   generate(d_big) nograph
kdensity ln_ingpc [aw = w_pers], at(x_small) bwidth(`hsmall') generate(d_small) nograph
kdensity ln_ingpc [aw = w_pers], at(x_gau)   bwidth(`h') kernel(gaussian)  generate(d_gau) nograph
kdensity ln_ingpc [aw = w_pers], at(x_rect)  bwidth(`h') kernel(rectangle) generate(d_rect) nograph

local op "xlabel(5(1)12, labsize($gtam) nogrid) ylabel(, labsize($gtam) angle(horizontal) format(%3.1f) grid glcolor(gs14)) xtitle(Logaritmo del ingreso per cápita, size($gtam)) ytitle(Densidad, size($gtam)) graphregion(color(white)) plotregion(color(white) lcolor(none))"
local hs  : display %5.3f `h'
local hbs : display %5.3f `hbig'
local hss : display %5.3f `hsmall'
twoway (line d_base x_base, lcolor("31 58 104") lwidth(medthick)) (line d_big x_big, lcolor("200 112 42") lwidth(medthick) lpattern(dash)), ///
    title("Ancho de banda mayor", size($gtam) color(black)) `op' ///
    legend(order(1 "h = `hs' (Silverman)" 2 "h = `hbs' (x 4)") rows(2) size(small) region(lcolor(white))) name(b1, replace) nodraw
twoway (line d_base x_base, lcolor("31 58 104") lwidth(medthick)) (line d_small x_small, lcolor("200 112 42") lwidth(thin)), ///
    title("Ancho de banda menor", size($gtam) color(black)) `op' ///
    legend(order(1 "h = `hs' (Silverman)" 2 "h = `hss' (/ 8)") rows(2) size(small) region(lcolor(white))) name(b2, replace) nodraw
twoway (line d_base x_base, lcolor("31 58 104") lwidth(medthick)) (line d_gau x_gau, lcolor("46 107 52") lwidth(medthick) lpattern(dash)), ///
    title("Kernel gaussiano", size($gtam) color(black)) `op' ///
    legend(order(1 "Epanechnikov" 2 "Gaussiano") rows(2) size(small) region(lcolor(white))) name(k1, replace) nodraw
twoway (line d_base x_base, lcolor("31 58 104") lwidth(medthick)) (line d_rect x_rect, lcolor("142 36 50") lwidth(medthick) lpattern(dash)), ///
    title("Kernel rectangular", size($gtam) color(black)) `op' ///
    legend(order(1 "Epanechnikov" 2 "Rectangular") rows(2) size(small) region(lcolor(white))) name(k2, replace) nodraw
graph combine b1 b2, rows(1) iscale(1) graphregion(color(white)) xsize(6.5) ysize(3.4) ///
    note("Nota: ENIGH 2024, logaritmo del ingreso corriente per cápita; kernel de Epanechnikov; ponderado por personas." ///
         "$fte_enigh", size(small) span)
graph export "$out/Fig_5_3_enigh_ancho_banda.png", width(2400) replace
graph combine k1 k2, rows(1) iscale(1) graphregion(color(white)) xsize(6.5) ysize(3.4) ///
    note("Nota: ENIGH 2024, logaritmo del ingreso corriente per cápita; ancho de banda fijo h = `hs' en los tres kernels; ponderado por personas." ///
         "$fte_enigh", size(small) span)
graph export "$out/Fig_5_3_enigh_kernels.png", width(2400) replace

* Muestra para el tablero interactivo (5.4): 4,000 hogares remuestreados con probabilidad
* proporcional a las personas que representan
preserve
    set seed 20261005
    keep ln_ingpc w_pers
    * Muestreo con reemplazo con probabilidad proporcional a w_pers (inversión de la distribución acumulada)
    mata: y = st_data(., "ln_ingpc"); c = runningsum(st_data(., "w_pers")); c = c :/ c[rows(c)]
    mata: u = sort(runiform(4000, 1), 1); s = J(4000, 1, .); j = 1
    mata: for (i = 1; i <= 4000; i++) { while (c[j] < u[i]) j++; s[i] = y[j]; }
    clear
    getmata ln_ingpc = s
    format ln_ingpc %6.4f
    export delimited using "$root/papers/tableros/muestra_ln_ingpc_enigh2024.csv", replace
restore


/*==============================================================================
  5.5 ENOE: ingreso laboral per cápita del hogar (trimestre II)
  Hogar = cd_a ent con v_sel n_hog h_mud. Se suman los ingresos laborales
  mensuales (ingocup) de los residentes y se dividen entre el número de
  residentes. Pesos de enero de 2026 con el INPC promedio del trimestre.
==============================================================================*/
use cd_a ent con v_sel n_hog h_mud anio_enoe trimestre_enoe fac r_def c_res ingocup ///
    using "$enoe/ENOE_todas.dta" ///
    if (inlist(anio_enoe, 2016, 2018, 2022, 2024) & trimestre_enoe == 2) | (anio_enoe == 2020 & trimestre_enoe == 3), clear
keep if r_def == 0 & inlist(c_res, 1, 3)
replace ingocup = 0 if missing(ingocup)
rename (anio_enoe trimestre_enoe) (year trimestre)
collapse (sum) ing = ingocup (count) tam = fac (sum) w_pers = fac, by(year trimestre cd_a ent con v_sel n_hog h_mud)
preserve
    use "$data/INPC/inpc_mensual_1990_2026.dta", clear
    summarize inpc if anio == 2026 & mes == 1, meanonly
    local base = r(mean)
    gen byte trimestre = ceil(mes / 3)
    collapse (mean) inpc, by(anio trimestre)
    gen double defl = `base' / inpc
    rename anio year
    keep year trimestre defl
    tempfile d
    save `d'
restore
merge m:1 year trimestre using `d', keep(match) nogenerate
gen double ingpc = ing / tam * defl
gen double ln_ingpc = ln(ingpc) if ingpc > 0
gen byte cero = (ingpc == 0)
label var ingpc "Ingreso laboral per cápita mensual (pesos de enero de 2026)"
save "$data/construidas/enoe_ingpc_hogares_t2.dta", replace
table year [aw = w_pers], statistic(mean cero ingpc) statistic(median ingpc) nformat(%9.3f mean) nformat(%12.0fc median)

* Porcentaje de personas en hogares con ingreso laboral cero (masa puntual en cero: se reporta
* aparte y se excluye de la densidad, que solo describe la parte continua de la distribución)
local ceros ""
foreach a in 2016 2018 2020 2022 2024 {
    quietly summarize cero [aw = w_pers] if year == `a'
    local pc : display %4.1f 100 * r(mean)
    local ceros "`ceros'`a': `=strtrim("`pc'")'%; "
}
local ceros = substr("`ceros'", 1, length("`ceros'") - 2)
di as res "Ingreso laboral cero: `ceros'"
gen double ingpc_pos = ingpc if ingpc > 0                  // parte continua (ingreso positivo)
dens_anios ingpc_pos [aw = w_pers], anios(2016 2018 2020 2022 2024) rango(0 30000) ///
    xtitulo("Ingreso laboral per cápita mensual (pesos de enero de 2026)") ///
    archivo("$out/Fig_5_5_enoe_densidad_ingreso.png") yformato(%9.5f) hformato(%9.0fc) ///
    nota("Nota: núcleo de Epanechnikov; h común = @H pesos (regla de Silverman con los cinco años juntos); ponderado por personas." ///
         "Solo hogares con ingreso laboral positivo; los de ingreso cero son una masa puntual y no una densidad, y se excluyen:" ///
         "`ceros'." "Cerca de cero la curva se subestima por el borde del soporte. Se grafica hasta 30,000 pesos." ///
         "$fte_enoe")
dens_anios ln_ingpc [aw = w_pers], anios(2016 2018 2020 2022 2024) rango(5 12) ///
    xtitulo("Logaritmo del ingreso laboral per cápita mensual") ///
    archivo("$out/Fig_5_5_enoe_densidad_log_ingreso.png") xformato(%3.0f) yformato(%3.1f) xlabel(5(1)12) ///
    nota("Nota: núcleo de Epanechnikov; h común = @H (regla de Silverman con los cinco años juntos); ponderado por personas." ///
         "Hogares con ingreso laboral positivo; se grafica el rango de 5 a 12." ///
         "$fte_enoe")
foreach a in 2016 2018 2020 2022 2024 {
    quietly summarize ln_ingpc [aw = w_pers] if year == `a', detail
    di as txt "ENOE `a': media log = " %5.3f r(mean) "  mediana log = " %5.3f r(p50)
}

log close
