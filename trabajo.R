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
library(tibble, warn.conflicts = FALSE)

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
#' El proceso de descarga, importación y preparación de los datos se encuentra
#' documentado en el archivo `miteco.R`, que genera el conjunto `diario_as`
#' utilizado en este análisis.
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
#' Dado que la falta de estos valores se da únicamente por la forma de guardar los
#' datos, decidimos convertir las 31 variables en una columna `valor` (de tipo
#' `numeric`) y crear a su vez una columna `fecha` (de tipo `Date`) a partir de
#' los valores de `ANNO`, `MES` y `DXX`, de manera que se eliminan los días
#' que no existen.
#'
#' Además, hemos incorporado la metainformación oficial de las estaciones proporcionada por el MITECO
#' para cada año, relacionándola con las mediciones mediante el código de estación.
#' De esta forma, disponemos de los nombres de las estaciones, comunidades
#' autónomas, provincias y municipios, así como su tipo de estación,
#' tipo de área y zona.
#' También hemos conservado las fechas de alta y baja de las estaciones para comprobar más adelante
#' si algunas ausencias pueden estar relacionadas con sus períodos de actividad.
#'
#' Haciendo `colMeans()` podemos identificar que, las ausencias no aparecen únicamente en
#' `valor`, sino también en `fecha_fin`, que indica la fecha de baja
#' de las estaciones cuando consta.
#' Como las ausencias en `fecha_fin` se deben principalmente a estaciones
#' que aún no han sido dadas de baja, conocemos su causa y no las
#' incluiremos en el análisis de patrones de ausencia.
#' Sin embargo, conservamos estas fechas en `diario_as`, ya que pueden
#' ayudar a explicar algunas ausencias de mediciones.
#' Para el análisis creamos `diario_as_final`, excluyendo las fechas
#' administrativas.

colMeans(is.na(diario_as))
# Excluimos las fechas administrativas para el análisis de patrones
diario_as_final <- diario_as[1:13]
colMeans(is.na(diario_as_final))

#' Además, convertimos las variables `provincia`, `municipio`, `estacion`,
#' `punto_muestreo` `tipo_estacion`, `tipo_area` y `zona` a `factor`.
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
#' | `nombre_estacion` | Nombre oficial de la estación de medición. |
#' | `nombre_ccaa` | Comunidad autónoma donde se encuentra la estación. |
#' | `nombre_prov` | Nombre de la provincia. |
#' | `nombre_mun` | Nombre del municipio. |
#' | `tipo_estacion` | Tipo de estación según la fuente predominante: tráfico, industrial o fondo. |
#' | `tipo_area` | Clasificación del entorno: urbano, suburbano o rural. |
#' | `zona` | Caracterización del entorno de la estación. |
#' | `fecha_inicio` | Fecha de alta de la estación. |
#' | `fecha_fin` | Fecha de baja de la estación, cuando consta. |
#'
#' ## Distribución de los valores y nulos
#'
#' Comenzaremos mostrando las estadísticas generales del valor medio de la
#' concentración diaria de arsénico:

summary(diario_as)
str(diario_as)

#' La variable de estudio `valor` tiene, por tanto, un rango de valores entre 0
#' y 33, con media 0.5571 y mediana 0.33.
#' Además, cuenta con 61233 nulos.
#'
#' Si mostramos la distribución de los valores de la misma, observamos que
#' efectivamente, la mayoría de valores se encuentran entorno al 0.

hist(diario_as_final$valor,
  breaks = "FD", col = "black", main = "Arsénico observado",
  xlab = "Concentración de arsénico", ylab = "Frecuencia", freq = TRUE
)

mice::md.pattern(diario_as_final)

#' Como era de esperar, la función `mice::md.pattern()` muestra un patrón de ausencia univariante,
#' ya que `valor` es la única variable que presenta datos faltantes del conjunto seleccionado.
#' Las variables restantes están completamente observadas y contienen información
#' temporal y geográfica que podremos utilizar para investigar posibles asociaciones con la ausencia de concentración de arsénico.



#' ## Ausencias según las características geográficas de las estaciones
#'
#' En primer lugar, estudiamos la distribución geográfica de las ausencias,
#' comenzando por las provincias. Para facilitar su interpretación,
#' utilizamos los nombres oficiales incorporados mediante la metainformación.
#' Representamos el porcentaje de valores ausentes de arsénico en cada
#' provincia mediante `naniar::gg_miss_fct()`.

datos_prov <- diario_as_final %>%
  mutate(nombre_prov = factor(nombre_prov))

naniar::gg_miss_fct(
  datos_prov[, c("nombre_prov", "valor")],
  fct = nombre_prov
) + ggplot2::coord_flip()

#' A continuación, realizamos el mismo análisis a nivel municipal.
#' Utilizamos conjuntamente los códigos de provincia y municipio, ya que
#' el código de municipio por sí solo no es único en todo el territorio.
#' Incorporamos sus nombres oficiales para facilitar la identificación.
#'
#' Calculamos el número de registros, los valores observados, los ausentes
#' y el porcentaje de ausencia en cada municipio.

tabla_municipios <- diario_as %>%
  group_by(provincia, municipio, nombre_prov, nombre_mun) %>%
  summarise(
    n = n(),
    observados = sum(!is.na(valor)),
    ausentes = sum(is.na(valor)),
    porcentaje_NA = round(100 * mean(is.na(valor)), 2),
    .groups = "drop"
  ) %>%
  arrange(desc(porcentaje_NA))

print(tabla_municipios)

