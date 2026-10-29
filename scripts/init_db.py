from pathlib import Path
import sys

from dotenv import load_dotenv
import mysql.connector

load_dotenv()

ROOT = Path(__file__).resolve().parents[1]
SQL_DIR = ROOT / "SQL"
sys.path.insert(0, str(ROOT))

from backend.db import get_connection


def split_sql_statements(text: str):
    delimiter = ";"
    buffer = []

    for raw_line in text.splitlines():
        line = raw_line.strip()

        if not line or line.startswith("--"):
            continue

        if line.upper().startswith("DELIMITER "):
            delimiter = line.split(" ", 1)[1]
            continue

        buffer.append(raw_line)
        candidate = "\n".join(buffer).strip()

        if candidate.endswith(delimiter):
            statement = candidate[: -len(delimiter)].strip()
            if statement:
                yield statement
            buffer = []

    if buffer:
        trailing = "\n".join(buffer).strip()
        if trailing:
            yield trailing


def execute_file(conn: mysql.connector.MySQLConnection, file_path: Path):
    content = file_path.read_text(encoding="utf-8")
    cur = conn.cursor()
    try:
        for idx, statement in enumerate(split_sql_statements(content), start=1):
            try:
                cur.execute(statement)
            except Exception as ex:
                preview = " ".join(statement.strip().splitlines()[:2])
                raise RuntimeError(
                    f"Error in {file_path.name} statement #{idx}: {preview[:220]}"
                ) from ex
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        cur.close()


def main():
    conn_server = get_connection(database=None)
    cur_server = conn_server.cursor()

    try:
        cur_server.execute("CREATE DATABASE IF NOT EXISTS banking")
        conn_server.commit()
    finally:
        cur_server.close()
        conn_server.close()

    conn_db = get_connection(database="banking")

    try:
        execute_file(conn_db, SQL_DIR / "delete_all_table.sql")
        execute_file(conn_db, SQL_DIR / "banking.sql")
        execute_file(conn_db, SQL_DIR / "trigger_TT.sql")
        execute_file(conn_db, SQL_DIR / "procedure.sql")
        execute_file(conn_db, SQL_DIR / "procedure_TT.sql")
        execute_file(conn_db, SQL_DIR / "funct.sql")
        execute_file(conn_db, SQL_DIR / "data.sql")
        execute_file(conn_db, SQL_DIR / "admin_dataset.sql")
        print("Database initialized successfully.")
    finally:
        conn_db.close()


if __name__ == "__main__":
    main()
