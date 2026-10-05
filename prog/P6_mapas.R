# ==============================================================================
#  PROBLEMA 6 (inciso 6.4): mapas de pobreza laboral por entidad en R
#  Pobreza laboral (programa oficial INEGI/CONEVAL replicado con la ENOE),
#  segundo trimestre de 2006, 2016 y 2026. Insumo: CSV de prog/P6_imputacion.do
# ==============================================================================
user_lib <- file.path(Sys.getenv("USERPROFILE"), "Documents", "R", "win-library", "4.6")
.libPaths(c(user_lib, .libPaths()))
suppressPackageStartupMessages({ library(sf); library(ggplot2); library(dplyr); library(patchwork) })

root <- "C:/Users/lcastillo/Music/TAREA 2"
out  <- file.path(root, "papers/output")
tema <- theme_void(base_family = "serif", base_size = 11) +
  theme(plot.title = element_text(hjust = 0.5, size = 12), legend.position = "bottom",
        legend.title = element_text(size = 8.5), legend.text = element_text(size = 7.5),
        legend.key.width = unit(1.4, "cm"), legend.key.height = unit(0.3, "cm"),
        plot.caption = element_text(hjust = 0, size = 8.5), plot.caption.position = "plot",
        plot.background = element_rect(fill = "white", colour = NA))

ent <- st_read(file.path(root, "data/mapas/entidades.shp"), quiet = TRUE)
pl  <- read.csv(file.path(root, "data/construidas/p6_pl_entidad_mapas.csv"))
ent$ent <- as.integer(ent$CVE_ENT)
ent <- left_join(ent, pl, by = "ent")
lims <- range(c(ent$pl2006, ent$pl2016, ent$pl2026), na.rm = TRUE)

mapa <- function(v, titulo) {
  ggplot(ent) + geom_sf(aes(fill = .data[[v]]), colour = "white", linewidth = 0.1) +
    scale_fill_gradient(low = "#fbe6d4", high = "#8e2432", limits = lims,
                        name = "Población en pobreza laboral (%)") +
    labs(title = titulo) + tema
}
g <- (mapa("pl2006", "2006") | mapa("pl2016", "2016") | mapa("pl2026", "2026")) +
  plot_layout(guides = "collect") &
  theme(legend.position = "bottom")
g <- g + plot_annotation(caption = paste0(
  "Nota: porcentaje de la población con ingreso laboral per cápita menor a la línea de pobreza extrema por ingresos;\n",
  "segundo trimestre de cada año; misma escala de color en los tres mapas.\n",
  "Fuente: elaboración propia con datos de la ENOE (INEGI) y líneas de pobreza de CONEVAL; marco geoestadístico de INEGI."),
  theme = tema)
ggsave(file.path(out, "Fig_6_4_R_mapas_pobreza_laboral.png"), g, width = 6.5, height = 3.1, dpi = 370, bg = "white")
cat("Mapa de pobreza laboral guardado\n")
