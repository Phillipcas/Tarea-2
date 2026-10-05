/*==============================================================================
  PROBLEMA 4: BOOTSTRAP

  Regresión: ln(salario por hora) = b0 + b1 escolaridad + b2 edad + b3 edad^2
             + b4 rural + b5 mujer + u,   MCO con errores estándar robustos.
  Muestras:  ENIGH 2024 y ENOE 2026 (trimestre II), personas de 25 a 65 años
             con salario por hora válido (bases limpias del Problema 1).
  La regresión se estima sin factor de expansión: el bootstrap y el jackknife
  remuestrean observaciones, y así el ejercicio compara métodos de inferencia
  sobre la misma regresión.
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
log using "$log/P4_bootstrap.log", replace text

global x "educ_anios edad edad2 rural mujer"
global corre_4 1                  // 1 = estima bootstrap y jackknife (tarda ~2 horas); 0 = solo arma los cuadros
set seed 20261005

* Exportación de cuadros (mismos programas de los problemas anteriores)
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

* Bases de trabajo
use ln_w educ_anios edad rural mujer muestra_w year ///
    using "$data/construidas/enigh_limpia_salarios.dta" if muestra_w & year == 2024, clear
gen int edad2 = edad^2
compress
save "$data/construidas/p4_enigh2024.dta", replace
use ln_w educ_anios edad rural mujer muestra_w year trimestre ///
    using "$data/construidas/enoe_limpia_salarios.dta" if muestra_w & year == 2026 & trimestre == 2, clear
gen int edad2 = edad^2
compress
save "$data/construidas/p4_enoe2026t2.dta", replace


/*==============================================================================
  Programa que hace todo el ejercicio para una base:
    (a)  bootstrap no paramétrico con 100 y 1,000 repeticiones (comando bootstrap)
    (b)  jackknife (comando jackknife)
    (c)  bootstrap con submuestras de 0.25 N (opción size())
    (d)  jackknife con una submuestra aleatoria de 0.25 N
  y lo guarda en una base de resultados (un renglón por método y coeficiente).
  Para cada coeficiente se guardan: coeficiente de MCO, error estándar
  (robusto o de remuestreo), IC percentil al 95% y IC percentil-t al 95%.
==============================================================================*/
capture program drop percentil_t
program define percentil_t, rclass
    * Recibe una base con b_v y se_v por réplica; devuelve cuantiles 2.5 y 97.5 de t*
    syntax, v(string) b(real) se(real)
    tempvar t
    gen double `t' = (b_`v' - `b') / se_`v'
    _pctile `t', percentiles(2.5 97.5)
    return scalar lo = `b' - r(r2) * `se'
    return scalar hi = `b' - r(r1) * `se'
end

