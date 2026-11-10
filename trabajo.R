#' ---
#' title: \textbf{Trabajo Datos Faltantes}
#' subtitle: Tema 1, MITECO
#' author: [S. E. Elizabet, M. R. Nicolás]
#' date: \today
#' fontsize: 11pt
#' fig_width: \textwidth
#' fig_height: 6
#' fig_caption: true
#' df_print: tibble  # print.data.frame(default)/kable/tibble
#' highlight: tango
#' header-includes:
#' - \usepackage{fvextra}
#' - \DefineVerbatimEnvironment{Highlighting}{Verbatim}{breaklines,commandchars=\\\{\}}
#' - \RecustomVerbatimEnvironment{verbatim}{Verbatim}{breaklines}
#' output:
#'   pdf_document:
#'     latex_engine: pdflatex
#'     number_sections: yes
#'     toc: yes
#'     toc_depth: 2
#' ---
#'
#' ```{r setup, include=FALSE}
#' knitr::opts_chunk$set(
#'    echo=FALSE,
#'    tidy=TRUE,
#'    tidy.opts=list(width.cutoff=75),
#'    knit=FALSE
#' )
#' knitr::spin(
#'    "trabajo.R",
#'    format = "Rmd",
#'    knit = FALSE
#' )
#' ```

library(mice, warn.conflicts = FALSE)
library(naniar, warn.conflicts = FALSE)

source("miteco.R")

#'
#' \newpage
#'
#' # Introducción y objetivo
#'
#' Los mecanismos de identificación del tipo de datos faltantes son herramientas
#' que resultan muy útiles en muchos trabajos reales en los que se aplica la
#' estadística.
#' El objetivo de este trabajo es hacer tanto una exploración de los datos como
#' un análisis de datos faltantes, indicando si el mecanismo de ausencia es MCAR,
#' MAR o MNAR.
#'
#'
#' # Datos
#'
#' Los datos que utilizaremos en este trabajo contienen información sobre mediciones
#' para evaluar la calidad del aire en diferentes puntos de muestreo. En nuestro
#' caso, utilizaremos únicamente las mediciones de arsénico (As) del 2022 y 2023.
#' Estos datos son públicos y se pueden obtener en la sección
#' [**Datos de Calidad del Aire**](https://www.miteco.gob.es/es/calidad-y-evaluacion-ambiental/temas/atmosfera-y-calidad-del-aire/evaluacion-y-datos-de-calidad-del-aire/datos.html)
#' en la página web del MITECO.
#'
#' Al cargar los datos por primera vez pudimos observar que los datos contenían
#' 38 variables de tipo `chr` para identificar cada una de las mediciones, de las
#' cuales las 31 variables llamadas `DXX` corresponden a cada uno de los días del
#' mes.
#' Debido a esto, la variable `D31` tendrá un nulo en los meses que tengan 30 días.
#' De manera similar, en febrero habrá nulos en los días 30 y 31, además de el 29
#' en años bisiestos.
#' Es decir, que todas las ausencias son reales, pero estas últimas que tratamos
#' son sistemáticas, por la forma de guardar los datos. El resto de ausencias son
#' intrínsecas a los datos.
#'
#' Dado que la falta de estos valores se da únicamente por la forma de guardar los
#' datos, decidimos convertir las 31 variables en una columna `valor` (de tipo
#' `numeric`) y crear a su vez una columna `fecha` (de tipo `Date`) a partir de
#' los valores de `ANNO`, `MES` y `DXX`, de manera que se eliminan los días
#' que no existen.
#' Podemos observar que `valor` es la única variable con nulos mediante `colMeans()`:

colMeans(is.na(diario_as))

