/*==============================================================================
  PROBLEMA 1: ENIGH y ENOE

  Estructura del proyecto:
     data/  -> bases de datos (originales y construidas)
     prog/  -> do-files (este archivo)
     log/   -> log files
     papers/-> documentos generados
==============================================================================*/

*------------------------------------------------------------------------------
* 0. CONFIGURACIÓN GENERAL
*------------------------------------------------------------------------------
clear all
set more off
set varabbrev off                 // evita que Stata "adivine" nombres de variables
version 19

* Rutas del proyecto (global root se ajusta al directorio)
global root  "C:/Users/lcastillo/Music/TAREA 2"
global data  "$root/data"
global prog  "$root/prog"
global log   "$root/log"
global out   "$root/papers/output"   // tablas y gráficas que irán generandose
global enigh "$data/ENIGH/raw"
global enoe  "$data/ENOE/ENOE"

capture mkdir "$out"
capture mkdir "$data/construidas"   // aquí guardaremos las bases limpias

capture log close
log using "$log/P1_ENIGH_ENOE.log", replace text

* Estilo gráfico uniforme para todo el problema set
set scheme s2color
graph set window fontface "Times New Roman"

* Estilo A para todas las gráficas: paleta, tamaño de texto y tamaño de figura
global c1   "31 58 104"           // azul marino
global c2   "200 112 42"          // naranja
global c3   "46 107 52"           // verde
global c4   "142 36 50"           // guinda
global gtam "medsmall"            // mismo tamaño para títulos de eje y etiquetas
global gfig "xsize(6.5) ysize(4.5) graphregion(color(white) margin(small)) plotregion(color(white) lcolor(none))"

* Estilo de todos los cuadros: sin línea vertical, encabezados centrados,
* Times New Roman
capture program drop estilo_cuadro
program define estilo_cuadro
    syntax [, SIZE(integer 9)]
    collect style header result, level(hide)
    collect style cell border_block, border(right, pattern(nil))
    collect style cell cell_type[column-header corner], font(, bold) shading(background(D9D9D9))   // formato C: encabezado gris y en negrita
    collect style cell cell_type[column-header], halign(center)
    collect style cell, font("Times New Roman", size(`size'))
    capture noisily collect style title, font("Times New Roman", size(10))
    capture noisily collect style header year, title(hide)
end

* Exporta el cuadro: Excel con collect; Word con putdocx para que la nota y la
* fuente queden en renglones separados y en letra menor
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

* Interruptores: 1 = corre la sección, 0 = la omite (para no repetir pasos lentos)
global corre_1_1b 1               // revisión de la ENOE (tarda ~1.5 min)
global corre_1_2  1               // construcción del ingreso ENIGH (ya corrida; sus archivos existen)
global corre_1_3  1               // bases limpias ENIGH y ENOE (ya corrida; sus archivos existen)


/*==============================================================================
  INCISO 1.1 — Bases a utilizar
  ENIGH: todas las levantadas entre 1992 y 2024 (18 levantamientos).
  ENOE : todos los trimestres 2005-I a 2026-II, SIN la ETOE (2020-II).
  Objetivo de esta sección: verificar que tenemos todos los insumos 
==============================================================================*/

*------------------------------------------------------------------------------
* 1.1.a ENIGH: inventario de tablas de POBLACIÓN e INGRESOS por año
*   Los nombres de los archivos cambian entre años (dbf hasta 2005, dta después;
*   "NCV_" para la Nueva Construcción de Variables 2008-2014). Guardamos los
*   nombres en locales para reutilizarlos en el inciso 1.2.
*------------------------------------------------------------------------------
global enigh_years 1992 1994 1996 1998 2000 2002 2004 2005 2006 ///
                   2008 2010 2012 2014 2016 2018 2020 2022 2024

* Tabla de población por año
global pob1992 "POBLA92.dbf"
global pob1994 "POBLA94.dbf"
global pob1996 "POBLA96.dbf"
global pob1998 "POBLA98.dbf"
global pob2000 "pobla.dbf"
global pob2002 "POBLA02.dbf"
global pob2004 "POBLA04.dbf"
global pob2005 "pobla.dbf"
global pob2006 "poblacion.dta"
global pob2008 "NCV_Poblacion_2008_concil_2010.dta"
global pob2010 "NCV_Poblacion_2010_concil_2010.dta"
global pob2012 "ncv_poblacion_2012_concil_2010.dta"
global pob2014 "ncv_poblacion_2014_concil_2010.dta"
foreach y in 2016 2018 2020 2022 2024 {
    global pob`y' "poblacion.dta"
}

* Tabla de ingresos por año
foreach y in 1992 1994 1996 1998 2000 2002 2004 2005 {
    global ing`y' "ingresos.dbf"
}
global ing2006 "Ingresos.dta"
global ing2008 "NCV_Ingresos_2008_concil_2010.dta"
global ing2010 "NCV_Ingresos_2010_concil_2010.dta"
global ing2012 "ncv_ingresos_2012_concil_2010.dta"
global ing2014 "ncv_ingresos_2014_concil_2010.dta"
foreach y in 2016 2018 2020 2022 2024 {
    global ing`y' "ingresos.dta"
}

* Verificación: si falta algún archivo, el do-file se detiene con error
foreach y of global enigh_years {
    confirm file "$enigh/`y'/${pob`y'}"
    confirm file "$enigh/`y'/${ing`y'}"
    di as txt "ENIGH `y': OK  ->  ${pob`y'}  |  ${ing`y'}"
}

*------------------------------------------------------------------------------
* 1.1.b ENOE: cobertura por año-trimestre, factor de expansión y ETOE
*   Solo leemos las variables de identificación del periodo y los pesos.
*------------------------------------------------------------------------------
if $corre_1_1b {
use anio_enoe trimestre_enoe fac fac_men r_def c_res eda ///
    using "$enoe/ENOE_todas.dta", clear

describe, short
destring anio_enoe trimestre_enoe, replace   // por si vinieran como texto

* Número de registros por año y trimestre
table anio_enoe trimestre_enoe, nformat(%12.0fc)

* ¿Hay registros de 2020-II (periodo de la ETOE)? Debe ser 0.
count if anio_enoe == 2020 & trimestre_enoe == 2
if r(N) > 0 {
    di as err "ATENCIÓN: existen `r(N)' registros de 2020-II (ETOE)."
}

* ¿El factor de expansión trimestral (fac) está disponible en todos los
*  trimestres? En la ENOE-N (2020-III a 2022-IV) INEGI lo llama fac_tri;
*  si faltara aquí, lo veremos como missing.
gen byte fac_miss = missing(fac)
table anio_enoe, statistic(mean fac_miss) statistic(min fac) ///
      statistic(max fac) nformat(%9.3f mean) nformat(%12.0fc min max)

* Resultado de la entrevista y condición de residencia
*  (filtros estándar de INEGI: r_def==0 entrevista completa;
*   c_res 1 o 3 = residente habitual / nuevo residente)
tab r_def, missing
tab c_res, missing
}   // fin de 1.1.b


/*==============================================================================
  INCISO 1.2 — ENIGH: ingreso laboral por persona (collapse -> merge -> append)
  Para cada año:
    (1) Tabla de ingresos: nos quedamos con las claves de ingreso por trabajo
        (remuneraciones + negocios propios + cooperativas, según la
        clasificación del INEGI/CONEVAL de cada levantamiento).
    (2) collapse: sumamos todas las claves laborales de cada persona.
    (3) merge 1:1 con la tabla de población (todas las personas del hogar).
    (4) Guardamos un archivo por año y al final los unimos con append.
==============================================================================*/
if $corre_1_2 {
capture mkdir "$data/construidas/enigh"

*------------------------------------------------------------------------------
* 1.2.a Claves de ingreso laboral por año (validadas contra el concentrado INEGI)
*------------------------------------------------------------------------------
global lab1992 `"inrange(clave,"P001","P011") | clave=="P013""'
foreach y in 1994 1996 {
    global lab`y' `"inrange(clave,"P001","P015")"'
}
foreach y in 1998 2000 {
    global lab`y' `"inrange(clave,"P001","P019")"'
}
global lab2002 `"inrange(clave,"P001","P020") | inlist(clave,"P022","P023")"'
foreach y in 2004 2005 2006 {
    global lab`y' `"inrange(clave,"P001","P027") | inrange(clave,"P029","P038")"'
}
foreach y in 2008 2010 2012 2014 2016 2018 2020 2022 2024 {
    global lab`y' `"inrange(clave,"P001","P009") | inrange(clave,"P011","P016") | inrange(clave,"P018","P022") | inrange(clave,"P067","P081")"'
}

