# AEDC · Trabajo 1 — Datos faltantes en calidad del aire (MITECO)

Análisis de datos faltantes (MCAR, MAR y MNAR) sobre las **series diarias de arsénico (As)** de la red de calidad del aire publicadas por el Ministerio para la Transición Ecológica y el Reto Demográfico (MITECO), años **2022 y 2023**.

Este repositorio contiene el script que descarga, extrae y prepara los datos. El análisis posterior parte del dataset `diario_as` que genera.

## Contenido

```
.
├── miteco.R      # descarga, extracción, preparación y resumen inicial de faltantes
├── README.md
└── datos/        # se crea al ejecutar el script
    ├── miteco_zip/   # ZIP descargados
    └── miteco_csv/   # CSV extraídos
```

## Datos

- **Fuente:** páginas de datos oficiales del MITECO (una por año):
  - [Datos oficiales 2022](https://www.miteco.gob.es/es/calidad-y-evaluacion-ambiental/temas/atmosfera-y-calidad-del-aire/evaluacion-y-datos-de-calidad-del-aire/datos/datos-oficiales-2022.html)
  - [Datos oficiales 2023](https://www.miteco.gob.es/es/calidad-y-evaluacion-ambiental/temas/atmosfera-y-calidad-del-aire/evaluacion-y-datos-de-calidad-del-aire/datos/datos-oficiales-2023.html)
- **Qué se descarga:** solo los ZIP de *datos diarios* de cada año; de ellos se extraen únicamente los CSV `As_DD_*.csv`.
- **Formato de origen:** CSV separados por `;`, codificación ISO-8859-1, en **formato ancho**: una fila por punto de muestreo y mes, con una columna por día (`D01` … `D31`).

> El patrón de extracción (`As_DD_.*\.csv$`) se define en una sola variable (`patron`) del script. Cambiándolo se puede trabajar con otro contaminante diario (por ejemplo, `C6H6_DD_`), siempre que ese fichero exista en los ZIP del año. En ese caso hay que actualizar también el nombre del dataset y este README.

## Requisitos

- R (≥ 4.1 recomendado)
- Paquetes: `dplyr`, `readr`, `purrr`, `stringr`, `tidyr`, `xml2`, `rvest`
- Conexión a internet la primera vez (después se reutilizan los ZIP ya descargados)

```r
install.packages(c("dplyr", "readr", "purrr", "stringr", "tidyr", "xml2", "rvest"))
```

## Uso

Desde la raíz del repositorio:

```r
source("miteco.R")
```

o desde la terminal:

```bash
Rscript miteco.R
```

Las rutas son relativas, así que el directorio de trabajo debe ser la carpeta donde está el script.

## Qué hace el script

1. **Rutas.** Define y crea `datos/miteco_zip` y `datos/miteco_csv`.
2. **Descarga.** Lee las páginas del MITECO de 2022 y 2023, extrae los enlaces a ficheros `.zip`, se queda con los de *datos diarios*, normaliza la URL (tildes y espacios) y descarga solo los que aún no están en disco.
3. **Extracción selectiva.** Mira el contenido de cada ZIP sin descomprimirlo y extrae únicamente los CSV que coinciden con el patrón del contaminante.
4. **Lectura.** Lee los CSV (separador `;`, ISO-8859-1) como texto y los apila en `raw_chr`.
5. **Construcción de `diario_as`.** Pasa de formato ancho a largo (una fila por punto de muestreo y día), construye `fecha` a partir de año, mes y número de día, y descarta las combinaciones que no existen en el calendario (30 de febrero, 31 de abril…), que son faltantes *estructurales* y no datos perdidos. Después convierte `valor` a numérico y los identificadores a factor.
6. **Resumen inicial.** Imprime una tabla por año con el número de observaciones, valores presentes, ausentes y porcentaje de `NA`.

### Objetos principales

| Objeto | Descripción |
|---|---|
| `raw_chr` | Datos tal cual vienen en los CSV (todo texto, formato ancho). Es la única copia del texto original, útil para inspeccionar qué había exactamente en una celda que acabó en `NA`. Conserva columnas que `diario_as` no incluye, como `MAGNITUD`, `ANNO` y `MES`. |
| `diario_as` | Formato largo, una fila por punto de muestreo y día. Es el dataset de análisis. |

## Diccionario de variables de `diario_as`

| Variable | Tipo | Descripción |
|---|---|---|
| `provincia` | factor | Código INE de la provincia. |
| `municipio` | factor | Código del municipio dentro de la provincia (solo es único combinado con `provincia`). |
| `estacion` | factor | Código de la estación dentro del municipio (solo es único combinado con provincia y municipio). |
| `punto_muestreo` | factor | Identificador del equipo concreto dentro de una estación. |
| `fecha` | Date | Día de la medición (construida a partir del año, el mes y la columna `D01`…`D31` de origen). |
| `valor` | numérico | Concentración media diaria de arsénico. `NA` indica ausencia de dato. Unidad: confirmar en la documentación del MITECO. |

Notas sobre las variables:

- `provincia`, `municipio`, `estacion` y `punto_muestreo` son **códigos**, no nombres. Para obtener nombres y coordenadas de las estaciones hace falta un catálogo aparte.
- Las cuatro están **anidadas** (provincia ⊃ municipio ⊃ estación ⊃ punto de muestreo). Al modelar, conviene elegir un único nivel de granularidad en lugar de incluirlas todas a la vez.
- No se incluyen `magnitud` (constante, porque todo el dataset es arsénico; el código sigue disponible en `raw_chr$MAGNITUD`), `anno` y `mes` (derivables de `fecha`) ni el fichero de origen.

## Consideraciones para el análisis de faltantes

- **Tres tipos de ausencia que no deben mezclarse:**
  - *Estructurales:* días que no existen en el calendario. Ya se eliminan en el script.
  - *Celdas vacías en días que sí existen:* los faltantes propiamente dichos.
  - *Filas ausentes:* puntos de muestreo que no aparecen en algún mes o año; no son `NA` en la tabla, simplemente no existen. Para verlos hay que completar la rejilla `punto_muestreo × fecha`.
- **Sin indicador de validación.** Los ficheros diarios solo traen el valor, así que no se puede saber si un `NA` es un fallo del equipo, un dato invalidado o una medición no planificada.
- **Muestreo no continuo.** Algunos contaminantes no se miden todos los días; parte de los huecos pueden ser planificados.
- **Posible MNAR.** Valores por debajo del límite de detección dejados en blanco, o equipos que fallan en episodios de concentración alta, harían que la ausencia dependa del propio valor. Conviene revisar ceros o valores mínimos repetidos y plantear análisis de sensibilidad, porque MNAR no puede contrastarse solo con los datos observados.
- **Cobertura temporal limitada** (dos años), lo que restringe lo que se puede decir sobre estacionalidad o tendencias en los faltantes.

## Notas

- La carpeta `datos/` se genera al ejecutar el script y contiene ficheros descargados, por lo que suele convenir excluirla del control de versiones (`.gitignore`).
- Si el MITECO cambia la estructura de sus páginas o los nombres de los ZIP, la detección de enlaces (`get_zip_links`) o el filtro por `"diarios"` pueden dejar de funcionar.
