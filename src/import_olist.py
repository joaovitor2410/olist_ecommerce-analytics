"""Importa o resultado da limpeza Olist sem apagar ou substituir tabelas existentes.

Execute no Windows, na raiz do projeto. A senha é solicitada no terminal.
Uma única transação carrega todas as tabelas e valida contra a referência Python.
"""
from __future__ import annotations
import argparse
from datetime import datetime, timezone
from decimal import Decimal
import getpass
import hashlib
from io import BytesIO
import json
from pathlib import Path
import platform
import sys
from zipfile import ZipFile
import numpy as np
import pandas as pd
import psycopg
from psycopg import sql

SPEC_PATH = Path(__file__).with_name("table_spec.json")
SPEC = json.loads(SPEC_PATH.read_text(encoding="utf-8"))


def source_bytes(path: Path, relative: str) -> bytes:
    if path.is_dir():
        candidate = path / relative
        if not candidate.exists():
            raise FileNotFoundError(f"Arquivo não encontrado: {candidate}")
        return candidate.read_bytes()
    if path.suffix.lower() != ".zip":
        raise ValueError("--input deve apontar para o ZIP da LIMPEZA ou a pasta que contém clean/ e analytical/.")
    with ZipFile(path) as archive:
        matches = [name for name in archive.namelist()
                   if name == relative or name.endswith("/" + relative)]
        if len(matches) != 1:
            raise ValueError(f"Esperado um arquivo {relative}; encontrados {len(matches)}. Use o ZIP da limpeza, não o da EDA.")
        return archive.read(matches[0])


def load_inputs(path: Path):
    frames, hashes = {}, {}
    for table, columns in SPEC.items():
        relative = "analytical/orders_analysis.parquet" if table == "reference_orders" else f"clean/{table}.parquet"
        payload = source_bytes(path, relative)
        hashes[relative] = hashlib.sha256(payload).hexdigest()
        frame = pd.read_parquet(BytesIO(payload))
        if table in {"reviews", "geolocation"}:
            # Parquet foi exportado sem índice. A ordem física reproduz o desempate da limpeza.
            frame = frame.reset_index(drop=True)
            frame["source_row"] = np.arange(len(frame), dtype=np.int64)
        names = [column["name"] for column in columns]
        missing = sorted(set(names) - set(frame.columns))
        if missing:
            raise ValueError(f"{table}: faltam {missing}. Use a versão tratada, não os CSVs brutos.")
        for column in columns:
            name, kind = column["name"], column["type"]
            s = frame[name]
            if kind == "timestamp" and not pd.api.types.is_datetime64_any_dtype(s):
                raise TypeError(f"{table}.{name}: esperado datetime no Parquet.")
            if kind == "boolean" and not pd.api.types.is_bool_dtype(s):
                raise TypeError(f"{table}.{name}: esperado boolean no Parquet.")
            if kind in {"bigint", "integer", "numeric", "double"}:
                if not pd.api.types.is_numeric_dtype(s):
                    raise TypeError(f"{table}.{name}: esperado tipo numérico.")
                valid = s.dropna()
                if not np.isfinite(valid).all():
                    raise ValueError(f"{table}.{name}: valores não finitos.")
                if kind in {"bigint", "integer"}:
                    if valid.mod(1).ne(0).any():
                        raise ValueError(f"{table}.{name}: parte fracionária inesperada.")
                    limits = np.iinfo(np.int32 if kind == "integer" else np.int64)
                    if valid.lt(limits.min).any() or valid.gt(limits.max).any():
                        raise ValueError(f"{table}.{name}: número fora do intervalo do tipo SQL.")
        frames[table] = frame[names].copy()
    if frames["orders"].empty or frames["reference_orders"].empty:
        raise ValueError("Pedidos ou referência vazios: não há análise para importar.")
    return frames, hashes


def native(value, kind):
    if pd.isna(value):
        return None
    if kind in {"bigint", "integer"}:
        return int(value)
    if kind == "boolean":
        return bool(value)
    if kind == "timestamp":
        return pd.Timestamp(value).to_pydatetime()
    if kind == "numeric":
        return Decimal(str(value))
    if kind == "double":
        return float(value)
    return str(value)