*------------------------------------------------------------------------------
* 1.2.b Ciclo por año: ingresos -> collapse -> merge con población
*------------------------------------------------------------------------------
foreach y of global enigh_years {

    di _n as res "================  ENIGH `y'  ================"

    * --- (1) Tabla de INGRESOS -------------------------------------------
    if strpos("${ing`y'}", ".dbf") {
        import dbase using "$enigh/`y'/${ing`y'}", clear case(lower)
    }
    else {
        use "$enigh/`y'/${ing`y'}", clear
        rename *, lower
    }

    * Identificador del hogar homogéneo (folio) y de la persona (numren)
    capture confirm variable folioviv
    if _rc == 0 {
        capture tostring folioviv foliohog, replace format(%15.0f)
        gen str30 folio = folioviv + "_" + foliohog
    }
    else {
        capture tostring folio, replace format(%15.0f)
    }
    capture rename num_ren numren
    destring numren, replace

    * Ingreso del mes pasado: su nombre cambia entre años
    capture rename ing_mp ing_1                 // 1992
    capture rename ing1   ing_1                 // 1994 y 1996
    destring ing_1 ing_tri, replace

    * Solo claves de ingreso por trabajo
    replace clave = upper(trim(clave))
    keep if ${lab`y'}

    * 2008-2024: utilidades (P008, P015) y aguinaldo (P009, P016) se captan
    * como un monto anual en ing_1; no corresponden al mes pasado.
    if `y' >= 2008 {
        replace ing_1 = 0 if inlist(clave, "P008", "P009", "P015", "P016")
    }

    * 1992: montos en "viejos pesos" -> nuevos pesos (1 N$ = 1,000 $)
    if `y' == 1992 {
        replace ing_1   = ing_1   / 1000
        replace ing_tri = ing_tri / 1000
    }

    * --- (2) collapse: un renglón por persona ------------------------------
    collapse (sum) ing_lab_mp = ing_1 ing_lab_tri = ing_tri ///
             (count) n_lab = ing_tri, by(folio numren)
    tempfile ing`y'
    save `ing`y''

    * --- (3) Tabla de POBLACIÓN y merge -------------------------------------
    if strpos("${pob`y'}", ".dbf") {
        import dbase using "$enigh/`y'/${pob`y'}", clear case(lower)
    }
    else {
        use "$enigh/`y'/${pob`y'}", clear
        rename *, lower
    }
    capture confirm variable folioviv
    if _rc == 0 {
        capture tostring folioviv foliohog, replace format(%15.0f)
        gen str30 folio = folioviv + "_" + foliohog
    }
    else {
        capture tostring folio, replace format(%15.0f)
    }
    capture rename num_ren numren
    destring numren, replace
    isid folio numren                           // una fila por persona

    merge 1:1 folio numren using `ing`y''
    tab _merge
    count if _merge == 2
    if r(N) > 0 di as err "ATENCIÓN `y': `r(N)' personas con ingreso sin registro en población"
    drop if _merge == 2

    gen byte con_ing_lab = (_merge == 3)        // 1 = reportó alguna clave laboral
    drop _merge
    foreach v in ing_lab_mp ing_lab_tri n_lab {
        replace `v' = 0 if con_ing_lab == 0
    }

    * --- (4) Año y guardado --------------------------------------------------
    gen int year = `y'
    compress
    save "$data/construidas/enigh/enigh_pob_ing_`y'.dta", replace
}

*------------------------------------------------------------------------------
* 1.2.c append: una sola base con todos los años
*------------------------------------------------------------------------------
clear
foreach y of global enigh_years {
    append using "$data/construidas/enigh/enigh_pob_ing_`y'.dta", ///
        keep(year folio numren ing_lab_mp ing_lab_tri n_lab con_ing_lab)
}
order year folio numren
label var year        "Año de la ENIGH"
label var folio       "Folio del hogar (armonizado)"
label var numren      "Número de renglón de la persona"
label var ing_lab_mp  "Ingreso laboral del mes pasado (pesos corrientes)"
label var ing_lab_tri "Ingreso laboral trimestral normalizado (INEGI, pesos corrientes)"
label var n_lab       "Número de claves de ingreso laboral"
label var con_ing_lab "Reporta alguna clave de ingreso laboral (1=sí)"
compress
save "$data/construidas/enigh_ing_lab_1992_2024.dta", replace

* Verificación por año: personas, % con ingreso laboral y promedios (nominales)
table year, statistic(frequency) statistic(mean con_ing_lab) nformat(%12.0fc frequency) nformat(%5.3f mean)
table year if con_ing_lab == 1, statistic(mean ing_lab_mp ing_lab_tri) nformat(%12.1fc)
}   // fin de 1.2


/*==============================================================================
  INCISO 1.3 — Variables de interés, pesos reales y muestra de 25 a 65 años
  Variables: edad, escolaridad (años y nivel terminado), ingreso del mes
  pasado, ingreso trimestral normalizado (solo ENIGH), horas trabajadas,
  sexo y rural. Ingresos en pesos reales de ENERO DE 2026:
     ENIGH: INPC de agosto del año de levantamiento (convención INEGI/CONEVAL)
     ENOE : INPC promedio de los tres meses del trimestre
==============================================================================*/

