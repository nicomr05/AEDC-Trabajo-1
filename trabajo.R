#' ---
#' title: \textbf{Trabajo Datos Faltantes}
#' subtitle: Tema 1, MITECO
#' author: [S. E. Elizabet, M. R. Nicolás]
#' date: \today
#' toc: true
#' toc_depth: 2
#' fontsize: 12pt
#' number_sections: true
#' fig_width: 7
#' fig_height: 6
#' fig_caption: true
#' df_print: tibble  # print.data.frame(default)/kable/tibble
#' highlight: tango
#' latex_engine: pdflatex
#' abstract: Aquí definimos el trabajo realizado en un pequeño resumen.
#' ---

#' ```{r setup, include=FALSE}
#' knitr::opts_chunk$set(echo = FALSE)
#' ```

#' \newpage

#' # Primeros pasos
#' Al cargar los datos y realizar una primera ojeada, vemos que el tipo de las
#' variables de interés `DNN` es `str`, por lo que los transformaremos a `numeric`.

setwd("/home/nicomr/Escritorio/GCED/Q7/AEDC/Practica/Trabajo/")

#' ```{r, results='hide'}
#' # carga de datos
#' source("miteco.R")
#' datos <- diario_c6h6
#' 
#' # resúmenes de los datos
#' str(datos)
#' summary(datos)
#' ```

#' ## Diccionario de variables de `diario_c6h6`
#'
#' Algunas columnas vienen del MITECO y otras se crean en el script.
#'
#' | **Variable** | **Descripción** |
#' |:---|:---|
#' | `provincia` | Código INE de la provincia (2 dígitos, p. ej. 15 = A Coruña, 28 = Madrid). |
#' | `municipio` | Código INE del municipio dentro de la provincia (3 dígitos). Para identificarlo del todo hay que combinarlo con `provincia`. |
#' | `estacion` | Número de la estación de medición dentro del municipio. Una estación es una caseta con varios equipos. |
#' | `magnitud` | Código numérico del contaminante. Para el benceno debería ser **30** (comprobar con `distinct(diario_c6h6, magnitud)` y con la documentación del MITECO). |
#' | `punto_muestreo` | Identificador del equipo concreto. Suele tener la forma `códigoEstación_magnitud_técnica`: provincia + municipio + estación, el contaminante y un código del método de análisis. Una estación puede tener varios puntos. |
#' | `Variables DXX` | Día de la medición, del `D01` al `D31`. |
#' | `valor` | Concentración media diaria del benceno. Lo habitual es µg/m³ (confirmar la unidad en la documentación del MITECO). Los `NA` son días sin dato válido. |
#' | `fichero` | Nombre del CSV de origen (`C6H6_DD_2022.csv`, etc.). Campo propio, sirve para saber de qué año viene cada fila. |
#'
#' **Notas**
#'
#' - `provincia`, `municipio` y `estacion` son solo códigos; para obtener nombres y coordenadas hace falta un catálogo aparte.
#' - La clave de una serie temporal es `punto_muestreo` (o `provincia` + `municipio` + `estacion` + `magnitud`).
#' - El benceno diario no lleva indicador de validación.

