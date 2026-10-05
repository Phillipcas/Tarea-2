/*==============================================================================
  PROBLEMA 3: REGRESIÓN CUANTIL

  Usa las bases limpias del Problema 1 (salario por hora censurado):
     data/construidas/enigh_limpia_salarios.dta
     data/construidas/enoe_limpia_salarios.dta
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

capture log close
log using "$log/P3_regresion_cuantil.log", replace text

* Estilo gráfico A (igual que los problemas anteriores)
set scheme s2color
graph set window fontface "Times New Roman"
global c1   "31 58 104"
global c2   "200 112 42"
global c3   "46 107 52"
global c4   "142 36 50"
global gtam "medsmall"

global fte_enigh "Fuente: elaboración propia con datos de la ENIGH (INEGI)."
global fte_enoe  "Fuente: elaboración propia con datos de la ENOE (INEGI), trimestres I y II."

* Interruptor: las regresiones cuantiles de la ENOE tardan
global corre_qreg 1


/*==============================================================================
  Bases de trabajo: personas de 25 a 65 años con salario por hora válido
  ENIGH 2018 y 2024; ENOE 2006, 2016 y 2026 (trimestres I y II juntos)
==============================================================================*/
use year ln_w educ_anios edad mujer rural factor muestra_w ///
    using "$data/construidas/enigh_limpia_salarios.dta" if muestra_w & inlist(year, 2018, 2024), clear
gen int edad2 = edad^2
gen byte enc = 1
tempfile enigh
save `enigh'

use year trimestre ln_w educ_anios edad mujer rural factor muestra_w ///
    using "$data/construidas/enoe_limpia_salarios.dta" ///
    if muestra_w & inlist(year, 2006, 2016, 2026) & inlist(trimestre, 1, 2), clear
gen int edad2 = edad^2
gen byte enc = 2
append using `enigh'
label var ln_w       "Log del salario por hora"
label var educ_anios "Años de escolaridad"
label var edad2      "Edad al cuadrado"
label var mujer      "Mujer"
label var rural      "Rural"
compress
save "$data/construidas/p3_base.dta", replace
table (enc year), statistic(frequency) statistic(mean ln_w)


