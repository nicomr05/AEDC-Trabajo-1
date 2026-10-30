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
#' 
#' # Primeros pasos
#' 
#' Al cargar los datos por primera vez pudimos observar que los datos contenían
#' 38 variables de tipo `chr` para identificar cada una de las mediciones, de las
#' cuales las 31 variables llamadas `DXX` corresponden a cada uno de los días del
#' mes.
#' Debido a esto, la variable `D31` tendrá un nulo en los meses que tengan 30 días.
#' De manera similar, en febrero habrá nulos en los días 30 y 31, además de el 29
#' en años bisiestos.
#' Se puede observar además que estas últimas son las únicas variables con valores
#' faltantes.
#' 
#' Dado que la falta de estos valores se da únicamente por la forma de guardar los
#' datos, decidimos convertir las 31 variables en una columna `valor` (de tipo
#' `numeric`) y crear a su vez una columna `fecha` (de tipo `Date`) a partir de
#' los valores de `ANNO`, `MES` y `DXX`.
#' Además, convertimos las variables `provincia`, `municipio`, `estacion`,
#' `punto_muestreo` a `factor`.
#' 
#' 
#' ```{r carga-datos, results='hide'}
#' source("miteco.R")
#' datos <- diario_as
#' ```
#' 
#' 
#' ## Diccionario de variables de `diario_as`
#' A continuación se muestra una tabla de guía para las variables del *tibble*
#' `diario_as`.
#'
#' | **Variable** | **Descripción** |
#' |:---|:---|
#' | `provincia` | Código INE de la provincia (2 dígitos, p. ej. 15 = A Coruña, 28 = Madrid). |
#' | `municipio` | Código INE del municipio dentro de la provincia (3 dígitos). Para identificarlo del todo hay que combinarlo con `provincia`. |
#' | `estacion` | Número de la estación de medición dentro del municipio. Una estación es una caseta con varios equipos. |
#' | `punto_muestreo` | Identificador del equipo concreto. Suele tener la forma `códigoEstación_magnitud_técnica`: provincia + municipio + estación, el contaminante y un código del método de análisis. Una estación puede tener varios puntos. |
#' | `fecha` | Fecha en la que se realizó la observación |
#' | `valor` | Concentración media diaria del arsénico. No encontramos unidades en la página oficial del MITECO, pero normalmente se miden en $ng / m^3$. |
#' 
#' 
#' # Distribución de los valores y nulos
#' 
#' Comenzaremos mostrando las estadísticas generales del valor medio de la
#' concentración de `As`, sin contar los nulos:

summary(diario_as$valor)

#' Así como la distribución de la variable:

hist(diario_as$valor, breaks="FD", col='black',
     main='Arsénico observado', xlab='Concentración de arsénico',
     ylab='Frecuencia', freq=TRUE)

#' A la vista de estos resultados, se observa que la mayoría de los valores