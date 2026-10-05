# ==============================================================================
#  PROBLEMA 2 (incisos 2.8 y 2.9): mapas en R
#  Cambio porcentual del empleo y del salario promedio real (IMSS) entre
#  julio del año base (2006 y 2016) y julio de 2026.
#   - 2.8: entidades federativas
#   - 2.9: municipios con al menos 10,000 puestos de trabajo en el año base
#  Insumos: CSV que genera prog/P2_IMSS.do y shapefiles de INEGI en data/mapas.
# ==============================================================================
user_lib <- file.path(Sys.getenv("USERPROFILE"), "Documents", "R", "win-library", "4.6")
.libPaths(c(user_lib, .libPaths()))
suppressPackageStartupMessages({
  library(sf); library(ggplot2); library(dplyr); library(patchwork)
})

root <- "C:/Users/lcastillo/Music/TAREA 2"
out  <- file.path(root, "papers/output")
fuente <- "Fuente: elaboración propia con datos del IMSS (puestos de trabajo afiliados) y marco geoestadístico de INEGI."

# Estilo común (estilo A: Times New Roman, fondo blanco, leyenda abajo)
tema <- theme_void(base_family = "serif", base_size = 11) +
  theme(plot.title   = element_text(hjust = 0.5, size = 12),
        legend.position = "bottom",
        legend.title = element_text(size = 8.5),
        legend.text  = element_text(size = 7.5),
        legend.key.size = unit(0.32, "cm"),
        plot.caption = element_text(hjust = 0, size = 8.5),
        plot.caption.position = "plot",
        plot.background = element_rect(fill = "white", colour = NA))

# Clasificación en quintiles (igual que los mapas de Stata)
quintiles <- function(x) {
  q <- unique(quantile(x, probs = seq(0, 1, 0.2), na.rm = TRUE))
  cut(x, breaks = q, include.lowest = TRUE, dig.lab = 4,
      labels = sprintf("%.1f a %.1f", head(q, -1), q[-1]))
}
panel <- function(datos, var, titulo, paleta, bordes = NULL) {
  datos$clase <- quintiles(datos[[var]])
  g <- ggplot() +
    geom_sf(data = datos, fill = "grey88", colour = NA) +                 # fondo: unidades sin dato en gris
    geom_sf(data = datos[!is.na(datos$clase), ], aes(fill = clase), colour = "white", linewidth = 0.05) +
    scale_fill_brewer(palette = paleta, name = "Cambio (%)") +
    guides(fill = guide_legend(nrow = 2, byrow = TRUE, title.position = "top")) +
    labs(title = titulo) + tema
  if (!is.null(bordes)) g <- g + geom_sf(data = bordes, fill = NA, colour = "black", linewidth = 0.35)
  g
}

# ------------------------------------------------------------------ 2.8 entidades
ent  <- st_read(file.path(root, "data/mapas/entidades.shp"), quiet = TRUE)
cent <- read.csv(file.path(root, "data/construidas/imss_cambios_entidad.csv"))
ent$cve_entidad <- as.integer(ent$CVE_ENT)
ent <- left_join(ent, cent, by = "cve_entidad")

for (b in c(2006, 2016)) {
  g <- panel(ent, paste0("demp_", b), "Empleo", "Blues") +
       panel(ent, paste0("dsal_", b), "Salario promedio real", "Oranges") +
       plot_annotation(caption = paste0(
         "Nota: cambio porcentual entre julio de ", b, " y julio de 2026; quintiles. Salario mensual real en pesos\nde enero de 2026.\n",
         fuente), theme = tema)
  ggsave(file.path(out, sprintf("Fig_2_8_R_entidades_%d_2026.png", b)), g,
         width = 6.5, height = 3.9, dpi = 370, bg = "white")
}

# ------------------------------------------------------------------ 2.9 municipios
mun  <- st_read(file.path(root, "data/mapas/municipios_imss.shp"), quiet = TRUE)
cmun <- read.csv(file.path(root, "data/construidas/imss_cambios_municipio.csv"),
                 colClasses = c(cvegeo = "character"))
cmun$cvegeo <- sprintf("%05d", as.integer(cmun$cvegeo))
mun <- left_join(mun, cmun, by = c("CVEGEO" = "cvegeo"))
# La CDMX viene en el IMSS sin desglose por alcaldía (clave 09000): su valor se asigna a todas sus alcaldías
agreg <- cmun[substr(cmun$cvegeo, 3, 5) == "000", ]
cols  <- setdiff(names(cmun), "cvegeo")
for (i in seq_len(nrow(agreg))) {
  idx <- substr(mun$CVEGEO, 1, 2) == substr(agreg$cvegeo[i], 1, 2)
  for (v in cols) mun[[v]][idx] <- agreg[[v]][i]
}
zlfn <- mun %>% filter(!is.na(zlfn) & zlfn == 1) %>% summarise()

for (b in c(2006, 2016)) {
  n <- sum(cmun[[paste0("muestra_", b)]] == 1, na.rm = TRUE)
  g <- panel(mun, paste0("demp_", b), "Empleo", "Blues", bordes = zlfn) +
       panel(mun, paste0("dsal_", b), "Salario promedio real", "Oranges", bordes = zlfn) +
       plot_annotation(caption = paste0(
         "Nota: cambio porcentual entre julio de ", b, " y julio de 2026 en los ", n,
         " municipios con al menos 10,000 puestos de trabajo\nen julio de ", b, "; quintiles. ",
         "En gris, municipios fuera de la muestra; contorno negro: Zona Libre de la Frontera Norte.\n",
         "La Ciudad de México se muestra como una unidad.\n",
         fuente), theme = tema)
  ggsave(file.path(out, sprintf("Fig_2_9_R_municipios_%d_2026.png", b)), g,
         width = 6.5, height = 4.1, dpi = 370, bg = "white")
}
cat("Mapas de R guardados en", out, "\n")