#' Además, convertimos las variables `provincia`, `municipio`, `estacion`,
#' `punto_muestreo` a `factor`.
#'
#'
#' ## Diccionario de variables
#' A continuación se muestra una tabla de guía para las variables del *tibble*
#' `diario_as`.
#'
#' | **Variable** | **Descripción** |
#' |:---|:---|
#' | `provincia` | Código INE de la provincia (2 dígitos, p. ej. 15 = A Coruña, 28 = Madrid). |
#' | `municipio` | Código INE del municipio dentro de la provincia (3 dígitos). Para identificarlo del todo hay que combinarlo con `provincia`. |
#' | `estacion` | Número de la estación de medición dentro del municipio. Una estación es una caseta con varios equipos. |
#' | `punto_muestreo` | Identificador del equipo concreto. Suele tener la forma `códigoEstación_magnitud_técnica`: provincia + municipio + estación, el contaminante y un código del método de análisis. Una estación puede tener varios puntos. |
#' | `fecha` | Fecha en la que se realizó la observación. |
#' | `valor` | Concentración media diaria del arsénico. Se mide en $ng / m^3$. |
#'
#'
#' ## Distribución de los valores y nulos
#'
#' Comenzaremos mostrando las estadísticas generales del valor medio de la
#' concentración diaria de arsénico:

summary(diario_as)

#' La variable de estudio `valor` tiene, por tanto, un rango de valores entre 0
#' y 33, con media 0.5571 y mediana 0.33.
#' Además, cuenta con 61233 nulos.
#'
#' Si mostramos la distribución de los valores de la misma, observamos que
#' efectivamente, la mayoría de valores se aproximan al 0.

hist(diario_as$valor,
  breaks = "FD", col = "black", main = "Arsénico observado",
  xlab = "Concentración de arsénico", ylab = "Frecuencia", freq = TRUE
)

#' La función `mice::md.pattern()` no aporta mucha información útil, ya que solo
#' contamos con una variable, así que no nos molestaremos en incluirla.
#' Igualmente, dentro de esta variable podemos ver el conteo de nulos, por ejemplo
#' por año:


anio <- format(diario_as$fecha, "%Y")
ausente <- is.na(diario_as$valor)

tabla.anios <- data.frame(
  n = as.vector(table(anio)),
  observados = as.vector(tapply(!ausente, anio, sum)),
  ausentes = as.vector(tapply(ausente, anio, sum)),
  porcentaje_NA = round(100 * as.vector(tapply(ausente, anio, mean)), 2),
  row.names = names(table(anio))
)
tabla.anios

#' Podemos visualizar también la distribución temporal de nulos.

var <- "Provincia"
VIM::marginplot(diario_as[, c(stringr::str_to_lower(var), "valor")],
  xlab = var,
  ylab = "As (ng/m³)", pch = 16, cex.numbers = .9
)

#' De esta última gráfica podemos sacar que los nulos se encuentran a lo largo
#' de todo el rango de valores.
#'
#'
#' ## Estructura de la ausencia
#'
#' Podemos también realizar un análisis de los puntos de muestreo, para
#' comprobar si existe alguno que no contenga mediciones nunca, para poder
#' descartarlo.

por_punto <- diario_as %>%
  group_by(punto_muestreo) %>%
  summarise(
    dias = n(), # filas (días) que tiene ese punto
    con_valor = sum(!is.na(valor)), # de ellas, cuántas tienen valor
    .groups = "drop"
  )

n_puntos <- nrow(por_punto) # puntos de muestreo en total
n_puntos_sin_valores <- sum(por_punto$con_valor == 0) # puntos sin ni un solo valor

data.frame(n_puntos, n_puntos_sin_valores, row.names = "n")

#' Concluimos, por tanto, que no existen puntos de muestreo sin ningún valor.
#'
#' A continuación, observaremos la distancia entre las mediciones, para intentar
#' descubrir si existe algún patrón de medición (diario, semanal, etc.).

intervalos <- diario_as %>%
  filter(!is.na(valor)) %>% # solo días con medida
  arrange(punto_muestreo, fecha) %>% # ordenados dentro de cada punto
  group_by(punto_muestreo) %>%
  mutate(dif = as.integer(fecha - lag(fecha))) %>% # días desde la medida anterior
  ungroup() %>%
  filter(!is.na(dif)) # quitamos la primera medida de cada punto

intervalos %>%
  count(dif, sort = TRUE) %>%
  head(10)

#'
#'
#' # Métodos
#'
#'
#'
#' # Resultados
#'
#'
#'
#' # Discusión
#'
#'
#'
#' # Reproducibilidad
#'
#'