/*==============================================================================
  3.3 (y 3.5) Cambio del log del salario por hora en cada cuantil, por sexo
  Percentiles 1 a 99 ponderados con el factor de expansión.
==============================================================================*/
tempname pf
tempfile cuant
postfile `pf' byte enc int year byte mujer byte q double valor using `cuant', replace
foreach e in 1 2 {
    levelsof year if enc == `e', local(anios)
    foreach a of local anios {
        forvalues s = 0/1 {
            quietly _pctile ln_w [pw = factor] if enc == `e' & year == `a' & mujer == `s', nquantiles(100)
            forvalues q = 1/99 {
                post `pf' (`e') (`a') (`s') (`q') (r(r`q'))
            }
        }
    }
}
postclose `pf'
use `cuant', clear
reshape wide valor, i(enc mujer q) j(year)
gen double d_18_24 = valor2024 - valor2018 if enc == 1
gen double d_06_16 = valor2016 - valor2006 if enc == 2
gen double d_16_26 = valor2026 - valor2016 if enc == 2
save "$data/construidas/p3_cambio_cuantiles.dta", replace

* Resumen para el texto
list mujer q d_18_24 if enc == 1 & inlist(q, 10, 25, 50, 75, 90), noobs sepby(mujer)
list mujer q d_06_16 d_16_26 if enc == 2 & inlist(q, 10, 25, 50, 75, 90), noobs sepby(mujer)

* Gráficas: hombres y mujeres en el mismo renglón
local op "xlabel(0(10)100, labsize($gtam) nogrid) ylabel(, labsize($gtam) angle(horizontal) format(%3.2f) grid glcolor(gs14)) yline(0, lcolor(gs8)) graphregion(color(white)) plotregion(color(white) lcolor(none))"
foreach s in 0 1 {
    local tit = cond(`s' == 0, "Hombres", "Mujeres")
    twoway (line d_18_24 q if enc == 1 & mujer == `s', lcolor("$c1") lwidth(medthick)), ///
        title("`tit'", size($gtam) color(black)) ytitle("Cambio del log del salario por hora", size($gtam)) ///
        xtitle("Cuantil", size($gtam)) `op' name(g`s', replace) nodraw
}
graph combine g0 g1, rows(1) ycommon iscale(1) graphregion(color(white)) xsize(6.5) ysize(3.4) ///
    note("Nota: diferencia entre 2024 y 2018 del percentil q del log del salario por hora (pesos de enero de 2026); personas de 25 a 65 años" ///
         "con salario por hora válido; percentiles ponderados con el factor de expansión." ///
         "$fte_enigh", size(small) span)
graph export "$out/Fig_3_3_enigh_cambio_cuantiles.png", width(2400) replace

foreach s in 0 1 {
    local tit = cond(`s' == 0, "Hombres", "Mujeres")
    twoway (line d_06_16 q if enc == 2 & mujer == `s', lcolor("$c1") lwidth(medthick)) ///
           (line d_16_26 q if enc == 2 & mujer == `s', lcolor("$c2") lwidth(medthick) lpattern(dash)), ///
        title("`tit'", size($gtam) color(black)) ytitle("Cambio del log del salario por hora", size($gtam)) ///
        xtitle("Cuantil", size($gtam)) `op' legend(order(1 "2006-2016" 2 "2016-2026") rows(1) size(small) region(lcolor(white))) ///
        name(h`s', replace) nodraw
}
graph combine h0 h1, rows(1) ycommon iscale(1) graphregion(color(white)) xsize(6.5) ysize(3.6) ///
    note("Nota: diferencia del percentil q del log del salario por hora (pesos de enero de 2026) entre los años indicados; personas de 25 a 65" ///
         "años con salario por hora válido; percentiles ponderados con el factor de expansión." ///
         "$fte_enoe", size(small) span)
graph export "$out/Fig_3_5_enoe_cambio_cuantiles.png", width(2400) replace


/*==============================================================================
  3.4 (y 3.5) Regresión cuantil y MCO por año
  ln(w) = b0 + b1 escolaridad + b2 edad + b3 edad^2 + b4 rural + b5 mujer
  Cuantiles 1 a 99; errores estándar robustos; ponderado con el factor.
==============================================================================*/
if $corre_qreg {
use "$data/construidas/p3_base.dta", clear
tempname pq
tempfile coef
postfile `pq' byte enc int year byte q str10 var double(b se) using `coef', replace
levelsof enc, local(encs)
foreach e of local encs {
    levelsof year if enc == `e', local(anios)
    foreach a of local anios {
        * MCO (q = 0)
        quietly regress ln_w educ_anios edad edad2 rural mujer [pw = factor] if enc == `e' & year == `a'
        foreach v in educ_anios edad edad2 rural mujer {
            post `pq' (`e') (`a') (0) ("`v'") (_b[`v']) (_se[`v'])
        }
        forvalues q = 1/99 {
            quietly qreg ln_w educ_anios edad edad2 rural mujer [pw = factor] if enc == `e' & year == `a', ///
                quantile(`=`q'/100') vce(robust)
            foreach v in educ_anios edad edad2 rural mujer {
                post `pq' (`e') (`a') (`q') ("`v'") (_b[`v']) (_se[`v'])
            }
        }
        di as res "Encuesta `e', año `a': listo"
    }
}
postclose `pq'
use `coef', clear
gen double lo = b - invnormal(0.975) * se
gen double hi = b + invnormal(0.975) * se
save "$data/construidas/p3_coeficientes.dta", replace
}


/*==============================================================================
  3.6 Coeficientes de escolaridad y de mujer por cuantil, con IC al 95% y MCO
  ENIGH: 2018 (izquierda) y 2024 (derecha); ENOE: 2016 y 2026
==============================================================================*/
use "$data/construidas/p3_coeficientes.dta", clear
list enc year var b se if q == 0 & inlist(var, "educ_anios", "mujer"), noobs sepby(enc year)
list enc year q var b if inlist(q, 10, 50, 90) & inlist(var, "educ_anios", "mujer"), noobs sepby(enc year var)

foreach e in 1 2 {
    local a1 = cond(`e' == 1, 2018, 2016)
    local a2 = cond(`e' == 1, 2024, 2026)
    local ENC = cond(`e' == 1, "enigh", "enoe")
    foreach v in educ_anios mujer {
        local nom = cond("`v'" == "educ_anios", "Escolaridad", "Mujer")
        * misma escala vertical en los dos años de cada variable (cuantiles 1 a 99 e IC)
        summarize lo if enc == `e' & inlist(year, `a1', `a2') & var == "`v'" & q > 0, meanonly
        local ymin = r(min)
        summarize hi if enc == `e' & inlist(year, `a1', `a2') & var == "`v'" & q > 0, meanonly
        local ymax = r(max)
        foreach a in `a1' `a2' {
            summarize b if enc == `e' & year == `a' & var == "`v'" & q == 0, meanonly
            local mco = r(mean)
            local ytit = cond(`a' == `a1', "Coeficiente", "")
            twoway (rarea lo hi q if enc == `e' & year == `a' & var == "`v'" & q > 0, color("$c1%25") lwidth(none)) ///
                   (line b q if enc == `e' & year == `a' & var == "`v'" & q > 0, lcolor("$c1") lwidth(medthick)), ///
                yline(`mco', lcolor("$c2") lpattern(dash) lwidth(medthick)) ///
                title("`nom', `a'", size(medsmall) color(black)) ytitle("`ytit'", size(small) margin(r=2)) xtitle("Cuantil", size(small)) ///
                xlabel(0(20)100, labsize(small) nogrid) yscale(range(`ymin' `ymax')) ///
                ylabel(#5, labsize(small) angle(horizontal) format(%4.2f) grid glcolor(gs14)) legend(off) ///
                graphregion(color(white) margin(small)) plotregion(color(white) lcolor(none)) name(k_`v'_`a', replace) nodraw
        }
    }
    local fte = cond(`e' == 1, "$fte_enigh", "$fte_enoe")
    graph combine k_educ_anios_`a1' k_educ_anios_`a2' k_mujer_`a1' k_mujer_`a2', rows(2) iscale(0.9) imargin(small) ///
        graphregion(color(white)) xsize(6.5) ysize(5.5) ///
        note("Nota: coeficientes de la regresión cuantil del log del salario por hora sobre años de escolaridad, edad, edad al cuadrado," ///
             "rural y mujer; errores estándar robustos y factor de expansión. Línea continua: regresión cuantil; área sombreada:" ///
             "intervalo de confianza al 95%; línea discontinua naranja: coeficiente de MCO." ///
             "`fte'", size(vsmall) span)
    graph export "$out/Fig_3_6_`ENC'_coeficientes_cuantiles.png", width(2400) replace
}

log close
