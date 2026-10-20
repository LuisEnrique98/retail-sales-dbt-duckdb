from pathlib import Path
import re

import duckdb
import pandas as pd

RAW_DIR = Path("data/raw")
CSV_DIR = Path("data/converted")
DB_PATH = Path("retail.duckdb")

def convert_excel_to_csv():
    CSV_DIR.mkdir(parents=True, exist_ok=True)

    xlsx_files = sorted(RAW_DIR.glob("*.xlsx"))
    if not xlsx_files:
        raise FileNotFoundError(f"No hay XLSX en {RAW_DIR.resolve()}")

    for xlsx in xlsx_files:
        with pd.ExcelFile(xlsx) as excel:
            for sheet in excel.sheet_names:
                name = re.sub(r"\W+", "_", f"{xlsx.stem}_{sheet}").lower()
                csv_path = CSV_DIR / f"{name}.csv"

                if csv_path.exists():
                    print(f"Omitido (ya existe): {csv_path.name}")
                    continue

                data = pd.read_excel(excel, sheet_name=sheet, dtype=str)

                tmp_path = csv_path.with_suffix(".tmp")
                data.to_csv(tmp_path, index=False)
                tmp_path.replace(csv_path)


def load_csv_to_duckdb():
    csv_files = sorted(CSV_DIR.glob("*.csv"))
    if not csv_files:
        raise FileNotFoundError(f"No hay CSV en {CSV_DIR.resolve()}")
        
    con = duckdb.connect(str(DB_PATH))
    try:
        con.execute("CREATE SCHEMA IF NOT EXISTS raw")

        for csv in csv_files:
            table = csv.stem
            con.execute(
                f"""
                CREATE OR REPLACE TABLE raw.{table} AS
                SELECT *
                FROM read_csv('{csv.as_posix()}', header=true, all_varchar=true)
                """
            )
            n = con.execute(f"SELECT COUNT(*) FROM raw.{table}").fetchone()[0]
            print(f"{table}: {n} filas")    
    finally:
        con.close()

def main():
    convert_excel_to_csv()
    load_csv_to_duckdb()


if __name__ == "__main__":
    main()
        