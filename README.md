# retail-sales-dbt-duckdb

![CI](https://github.com/LuisEnrique98/retail-sales-dbt-duckdb/actions/workflows/ci.yml/badge.svg)

End-to-end ELT pipeline on the UCI Online Retail II dataset: Python ingestion, DuckDB storage, dbt transformations, data quality tests and CI with GitHub Actions.

> **Estado:** pipeline funcional y automatizado. Dashboard pendiente.

**English summary:** Python loads the two sheets of the Online Retail II Excel file into DuckDB (raw layer, all text). dbt cleans and types them (staging), removes a 22,523-row overlap between sheets and builds a star schema (`fct_sales`, `dim_products`, `dim_date`). Data quality tests run on every pull request in GitHub Actions.

## Objetivo

Construir de punta a punta un flujo de datos sobre transacciones reales de una tienda en línea, tratando los problemas de calidad que trae el dataset (hojas solapadas, cancelaciones, ajustes de inventario, códigos que no son productos), y dejar un modelo listo para responder preguntas de negocio como:

- ¿Cuánto se vende por mes, en bruto y neto de cancelaciones?
- ¿Qué países generan más ingresos?
- ¿Cuáles son los productos más vendidos, sin contar envíos ni comisiones?
- ¿Cuál es la tasa de cancelación por mes?

## Arquitectura

```mermaid
flowchart LR
    A[Excel de UCI<br/>2 hojas] -->|Python: ingest.py| B[(DuckDB<br/>esquema raw)]
    B -->|dbt| C[Staging<br/>stg_transactions]
    C -->|dbt| D[Marts<br/>fct_sales + dimensiones]
    E[Seed<br/>non_product_stock_codes] --> D
    C -.->|tests| F{Calidad de datos}
    D -.->|tests| F
    G[GitHub Actions] -.->|ejecuta todo en cada PR| B
```

| Capa | Contenido | Materialización |
|---|---|---|
| **raw** | Una tabla por hoja del Excel, tal como llegó (todo como texto) | Tablas |
| **staging** | Nombres claros, tipos convertidos, unión de las dos hojas sin el solape | Vistas |
| **marts** | Modelo en estrella listo para análisis | Tablas |

### Modelo dimensional

- **Hecho:** `fct_sales`, una fila por línea de factura, con `line_total` (cantidad por precio) y `transaction_type`.
- **Dimensiones:** `dim_products` (una fila por código de producto, con una marca `is_product` y un `item_type`) y `dim_date`.
- **Seed:** `non_product_stock_codes`, la lista de códigos que no son mercadería (envíos, comisiones, ajustes, descuentos, muestras, pruebas y vales de regalo).

El país se mantiene como columna de `fct_sales`, porque solo hay unos 43 valores y no tienen atributos propios: una dimensión aparte solo agregaría un join. No hay `dim_customers`: del cliente solo se tiene su ID, sin atributos propios, así que una dimensión no agregaría información. Los análisis por cliente se hacen directamente sobre `fct_sales`, excluyendo las líneas sin `customer_id`.

## Stack

- **Python** (pandas, openpyxl) para la ingesta
- **DuckDB** como almacén analítico local
- **dbt-core** (adaptador `dbt-duckdb`) para transformaciones, seeds y tests
- **GitHub Actions** para ejecutar el pipeline en cada Pull Request
- **Git / GitHub** para control de versiones

## Dataset

Chen, D. (2012). *Online Retail II* [Dataset]. UCI Machine Learning Repository. https://doi.org/10.24432/C5CG6D

Licencia del dataset: [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). Contiene las transacciones de una tienda en línea del Reino Unido entre el 01/12/2009 y el 09/12/2011: 1.067.371 filas en dos hojas de un Excel.

Los datos **no se incluyen en este repositorio**; se descargan desde UCI. Se transforman en las capas staging y marts de este proyecto (renombrado de columnas, conversión de tipos, unión de hojas, clasificación de transacciones y cálculos).

El código de este repositorio se distribuye bajo licencia MIT (ver `LICENSE`). La licencia del dataset aplica únicamente a los datos.

## Estructura del repositorio

```
.
├── .github/workflows/ci.yml   # pipeline automático
├── data/                      # datos descargados y convertidos (no versionado)
├── ingestion/
│   └── ingest.py              # Excel -> CSV -> DuckDB (esquema raw)
├── dbt_project/
│   ├── dbt_project.yml
│   ├── profiles.yml
│   ├── models/
│   │   ├── staging/           # fuentes, modelos por hoja, unión y tests
│   │   └── marts/             # fct_sales, dim_products, dim_date y tests
│   ├── seeds/                 # non_product_stock_codes
│   └── tests/                 # tests propios (totales de filas)
├── requirements.txt
└── README.md
```

## Cómo ejecutarlo

**1. Clonar el repositorio y crear el entorno**

```bash
git clone https://github.com/LuisEnrique98/retail-sales-dbt-duckdb.git
cd retail-sales-dbt-duckdb
python -m venv .venv
.venv\Scripts\activate        # Windows
source .venv/bin/activate     # Linux / Mac
pip install -r requirements.txt
```

**2. Descargar el dataset**

Crear la carpeta `data/raw/` (no viene en el repositorio):

```bash
mkdir -p data/raw             # Linux / Mac
mkdir data\raw                # Windows
```

Descargar el ZIP desde [UCI](https://archive.ics.uci.edu/dataset/502/online+retail+ii) y extraer `online_retail_II.xlsx` en `data/raw/`.

**3. Cargar los datos crudos a DuckDB**

Desde la raíz del proyecto:

```bash
python ingestion/ingest.py
```

Convierte cada hoja del Excel a CSV (la primera vez tarda varios minutos) y crea `retail.duckdb` con una tabla `raw` por hoja. Los CSV ya convertidos se omiten en las ejecuciones siguientes.

**4. Transformar y probar con dbt**

```bash
cd dbt_project
dbt seed --profiles-dir .
dbt run --profiles-dir .
dbt test --profiles-dir .
```

El pipeline completo también se ejecuta automáticamente en GitHub Actions en cada Pull Request.

## Decisiones de diseño

- **ELT en lugar de ETL:** `raw` es una copia fiel del Excel (todo como texto) y las transformaciones ocurren dentro de DuckDB con dbt, lo que deja cada paso trazable.
- **Una tabla `raw` por hoja:** la unión es una transformación, así que se hace en staging y no al cargar.
- **Capas separadas:** `raw` queda intacto, `staging` solo ordena y tipifica, y la lógica de negocio vive en `marts`.
- **Mayúsculas en `stock_code`:** se normaliza con `upper()` en el paso final de `stg_transactions`, después de quitar el solape, para que códigos que solo difieren en mayúsculas (por ejemplo `M` y `m`) no se traten como distintos.
- **Granularidad a nivel de línea de factura:** permite analizar por producto, país y fecha, y calcular el ticket por factura.
- **Clasificación de transacciones:** `transaction_type` separa ventas, cancelaciones, ajustes y líneas sin precio, para que los ingresos brutos y netos no se mezclen con movimientos que no son ventas.
- **Descripción de cada producto:** cuando un código tiene varias descripciones, se elige la que aparece en más líneas con precio, luego la más frecuente, luego la más reciente, y por último el orden alfabético, para que el resultado sea siempre el mismo.
- **Precios:** se usan tal como vienen en el dataset (libras). El dataset no indica si incluyen impuestos, y no se calcula ningún IGV ni equivalente.
- **Ingesta idempotente:** `CREATE OR REPLACE TABLE` permite repetir la carga sin duplicar datos.

## Calidad de datos

Tests en dbt: no nulos, unicidad de claves en las dimensiones, integridad referencial entre el hecho y sus dimensiones, valores aceptados en `transaction_type` e `item_type`, y dos tests propios que verifican los totales de filas.

**Hallazgos**

| Hallazgo | Detalle |
|---|---|
| Hojas solapadas | Las dos hojas coinciden del 01/12/2010 al 09/12/2010: 22.523 filas idénticas. Se conserva una sola copia: 1.067.371 − 22.523 = **1.044.848** filas, verificado con un test |
| Códigos que no son productos | Envíos (`POST`, `DOT`, `C2`), comisiones, ajustes, descuentos, muestras, pruebas y vales de regalo. Se clasifican con un seed |
| Descripciones empatadas | 5 códigos tenían dos descripciones igual de frecuentes; se resuelven con la regla de desempate descrita arriba |
| Líneas negativas sin factura "C" | 3.393 líneas, todas con precio 0 y sin cliente (2.633 sin descripción; entre las que sí la tienen predominan notas como `damaged`, `missing` o `check`). Se tratan como ajustes de inventario |
| Código `B` (deuda incobrable) | 6 líneas con importes grandes, cinco negativos y uno positivo. Se tratan como ajustes contables |
| Líneas con precio 0 y cantidad positiva | 2.631 líneas; solo 70 tienen cliente. Se clasifican aparte como `zero_price` |
| Factura "C" con cantidad positiva | 1 caso; se marca como `cancellation_anomaly` |

**Líneas por `transaction_type`**

| Tipo | Líneas |
|---|---|
| `sale` | 1.019.653 |
| `cancellation` | 19.164 |
| `adjustment` | 3.399 |
| `zero_price` | 2.631 |
| `cancellation_anomaly` | 1 |
| **Total** | **1.044.848** |

**Limitaciones:** la clasificación de ajustes y de líneas sin precio se infiere de los datos y de sus descripciones, y no se pudo confirmar con quien generó el dataset. Hay líneas sin `customer_id`, por lo que cualquier análisis por cliente no las incluiría.

## Roadmap

- [x] Ingesta a DuckDB (una tabla raw por hoja)
- [x] Capa staging, unión de hojas y tests de calidad
- [x] Modelo dimensional (marts) y clasificación de transacciones
- [x] Automatización con GitHub Actions
- [ ] Dashboard

## Autor

**Luis Enrique Allcca Alarcón** — Data Analyst | Data Engineering  
[LinkedIn](https://www.linkedin.com/in/luis-enrique-allcca-alarcon) · [GitHub](https://github.com/LuisEnrique98)

## Licencia

Código bajo licencia [MIT](LICENSE). Dataset bajo [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).