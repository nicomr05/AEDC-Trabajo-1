library(dplyr, warn.conflicts = FALSE)
library(readr)
library(purrr)
library(stringr)
library(tidyr)


# Rutas (se definen una vez y se usan en todo el script)
data_dir <- "datos"
dir_zip <- file.path(data_dir, "miteco_zip")
dir_csv <- file.path(data_dir, "miteco_csv")
dir.create(dir_zip, showWarnings = FALSE, recursive = TRUE)
dir.create(dir_csv, showWarnings = FALSE, recursive = TRUE)
stopifnot(dir.exists(dir_zip), dir.exists(dir_csv))

base_urls <- list(
  "2022" = "https://www.miteco.gob.es/es/calidad-y-evaluacion-ambiental/temas/atmosfera-y-calidad-del-aire/evaluacion-y-datos-de-calidad-del-aire/datos/datos-oficiales-2022.html",
  "2023" = "https://www.miteco.gob.es/es/calidad-y-evaluacion-ambiental/temas/atmosfera-y-calidad-del-aire/evaluacion-y-datos-de-calidad-del-aire/datos/datos-oficiales-2023.html"
)


get_zip_links <- function(url) {
  page <- tryCatch(xml2::read_html(url), error = function(e) {
    warning("No se pudo leer: ", url)
    NULL
  })
  if (is.null(page)) {
    return(character())
  }
  hrefs <- rvest::html_nodes(page, "a") %>% rvest::html_attr("href")
  hrefs <- hrefs[grepl("\\.zip$", hrefs, ignore.case = TRUE)]
  hrefs <- ifelse(grepl("^http", hrefs), hrefs, paste0("https://www.miteco.gob.es", hrefs))
  unique(hrefs)
}


# 1. Descargar solo los ZIP de datos diarios (solo los años que falten)
zips_locales <- dir(dir_zip, pattern = "\\.zip$", ignore.case = TRUE)
anios_pendientes <- names(base_urls)[
  !map_lgl(names(base_urls), ~ any(str_detect(zips_locales, .x)))
]

if (length(anios_pendientes) > 0) {
  all_zips <- unlist(map(base_urls[anios_pendientes], get_zip_links))
  all_zips <- all_zips[str_detect(URLdecode(all_zips), regex("diarios", ignore_case = TRUE))]

  for (z in all_zips) {
    nombre <- URLdecode(basename(z))
    url <- URLencode(URLdecode(z))
    fname <- file.path(dir_zip, nombre)
    if (!file.exists(fname)) {
      cat("Descargando", fname, "\n")
      tmp <- paste0(fname, ".part")
      download.file(url, destfile = tmp, mode = "wb", quiet = TRUE)
      file.rename(tmp, fname) # solo queda el .zip si la descarga terminó bien
    }
  }
}


# 2. Extraer solo los CSV diarios que aún no estén extraídos
patron <- "As_DD_.*\\.csv$"

zip_files <- dir(dir_zip, pattern = "\\.zip$", full.names = TRUE)
walk(zip_files, function(z) {
  contenido <- unzip(z, list = TRUE)$Name
  buscados <- contenido[str_detect(contenido, regex(patron, ignore_case = TRUE))]
  existentes <- dir(dir_csv, recursive = TRUE)
  pendientes <- buscados[!(basename(buscados) %in% basename(existentes))]
  if (length(pendientes) > 0) unzip(z, files = pendientes, exdir = dir_csv)
})


# 3. Leer
csv_files <- dir(dir_csv, pattern = patron, full.names = TRUE, recursive = TRUE)
# print(basename(csv_files))
stopifnot("No hay CSV diario del elemento/compuesto: revisa descarga y extracción" = length(csv_files) > 0)

leer <- function(f) {
  read_delim(f,
    delim = ";", locale = locale(encoding = "ISO-8859-1"),
    col_types = cols(.default = "c"), show_col_types = FALSE
  )
}


# 3a. Texto tal cual viene en los CSV (todo character)
raw_chr <- map_dfr(csv_files, leer)