#' Para resumir la distribución de las tasas de ausencia entre municipios,
#' representamos un histograma de sus porcentajes.

hist(tabla_municipios$porcentaje_NA,
  main = "Distribución de ausencias por municipio",
  xlab = "% de valores ausentes",
  ylab = "Número de municipios",
  xlim = c(0, 100)
)

#' Finalmente, estudiamos las ausencias según el punto de muestreo.
#' Esta desagregación permite comparar las distintas series de medición
#' de arsénico, que pueden presentar porcentajes y patrones de ausencia
#' diferentes.
#'
#' Para cada punto calculamos el número de registros, observaciones
#' disponibles, valores ausentes y porcentaje de ausencia.

tabla_puntos <- diario_as_final %>%
  group_by(punto_muestreo) %>%
  summarise(
    nombre_estacion = first(nombre_estacion),
    nombre_prov = first(nombre_prov),
    nombre_mun = first(nombre_mun),
    n = n(),
    observados = sum(!is.na(valor)),
    ausentes = sum(is.na(valor)),
    porcentaje_NA = round(100 * mean(is.na(valor)), 2),
    .groups = "drop"
  ) %>%
  arrange(desc(porcentaje_NA))

print(tabla_puntos, n = 15)

#' Representamos la distribución de los porcentajes de ausencia entre
#' puntos de muestreo para comprobar si predominan tasas similares
#' o si existe una gran heterogeneidad entre las series.

hist(tabla_puntos$porcentaje_NA,
  main = "Distribución de ausencias por punto de muestreo",
  xlab = "% de valores ausentes",
  ylab = "Número de puntos de muestreo",
  xlim = c(0, 100)
)

#' Además de la ubicación geográfica, disponemos de información sobre
#' las características de las estaciones.
#' Estudiamos si la proporción de ausencias presenta diferencias según
#' el tipo de estación (fondo, industrial o tráfico) y según el tipo
#' de área donde se encuentra (rural, suburbana o urbana).
#'
#' Primero mostramos el número de registros de cada categoría y
#' después calculamos sus correspondientes porcentajes de ausencia.

# Ausencias según tipo de estación
table(diario_as_final$tipo_estacion)

round(100 * tapply(
  is.na(diario_as_final$valor),
  diario_as_final$tipo_estacion,
  mean
), 2)

# Ausencias según tipo de área
table(diario_as_final$tipo_area)

round(100 * tapply(
  is.na(diario_as_final$valor),
  diario_as_final$tipo_area,
  mean
), 2)

#' Los resultados muestran diferencias en los porcentajes de ausencia
#' según la localización y las características de las estaciones.
#' Destacan provincias como Murcia y Zaragoza, con porcentajes de
#' ausencia inferiores a los de otras provincias.
#'
#' Las distribuciones por municipio y por punto de muestreo son muy
#' similares, con una concentración de porcentajes de ausencia entre
#' el 80 % y el 90 %.
#'
#' También observamos diferencias según el tipo de estación: las de
#' fondo presentan un 75 % de ausencias, frente al 66,8 % de las de
#' tráfico. Por tipo de área, las estaciones rurales presentan el
#' mayor porcentaje de ausencia (78,04 %).
#'
#' Por tanto, la ausencia de mediciones parece estar asociada con
#' características geográficas de las estaciones. Más adelante estudiaremos si
#' estas diferencias son significativas y tienen la posibilidad de el explicar el mecanismo
#' de ausencia.


# Porcentaje de ausencias según mes y año
par(mfrow = c(2, 2))

for (anio in c("2022", "2023")) {
  for (punto in c("50297026_17_M", "33004020_17_M")) {
    est <- subset(
      diario_as,
      punto_muestreo == punto &
        format(fecha, "%Y") == anio
    )

    est <- est[order(est$fecha), ]

    plot(est$fecha, est$valor,
      type = "p", pch = 16, cex = .5,
      col = "steelblue4",
      xlim = as.Date(c(
        paste0(anio, "-01-01"),
        paste0(anio, "-12-31")
      )),
      xlab = "Fecha",
      ylab = "Arsénico (ng/m³)",
      main = paste(punto, "-", anio)
    )

    rug(est$fecha[is.na(est$valor)],
      side = 1, col = "firebrick3", lwd = 2
    )
  }
}

par(mfrow = c(1, 1))
# la serie temporal
por_dia <- diario_as %>%
  group_by(fecha) %>%
  summarise(
    porcentaje_NA = 100 * mean(is.na(valor)),
    n_registros = n(),
    .groups = "drop"
  )

par(mfrow = c(2, 1))

for (anio in c("2022", "2023")) {
  datos_anio <- subset(
    por_dia,
    format(fecha, "%Y") == anio
  )

  plot(datos_anio$fecha, datos_anio$porcentaje_NA,
    type = "l",
    col = "steelblue4",
    ylim = c(0, 100),
    xlim = as.Date(c(
      paste0(anio, "-01-01"),
      paste0(anio, "-12-31")
    )),
    xlab = "Fecha",
    ylab = "% de ausencias",
    main = paste("Ausencias de arsénico -", anio)
  )
}

par(mfrow = c(1, 1))


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
#' Test de Little para MCAR:

naniar::mcar_test(diario_as[c("punto_muestreo", "provincia", "municipio", "estacion", "valor")])

naniar::mcar_test(diario_as)

#' Según el test de Little, existe evidencia suficiente para rechazar
#' la hipótesis de que la ausencia provenga de un mecanismo MCAR tanto con todas
#' las variables como cuando no se tiene en cuenta la dependencia temporal (no
#' metemos la variable fecha en el test).

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