capture program drop ejercicio
program define ejercicio
    syntax, BASE(string) ETiq(string) RES(string)
    use "`base'", clear
    local N = _N
    tempname pf
    postfile `pf' str12 metodo int reps str10 var double(b se lo_p hi_p lo_t hi_t tstat) using "`res'", replace

    * --- MCO con errores robustos (referencia)
    regress ln_w $x, vce(robust)
    foreach v of global x {
        local b_`v'  = _b[`v']
        local se_`v' = _se[`v']
        post `pf' ("MCO robusto") (0) ("`v'") (_b[`v']) (_se[`v']) ///
            (_b[`v'] - invttail(e(df_r), .025) * _se[`v']) (_b[`v'] + invttail(e(df_r), .025) * _se[`v']) (.) (.) (_b[`v'] / _se[`v'])
    }

    * --- (a) y (c): bootstrap con N y con 0.25 N; 100 y 1,000 repeticiones
    foreach tam in N m {
        local sz = cond("`tam'" == "N", `N', floor(`N' / 4))
        local nombre = cond("`tam'" == "N", "Bootstrap", "Bootstrap m")
        foreach R in 100 1000 {
            tempfile rep
            quietly bootstrap _b _se, reps(`R') size(`sz') saving(`rep', replace) nodots: regress ln_w $x, vce(robust)
            preserve
                use `rep', clear
                foreach v of global x {
                    rename _b_`v' b_`v'
                    rename _se_`v' se_`v'
                    quietly summarize b_`v'
                    local seb = r(sd)
                    _pctile b_`v', percentiles(2.5 97.5)
                    local lp = r(r1)
                    local hp = r(r2)
                    percentil_t, v(`v') b(`b_`v'') se(`se_`v'')
                    post `pf' ("`nombre'") (`R') ("`v'") (`b_`v'') (`seb') (`lp') (`hp') (r(lo)) (r(hi)) (`b_`v'' / `seb')
                }
            restore
        }
    }

    * --- (b) jackknife (dejar fuera una observación a la vez)
    quietly jackknife _b, nodots: regress ln_w $x
    foreach v of global x {
        local sej = _se[`v']
        post `pf' ("Jackknife") (`N') ("`v'") (`b_`v'') (`sej') ///
            (`b_`v'' - invnormal(.975) * `sej') (`b_`v'' + invnormal(.975) * `sej') (.) (.) (`b_`v'' / `sej')
    }

    * --- (d) jackknife con una submuestra aleatoria de 0.25 N
    preserve
        sample 25
        local n25 = _N
        quietly regress ln_w $x
        foreach v of global x {
            local b25_`v' = _b[`v']
        }
        quietly jackknife _b, nodots: regress ln_w $x
        foreach v of global x {
            local sej = _se[`v']
            post `pf' ("Jackknife m") (`n25') ("`v'") (`b25_`v'') (`sej') ///
                (`b25_`v'' - invnormal(.975) * `sej') (`b25_`v'' + invnormal(.975) * `sej') (.) (.) (`b25_`v'' / `sej')
        }
    restore
    postclose `pf'
    use "`res'", clear
    gen str10 base = "`etiq'"
    save "`res'", replace
end


/*==============================================================================
  4.2 ENIGH 2024 con los comandos bootstrap y jackknife
==============================================================================*/
if $corre_4 {
    ejercicio, base("$data/construidas/p4_enigh2024.dta") etiq("ENIGH") res("$data/construidas/p4_res_enigh_comandos.dta")
    use "$data/construidas/p4_res_enigh_comandos.dta", clear
    list metodo reps var b se lo_p hi_p lo_t hi_t tstat, noobs sepby(metodo reps) abbreviate(8)
}


/*==============================================================================
  4.3 El mismo ejercicio con bsample (repeticiones programadas a mano)
  En cada réplica se guarda coeficiente, error estándar robusto y t. El
  jackknife se calcula con la fórmula exacta de "dejar uno fuera" de MCO:
  b(-i) = b - (X'X)^-1 x_i e_i / (1 - h_i), sin volver a estimar N veces.
==============================================================================*/
capture program drop manual
program define manual
    syntax, BASE(string) ETiq(string) RES(string)
    use "`base'", clear
    local N = _N
    quietly regress ln_w $x, vce(robust)
    foreach v of global x {
        local b_`v'  = _b[`v']
        local se_`v' = _se[`v']
    }
    tempname pf
    postfile `pf' str12 metodo int reps str10 var double(b se lo_p hi_p lo_t hi_t tstat) using "`res'", replace
    foreach tam in N m {
        local sz = cond("`tam'" == "N", `N', floor(`N' / 4))
        local nombre = cond("`tam'" == "N", "Bootstrap", "Bootstrap m")
        foreach R in 100 1000 {
            tempname pr
            tempfile rep
            postfile `pr' int r double(b_educ_anios se_educ_anios b_edad se_edad b_edad2 se_edad2 b_rural se_rural b_mujer se_mujer) using `rep', replace
            forvalues r = 1/`R' {
                preserve
                    bsample `sz'
                    quietly regress ln_w $x, vce(robust)
                    post `pr' (`r') (_b[educ_anios]) (_se[educ_anios]) (_b[edad]) (_se[edad]) (_b[edad2]) (_se[edad2]) ///
                        (_b[rural]) (_se[rural]) (_b[mujer]) (_se[mujer])
                restore
            }
            postclose `pr'
            preserve
                use `rep', clear
                if "`tam'" == "N" & `R' == 1000 save "$data/construidas/p4_replicas_`etiq'.dta", replace
                foreach v of global x {
                    quietly summarize b_`v'
                    local seb = r(sd)
                    _pctile b_`v', percentiles(2.5 97.5)
                    local lp = r(r1)
                    local hp = r(r2)
                    percentil_t, v(`v') b(`b_`v'') se(`se_`v'')
                    post `pf' ("`nombre'") (`R') ("`v'") (`b_`v'') (`seb') (`lp') (`hp') (r(lo)) (r(hi)) (`b_`v'' / `seb')
                }
            restore
        }
    }
    * Jackknife exacto con la fórmula de dejar uno fuera (N y 0.25 N)
    foreach tam in N m {
        preserve
            if "`tam'" == "m" sample 25
            local n = _N
            quietly regress ln_w $x
            mata: jk_ols("ln_w", "$x")
            local k = 0
            foreach v of global x {
                local ++k
                local bj = el(JK, 1, `k')
                local sj = el(JK, 2, `k')
                local nombre = cond("`tam'" == "N", "Jackknife", "Jackknife m")
                post `pf' ("`nombre'") (`n') ("`v'") (`bj') (`sj') (`bj' - invnormal(.975) * `sj') (`bj' + invnormal(.975) * `sj') (.) (.) (`bj' / `sj')
            }
        restore
    }
    postclose `pf'
    use "`res'", clear
    gen str10 base = "`etiq'"
    save "`res'", replace
end

mata:
void jk_ols(string scalar yv, string scalar xv)
{
    real matrix X, XXi, Bi
    real colvector y, e, h
    real rowvector b, bbar, sej
    real scalar n
    y   = st_data(., yv)
    X   = (st_data(., tokens(xv)), J(rows(y), 1, 1))
    n   = rows(X)
    XXi = invsym(cross(X, X))
    b   = (XXi * cross(X, y))'
    e   = y - X * b'
    h   = rowsum((X * XXi) :* X)
    Bi  = b :- ((X * XXi) :* (e :/ (1 :- h)))       // coeficientes al dejar fuera a i
    bbar = mean(Bi)
    sej  = sqrt((n - 1) / n * colsum((Bi :- bbar) :^ 2))
    st_matrix("JK", (b[1..cols(b)-1] \ sej[1..cols(sej)-1]))
}
end

if $corre_4 {
    manual, base("$data/construidas/p4_enigh2024.dta") etiq("ENIGH") res("$data/construidas/p4_res_enigh_manual.dta")
    use "$data/construidas/p4_res_enigh_manual.dta", clear
    list metodo reps var b se lo_p hi_p lo_t hi_t tstat, noobs sepby(metodo reps) abbreviate(8)
}


/*==============================================================================
  4.4 ENOE 2026, trimestre II: incisos a, b, d y e con comandos y con bsample
==============================================================================*/
if $corre_4 {
    ejercicio, base("$data/construidas/p4_enoe2026t2.dta") etiq("ENOE") res("$data/construidas/p4_res_enoe_comandos.dta")
    manual,    base("$data/construidas/p4_enoe2026t2.dta") etiq("ENOE") res("$data/construidas/p4_res_enoe_manual.dta")
}


/*==============================================================================
  Cuadros (uno por base y forma de cálculo) para los coeficientes de
  escolaridad y mujer
==============================================================================*/
local n = 0
foreach b in enigh enoe {
    foreach f in comandos manual {
        local ++n
        use "$data/construidas/p4_res_`b'_`f'.dta", clear
        rename var coef
        keep if inlist(coef, "educ_anios", "mujer")
        gen byte orden = cond(metodo == "MCO robusto", 1, cond(metodo == "Bootstrap", 2, cond(metodo == "Bootstrap m", 3, cond(metodo == "Jackknife", 4, 5))))
        gen str40 fila = metodo + cond(inlist(metodo, "Bootstrap", "Bootstrap m"), " (" + string(reps) + " rep.)", "")
        replace fila = "MCO, EE robusto" if metodo == "MCO robusto"
        replace fila = subinstr(fila, "Bootstrap m", "Bootstrap 0.25 N", 1)
        replace fila = subinstr(fila, "Jackknife m", "Jackknife 0.25 N", 1)
        replace reps = 0 if missing(reps)               // jackknife con N: N no cabe en int; sin este cambio group() lo omite
        sort orden reps
        egen int fid = group(orden reps)
        levelsof fid, local(fids)
        foreach i of local fids {
            levelsof fila if fid == `i', local(lab) clean
            label define lfila `i' "`lab'", add
        }
        label values fid lfila
        gen byte vcoef = cond(coef == "educ_anios", 1, 2)
        label define lvcoef 1 "Escolaridad" 2 "Mujer", replace
        label values vcoef lvcoef
        label var b    "Coef."
        label var se   "E.E."
        label var lo_p "Percentil inf."
        label var hi_p "Percentil sup."
        label var lo_t "Percentil-t inf."
        label var hi_t "Percentil-t sup."
        label var tstat "t"
        table (vcoef fid) (var), statistic(mean b se lo_p hi_p lo_t hi_t tstat) nototals   // escolaridad y mujer en bloques de renglones
        estilo_cuadro, size(9)
        collect style header vcoef fid, title(hide)
        collect style cell, nformat(%9.4f)
        collect style cell var[tstat], nformat(%9.1f)
        local B = cond("`b'" == "enigh", "ENIGH 2024", "ENOE 2026, trimestre II")
        local F = cond("`f'" == "comandos", "comandos bootstrap y jackknife", "réplicas con bsample")
        collect title "Cuadro 4.`n'. `B': errores estándar e intervalos de confianza al 95% (`F')"
        local fte = cond("`b'" == "enigh", "Fuente: elaboración propia con datos de la ENIGH 2024 (INEGI).", "Fuente: elaboración propia con datos de la ENOE 2026, trimestre II (INEGI).")
        exporta_cuadro, archivo("$out/Cuadro_4_`n'_`b'_`f'") ///
            nota("Nota: MCO del log del salario por hora sobre escolaridad, edad, edad al cuadrado, rural y mujer, sin factor de expansión. En MCO y jackknife el intervalo es el normal (coeficiente ± 1.96 E.E.); en bootstrap, el percentil usa los cuantiles 2.5 y 97.5 de los coeficientes y el percentil-t los de t* = (b* - b) / E.E.*. Con 0.25 N el E.E. corresponde a muestras de tamaño N/4. t = coeficiente / E.E.") ///
            fuente("`fte'")
    }
}

log close