*------------------------------------------------------------------------------
* 1.3.a Deflactores (INPC, base 2a quincena de julio 2018 = 100)
*------------------------------------------------------------------------------
use "$data/INPC/inpc_mensual_1990_2026.dta", clear
summarize inpc if anio == 2026 & mes == 1, meanonly
scalar inpc_ene26 = r(mean)
di "INPC enero 2026 = " inpc_ene26

preserve
    keep if mes == 8                                  // ENIGH: agosto de cada año
    rename (anio inpc) (year inpc_ago)
    keep year inpc_ago
    tempfile inpc_enigh
    save `inpc_enigh'
restore
gen byte trimestre = ceil(mes/3)                      // ENOE: promedio trimestral
collapse (mean) inpc_trim = inpc, by(anio trimestre)
tempfile inpc_enoe
save `inpc_enoe'

*------------------------------------------------------------------------------
* 1.3.b ENIGH: nombres de las tablas de hogares (concentrado) y trabajos
*------------------------------------------------------------------------------
foreach y in 1992 1994 1996 1998 2000 2002 2004 2005 {
    global con`y' "concen.dbf"
}
global con2006 "concen.dta"
global con2008 "NCV_Concentrado_2008_concil_2010.dta"
global con2010 "NCV_Concentrado_2010_concil_2010.dta"
global con2012 "NCV_concentrado_2012_concil_2010.dta"
global con2014 "NCV_concentrado_2014_concil_2010.dta"
global tra2008 "NCV_Trabajos_2008_concil_2010.dta"
global tra2010 "NCV_Trabajos_2010_concil_2010.dta"
global tra2012 "ncv_trabajos_2012_concil_2010.dta"
global tra2014 "ncv_trabajos_2014_concil_2010.dta"
foreach y in 2016 2018 2020 2022 2024 {
    global con`y' "concentradohogar.dta"
    global tra`y' "trabajos.dta"
}

*------------------------------------------------------------------------------
* 1.3.c ENIGH: variables armonizadas por año
*------------------------------------------------------------------------------
if $corre_1_3 {
foreach y of global enigh_years {

    di _n as res "================  ENIGH `y' (1.3)  ================"

    * --- Hogar: factor de expansión y tamaño de localidad -------------------
    if strpos("${con`y'}", ".dbf") {
        import dbase using "$enigh/`y'/${con`y'}", clear case(lower)
    }
    else {
        use "$enigh/`y'/${con`y'}", clear
        rename *, lower
    }
    capture confirm variable folioviv
    if _rc == 0 {
        capture tostring folioviv foliohog, replace format(%15.0f)
        gen str30 folio = folioviv + "_" + foliohog
    }
    else {
        capture tostring folio, replace format(%15.0f)
    }
    capture rename hog        factor                  // 1992-2006
    capture rename factor_hog factor                  // 2012-2014
    capture rename estrato    tam_loc                 // 1992-2008: estrato; 2010+: tam_loc
    destring factor tam_loc, replace
    gen byte rural = (tam_loc == 4)                   // localidades de menos de 2,500 hab.
    keep folio factor rural
    tempfile hog
    save `hog'

    * --- Horas trabajadas 2008+: tabla de trabajos (suma de todos los empleos)
    if `y' >= 2008 {
        use "$enigh/`y'/${tra`y'}", clear
        rename *, lower
        capture tostring folioviv foliohog, replace format(%15.0f)
        gen str30 folio = folioviv + "_" + foliohog
        destring numren htrab, replace
        collapse (sum) horas = htrab, by(folio numren)
        tempfile hrs
        save `hrs'
    }

    * --- Personas (archivo del inciso 1.2) -----------------------------------
    use "$data/construidas/enigh/enigh_pob_ing_`y'.dta", clear
    destring sexo edad, replace

    * Años de escolaridad según el esquema de cada levantamiento
    if inlist(`y', 1992, 1994) {                      // nivel terminado (0-9)
        destring ed_formal, replace
        recode ed_formal (0=0) (1=3) (2=6) (3=7) (4=9) (5=10) (6=12) ///
                         (7=14) (8=16) (9=18) (else=.), gen(educ_anios)
    }
    else if inlist(`y', 1996, 1998, 2000) {           // último grado aprobado (00-16)
        destring ed_formal, replace
        recode ed_formal (0 1=0) (2=1) (3=2) (4=3) (5=4) (6=5) (7=6) (8=7) ///
                         (9=8) (10=9) (11=10) (12=12) (13=14) (14=16) (15=18) ///
                         (16=8) (else=.), gen(educ_anios)
    }
    else if `y' == 2002 {                             // grado o semestre aprobado (00-33)
        destring ed_formal, replace
        recode ed_formal (0/2=0) (3=1) (4=2) (5=3) (6=4) (7=5) (8=6) (9=7) ///
                         (10=8) (11 12=9) (13 14 17=10) (15 16=11) (18 19=12) ///
                         (20 21=13) (22 23=13) (24 25 30=14) (26 27=15) ///
                         (28 29=16) (31=17) (32=18) (33=20) (else=.), gen(educ_anios)
    }
    else {                                            // 2004+: nivel + grado + antecedente
        capture rename n_instr161 niv
        capture rename n_instr141 niv
        capture rename nivelaprob niv
        capture rename n_instr162 gra
        capture rename n_instr142 gra
        capture rename gradoaprob gra
        destring niv gra antec_esc, replace
        gen educ_anios = .
        replace educ_anios = 0          if inlist(niv, 0, 1)      // ninguno / preescolar
        replace educ_anios = gra        if niv == 2               // primaria
        replace educ_anios = 6  + gra   if niv == 3               // secundaria
        replace educ_anios = 9  + gra   if niv == 4               // preparatoria
        replace educ_anios = 6  + gra   if inlist(niv, 5, 6) & antec_esc == 1   // normal/técnica
        replace educ_anios = 9  + gra   if inlist(niv, 5, 6) & (antec_esc == 2 | missing(antec_esc))
        replace educ_anios = 12 + gra   if inlist(niv, 5, 6) & antec_esc >= 3 & !missing(antec_esc)
        replace educ_anios = 12 + gra   if niv == 7               // profesional
        replace educ_anios = 16 + gra   if niv == 8               // maestría
        replace educ_anios = 18 + gra   if niv == 9               // doctorado
        replace educ_anios = 24 if educ_anios > 24 & !missing(educ_anios)
    }

    * Horas trabajadas a la semana (todos los trabajos)
    if `y' <= 2002 {
        capture rename hr_semana  hrs_sem             // 1992
        capture rename hr_sem_sec hrs_sec
        destring hrs_sem hrs_sec, replace
        egen horas = rowtotal(hrs_sem hrs_sec)
    }
    else if `y' <= 2006 {
        capture rename horastrab horas_trab           // 2004
        destring horas_trab, replace
        gen horas = horas_trab
        replace horas = 0 if missing(horas)           // vacío = no trabajó (en 2004 viene vacío)
    }
    else {
        merge 1:1 folio numren using `hrs', keep(master match) nogenerate
        replace horas = 0 if missing(horas)           // sin registro en trabajos = no trabajó
    }

    * Hogar: factor y rural
    merge m:1 folio using `hog', keep(master match) nogenerate

    keep year folio numren sexo edad educ_anios horas rural factor ///
         ing_lab_mp ing_lab_tri con_ing_lab
    tempfile p`y'
    save `p`y''
}