# 3b. Dataset final: se convierte directamente en formato largo
diario_as <- raw_chr %>%
  pivot_longer(matches("^D\\d{2}$"), names_to = "dia", values_to = "valor") %>%
  transmute(
    provincia = PROVINCIA, municipio = MUNICIPIO, estacion = ESTACION,
    punto_muestreo = PUNTO_MUESTREO,
    fecha = as.Date(sprintf("%s-%02d-%s", ANNO, as.integer(MES), str_sub(dia, 2)),
      format = "%Y-%m-%d"
    ),
    valor
  ) %>%
  filter(!is.na(fecha)) %>%
  mutate(
    valor = parse_double(str_trim(valor), locale = locale(decimal_mark = ".")),
    across(c(provincia, municipio, estacion, punto_muestreo), factor)
  )

# 4. Incorporar metadatos de las estaciones
library(readxl)

archivos_meta <- c(
  "2022" = "datos/miteco_meta/Metainformacion2022.xlsx",
  "2023" = "datos/miteco_meta/Metainformacion2023_19022025.xlsx"
)

# Convertir fechas del Excel a Date
convertir_fecha <- function(x) {
  x <- trimws(as.character(x))
  x[x == ""] <- NA_character_

  fecha <- as.Date(x, format = "%d/%m/%Y")

  i <- is.na(fecha) & !is.na(x)
  fecha[i] <- as.Date(substr(x[i], 1, 10),
    format = "%Y-%m-%d"
  )

  i <- is.na(fecha) & grepl("^[0-9]{4,5}$", x)
  fecha[i] <- as.Date(as.numeric(x[i]),
    origin = "1899-12-30"
  )

  fecha
}

# Leer la hoja de estaciones correspondiente a cada año
leer_estaciones <- function(anio) {
  meta <- read_excel(
    archivos_meta[as.character(anio)],
    sheet = paste0("Estaciones", anio),
    col_types = "text"
  )

  names(meta) <- toupper(trimws(names(meta)))

  meta %>%
    filter(!is.na(COD_LOCAL)) %>%
    transmute(
      anio = as.integer(anio),
      cod_local = sprintf("%08d", as.integer(COD_LOCAL)),
      nombre_estacion = NOMBRE,
      nombre_ccaa = N_CCAA,
      nombre_prov = N_PROVINCIA,
      nombre_mun = N_MUNICIPIO,
      tipo_estacion = TIPO_ESTACION,
      tipo_area = TIPO_AREA,
      zona = ZONA,
      fecha_inicio = convertir_fecha(FECHA_INI),
      fecha_fin = convertir_fecha(FECHA_FIN)
    )
}

# Juntar metadatos de 2022 y 2023
meta_estaciones <- bind_rows(
  leer_estaciones(2022),
  leer_estaciones(2023)
)

# Comprobar que cada estación tiene un solo registro por año
stopifnot(
  !anyDuplicated(meta_estaciones[c("anio", "cod_local")])
)

# Crear las claves en los datos diarios
diario_as <- diario_as %>%
  mutate(
    anio = as.integer(format(fecha, "%Y")),
    cod_local = sprintf(
      "%02d%03d%03d",
      as.integer(as.character(provincia)),
      as.integer(as.character(municipio)),
      as.integer(as.character(estacion))
    )
  )

# Relacionar cada observación con sus metadatos del mismo año
n_original <- nrow(diario_as)

diario_as <- diario_as %>%
  left_join(
    meta_estaciones,
    by = c("anio", "cod_local"),
    relationship = "many-to-one"
  )

stopifnot(nrow(diario_as) == n_original)

# Número de registros
#nrow(diario_as)

# Comprobar cuántas observaciones tienen metadatos
#table(diario_as$anio, is.na(diario_as$nombre_estacion))

# Ver las estaciones con su información
#print(diario_as)

stopifnot(nrow(diario_as) == n_original)

diario_as <- diario_as %>%
  select(-anio, -cod_local) %>%
  mutate(
    across(
      c(tipo_estacion, tipo_area, zona),
      factor
    )
  )

# Eliminamos las filas para las cuales su fecha es mayor que la fecha_fin de la estación correspondiente
diario_as <- diario_as %>%
  filter(
    is.na(fecha_fin) |
      fecha <= fecha_fin |
      fecha_fin < as.Date("2022-01-01") |
      fecha_fin > as.Date("2023-12-31")
  )
