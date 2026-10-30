library(dplyr, warn.conflicts=FALSE)
library(readr)
library(purrr)
library(stringr)
library(tidyr)


# Rutas (se definen una vez y se usan en todo el script)
data_dir <- "datos"
dir_zip <- file.path(data_dir, "miteco_zip")
dir_csv <- file.path(data_dir, "miteco_csv")
dir.create(dir_zip, showWarnings=FALSE, recursive=TRUE)
dir.create(dir_csv, showWarnings=FALSE, recursive=TRUE)
stopifnot(dir.exists(dir_zip), dir.exists(dir_csv))

base_urls <- list(
  "2022" = "https://www.miteco.gob.es/es/calidad-y-evaluacion-ambiental/temas/atmosfera-y-calidad-del-aire/evaluacion-y-datos-de-calidad-del-aire/datos/datos-oficiales-2022.html",
  "2023" = "https://www.miteco.gob.es/es/calidad-y-evaluacion-ambiental/temas/atmosfera-y-calidad-del-aire/evaluacion-y-datos-de-calidad-del-aire/datos/datos-oficiales-2023.html"
)


get_zip_links <- function(url) {
  page <- tryCatch(xml2::read_html(url), error=function(e) {
    warning("No se pudo leer: ", url); NULL
  })
  if (is.null(page)) return(character())
  hrefs <- rvest::html_nodes(page, "a") %>% rvest::html_attr("href")
  hrefs <- hrefs[grepl("\\.zip$", hrefs, ignore.case=TRUE)]
  hrefs <- ifelse(grepl("^http", hrefs), hrefs, paste0("https://www.miteco.gob.es", hrefs))
  unique(hrefs)
}


# 1. Descargar solo los ZIP de datos diarios
all_zips <- unlist(map(base_urls, get_zip_links))
all_zips <- all_zips[str_detect(URLdecode(all_zips), regex("diarios", ignore_case = TRUE))]
print(URLdecode(all_zips))

for (z in all_zips) {
  nombre <- URLdecode(basename(z))      # "Datos diarios 202X.zip"
  url    <- URLencode(URLdecode(z))     # normaliza tildes y espacios
  fname  <- file.path(dir_zip, nombre)
  if (!file.exists(fname)) {
    cat("Descargando", fname, "\n")
    download.file(url, destfile=fname, mode="wb", quiet=TRUE)
  }
}
print(list.files(dir_zip))


# 2. Extraer solo los CSV diarios del elemento/compuesto a elegir
patron <- "As_DD_.*\\.csv$"

zip_files <- dir(dir_zip, pattern="\\.zip$", full.names=TRUE)
walk(zip_files, function(z) {
  contenido <- unzip(z, list=TRUE)$Name
  buscados  <- contenido[str_detect(contenido, regex(patron, ignore_case=TRUE))]
  if (length(buscados) > 0) unzip(z, files=buscados, exdir=dir_csv)
})


# 3. Leer
csv_files <- dir(dir_csv, pattern = patron, full.names=TRUE, recursive=TRUE)
#print(basename(csv_files))
stopifnot("No hay CSV diario del elemento/compuesto: revisa descarga y extracción" = length(csv_files) > 0)

leer <- function(f) {
  read_delim(f, delim = ";", locale = locale(encoding="ISO-8859-1"),
             col_types = cols(.default="c"), show_col_types=FALSE)
}


# 3a. Texto tal cual viene en los CSV (todo character)
raw_chr <- map_dfr(csv_files, leer)

# 3b. Dataset final: se convierte directamente en formato largo
diario_as <- raw_chr %>%
  pivot_longer(matches("^D\\d{2}$"), names_to="dia", values_to="valor") %>%
  transmute(provincia=PROVINCIA, municipio=MUNICIPIO, estacion=ESTACION,
            punto_muestreo=PUNTO_MUESTREO,
            fecha=as.Date(sprintf("%s-%02d-%s", ANNO, as.integer(MES), str_sub(dia, 2)),
                          format="%Y-%m-%d"),
            valor) %>%
  filter(!is.na(fecha)) %>%
  mutate(valor=parse_double(str_trim(valor), locale=locale(decimal_mark=".")),
         across(c(provincia, municipio, estacion, punto_muestreo), factor))


# analisis inicial 
anio <- format(diario_as$fecha, "%Y")
ausente <- is.na(diario_as$valor)

tabla <- data.frame(
  n = as.vector(table(anio)),
  observados = as.vector(tapply(!ausente, anio, sum)),
  ausentes = as.vector(tapply(ausente, anio, sum)),
  porcentaje_NA = round(100 * as.vector(tapply(ausente, anio, mean)), 2),
  row.names = names(table(anio))
)
print(tabla)