* Append de los 18 años
clear
foreach y of global enigh_years {
    append using `p`y''
}

* Pesos reales de enero de 2026
merge m:1 year using `inpc_enigh', keep(master match) nogenerate
gen double defl = inpc_ene26 / inpc_ago
gen double ing_mp_real  = ing_lab_mp  * defl
gen double ing_tri_real = ing_lab_tri * defl

* Variables finales
gen byte mujer = (sexo == 2) if inlist(sexo, 1, 2)
gen byte educ_nivel = .
replace educ_nivel = 0 if educ_anios == 0
replace educ_nivel = 1 if inrange(educ_anios, 1, 5)
replace educ_nivel = 2 if inrange(educ_anios, 6, 8)
replace educ_nivel = 3 if inrange(educ_anios, 9, 11)
replace educ_nivel = 4 if inrange(educ_anios, 12, 15)
replace educ_nivel = 5 if educ_anios >= 16 & !missing(educ_anios)
gen byte prepa_o_mas = (educ_anios >= 12) if !missing(educ_anios)

* --- Limpieza: muestra de 25 a 65 años y sin valores faltantes -------------
count
keep if inrange(edad, 25, 65)
count
misstable summarize edad mujer educ_anios horas rural factor ing_mp_real ing_tri_real
foreach v in mujer educ_anios horas rural factor ing_mp_real ing_tri_real {
    count if missing(`v')
    di as txt "  `v': se eliminan `r(N)' observaciones con valor faltante"
    drop if missing(`v')
}
count

label define lnivel 0 "Sin escolaridad" 1 "Primaria incompleta" 2 "Primaria completa" ///
                    3 "Secundaria completa" 4 "Media superior completa" 5 "Superior o más"
label values educ_nivel lnivel
label var edad         "Edad"
label var mujer        "Mujer"
label var educ_anios   "Años de escolaridad"
label var educ_nivel   "Nivel de escolaridad terminado"
label var prepa_o_mas  "Preparatoria completa o más"
label var horas        "Horas trabajadas a la semana"
label var rural        "Rural (<2,500 hab.)"
label var factor       "Factor de expansión"
label var ing_mp_real  "Ingreso laboral del mes pasado (pesos ene-2026)"
label var ing_tri_real "Ingreso laboral trimestral (pesos ene-2026)"
drop sexo defl inpc_ago
order year folio numren edad mujer educ_anios educ_nivel prepa_o_mas horas rural ///
      ing_mp_real ing_tri_real ing_lab_mp ing_lab_tri con_ing_lab factor
compress
save "$data/construidas/enigh_1992_2024_limpia.dta", replace

* Verificación: estadísticos por año (en el log)
tabstat edad mujer educ_anios prepa_o_mas horas rural ing_mp_real ing_tri_real, ///
    by(year) statistics(n mean sd min max) columns(statistics) format(%12.2fc) longstub

*------------------------------------------------------------------------------
* 1.3.d ENOE 2005-I a 2026-II
*------------------------------------------------------------------------------
use anio_enoe trimestre_enoe ent fac r_def c_res clase2 eda sex anios_esc ///
    hrsocup ingocup t_loc t_loc_men p6b2 p6c using "$enoe/ENOE_todas.dta" ///
    if inrange(eda, 25, 65), clear
count

* Filtros de INEGI: entrevista completa y residentes (habituales o nuevos)
capture confirm numeric variable r_def
if _rc destring r_def, replace
tab r_def
keep if r_def == 0
keep if inlist(c_res, 1, 3)
count

* Sin peso (factor 0) no representan población: se eliminan
count if fac == 0 | missing(fac)
drop if fac == 0 | missing(fac)

* Escolaridad: 99 = no especificado
replace anios_esc = . if anios_esc == 99
* Horas e ingreso: 0 para quien no está ocupado
replace hrsocup = 0 if missing(hrsocup) & clase2 != 1
replace ingocup = 0 if missing(ingocup) & clase2 != 1

* Pesos reales de enero de 2026 (INPC promedio del trimestre)
rename (anio_enoe trimestre_enoe) (anio trimestre)
merge m:1 anio trimestre using `inpc_enoe', keep(master match) nogenerate
gen double ing_mp_real = ingocup * inpc_ene26 / inpc_trim

* Variables finales
gen byte mujer = (sex == 2) if inlist(sex, 1, 2)
count if missing(t_loc)
replace t_loc = t_loc_men if missing(t_loc)        // respaldo: tamaño de localidad mensual
gen byte rural = (t_loc == 4) if !missing(t_loc)
rename (eda anios_esc hrsocup fac) (edad educ_anios horas factor)
gen byte educ_nivel = .
replace educ_nivel = 0 if educ_anios == 0
replace educ_nivel = 1 if inrange(educ_anios, 1, 5)
replace educ_nivel = 2 if inrange(educ_anios, 6, 8)
replace educ_nivel = 3 if inrange(educ_anios, 9, 11)
replace educ_nivel = 4 if inrange(educ_anios, 12, 15)
replace educ_nivel = 5 if educ_anios >= 16 & !missing(educ_anios)
gen byte prepa_o_mas = (educ_anios >= 12) if !missing(educ_anios)
label values educ_nivel lnivel

* Sin valores faltantes en las variables de interés
misstable summarize edad mujer educ_anios horas rural factor ing_mp_real
foreach v in mujer educ_anios horas rural factor ing_mp_real {
    count if missing(`v')
    di as txt "  `v': se eliminan `r(N)' observaciones con valor faltante"
    drop if missing(`v')
}
count

gen int year = anio
label var edad        "Edad"
label var mujer       "Mujer"
label var educ_anios  "Años de escolaridad"
label var educ_nivel  "Nivel de escolaridad terminado"
label var prepa_o_mas "Preparatoria completa o más"
label var horas       "Horas trabajadas a la semana"
label var rural       "Rural (<2,500 hab.)"
label var factor      "Factor de expansión trimestral"
label var ingocup     "Ingreso mensual (pesos corrientes)"
label var ing_mp_real "Ingreso laboral mensual (pesos ene-2026)"
drop sex t_loc t_loc_men r_def c_res inpc_trim
order year anio trimestre ent edad mujer educ_anios educ_nivel prepa_o_mas horas ///
      rural ing_mp_real ingocup p6b2 p6c clase2 factor
compress
save "$data/construidas/enoe_2005_2026_limpia.dta", replace

* Verificación: estadísticos por año (en el log)
tabstat edad mujer educ_anios prepa_o_mas horas rural ing_mp_real, ///
    by(year) statistics(n mean sd min max) columns(statistics) format(%12.2fc) longstub
}   // fin de 1.3.c y 1.3.d

*------------------------------------------------------------------------------
* 1.3.e Cuadros 1 y 2 (fuera del interruptor: se leen de las bases limpias)
*------------------------------------------------------------------------------
* ENIGH
use year edad mujer educ_anios prepa_o_mas horas rural ing_mp_real ing_tri_real factor ///
    using "$data/construidas/enigh_1992_2024_limpia.dta", clear
gen double ing_mp_pos  = ing_mp_real  if ing_mp_real  > 0
gen double ing_tri_pos = ing_tri_real if ing_tri_real > 0
bysort year: gen long n_obs = _N
label var n_obs       "Observaciones"
label var edad        "Edad"
label var mujer       "Mujer"
label var educ_anios  "Escolaridad (años)"
label var prepa_o_mas "Prepa o más"
label var horas       "Horas/semana"
label var rural       "Rural"
label var ing_mp_pos  "Ingreso mes pasado*"
label var ing_tri_pos "Ingreso trimestral*"

table year [aw=factor], statistic(mean n_obs edad mujer educ_anios prepa_o_mas horas rural ing_mp_pos ing_tri_pos) nototals
estilo_cuadro
collect style cell var[n_obs], nformat(%12.0fc)
collect style cell var[edad mujer educ_anios prepa_o_mas horas rural], nformat(%9.2f)
collect style cell var[ing_mp_pos ing_tri_pos], nformat(%12.0fc)
collect label dim year "Año", modify
collect title "Cuadro 1. ENIGH 1992-2024: características de la población de 25 a 65 años"
exporta_cuadro, archivo("$out/Cuadro1_ENIGH_descriptivos") ///
    nota("Nota: medias ponderadas con el factor de expansión; Observaciones: personas en la muestra (sin ponderar). Mujer, Prepa o más y Rural son proporciones; Rural: localidades de menos de 2,500 habitantes. *Ingresos laborales en pesos de enero de 2026 (INPC de agosto de cada año); promedio entre quienes reportan ingreso positivo.") ///
    fuente("Fuente: elaboración propia con datos de la ENIGH (INEGI), 1992-2024.")

* ENOE
use year edad mujer educ_anios prepa_o_mas horas rural ing_mp_real factor ///
    using "$data/construidas/enoe_2005_2026_limpia.dta", clear
gen double ing_mp_pos = ing_mp_real if ing_mp_real > 0
bysort year: gen long n_obs = _N
label var n_obs       "Observaciones"
label var edad        "Edad"
label var mujer       "Mujer"
label var educ_anios  "Escolaridad (años)"
label var prepa_o_mas "Prepa o más"
label var horas       "Horas/semana"
label var rural       "Rural"
label var ing_mp_pos  "Ingreso mensual*"

table year [aw=factor], statistic(mean n_obs edad mujer educ_anios prepa_o_mas horas rural ing_mp_pos) nototals
estilo_cuadro
collect style cell var[n_obs], nformat(%12.0fc)
collect style cell var[edad mujer educ_anios prepa_o_mas horas rural], nformat(%9.2f)
collect style cell var[ing_mp_pos], nformat(%12.0fc)
collect label dim year "Año", modify
collect title "Cuadro 2. ENOE 2005-2026: características de la población de 25 a 65 años"
exporta_cuadro, archivo("$out/Cuadro2_ENOE_descriptivos") ///
    nota("Nota: medias ponderadas con el factor de expansión trimestral; Observaciones: personas en la muestra (sin ponderar). Todos los trimestres de cada año (2020-II no disponible; 2026 incluye I y II). Mujer, Prepa o más y Rural son proporciones. *Ingreso laboral mensual en pesos de enero de 2026 (INPC promedio del trimestre); promedio entre quienes reportan ingreso positivo.") ///
    fuente("Fuente: elaboración propia con datos de la ENOE (INEGI), 2005-2026.")


/*==============================================================================
  Programa auxiliar para las gráficas por grupo (inciso 1.8)
  Dos paneles (Hombres | Mujeres) con el mismo eje y; en cada panel una línea
  por grupo de edad y escolaridad y el total de la población en negro.
==============================================================================*/
capture program drop graf_grupos
program define graf_grupos
    syntax varname, YTItulo(string) ARchivo(string) NOta(string asis) ///
           XLab(string) [FOrmato(string)]
    if "`formato'" == "" local formato "%9.0fc"
    preserve
        keep year grupo sexo_g sub_g `varlist'
        expand 2 if grupo == 9, generate(copia)       // el total aparece en ambos paneles
        gen byte panel = sexo_g
        replace panel = 1 + copia if grupo == 9
        label define lpanel 1 "Hombres" 2 "Mujeres", replace
        label values panel lpanel
        sort panel sub_g year
        twoway (connected `varlist' year if sub_g == 1, lcolor("$c1") mcolor("$c1") msymbol(O) msize(small) lwidth(medthin)) ///
               (connected `varlist' year if sub_g == 2, lcolor("$c2") mcolor("$c2") msymbol(O) msize(small) lwidth(medthin)) ///
               (connected `varlist' year if sub_g == 3, lcolor("$c3") mcolor("$c3") msymbol(O) msize(small) lwidth(medthin)) ///
               (connected `varlist' year if sub_g == 4, lcolor("$c4") mcolor("$c4") msymbol(O) msize(small) lwidth(medthin)) ///
               (line      `varlist' year if sub_g == 5, lcolor(black) lwidth(thick)), ///
            by(panel, rows(1) iscale(1) imargin(medium) note(`nota', size(small) span) ///
               legend(position(6)) graphregion(color(white) margin(small))) ///
            subtitle(, size($gtam) fcolor(white) lcolor(white)) ///
            ytitle("`ytitulo'", size($gtam)) xtitle("Año", size($gtam)) ///
            xlabel(`xlab', labsize($gtam) nogrid) ///
            ylabel(, labsize($gtam) angle(horizontal) format(`formato') grid glcolor(gs14)) ///
            legend(order(1 "25-45, sin prepa" 2 "25-45, prepa o más" 3 "46-65, sin prepa" ///
                         4 "46-65, prepa o más" 5 "Total de la población") ///
                   rows(2) size(small) region(lcolor(white))) ///
            plotregion(color(white) lcolor(none)) xsize(6.5) ysize(4.5)
        graph export "`archivo'", width(2400) replace
    restore
end


/*==============================================================================
  INCISOS 1.4 a 1.9 — se repiten para la ENIGH y para la ENOE
==============================================================================*/
foreach enc in enigh enoe {

    if "`enc'" == "enigh" {
        use "$data/construidas/enigh_1992_2024_limpia.dta", clear
        local ENC    "ENIGH"
        local xl     "1992(8)2024"
        local fuente "Fuente: elaboración propia con datos de la ENIGH (INEGI), 1992-2024."
        local nc     = 3                                  // numeración de cuadros
    }
    else {
        use "$data/construidas/enoe_2005_2026_limpia.dta", clear
        local ENC    "ENOE"
        local xl     "2005(5)2025"
        local fuente "Fuente: elaboración propia con datos de la ENOE (INEGI), 2005-2026; todos los trimestres, sin ETOE."
        local nc     = 7
    }
    di _n as res "=====================  `ENC': incisos 1.4 a 1.9  ====================="

    *--------------------------------------------------------------------------
    * 1.4 Ocho grupos: sexo x edad (25-45, 46-65) x escolaridad (< prepa, >= prepa)
    *--------------------------------------------------------------------------
    capture drop edad_g grupo
    gen byte edad_g = (edad >= 46)
    gen byte grupo  = 1 + 4*mujer + 2*edad_g + prepa_o_mas
    label define lgrupo 1 "Hombres, 25-45, sin prepa"   2 "Hombres, 25-45, prepa o más" ///
                        3 "Hombres, 46-65, sin prepa"   4 "Hombres, 46-65, prepa o más" ///
                        5 "Mujeres, 25-45, sin prepa"   6 "Mujeres, 25-45, prepa o más" ///
                        7 "Mujeres, 46-65, sin prepa"   8 "Mujeres, 46-65, prepa o más" ///
                        9 "Total", replace
    label values grupo lgrupo
    label var grupo "Grupo sexo-edad-escolaridad"
    tab grupo

    *--------------------------------------------------------------------------
    * 1.5 Salario válido y variable trabajo
    *   999998/999999 = no sabe/no responde -> faltante (antes de pasar a real)
    *   Salario 0 -> tampoco se usa
    *--------------------------------------------------------------------------
    capture drop salario_nom salario trabajo
    if "`enc'" == "enigh" {
        gen double salario_nom = ing_lab_mp
    }
    else {
        capture destring p6b2, replace
        di as txt "ENOE: p6b2 = 999998 (no sabe) y 999999 (no responde), por año"
        gen byte no_sabe  = (p6b2 == 999998)
        gen byte no_resp  = (p6b2 == 999999)
        table year, statistic(sum no_sabe no_resp) nformat(%12.0fc)
        gen double salario_nom = ingocup
        replace salario_nom = . if inlist(p6b2, 999998, 999999)
        drop no_sabe no_resp
        di as txt "ENOE: proporción de ocupados con ingreso 0 (no declaran monto), ponderada"
        gen byte ocup_ing0 = (ingocup == 0) if clase2 == 1
        table year [aw=factor], statistic(mean ocup_ing0) nformat(%5.3f)
        table trimestre year [aw=factor] if year >= 2023, statistic(mean ocup_ing0) nformat(%5.3f)
        drop ocup_ing0
    }
    if "`enc'" == "enoe" {
        count if salario_nom >= 999998 & !missing(salario_nom)
        replace salario_nom = . if salario_nom >= 999998
    }
    count if salario_nom == 0
    di as txt "`ENC': salarios iguales a cero que no se usan = `r(N)'"
    replace salario_nom = . if salario_nom == 0
    gen double salario = ing_mp_real if !missing(salario_nom)     // pesos de enero 2026
    gen byte trabajo = !missing(salario)
    label var salario "Salario mensual (pesos de enero de 2026)"
    label var trabajo "Trabajador: salario válido (1=sí)"
    drop salario_nom

    *--------------------------------------------------------------------------
    * 1.6 Salario por hora y censura en 1 y 5,000
    *--------------------------------------------------------------------------
    capture drop w_hora ln_w cens_bajo cens_alto muestra_w
    gen double w_hora = salario / (horas * 4.33) if horas > 0 & !missing(salario)
    count if !missing(salario) & (horas == 0 | missing(horas))
    di as txt "`ENC': salario válido pero 0 horas (sin salario por hora) = `r(N)'"
    gen byte cens_bajo = (w_hora < 1)
    gen byte cens_alto = (w_hora > 5000 & !missing(w_hora))
    di as txt "`ENC': observaciones censuradas por año"
    table year, statistic(sum cens_bajo cens_alto) statistic(count w_hora) nformat(%12.0fc)
    count if cens_bajo
    di as res "`ENC': salarios por hora < 1 cambiados a 1 = `r(N)'"
    count if cens_alto
    di as res "`ENC': salarios por hora > 5,000 cambiados a 5,000 = `r(N)'"
    replace w_hora = 1    if cens_bajo
    replace w_hora = 5000 if cens_alto
    gen double ln_w = ln(w_hora)
    gen byte muestra_w = !missing(w_hora)
    label var w_hora    "Salario por hora (pesos de enero de 2026)"
    label var ln_w      "Log del salario por hora"
    label var muestra_w "Salario por hora válido (1=sí)"
    label var cens_bajo "Salario por hora censurado en 1"
    label var cens_alto "Salario por hora censurado en 5,000"

    compress
    save "$data/construidas/`enc'_limpia_salarios.dta", replace

    *--------------------------------------------------------------------------
    * 1.7 Box plots del log del salario por hora (ponderados)
    *--------------------------------------------------------------------------
    * Etiquetas del eje x: cada 4 años (ENIGH) o cada 5 (ENOE); las demás en blanco
    levelsof year if muestra_w, local(anios)
    local rl ""
    local i = 0
    foreach a of local anios {
        local ++i
        if ("`enc'" == "enigh" & mod(`a' - 1992, 4) == 0) | ("`enc'" == "enoe" & mod(`a', 5) == 0) {
            local rl `rl' `i' "`a'"
        }
        else {
            local rl `rl' `i' " "
        }
    }

    local opbox over(year, relabel(`rl') label(labsize($gtam))) ///
        box(1, fcolor("$c1%35") lcolor("$c1")) medtype(line) medline(lcolor("$c1") lwidth(medthick)) ///
        ytitle("Log del salario por hora", size($gtam)) b1title("Año", size($gtam)) ///
        ylabel(, labsize($gtam) angle(horizontal) format(%3.0f) grid glcolor(gs14)) ///
        $gfig

    graph box ln_w [aw=factor] if muestra_w, `opbox' ///
        marker(1, msymbol(point) mcolor(gs10)) ///
        note("Nota: caja = percentiles 25 a 75; línea interior = mediana; bigotes = 1.5 veces el rango intercuartil." ///
             "Puntos = valores atípicos. Ponderado con el factor de expansión." ///
             "`fuente'", size(small) span)
    graph export "$out/Fig_1_7_`enc'_boxplot_con_atipicos.png", width(2400) replace

    graph box ln_w [aw=factor] if muestra_w, `opbox' nooutsides ///
        note("Nota: caja = percentiles 25 a 75; línea interior = mediana; bigotes = 1.5 veces el rango intercuartil." ///
             "No se grafican los valores atípicos. Ponderado con el factor de expansión." ///
             "`fuente'", size(small) span)
    graph export "$out/Fig_1_7_`enc'_boxplot_sin_atipicos.png", width(2400) replace

    *--------------------------------------------------------------------------
    * 1.8.a aweight vs fweight (salario por hora, por año)
    *--------------------------------------------------------------------------
    capture noisily summarize w_hora [fw=factor] if muestra_w
    if _rc di as err "`ENC': fweight no se puede usar con el factor original (no es entero)."
    else  di as res "`ENC': el factor original ya es entero; fweight sí se puede usar."
    capture drop factor_int
    gen long factor_int = round(factor)

    tempname pf
    tempfile cmp
    postfile `pf' int year double(media_aw ee_aw n_aw media_fw ee_fw n_fw) using `cmp', replace
    levelsof year if muestra_w, local(anios)
    foreach a of local anios {
        quietly mean w_hora [aw=factor] if muestra_w & year == `a'
        matrix T = r(table)
        local m1 = T[1,1]
        local s1 = T[2,1]
        local n1 = e(N)
        quietly mean w_hora [fw=factor_int] if muestra_w & year == `a'
        matrix T = r(table)
        post `pf' (`a') (`m1') (`s1') (`n1') (T[1,1]) (T[2,1]) (e(N))
    }
    postclose `pf'
    preserve
        use `cmp', clear
        label var year     "Año"
        label var media_aw "Media (aweight)"
        label var ee_aw    "Error estándar (aweight)"
        label var n_aw     "N (aweight)"
        label var media_fw "Media (fweight)"
        label var ee_fw    "Error estándar (fweight)"
        label var n_fw     "N (fweight)"
        list, noobs abbreviate(12) separator(0)
        * Formato largo: un renglón por año y tipo de peso (encabezado en dos niveles)
        rename (media_aw ee_aw n_aw media_fw ee_fw n_fw) (media1 ee1 n1 media2 ee2 n2)
        reshape long media ee n, i(year) j(metodo)
        label define lmet 1 "aweight" 2 "fweight", replace
        label values metodo lmet
        label var media "Media"
        label var ee    "Error estándar"
        label var n     "N"
        table (year) (metodo var), statistic(mean media ee n) nototals
        estilo_cuadro
        collect style header metodo, title(hide)
        collect style cell var[media], nformat(%9.2f)
        collect style cell var[ee], nformat(%9.4f)
        collect style cell var[n], nformat(%15.0fc)
        collect label dim year "Año", modify
        collect title "Cuadro `nc'. `ENC': salario por hora promedio con aweight y fweight (pesos de enero de 2026)"
        exporta_cuadro, archivo("$out/Cuadro`nc'_`enc'_aweight_fweight") ///
            nota("Nota: fweight usa el factor de expansión redondeado a entero. N: observaciones de la muestra (aweight) o población representada (fweight).") ///
            fuente("`fuente'")
    restore

    *--------------------------------------------------------------------------
    * 1.8.b y 1.9 Medias ponderadas por año y grupo (aweight)
    *   Salario y salario por hora: solo quienes tienen salario por hora válido
    *   Proporción de trabajadores: toda la población de 25 a 65 años
    *--------------------------------------------------------------------------
    preserve
        collapse (mean) w_hora salario [aw=factor] if muestra_w, by(year grupo)
        tempfile g1
        save `g1'
    restore
    preserve
        collapse (mean) w_hora salario [aw=factor] if muestra_w, by(year)
        gen byte grupo = 9
        append using `g1'
        tempfile g2
        save `g2'
    restore
    preserve
        collapse (mean) trabajo [aw=factor], by(year grupo)
        tempfile g3
        save `g3'
    restore
    preserve
        collapse (mean) trabajo [aw=factor], by(year)
        gen byte grupo = 9
        append using `g3'
        merge 1:1 year grupo using `g2', nogenerate
        replace trabajo = 100 * trabajo
        label values grupo lgrupo
        gen byte sexo_g = cond(grupo <= 4, 1, cond(grupo <= 8, 2, 3))
        gen byte sub_g  = cond(grupo == 9, 5, mod(grupo - 1, 4) + 1)
        label define lsexo 1 "Hombres" 2 "Mujeres" 3 "Total", replace
        label define lsub  1 "25-45, sin prepa" 2 "25-45, prepa o más" ///
                           3 "46-65, sin prepa" 4 "46-65, prepa o más" 5 "Todos", replace
        label values sexo_g lsexo
        label values sub_g lsub
        * Dimensiones para el encabezado de los cuadros: sexo > edad > escolaridad
        gen byte edad_c = cond(grupo == 9, 3, cond(inlist(sub_g, 1, 2), 1, 2))
        gen byte educ_c = cond(grupo == 9, 3, cond(inlist(sub_g, 1, 3), 1, 2))
        label define lsexoc 1 "Hombres" 2 "Mujeres" 3 " ", replace
        label define ledadc 1 "25-45 años" 2 "46-65 años" 3 "Total", replace
        label define leducc 1 "Sin prepa" 2 "Prepa o más" 3 " ", replace
        label values edad_c ledadc
        label values educ_c leducc
        label var w_hora  "Salario por hora"
        label var salario "Salario mensual"
        label var trabajo "Trabajadores (%)"
        sort grupo year
        save "$data/construidas/`enc'_resultados_grupos.dta", replace

        * Cuadros (años en renglones; sexo y grupo en columnas)
        local k = 0
        foreach v in w_hora salario trabajo {
            local ++k
            local n = `nc' + `k'
            if "`v'" == "w_hora"  local tit "salario por hora promedio por grupo (pesos de enero de 2026)"
            if "`v'" == "salario" local tit "salario mensual promedio por grupo (pesos de enero de 2026)"
            if "`v'" == "trabajo" local tit "porcentaje de trabajadores (con salario válido) por grupo"
            if "`v'" == "w_hora"  local fmt "%9.1f"
            if "`v'" == "salario" local fmt "%12.0fc"
            if "`v'" == "trabajo" local fmt "%9.1f"
            label values sexo_g lsexoc
            table (year) (sexo_g edad_c educ_c), statistic(mean `v') nototals nformat(`fmt')
            estilo_cuadro, size(8)
            collect style header sexo_g edad_c educ_c, title(hide)
            capture noisily collect style header sexo_g[3] educ_c[3], level(hide)
            collect label dim year "Año", modify
            collect title "Cuadro `n'. `ENC': `tit'"
            if "`v'" != "trabajo" local nt "Nota: medias ponderadas con el factor de expansión (aweight); personas de 25 a 65 años con salario por hora válido. Prepa o más: preparatoria completa (12 años de escolaridad o más)."
            else local nt "Nota: medias ponderadas con el factor de expansión (aweight); población de 25 a 65 años. Trabajador: salario positivo y declarado. Prepa o más: preparatoria completa (12 años de escolaridad o más)."
            exporta_cuadro, archivo("$out/Cuadro`n'_`enc'_`v'_grupos") nota("`nt'") fuente("`fuente'")
        }
        label values sexo_g lsexo

        * Gráficas por grupo (inciso 1.8)
        graf_grupos w_hora, ytitulo("Pesos por hora (enero de 2026)") ///
            archivo("$out/Fig_1_8_`enc'_salario_hora_grupos.png") xlab(`xl') formato("%9.0f") ///
            nota("Nota: medias ponderadas con el factor de expansión (aweight); personas de 25 a 65 años" ///
                 "con salario por hora válido. Prepa o más: preparatoria completa (12 años de escolaridad o más)." ///
                 "`fuente'")
        graf_grupos salario, ytitulo("Pesos al mes (enero de 2026)") ///
            archivo("$out/Fig_1_8_`enc'_salario_mensual_grupos.png") xlab(`xl') ///
            nota("Nota: medias ponderadas con el factor de expansión (aweight); personas de 25 a 65 años" ///
                 "con salario por hora válido. Prepa o más: preparatoria completa (12 años de escolaridad o más)." ///
                 "`fuente'")
    restore
}


/*==============================================================================
  INCISO 1.11 — ENIGH: ingreso corriente per cápita del hogar (INEGI) y
  líneas de pobreza por ingresos (CONEVAL)
  Ingreso per cápita = ingreso corriente trimestral del hogar / 3 / integrantes
==============================================================================*/
foreach y of global enigh_years {
    if strpos("${con`y'}", ".dbf") {
        import dbase using "$enigh/`y'/${con`y'}", clear case(lower)
    }
    else {
        use "$enigh/`y'/${con`y'}", clear
        rename *, lower
    }
    capture confirm variable folioviv
    if _rc == 0 {
        capture tostring folioviv foliohog, replace format(%15.0f)
        gen str30 folio = folioviv + "_" + foliohog
    }
    else {
        capture tostring folio, replace format(%15.0f)
    }
    capture rename hog        factor
    capture rename factor_hog factor
    capture rename estrato    tam_loc
    capture rename ing_cor    ingcor
    capture rename tot_integ  tam_hog
    destring factor tam_loc ingcor tam_hog, replace
    if `y' == 1992 replace ingcor = ingcor / 1000             // viejos pesos
    gen byte rural = (tam_loc == 4)
    gen int year = `y'
    keep year folio factor rural ingcor tam_hog
    tempfile h`y'
    save `h`y''
}
clear
foreach y of global enigh_years {
    append using `h`y''
}
count if tam_hog == 0 | missing(tam_hog)
drop if tam_hog == 0 | missing(tam_hog)

* Pesos reales y líneas de pobreza (agosto de cada año)
merge m:1 year using `inpc_enigh', keep(master match) nogenerate
preserve
    use "$data/lineas_pobreza/lineas_pobreza_mensual_1992_2026.dta", clear
    keep if mes == 8
    rename anio year
    keep year lpi_rural lpi_urbano lpei_rural lpei_urbano
    tempfile lp
    save `lp'
restore
merge m:1 year using `lp', keep(master match) nogenerate

gen double ingpc_nom = ingcor / 3 / tam_hog                    // mensual por persona
gen double lpi_nom   = cond(rural == 1, lpi_rural,  lpi_urbano)
gen double lpei_nom  = cond(rural == 1, lpei_rural, lpei_urbano)
gen byte pobre_ing     = (ingpc_nom < lpi_nom)
gen byte pobre_ext_ing = (ingpc_nom < lpei_nom)
gen double defl   = inpc_ene26 / inpc_ago
gen double ingpc  = ingpc_nom  * defl
gen double lpi_u  = lpi_urbano * defl
gen double lpi_r  = lpi_rural  * defl
gen double w_pers = factor * tam_hog                           // personas representadas
label var ingpc "Ingreso corriente per cápita mensual (pesos ene-2026)"
save "$data/construidas/enigh_ingpc_hogares_1992_2024.dta", replace

collapse (mean) media = ingpc pobre_ing pobre_ext_ing lpi_u lpi_r ///
         (median) mediana = ingpc [pw=w_pers], by(year)
replace pobre_ing     = 100 * pobre_ing
replace pobre_ext_ing = 100 * pobre_ext_ing
label var media         "Media"
label var mediana       "Mediana"
label var pobre_ing     "Pobreza por ingresos (%)"
label var pobre_ext_ing "Pobreza extrema por ingresos (%)"
label var lpi_u         "Línea de pobreza urbana"
label var lpi_r         "Línea de pobreza rural"
list, noobs abbreviate(14) separator(0)

twoway (connected media   year, lcolor("$c1") mcolor("$c1") msymbol(O)  msize(small) lwidth(medthick)) ///
       (connected mediana year, lcolor("$c1") mcolor("$c1") msymbol(Oh) msize(small) lwidth(medthick) lpattern(dash)) ///
       (line lpi_u year, lcolor("$c4") lpattern(shortdash)    lwidth(medthick)) ///
       (line lpi_r year, lcolor("$c3") lpattern(longdash_dot) lwidth(medthick)), ///
    ytitle("Pesos mensuales por persona" "(enero de 2026)", size($gtam)) xtitle("Año", size($gtam)) ///
    xlabel(1992(4)2024, labsize($gtam) nogrid) ///
    ylabel(, labsize($gtam) angle(horizontal) format(%9.0fc) grid glcolor(gs14)) ///
    legend(order(1 "Media" 2 "Mediana" 3 "Línea de pobreza urbana" 4 "Línea de pobreza rural") ///
           cols(2) size(small) position(6) region(lcolor(white))) ///
    note("Nota: ingreso corriente trimestral del hogar entre 3 y entre el número de integrantes." ///
         "Pesos de enero de 2026; media y mediana ponderadas por personas. Líneas de pobreza de CONEVAL (agosto)." ///
         "Fuente: elaboración propia con datos de la ENIGH (INEGI), 1992-2024, y CONEVAL.", size(small) span) ///
    $gfig
graph export "$out/Fig_1_11_enigh_ingreso_per_capita.png", width(2400) replace

log close
