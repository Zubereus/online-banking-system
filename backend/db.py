import os

import mysql.connector
from dotenv import load_dotenv

load_dotenv()


def get_connection(database: str | None = "__ENV__"):
    target_db = os.getenv("DB_NAME", "banking_online_app") if database == "__ENV__" else database
    connect_args = {
        "host": os.getenv("DB_HOST", "127.0.0.1"),
        "port": int(os.getenv("DB_PORT", "3306")),
        "user": os.getenv("DB_USER", "root"),
        "password": os.getenv("DB_PASSWORD", ""),
        "autocommit": False,
    }

    if target_db:
        connect_args["database"] = target_db

    return mysql.connector.connect(**connect_args)
