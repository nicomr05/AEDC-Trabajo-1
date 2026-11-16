#' ---
#' title: \textbf{Trabajo Datos Faltantes}
#' subtitle: Tema 1, MITECO
#' author: [S. E. Elizabet, M. R. Nicolás]
#' date: \today
#' fontsize: 11pt
#' fig_width: \textwidth
#' fig_height: 6
#' fig_caption: true
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
#'     df_print: tibble  # print.data.frame(default)/kable/tibble
#' ---
#'
#' ```{r setup, include=FALSE}
#' knitr::opts_chunk$set(
#'    echo=FALSE,
#'    message = FALSE,
#'    warning = FALSE,
#'    width = 120,
#'    comment = NA,
#'    tidy = TRUE,
#'    tidy.opts = list(width.cutoff=75),
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
#' Además, hemos incorporado la metainformación oficial de las estaciones proporcionada
#' por el MITECO para cada año, relacionándola con las mediciones mediante el código
#' de estación.
#' De esta forma, disponemos de los nombres de las estaciones, comunidades
#' autónomas, provincias y municipios, así como su tipo de estación,
#' tipo de área y zona.
#' También hemos conservado las fechas de alta y baja de las estaciones para comprobar
#' más adelante si algunas ausencias pueden estar relacionadas con sus períodos de actividad.
#' De hecho, 17 de las filas de la tabla contenían filas con `valor` a nulo, en
#' las que se cumplía que `fecha` > `fecha_fin`, por lo que las eliminamos también.
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

colMeans(is.na(diario_as))[c("valor","fecha_fin")]
# Excluimos las fechas administrativas para el análisis de patrones
diario_as_final <- diario_as[1:13]

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
#'
#'
#' # Distribución de los valores y nulos
#'
#' Comenzaremos mostrando las estadísticas generales del valor medio de la
#' concentración diaria de arsénico:

summary(diario_as_final)
glimpse(diario_as_final)

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

#'
patrones <- mice::md.pattern(diario_as_final, rotate.names = TRUE)

#' Como era de esperar, la función `mice::md.pattern()` muestra un patrón de ausencia univariante,
#' ya que `valor` es la única variable que presenta datos faltantes del conjunto seleccionado.
#' Las variables restantes están completamente observadas y contienen información
#' temporal y geográfica que podremos utilizar para investigar posibles asociaciones con la ausencia de concentración de arsénico.
#'
#'
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

#'
#' ## Ausencias según la fecha de medición
#'
#' A continuación, estudiamos cómo varía la proporción de ausencias
#' a lo largo de 2022 y 2023, tanto a nivel mensual como diario.

# Porcentaje de ausencias según año

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

# Porcentaje de ausencias según mes

mes <- format(diario_as$fecha, "%m")

por_mes <- round(
  100 * tapply(ausente, list(anio, mes), mean),
  2
)

por_mes

matplot(1:12, t(por_mes),
        type = "b", pch = 16, lty = 1,
        col = c("steelblue4", "firebrick3"),
        xaxt = "n",
        xlab = "Mes",
        ylab = "% de ausencias",
        main = "Ausencias mensuales de arsénico",
        ylim = c(0,100))
        

axis(1, at = 1:12, labels = month.abb)
legend("topright", legend = rownames(por_mes),
       col = c("steelblue4", "firebrick3"),
       lty = 1, pch = 16)

#' Los porcentajes mensuales de ausencia son similares en ambos años,
#' sin observarse un patrón estacional claramente repetido.
#' Por tanto, el mes y el año no parecen explicar por sí solos
#' las diferencias en la disponibilidad de las mediciones.
#'
#' Para observar con más detalle la distribución temporal de las ausencias,
#' seleccionamos dos puntos de muestreo con porcentajes de ausencia
#' diferentes y representamos sus mediciones durante ambos años.
#' Los puntos azules representan las concentraciones observadas y
#' las marcas rojas del eje horizontal indican las fechas sin medición.

par(mfrow = c(2, 2))

for (a in c("2022", "2023")) {
  for (punto in c("50297026_17_M", "33004020_17_M")) {
    est <- subset(
      diario_as,
      punto_muestreo == punto &
        format(fecha, "%Y") == a
    )

    est <- est[order(est$fecha), ]

    plot(est$fecha, est$valor,
      type = "p", pch = 16, cex = .5,
      col = "steelblue4",
      xlim = as.Date(c(
        paste0(a, "-01-01"),
        paste0(a, "-12-31")
      )),
      xlab = "Fecha",
      ylab = "Arsénico (ng/m³)",
      main = paste(substr(est$nombre_estacion[1], 1, 25), "-", a),
      cex.main = 0.85
    )

    rug(est$fecha[is.na(est$valor)],
      side = 1, col = "firebrick3", lwd = 2
    )
  }
}

par(mfrow = c(1, 1))

#' Se observan diferencias importantes entre los dos puntos de muestreo,
#' mientras que cada uno mantiene un comportamiento relativamente similar
#' entre 2022 y 2023. Esto sugiere que la disponibilidad de mediciones
#' podría estar más relacionada con el punto de muestreo que con el año.
#' No obstante, se trata únicamente de dos ejemplos y no podemos
#' generalizar esta conclusión al conjunto de estaciones.