def import_frames(conn, frames):
    """Chamar dentro de uma transação. Falhas causam rollback pelo chamador."""
    with conn.cursor() as cur:
        for view in ["olist.v_orders_analysis", "olist.v_reconciliation_detail"]:
            cur.execute("SELECT to_regclass(%s)", (view,))
            if cur.fetchone()[0] is None:
                raise RuntimeError("Execute 01_create_tables.sql, 02_analytical_views.sql e 03_python_sql_validation.sql antes da importação.")
        # Evita cargas simultâneas e alterações concorrentes durante a reconciliação.
        cur.execute(sql.SQL("LOCK TABLE {} IN SHARE ROW EXCLUSIVE MODE").format(
            sql.SQL(", ").join(sql.Identifier("olist", name) for name in SPEC)))
        for table in SPEC:
            cur.execute(sql.SQL("SELECT count(*) FROM {}").format(sql.Identifier("olist", table)))
            if cur.fetchone()[0] != 0:
                raise RuntimeError(f"olist.{table} já contém dados. A carga foi interrompida sem apagar nada. Se já importou, siga para as consultas.")
        for table, columns in SPEC.items():
            frame = frames[table]
            names = [c["name"] for c in columns]
            statement = sql.SQL("COPY {} ({}) FROM STDIN").format(
                sql.Identifier("olist", table), sql.SQL(", ").join(map(sql.Identifier, names)))
            with cur.copy(statement) as copy:
                for row in frame.itertuples(index=False, name=None):
                    copy.write_row(tuple(native(value, column["type"]) for value, column in zip(row, columns)))
            cur.execute(sql.SQL("SELECT count(*) FROM {}").format(sql.Identifier("olist", table)))
            actual = cur.fetchone()[0]
            if actual != len(frame):
                raise RuntimeError(f"Contagem divergente em {table}: {actual} / {len(frame)}")
            print(f"  {table}: {actual:,} linhas carregadas na transação.")
        cur.execute("SELECT count(*) FROM olist.v_orders_analysis")
        if cur.fetchone()[0] != len(frames["orders"]):
            raise RuntimeError("A view não preservou a quantidade de pedidos.")
        cur.execute("SELECT field, count(*) FROM olist.v_reconciliation_detail GROUP BY field ORDER BY field")
        discrepancies = cur.fetchall()
        if discrepancies:
            raise RuntimeError(f"SQL difere da referência Python: {discrepancies}. Toda a carga será desfeita; confira a versão dos arquivos.")
        cur.execute("SELECT version()")
        postgres_version = cur.fetchone()[0]
    return postgres_version


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, default=Path("data/processed"))
    parser.add_argument("--host", default="localhost")
    parser.add_argument("--port", type=int, default=5432)
    parser.add_argument("--database", default="olist_analytics")
    parser.add_argument("--user", default="postgres")
    parser.add_argument("--check-only", action="store_true", help="Verifica os arquivos sem se conectar ao banco.")
    args = parser.parse_args()
    frames, hashes = load_inputs(args.input)
    print("Arquivos verificados:")
    for name, frame in frames.items():
        print(f"  {name}: {len(frame):,} linhas")
    if args.check_only:
        print("Pré-verificação concluída. Nenhuma conexão ou alteração no banco.")
        return
    print(f"Destino: {args.host}:{args.port}/{args.database}; usuário {args.user}")
    password = getpass.getpass("Senha do PostgreSQL (não aparece ao digitar): ")
    with psycopg.connect(host=args.host, port=args.port, dbname=args.database,
                         user=args.user, password=password, connect_timeout=10) as conn:
        postgres_version = import_frames(conn, frames)
        # O contexto só confirma a transação se todas as validações passaram.
    print("IMPORTAÇÃO CONFIRMADA. Contagens e referência Python/SQL conferidas.")
    report = {
        "executado_em_utc": datetime.now(timezone.utc).isoformat(),
        "database": args.database, "sha256": hashes,
        "linhas": {name: len(frame) for name, frame in frames.items()},
        "postgresql": postgres_version, "python": platform.python_version(),
        "pandas": pd.__version__, "psycopg": psycopg.__version__,
        "reconciliacao": "zero divergencias nos campos contratuais por pedido",
        "tolerancia_delivery_days": 1e-8,
    }
    target = Path("reports/sql")
    target.mkdir(parents=True, exist_ok=True)
    filename = target / ("importacao_" + datetime.now().strftime("%Y%m%d_%H%M%S_%f") + ".json")
    filename.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print("Relatório:", filename)


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(f"\nNão foi possível concluir: {exc}", file=sys.stderr)
        sys.exit(1)