#' Por último, analizamos la evolución diaria del porcentaje de
#' ausencias considerando conjuntamente todos los puntos de muestreo.
#' Para facilitar la comparación, representamos cada año por separado,
#' manteniendo la misma escala vertical.
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

#' En ambos años, el porcentaje diario de ausencias presenta
#' fluctuaciones, generalmente alrededor del 70 % y el 80 %,
#' sin observarse una tendencia temporal clara.
#' Tampoco parecen existir grandes diferencias globales entre ambos años.
#' Esto indica que la elevada proporción de ausencias se mantiene
#' relativamente estable a lo largo del período estudiado.


#'
#' ## Estructura de la ausencia
#'
#' Comprobamos si existen puntos de muestreo sin ninguna medición
#' disponible durante el período estudiado.

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

#' Los intervalos más frecuentes entre mediciones consecutivas son
#' de 1, 2 y 6 días. Esto sugiere que podrían existir diferentes
#' periodicidades de muestreo según el punto de medición.
#' Por tanto, parte de las ausencias podría corresponder a días
#' en los que no estaba programada una medición.
#' 
#' ## Análisis del mecanismo de ausencia
#'
#' ### Test de Little 
#' Aplicamos el test de Little para contrastar la hipótesis de
#' ausencia completamente aleatoria (MCAR).
#' Incorporamos un índice temporal, calculado a partir de la fecha,
#' para investigar si la ausencia está relacionada con el tiempo.

datos_little <- data.frame(
  valor = diario_as$valor,
  indice_fecha = as.integer(diario_as$fecha -
                              min(diario_as$fecha)) + 1
)

naniar::mcar_test(datos_little)

#' ### Regresión logística
#'
#' Ajustamos una regresión logística para investigar si las ausencias
#' están relacionadas con variables observadas. Creamos un indicador
#' de ausencia y extraemos el mes, el año y el día de la semana.
#' Esta última variable nos permitirá investigar si existe alguna
#' relación con la periodicidad de las mediciones.

datos_log <- diario_as %>%
  mutate(
    ausente = is.na(valor),
    mes = factor(format(fecha, "%m")),
    anio = factor(format(fecha, "%Y")),
    dia_semana = factor(weekdays(fecha))
  )

#' Comenzamos con un modelo que incluye las variables temporales,
#' geográficas y las características de las estaciones.
#' Utilizamos `drop1()` para evaluar la contribución de cada variable,
#' mediante contrastes de razón de verosimilitudes, con un nivel
#' de significación del 5 %.

modelo <- glm(
  ausente ~ mes + anio + tipo_estacion + tipo_area +
    provincia + zona + dia_semana,
  data = datos_log,
  family = binomial()
)

drop1(modelo, test = "Chisq")

#' El año presenta el mayor valor p (0,781), por lo que lo
#' eliminamos al no aportar información significativa al modelo
#' una vez consideradas las demás variables.

modelo2 <- update(modelo, . ~ . - anio)

drop1(modelo2, test = "Chisq")

#' Tras eliminar el año, `tipo_area` presenta el mayor valor p
#' (0,062), superior al 5 %. Por tanto, también la eliminamos
#' y volvemos a comprobar la significación de las variables.

modelo3 <- update(modelo2, . ~ . - tipo_area)

drop1(modelo3, test = "Chisq")

#' Todas las variables restantes resultan significativas:
#' `mes`, `tipo_estacion`, `provincia`, `zona` y `dia_semana`.
#' Destacan especialmente las diferencias geográficas y la
#' asociación entre el día de la semana y la ausencia de mediciones.
#' Esta última podría estar relacionada con los calendarios de
#' muestreo, aunque no conocemos la programación de cada estación.

#' A continuación, ajustamos otro modelo sustituyendo las
#' características generales de las estaciones por el identificador
#' del punto de muestreo. Queremos comprobar si conocer el punto
#' concreto aporta más información sobre las ausencias que las características 
#' que lo representan.

modelo_puntos <- glm(
  ausente ~ mes + punto_muestreo + dia_semana,
  data = datos_log,
  family = binomial()
)

drop1(modelo_puntos, test = "Chisq")

#' Las tres variables resultan significativas. El punto de
#' muestreo presenta la mayor contribución al ajuste, aunque
#' el día de la semana también muestra una asociación importante.
#' Esto sugiere que tanto el punto concreto como la distribución
#' semanal pueden influir en la disponibilidad de mediciones.

#' Finalmente, comparamos ambos modelos mediante el AIC, que
#' penaliza la complejidad y permite comparar sus ajustes.

AIC(modelo3, modelo_puntos)

#' El modelo por puntos obtiene un AIC de 86482,64, frente a
#' 91385,24 del modelo general. Por tanto, ofrece un mejor ajuste
#' penalizado, incluso teniendo un mayor número de parámetros.
#'
#' En conjunto, encontramos asociaciones entre las ausencias y
#' variables observadas, lo que aporta evidencia contraria a MCAR.
#' No obstante, los modelos no permiten confirmar MAR ni descartar
#' MNAR. Además, las observaciones repetidas por estación pueden
#' presentar dependencia temporal, por lo que los valores p deben
#' interpretarse con cautela.

