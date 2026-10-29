import os
import random
import json
import re
import secrets
from datetime import datetime, timezone, timedelta
from pathlib import Path
from typing import Any
from dotenv import load_dotenv
from flask import Flask, jsonify, request, send_from_directory
from flask_cors import CORS

from db import get_connection as _base_get_connection


def get_connection(database: str | None = "__ENV__"):
    target_db = "banking" if database == "__ENV__" else database
    return _base_get_connection(database=target_db)

load_dotenv()

ROOT_DIR = Path(__file__).resolve().parents[1]
CREATED_ACCOUNTS_FILE = ROOT_DIR / "data" / "created_accounts.jsonl"
ADMIN_ACCESS_USERNAME = os.getenv("ADMIN_ACCESS_USERNAME", "admin123")
ADMIN_ACCESS_PASSWORD = os.getenv("ADMIN_ACCESS_PASSWORD", "AdminAuthority@")
_ADMIN_SESSIONS: dict[str, dict[str, str]] = {}
GMT_PLUS_7 = timezone(timedelta(hours=7))
LEGACY_LOAN_AMOUNT_BY_CODE = {
    "A": 50000000.0,
    "B": 100000000.0,
    "C": 200000000.0,
}

app = Flask(__name__, static_folder=str(ROOT_DIR), static_url_path="")
CORS(app)


def _call_proc_fetchone(cur, proc_name: str, params: tuple[Any, ...] | list[Any] | None = None) -> dict[str, Any]:
    cur.callproc(proc_name, params or ())
    for result in cur.stored_results():
        return result.fetchone() or {}
    return {}


def _call_proc_fetchall(cur, proc_name: str, params: tuple[Any, ...] | list[Any] | None = None) -> list[dict[str, Any]]:
    cur.callproc(proc_name, params or ())
    for result in cur.stored_results():
        return result.fetchall() or []
    return []


def _generate_unique_transaction_id(cur) -> str:
    cur.execute("CALL api_generate_transaction_id(@p_id)")
    cur.execute("SELECT @p_id AS id")
    row = cur.fetchone() or {}
    v = row.get("id")
    if not v:
        raise RuntimeError("Unable to generate transaction id from database.")
    return str(v)


def _generate_unique_loan_id(cur) -> str:
    cur.execute("CALL api_generate_loan_id(@p_id)")
    cur.execute("SELECT @p_id AS id")
    row = cur.fetchone() or {}
    v = row.get("id")
    if not v:
        raise RuntimeError("Unable to generate loan id from database.")
    return str(v)


def _next_numeric_account_number(cur) -> str:
    cur.execute("CALL api_next_numeric_account_number(@p_acc)")
    cur.execute("SELECT @p_acc AS accountNumber")
    row = cur.fetchone() or {}
    v = row.get("accountNumber")
    if not v:
        raise RuntimeError("Unable to generate next account number from database.")
    return str(v)


def _record_transaction(
    cur,
    *,
    transaction_code: str,
    sender_account: str,
    receiver_account: str,
    amount: float,
    fee: float = 0,
    transaction_type: str = "Trans",
    bill_id: str | None = None,
    repayment_id: str | None = None,
    loan_id: str | None = None,
) -> None:
    # Map parameters to ThemGiaoDich stored procedure signature
    cur.execute(
        "CALL ThemGiaoDich(%s, %s, %s, %s, %s, %s, %s, %s, %s)",
        (
            transaction_code,
            sender_account,
            receiver_account,
            amount,
            fee,
            transaction_type,
            bill_id,
            repayment_id,
            loan_id,
        ),
    )


def _sql_message(ex: Exception) -> str:
    message = str(ex).strip()
    if not message:
        return "Database operation failed."
    return message


def _append_created_account_log(payload: dict[str, Any] | None = None, **kwargs: Any) -> None:
    entry = dict(payload or {})
    if kwargs:
        entry.update(kwargs)
    CREATED_ACCOUNTS_FILE.parent.mkdir(parents=True, exist_ok=True)
    with CREATED_ACCOUNTS_FILE.open("a", encoding="utf-8") as f:
        f.write(json.dumps(entry, ensure_ascii=False) + "\n")


def _parse_vnd_number(value: Any) -> float:
    if isinstance(value, (int, float)):
        return float(value)
    text = str(value or "").strip()
    if not text:
        return 0.0
    cleaned = re.sub(r"[^0-9,.-]", "", text)
    # Remove dots (thousand separators) and replace comma with dot (decimal separator)
    cleaned = cleaned.replace(".", "").replace(",", ".")
    return float(cleaned)


def _calculate_transaction_fee(amount: float) -> float:
    return round(float(amount) * 0.02, 2)


def _format_datetime_gmt_plus_7(value: Any) -> str | None:
    if not value:
        return None
    if isinstance(value, datetime):
        dt = value
    else:
        try:
            dt = datetime.fromisoformat(str(value))
        except ValueError:
            return str(value)
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    local_dt = dt.astimezone(GMT_PLUS_7)
    return local_dt.strftime("%Y-%m-%d %H:%M:%S")


def _issue_admin_session(*, admin_id: str, username: str, full_name: str, ma_so: str) -> str:
    token = secrets.token_urlsafe(32)
    _ADMIN_SESSIONS[token] = {
        "adminId": admin_id,
        "username": username,
        "fullName": full_name,
        "maSo": ma_so,
    }
    return token


def _admin_session_or_error() -> tuple[dict[str, str] | None, Any | None]:
    token = (request.headers.get("X-Admin-Session") or request.args.get("adminSession") or "").strip()
    if not token:
        auth_header = request.headers.get("Authorization", "")
        if auth_header.startswith("Bearer "):
            token = auth_header[7:].strip()
    if not token:
        return None, (jsonify({"message": "Admin session token is required."}), 401)
    session = _ADMIN_SESSIONS.get(token)
    if not session:
        return None, (jsonify({"message": "Admin session is invalid or expired."}), 401)
    return session, None


def _legacy_loan_code_from_amount(amount: float) -> str:
    for code, value in LEGACY_LOAN_AMOUNT_BY_CODE.items():
        if abs(float(value) - float(amount)) < 0.5:
            return code
    return "C"


def _loan_amount_from_any(value: Any) -> float:
    if isinstance(value, (int, float)):
        return float(value)
    text = str(value or "").strip().upper()
    if text in LEGACY_LOAN_AMOUNT_BY_CODE:
        return LEGACY_LOAN_AMOUNT_BY_CODE[text]
    return _parse_vnd_number(text)


def _derive_repayment_status(*, due_date: Any, paid_date: Any) -> str:
    if not paid_date:
        return "Chua_thanh_toan"
    if isinstance(paid_date, datetime):
        paid = paid_date.date()
    else:
        paid = datetime.fromisoformat(str(paid_date)).date()
    if isinstance(due_date, datetime):
        due = due_date.date()
    else:
        due = datetime.fromisoformat(str(due_date)).date()
    return "Da_thanh_toan" if paid <= due else "Qua_han"


def _create_repayment_transaction(
    cur,
    *,
    account_number: str,
    amount: float,
    fee: float = 0,
    receiver_account: str = "0000000001",
    repayment_id: str | None = None,
    loan_id: str | None = None,
) -> str:
    tx_id = _generate_unique_transaction_id(cur)
    _record_transaction(
        cur,
        transaction_code=tx_id,
        sender_account=account_number,
        receiver_account=receiver_account,
        amount=amount,
        fee=fee,
        transaction_type="Loan",
        repayment_id=repayment_id,
        loan_id=loan_id,
    )
    return tx_id


def _refresh_loan_status(cur, *, loan_id: str) -> str:
    cur.execute(
        """
        SELECT
            COUNT(*) AS total_rows,
            SUM(CASE WHEN Ngay_tra_thuc_te IS NOT NULL THEN 1 ELSE 0 END) AS paid_rows,
            SUM(CASE WHEN Ngay_tra_thuc_te IS NULL AND Ngay_tra_du_kien < CURDATE() THEN 1 ELSE 0 END) AS overdue_rows
        FROM Thanh_toan_khoan_vay
        WHERE Ma_khoan_vay = %s
        """,
        (loan_id,),
    )
    row = cur.fetchone() or {}
    total_rows = int(row.get("total_rows") or 0)
    paid_rows = int(row.get("paid_rows") or 0)
    overdue_rows = int(row.get("overdue_rows") or 0)

    if total_rows > 0 and paid_rows >= total_rows:
        status = "Da_thanh_toan"
    elif overdue_rows > 0:
        status = "Qua_han"
    else:
        status = "Hoat_dong"

    cur.execute("UPDATE Khoan_vay SET Trang_thai = %s WHERE Ma_khoan_vay = %s", (status, loan_id))
    return status


def _is_missing_procedure_error(ex: Exception, procedure_name: str) -> bool:
    message = str(ex).lower()
    return "does not exist" in message and procedure_name.lower() in message


def _deactivate_account_fallback(cur, *, admin_ma_so: str, account_number: str) -> None:
    cur.execute("SELECT 1 FROM Quan_tri_vien WHERE Ma_so = %s LIMIT 1", (admin_ma_so,))
    if not cur.fetchone():
        raise RuntimeError("Admin account is invalid.")

    cur.execute(
        """
        UPDATE Tai_khoan
        SET Trang_thai = 'DEACTIVE', Ma_so = %s
        WHERE So_tai_khoan = %s
        """,
        (admin_ma_so, account_number),
    )
    if cur.rowcount == 0:
        raise RuntimeError("Account does not exist.")


def _activate_account_fallback(cur, *, admin_ma_so: str, account_number: str) -> None:
    cur.execute("SELECT 1 FROM Quan_tri_vien WHERE Ma_so = %s LIMIT 1", (admin_ma_so,))
    if not cur.fetchone():
        raise RuntimeError("Admin account is invalid.")

    cur.execute(
        """
        UPDATE Tai_khoan
        SET Trang_thai = 'ACTIVE', Ma_so = %s
        WHERE So_tai_khoan = %s
        """,
        (admin_ma_so, account_number),
    )
    if cur.rowcount == 0:
        raise RuntimeError("Account does not exist.")


@app.get("/api/card-types")
def get_card_types():
    conn = get_connection()
    cur = conn.cursor(dictionary=True, buffered=True)

    try:
        rows = _call_proc_fetchall(cur, "api_get_card_types")
        rows = [row["Ten_the"] for row in rows]
    finally:
        cur.close()
        conn.close()

    return jsonify(rows)


@app.post("/api/cards")
def create_card():
    data: dict[str, Any] = request.get_json(silent=True) or {}
    account_number = str(data.get("accountNumber", "")).strip()
    card_type = str(data.get("cardType", "")).strip()
    cccd = str(data.get("cccd", "")).strip()

    if not account_number or not card_type:
        return jsonify({"message": "accountNumber and cardType are required."}), 400

    conn = get_connection()
    cur = conn.cursor(dictionary=True)

    try:
        result = _call_proc_fetchone(cur, "api_create_card", (account_number, card_type, cccd or None))
        conn.commit()
    except Exception as ex:
        conn.rollback()
        return jsonify({"message": _sql_message(ex)}), 400
    finally:
        cur.close()
        conn.close()

    return jsonify(
        {
            "message": "Credit card created successfully.",
            "cardNumber": result.get("cardNumber"),
            "cardType": result.get("cardType"),
            "accountNumber": result.get("accountNumber"),
        }
    )


@app.post("/api/transactions")
def create_transaction():
    data: dict[str, Any] = request.get_json(silent=True) or {}
    sender_account = str(data.get("senderAccount", "")).strip()
    receiver_account = str(data.get("receiverAccount", "")).strip()
    promotion_code = str(data.get("promotionCode", "")).strip()
    cccd = str(data.get("cccd", "")).strip()

    try:
        amount = _parse_vnd_number(data.get("amount", 0))
    except (TypeError, ValueError):
        return jsonify({"message": "Amount must be a valid VND number."}), 400

    if not sender_account or not receiver_account:
        return jsonify({"message": "senderAccount and receiverAccount are required."}), 400

    if amount <= 0:
        return jsonify({"message": "Amount must be greater than 0."}), 400

    fee = _calculate_transaction_fee(amount)

    conn = get_connection()
    cur = conn.cursor(dictionary=True)

    try:
        result = _call_proc_fetchone(
            cur,
            "api_create_transaction",
            (
                sender_account,
                receiver_account,
                amount,
                fee,
                cccd or None,
                promotion_code or None,
            ),
        )
        conn.commit()
        transaction_code = result.get("transactionId")
        remaining_balance = float(result.get("remainingBalance") or 0)
        remaining_limit = float(result.get("remainingLimit") or 0)
    except Exception as ex:
        conn.rollback()
        return jsonify({"message": _sql_message(ex)}), 400
    finally:
        cur.close()
        conn.close()

    return jsonify(
        {
            "message": "Transaction created successfully.",
            "transactionId": transaction_code,
            "senderAccount": sender_account,
            "receiverAccount": receiver_account,
            "amount": amount,
            "fee": fee,
            "promotionCode": promotion_code or None,
            "remainingBalance": remaining_balance,
            "remainingLimit": remaining_limit,
        }
    )


@app.get("/api/health")
def health():
    """Health check endpoint for session validation."""
    try:
        conn = get_connection()
        cur = conn.cursor(dictionary=True)
        cur.execute("SELECT 1 AS status")
        cur.fetchone()
        cur.close()
        conn.close()
        return jsonify({"status": "ok"}), 200
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500


@app.post("/api/auth/login")
def login():
    data: dict[str, Any] = request.get_json(silent=True) or {}
    username = str(data.get("username", "")).strip()
    password = str(data.get("password", "")).strip()

    if not username or not password:
        return jsonify({"message": "Username and password are required."}), 400

    conn = get_connection()
    cur = conn.cursor(dictionary=True)

    try:
        cur.execute(
            """
                        SELECT tk.So_tai_khoan, tk.Ten_khach_hang, tk.Ten_dang_nhap, tk.CCCD
                        FROM Tai_khoan tk
                        WHERE tk.Ten_dang_nhap = %s
                            AND tk.Mat_khau = %s
                            AND tk.Trang_thai <> 'REMOVED'
                        LIMIT 1
            """,
            (username, password),
        )
        row = cur.fetchone()
    finally:
        cur.close()
        conn.close()

    if not row:
        return jsonify({"message": "Invalid username or password."}), 401

    return jsonify(
        {
            "message": "Login success.",
            "user": {
                "username": row["Ten_dang_nhap"],
                "fullName": row["Ten_khach_hang"],
                "accountNumber": row["So_tai_khoan"],
                "cccd": row["CCCD"],
            },
        }
    )


@app.post("/api/auth/register")
def register_account():
    data: dict[str, Any] = request.get_json(silent=True) or {}

    first_name = str(data.get("firstName", "")).strip()
    middle_name = str(data.get("middleName", "")).strip()
    last_name = str(data.get("lastName", "")).strip()
    cccd = str(data.get("cccd", "")).strip()
    gender = str(data.get("gender", "")).strip()
    nationality = str(data.get("nationality", "")).strip() or "Viet Nam"
    dob = str(data.get("dob", "")).strip()
    phone = str(data.get("phone", "")).strip()
    email = str(data.get("email", "")).strip()
    referrer_cccd = str(data.get("referrerCccd", "")).strip()
    username = str(data.get("username", "")).strip()
    password = str(data.get("password", "")).strip()

    if not all([first_name, last_name, cccd, gender, dob, phone, username, password]):
        return jsonify({"message": "Missing required fields for account creation."}), 400

    if len(password) < 8:
        return jsonify({"message": "Password must be at least 8 characters."}), 400

    if len(cccd) != 12 or not cccd.isdigit():
        return jsonify({"message": "CCCD must contain exactly 12 digits."}), 400

    if len(phone) != 10 or not phone.isdigit():
        return jsonify({"message": "Phone must contain exactly 10 digits."}), 400

    if email:
        if len(email) > 50 or " " in email or not re.match(r"^[^\s@]+@[^\s@]+\.[^\s@]+$", email):
            return jsonify({"message": "Email must be valid and at most 50 characters."}), 400

    if referrer_cccd:
        if len(referrer_cccd) != 12 or not referrer_cccd.isdigit():
            return jsonify({"message": "Referrer CCCD must contain exactly 12 digits."}), 400
        if referrer_cccd == cccd:
            return jsonify({"message": "Referrer CCCD cannot match the new customer CCCD."}), 400

    if gender not in {"Nam", "Nu"}:
        return jsonify({"message": "Gender must be Nam or Nu."}), 400

    full_name = " ".join([part for part in [first_name, middle_name, last_name] if part]).strip()

    conn = get_connection()
    cur = conn.cursor(dictionary=True)

    try:
        cur.execute("SELECT Ma_so FROM Quan_tri_vien ORDER BY Ma_so LIMIT 1")
        admin = cur.fetchone()
        if not admin:
            conn.rollback()
            return jsonify({"message": "No administrator configured in database."}), 500

        account_number = _next_numeric_account_number(cur)

        cur.execute(
            """
            INSERT INTO Nguoi (CCCD, Ho, Ten_lot, Ten, Quoc_tich, Gioi_tinh, Ngay_sinh)
            VALUES (%s, %s, %s, %s, %s, %s, %s)
            """,
            (cccd, first_name, middle_name or None, last_name, nationality, gender, dob),
        )
        cur.execute("INSERT INTO Nguoi_dung (CCCD) VALUES (%s)", (cccd,))

        if referrer_cccd:
            cur.execute("SELECT 1 FROM Nguoi WHERE CCCD = %s LIMIT 1", (referrer_cccd,))
            if not cur.fetchone():
                conn.rollback()
                return jsonify({"message": "Referrer CCCD does not exist."}), 404
            cur.execute(
                "INSERT INTO Gioi_thieu (CCCD_Nguoi_gioi_thieu, CCCD_Khach_moi) VALUES (%s, %s)",
                (referrer_cccd, cccd),
            )

        cur.execute("INSERT INTO So_dien_thoai (CCCD, So_dien_thoai) VALUES (%s, %s)", (cccd, phone))

        if email:
            cur.execute("INSERT INTO Tai_khoan_email (CCCD, Tk_email) VALUES (%s, %s)", (cccd, email))

        cur.execute(
            """
            INSERT INTO Tai_khoan
            (So_tai_khoan, Ten_khach_hang, Ten_dang_nhap, Mat_khau, CCCD, Trang_thai, Ma_so)
            VALUES (%s, %s, %s, %s, %s, 'ACTIVE', %s)
            """,
            (account_number, full_name, username, password, cccd, admin["Ma_so"]),
        )
        cur.execute(
            """
            INSERT INTO Tai_khoan_thanh_toan (So_tai_khoan, Han_muc, So_du)
            VALUES (%s, %s, %s)
            """,
            (account_number, 50000000, 0),
        )
        cur.execute(
            "INSERT INTO Tai_khoan_giao_dich (So_tai_khoan, Loai_tk) VALUES (%s, 'Noi_bo')",
            (account_number,),
        )

        conn.commit()
    except Exception as ex:
        conn.rollback()
        return jsonify({"message": _sql_message(ex)}), 400
    finally:
        cur.close()
        conn.close()

    try:
        _append_created_account_log(
            account_number=account_number,
            username=username,
            full_name=full_name,
            cccd=cccd,
            phone=phone,
            email=email,
        )
    except Exception:
        # Registration already succeeded in DB; do not fail response if file logging fails.
        pass

    return jsonify(
        {
            "message": "Account created successfully.",
            "accountNumber": account_number,
            "username": username,
            "fullName": full_name,
            "cccd": cccd,
        }
    )


@app.post("/api/accounts/create")
def create_additional_account():
    data: dict[str, Any] = request.get_json(silent=True) or {}

    cccd = str(data.get("cccd", "")).strip()
    username = str(data.get("username", "")).strip()
    password = str(data.get("password", "")).strip()

    if not cccd or not username or not password:
        return jsonify({"message": "cccd, username, and password are required."}), 400

    if len(password) < 8:
        return jsonify({"message": "Password must be at least 8 characters."}), 400

    if len(cccd) != 12 or not cccd.isdigit():
        return jsonify({"message": "CCCD must contain exactly 12 digits."}), 400

    conn = get_connection()
    cur = conn.cursor(dictionary=True)

    try:
        cur.execute(
            "SELECT Ten_khach_hang FROM Tai_khoan WHERE CCCD = %s ORDER BY So_tai_khoan LIMIT 1",
            (cccd,),
        )
        owner = cur.fetchone()
        if not owner:
            conn.rollback()
            return jsonify({"message": "Customer not found for this CCCD."}), 404

        cur.execute("SELECT Ma_so FROM Quan_tri_vien ORDER BY RAND() LIMIT 1")
        admin = cur.fetchone()
        if not admin:
            conn.rollback()
            return jsonify({"message": "No administrator configured in database."}), 500

        last_error: Exception | None = None
        account_number = ""

        for _ in range(6):
            try:
                account_number = _next_numeric_account_number(cur)

                cur.execute(
                    """
                    INSERT INTO Tai_khoan
                    (So_tai_khoan, Ten_khach_hang, Ten_dang_nhap, Mat_khau, CCCD, Trang_thai, Ma_so)
                    VALUES (%s, %s, %s, %s, %s, 'ACTIVE', %s)
                    """,
                    (account_number, owner["Ten_khach_hang"], username, password, cccd, admin["Ma_so"]),
                )
                cur.execute(
                    """
                    INSERT INTO Tai_khoan_thanh_toan (So_tai_khoan, Han_muc, So_du)
                    VALUES (%s, %s, %s)
                    """,
                    (account_number, 50000000, 0),
                )
                cur.execute(
                    "INSERT INTO Tai_khoan_giao_dich (So_tai_khoan, Loai_tk) VALUES (%s, 'Noi_bo')",
                    (account_number,),
                )
                conn.commit()
                break
            except Exception as ex:
                conn.rollback()
                last_error = ex
                message = str(ex)
                if "Duplicate entry" in message and ("PRIMARY" in message or "So_tai_khoan" in message):
                    continue
                return jsonify({"message": _sql_message(ex)}), 400
        else:
            return jsonify({"message": _sql_message(last_error or RuntimeError("Cannot allocate account number."))}), 500

    finally:
        cur.close()
        conn.close()

    return jsonify(
        {
            "message": "Additional account created successfully.",
            "accountNumber": account_number,
            "username": username,
            "cccd": cccd,
        }
    )


@app.post("/api/savings-accounts/create")
def create_savings_account():
    data: dict[str, Any] = request.get_json(silent=True) or {}

    cccd = str(data.get("cccd", "")).strip()
    username = str(data.get("username", "")).strip()
    password = str(data.get("password", "")).strip()
    receive_method_raw = str(data.get("receiveMethod", "")).strip()

    try:
        term_months = int(data.get("termMonths", 0))
    except (TypeError, ValueError):
        return jsonify({"message": "termMonths must be a valid integer."}), 400

    try:
        interest_rate = float(data.get("interestRate", 0))
    except (TypeError, ValueError):
        return jsonify({"message": "interestRate must be a valid decimal."}), 400

    try:
        amount = _parse_vnd_number(data.get("amount", 0))
    except (TypeError, ValueError):
        return jsonify({"message": "amount must be a valid VND number."}), 400

    if not cccd or not username or not password or not receive_method_raw:
        return jsonify({"message": "cccd, username, password, termMonths, interestRate, amount, and receiveMethod are required."}), 400

    if len(password) < 8:
        return jsonify({"message": "Password must be at least 8 characters."}), 400

    if len(cccd) != 12 or not cccd.isdigit():
        return jsonify({"message": "CCCD must contain exactly 12 digits."}), 400

    if term_months <= 0:
        return jsonify({"message": "termMonths must be greater than 0."}), 400

    if interest_rate < 0 or interest_rate > 0.2:
        return jsonify({"message": "interestRate must be between 0 and 0.2."}), 400

    if amount < 0:
        return jsonify({"message": "amount cannot be negative."}), 400

    receive_method = receive_method_raw.title()
    if receive_method not in {"Online", "Offline"}:
        return jsonify({"message": "receiveMethod must be Online or Offline."}), 400

    conn = get_connection()
    cur = conn.cursor(dictionary=True)

    account_number = ""

    try:
        cur.execute(
            """
            CALL tao_tai_khoan_tiet_kiem(
                %s, %s, %s, %s, %s, %s, %s, @p_so_tai_khoan
            )
            """,
            (cccd, username, password, term_months, interest_rate, amount, receive_method),
        )
        cur.execute("SELECT @p_so_tai_khoan AS account_number")
        out_row = cur.fetchone() or {}
        account_number = str(out_row.get("account_number") or "").strip()
        if not account_number:
            conn.rollback()
            return jsonify({"message": "Failed to create savings account."}), 500

        conn.commit()
    except Exception as ex:
        conn.rollback()
        return jsonify({"message": _sql_message(ex)}), 400
    finally:
        cur.close()
        conn.close()

    return jsonify(
        {
            "message": "Savings account created successfully.",
            "accountNumber": account_number,
            "username": username,
            "cccd": cccd,
            "termMonths": term_months,
            "interestRate": interest_rate,
            "amount": amount,
            "receiveMethod": receive_method,
        }
    )


@app.post("/api/loans/create")
def create_loan():
    data: dict[str, Any] = request.get_json(silent=True) or {}

    cccd = str(data.get("cccd", "")).strip()
    account_number = str(data.get("accountNumber", "")).strip()

    try:
        term_months = int(data.get("termMonths", 0))
    except (TypeError, ValueError):
        return jsonify({"message": "termMonths must be a valid integer."}), 400

    try:
        principal_cycle = int(data.get("principalCycle", 0))
    except (TypeError, ValueError):
        return jsonify({"message": "principalCycle must be a valid integer."}), 400

    try:
        interest_rate = float(data.get("interestRate", 0))
    except (TypeError, ValueError):
        return jsonify({"message": "interestRate must be a valid decimal."}), 400

    try:
        loan_amount = _parse_vnd_number(data.get("loanAmount", 0))
    except (TypeError, ValueError):
        return jsonify({"message": "loanAmount must be a valid VND number."}), 400

    if not cccd or not account_number:
        return jsonify({"message": "cccd, loanAmount, termMonths, principalCycle, interestRate, and accountNumber are required."}), 400

    if len(cccd) != 12 or not cccd.isdigit():
        return jsonify({"message": "CCCD must contain exactly 12 digits."}), 400

    if term_months <= 0:
        return jsonify({"message": "termMonths must be greater than 0."}), 400

    if principal_cycle <= 0:
        return jsonify({"message": "principalCycle must be greater than 0."}), 400

    if interest_rate < 0 or interest_rate > 0.2:
        return jsonify({"message": "interestRate must be between 0 and 0.2."}), 400

    if loan_amount <= 0:
        return jsonify({"message": "loanAmount must be greater than 0."}), 400

    if account_number == "0000000001":
        return jsonify({"message": "Cannot create loan for system account."}), 400

    conn = get_connection()
    cur = conn.cursor(dictionary=True)
    loan_id = ""

    try:
        cur.execute(
            """
            SELECT tk.So_tai_khoan
            FROM Tai_khoan tk
            WHERE tk.So_tai_khoan = %s
              AND tk.CCCD = %s
            LIMIT 1
            """,
            (account_number, cccd),
        )
        owner_account = cur.fetchone()
        if not owner_account:
            conn.rollback()
            return jsonify({"message": "Selected account does not belong to this customer."}), 404

        cur.execute("SELECT Ma_so FROM Quan_tri_vien ORDER BY Ma_so LIMIT 1")
        admin = cur.fetchone()
        if not admin:
            conn.rollback()
            return jsonify({"message": "No administrator configured in database."}), 500

        # Delegate loan creation to the database stored procedure `sp_ThemKhoanVay`.
        last_error: Exception | None = None
        for _ in range(6):
            try:
                loan_id = _generate_unique_loan_id(cur)
                cur.callproc(
                    "sp_ThemKhoanVay",
                    (
                        loan_id,
                        interest_rate,
                        float(loan_amount),
                        term_months,
                        principal_cycle,
                        account_number,
                        admin["Ma_so"],
                        datetime.now(GMT_PLUS_7).date(),
                    ),
                )
                break
            except Exception as ex:
                last_error = ex
                message = str(ex)
                if "Duplicate entry" in message and ("PRIMARY" in message or "Ma_khoan_vay" in message):
                    continue
                raise
        else:
            raise RuntimeError(_sql_message(last_error or RuntimeError("Cannot allocate loan id.")))

        cur.execute(
            "SELECT So_du FROM Tai_khoan_thanh_toan WHERE So_tai_khoan = %s LIMIT 1",
            (account_number,),
        )
        payment_account = cur.fetchone()
        if not payment_account:
            conn.rollback()
            return jsonify({"message": "Selected account is not a payment account."}), 404

        cur.execute(
            "UPDATE Tai_khoan_thanh_toan SET So_du = So_du + %s WHERE So_tai_khoan = %s",
            (loan_amount, account_number),
        )
        disbursement_transaction_id = _generate_unique_transaction_id(cur)
        _record_transaction(
            cur,
            transaction_code=disbursement_transaction_id,
            sender_account="0000000001",
            receiver_account=account_number,
            amount=loan_amount,
            fee=0,
            transaction_type="Trans",
        )

        # Generate repayment schedule for the new loan
        cur.execute("CALL GenerateLoanRepayments(%s)", (loan_id,))

        conn.commit()
    except Exception as ex:
        conn.rollback()
        return jsonify({"message": _sql_message(ex)}), 400
    finally:
        cur.close()
        conn.close()

    remaining_loan = float(loan_amount) * (1 + interest_rate * (term_months / 12.0))

    return jsonify(
        {
            "message": "Loan created successfully.",
            "loanId": loan_id,
            "disbursementTransactionId": disbursement_transaction_id,
            "disbursedAmount": float(loan_amount),
            "loanAmount": float(loan_amount),
            "termMonths": term_months,
            "principalCycle": principal_cycle,
            "interestRate": interest_rate,
            "accountNumber": account_number,
            "remainingLoan": remaining_loan,
        }
    )


@app.post("/api/admin/access-gate")
def admin_access_gate():
    data: dict[str, Any] = request.get_json(silent=True) or {}
    username = str(data.get("username", "")).strip()
    password = str(data.get("password", "")).strip()

    if not username or not password:
        return jsonify({"message": "Username and password are required."}), 400

    if username != ADMIN_ACCESS_USERNAME or password != ADMIN_ACCESS_PASSWORD:
        return jsonify({"message": "Invalid access credentials for admin portal."}), 401

    return jsonify({"message": "Admin portal access granted."})


@app.post("/api/admin/login")
def admin_login():
    data: dict[str, Any] = request.get_json(silent=True) or {}
    username = str(data.get("username", "")).strip()
    password = str(data.get("password", "")).strip()

    if not username or not password:
        return jsonify({"message": "Username and password are required."}), 400

    conn = get_connection()
    cur = conn.cursor(dictionary=True)

    try:
        cur.execute(
            """
            SELECT qtv.Ten_dang_nhap AS username,
                   qtv.Ma_so,
                   n.CCCD,
                   CONCAT_WS(' ', n.Ho, n.Ten_lot, n.Ten) AS full_name,
                   n.Gioi_tinh,
                   n.Quoc_tich,
                   GROUP_CONCAT(DISTINCT sdt.So_dien_thoai ORDER BY sdt.So_dien_thoai SEPARATOR ', ') AS phone_numbers,
                   GROUP_CONCAT(DISTINCT em.Tk_email ORDER BY em.Tk_email SEPARATOR ', ') AS emails
            FROM Quan_tri_vien qtv
            JOIN Nguoi n ON n.CCCD = qtv.CCCD
            LEFT JOIN So_dien_thoai sdt ON sdt.CCCD = n.CCCD
            LEFT JOIN Tai_khoan_email em ON em.CCCD = n.CCCD
            WHERE qtv.Ten_dang_nhap = %s
              AND qtv.Mat_khau = %s
            GROUP BY qtv.Ten_dang_nhap, qtv.Ma_so, n.CCCD, n.Ho, n.Ten_lot, n.Ten, n.Gioi_tinh, n.Quoc_tich
            LIMIT 1
            """,
            (username, password),
        )
        row = cur.fetchone()
    finally:
        cur.close()
        conn.close()

    if not row:
        return jsonify({"message": "Invalid admin username or password."}), 401

    full_name = str(row.get("full_name") or "Administrator").strip() or "Administrator"
    token = _issue_admin_session(
        admin_id=str(row["Ma_so"]),
        username=str(row["username"]),
        full_name=full_name,
        ma_so=str(row["Ma_so"]),
    )

    return jsonify(
        {
            "message": "Admin login success.",
            "token": token,
            "admin": {
                "username": row["username"],
                "fullName": full_name,
                "maSo": row["Ma_so"],
                "cccd": row.get("CCCD"),
                "gender": row.get("Gioi_tinh"),
                "nationality": row.get("Quoc_tich"),
                "phones": row.get("phone_numbers") or "",
                "emails": row.get("emails") or "",
            },
        }
    )


@app.get("/api/accounts")
def get_accounts():
    cccd = request.args.get("cccd", "").strip()
    if not cccd:
        return jsonify({"message": "cccd is required"}), 400

    conn = get_connection()
    cur = conn.cursor(dictionary=True)

    try:
        rows = _call_proc_fetchall(cur, "api_get_accounts_by_cccd", (cccd,))

        # Normalize `Trang_thai` values to match frontend expectations
        for row in rows:
            raw = str(row.get("Trang_thai") or "").strip().lower()
            if raw in ("active", "hoat_dong", "hoat dong", "hoatdong"):
                row["Trang_thai"] = "Hoat_dong"
            elif raw in ("deactive", "ngung_kich_hoat", "khong_hoat_dong", "ngung kich hoat", "inactive"):
                row["Trang_thai"] = "Ngung_kich_hoat"
            else:
                row["Trang_thai"] = row.get("Trang_thai") or "-"

        # Extra compatibility conversions
        for row in rows:
            if row.get("Trang_thai") == "ACTIVE":
                row["Trang_thai"] = "Hoat_dong"
            elif row.get("Trang_thai") == "DEACTIVE":
                row["Trang_thai"] = "Khong_hoat_dong"
    finally:
        cur.close()
        conn.close()

    return jsonify(rows)


@app.get("/api/recipient-lookup")
def lookup_recipient():
    query = request.args.get("query", "").strip()
    if not query:
        return jsonify({"found": False, "message": "query is required"}), 400

    conn = get_connection()
    cur = conn.cursor(dictionary=True)

    try:
        row = _call_proc_fetchone(cur, "api_lookup_recipient", (query,))
        if row:
            if row.get("source") == "account":
                return jsonify({"found": True, "source": "account", "key": row.get("key_value"), "name": row.get("display_name")})
            return jsonify({"found": True, "source": "external", "key": row.get("key_value"), "name": row.get("display_name"), "bank": row.get("bank_name")})
    finally:
        cur.close()
        conn.close()

    return jsonify({"found": False, "message": "Recipient not found"})


@app.get("/api/transactions")
def get_transactions():
    account_number = request.args.get("accountNumber", "").strip()
    if not account_number:
        return jsonify({"message": "accountNumber is required"}), 400

    conn = get_connection()
    cur = conn.cursor(dictionary=True)

    try:
        rows = _call_proc_fetchall(cur, "api_get_transactions", (account_number,))
        for row in rows:
            row["Ngay_gio"] = _format_datetime_gmt_plus_7(row.get("Ngay_gio"))
    finally:
        cur.close()
        conn.close()

    return jsonify(rows)


@app.get("/api/promotions")
def get_promotions():
    account_number = request.args.get("accountNumber", "").strip()

    conn = get_connection()
    cur = conn.cursor(dictionary=True)

    try:
        param = account_number or None
        rows = _call_proc_fetchall(cur, "api_get_promotions", (param,))
        for row in rows:
            row["Ngay_bat_dau"] = str(row.get("Ngay_bat_dau")) if row.get("Ngay_bat_dau") else None
            row["Ngay_ket_thuc"] = str(row.get("Ngay_ket_thuc")) if row.get("Ngay_ket_thuc") else None
    finally:
        cur.close()
        conn.close()

    return jsonify(rows)


@app.get("/api/promotions/history")
def get_promotion_history():
    cccd = request.args.get("cccd", "").strip()
    if not cccd:
        return jsonify({"message": "cccd is required"}), 400

    conn = get_connection()
    cur = conn.cursor(dictionary=True)

    try:
        rows = _call_proc_fetchall(cur, "api_get_promotion_history", (cccd,))
        for row in rows:
            row["Ngay_bat_dau"] = str(row.get("Ngay_bat_dau")) if row.get("Ngay_bat_dau") else None
            row["Ngay_ket_thuc"] = str(row.get("Ngay_ket_thuc")) if row.get("Ngay_ket_thuc") else None
            row["Ngay_gan_nhat"] = str(row.get("Ngay_gan_nhat")) if row.get("Ngay_gan_nhat") else None
    finally:
        cur.close()
        conn.close()

    return jsonify(rows)


@app.get("/api/bills")
def get_bills():
    cccd = request.args.get("cccd", "").strip()
    if not cccd:
        return jsonify({"message": "cccd is required"}), 400

    conn = get_connection()
    cur = conn.cursor(dictionary=True)

    try:
        rows = _call_proc_fetchall(cur, "api_get_bills", (cccd,))
    finally:
        cur.close()
        conn.close()

    return jsonify(rows)


@app.post("/api/bills/create")
def create_bill():
    data: dict[str, Any] = request.get_json(silent=True) or {}
    cccd = str(data.get("cccd", "")).strip()
    account_number = str(data.get("accountNumber", "")).strip()
    bill_type = str(data.get("billType", "")).strip()
    due_date = str(data.get("dueDate", "")).strip()

    try:
        amount = _parse_vnd_number(data.get("amount", 0))
    except (TypeError, ValueError):
        return jsonify({"message": "amount must be a valid VND number."}), 400

    if not cccd or not account_number or not bill_type:
        return jsonify({"message": "cccd, accountNumber and billType are required."}), 400

    if amount <= 0:
        return jsonify({"message": "amount must be greater than 0."}), 400

    if bill_type not in {"Dien", "Nuoc", "Quan_ly"}:
        return jsonify({"message": "billType must be Dien, Nuoc, or Quan_ly."}), 400

    if due_date:
        try:
            datetime.strptime(due_date, "%Y-%m-%d")
        except ValueError:
            return jsonify({"message": "dueDate must be in YYYY-MM-DD format."}), 400

    conn = get_connection()
    cur = conn.cursor(dictionary=True)

    try:
        row = _call_proc_fetchone(cur, "api_create_bill", (cccd, account_number, bill_type, amount))
        conn.commit()
        bill_id = row.get("billId")
    except Exception as ex:
        conn.rollback()
        return jsonify({"message": _sql_message(ex)}), 400
    finally:
        cur.close()
        conn.close()

    return jsonify(
        {
            "message": "Bill created successfully.",
            "billId": bill_id,
            "billType": bill_type,
            "amount": amount,
            "accountNumber": account_number,
            "dueDate": due_date or None,
            "status": "Chua_thanh_toan",
        }
    )


@app.post("/api/bills/pay")
def pay_bill():
    data: dict[str, Any] = request.get_json(silent=True) or {}
    cccd = str(data.get("cccd", "")).strip()
    bill_id = str(data.get("billId", "")).strip()
    promotion_code = str(data.get("promotionCode", "")).strip()

    if not cccd or not bill_id:
        return jsonify({"message": "cccd and billId are required."}), 400


    conn = get_connection()
    cur = conn.cursor(dictionary=True)

    try:
        result = _call_proc_fetchone(cur, "api_pay_bill", (cccd, bill_id, promotion_code or None))
        conn.commit()
        transaction_code = result.get("transactionId")
        remaining = float(result.get("remainingBalance") or 0)
        amount = float(result.get("paymentAmount") or 0) if result.get("paymentAmount") else None
    except Exception as ex:
        conn.rollback()
        return jsonify({"message": _sql_message(ex)}), 400
    finally:
        cur.close()
        conn.close()

    return jsonify(
        {
            "message": "Bill paid successfully.",
            "billId": bill_id,
            "transactionId": transaction_code,
            "amount": amount,
            "remainingBalance": remaining,
        }
    )


@app.get("/api/loans")
def get_loans():
    cccd = request.args.get("cccd", "").strip()
    if not cccd:
        return jsonify({"message": "cccd is required"}), 400

    conn = get_connection()
    cur = conn.cursor(dictionary=True)

    try:
        cur.callproc("api_get_loans_and_repayments", (cccd,))
        results = []
        for result in cur.stored_results():
            results.append(result.fetchall())

        loans = results[0] if len(results) > 0 else []
        repayments = results[1] if len(results) > 1 else []

        for row in loans:
            row["Khoan_vay"] = _loan_amount_from_any(row.get("Khoan_vay"))

        for row in repayments:
            row["Ngay_tra_thuc_te"] = str(row.get("Ngay_tra_thuc_te")) if row.get("Ngay_tra_thuc_te") else None
            row["Ngay_tra_du_kien"] = str(row.get("Ngay_tra_du_kien")) if row.get("Ngay_tra_du_kien") else None
            row["Trang_thai"] = _derive_repayment_status(due_date=row.get("Ngay_tra_du_kien"), paid_date=row.get("Ngay_tra_thuc_te"))
            row["So_tien_con_lai"] = 0.0 if row.get("Ngay_tra_thuc_te") else float(row.get("So_tien_phai_tra") or 0)
    finally:
        cur.close()
        conn.close()

    return jsonify({"loans": loans, "repayments": repayments})


@app.post("/api/repayments/pay")
def repay_installment():
    data: dict[str, Any] = request.get_json(silent=True) or {}

    cccd = str(data.get("cccd", "")).strip()
    repayment_id = str(data.get("repaymentId", "")).strip()
    amount_raw = data.get("amount")

    if not cccd or not repayment_id:
        return jsonify({"message": "cccd and repaymentId are required."}), 400

    custom_amount = None
    if amount_raw is not None and str(amount_raw).strip() != "":
        try:
            custom_amount = _parse_vnd_number(amount_raw)
        except (TypeError, ValueError):
            return jsonify({"message": "amount must be a valid VND number."}), 400

    conn = get_connection()
    cur = conn.cursor(dictionary=True)

    try:
        # pass NULL to pay full installment when custom_amount is None
        param_amount = None if custom_amount is None else float(custom_amount)
        result = _call_proc_fetchone(cur, "api_pay_repayment", (cccd, repayment_id, param_amount))
        conn.commit()
        transaction_id = result.get("transactionId")
        pay_amount = float(result.get("paymentAmount") or 0)
        new_status = result.get("repaymentStatus")
        loan_status = result.get("loanStatus")
    except Exception as ex:
        conn.rollback()
        return jsonify({"message": _sql_message(ex)}), 400
    finally:
        cur.close()
        conn.close()

    return jsonify(
        {
            "message": "Repayment processed successfully.",
            "repaymentId": repayment_id,
            "paymentAmount": pay_amount,
            "remainingAmount": 0.0,
            "repaymentStatus": new_status,
            "loanStatus": loan_status,
        }
    )


@app.post("/api/repayments/auto-debit")
def run_auto_debit():
    data: dict[str, Any] = request.get_json(silent=True) or {}
    cccd = str(data.get("cccd", "")).strip()
    if not cccd:
        return jsonify({"message": "cccd is required."}), 400

    summary = {"processed": 0, "paid": 0, "overdue": 0, "failed": 0}

    conn = get_connection()
    cur = conn.cursor(dictionary=True)

    try:
        result = _call_proc_fetchone(cur, "api_auto_debit", (cccd,))
        conn.commit()
        summary = {
            "processed": int(result.get("processed") or 0),
            "paid": int(result.get("paid") or 0),
            "overdue": int(result.get("overdue") or 0),
            "failed": int(result.get("failed") or 0),
        }
    except Exception as ex:
        conn.rollback()
        return jsonify({"message": _sql_message(ex)}), 400
    finally:
        cur.close()
        conn.close()

    return jsonify({"message": "Auto-debit run completed.", **summary})


@app.post("/api/deposits")
def create_deposit():
    admin_session, error_response = _admin_session_or_error()
    if error_response:
        return error_response

    data: dict[str, Any] = request.get_json(silent=True) or {}
    account_number = str(data.get("accountNumber", "")).strip()

    try:
        amount = _parse_vnd_number(data.get("amount", 0))
    except (TypeError, ValueError):
        return jsonify({"message": "Amount must be a valid VND number."}), 400

    if not account_number:
        return jsonify({"message": "accountNumber is required."}), 400

    if amount <= 0:
        return jsonify({"message": "Amount must be greater than 0."}), 400

    conn = get_connection()
    cur = conn.cursor(dictionary=True)

    try:
        result = _call_proc_fetchone(cur, "api_create_deposit", (admin_session["maSo"], account_number, amount))
        conn.commit()
        transaction_code = result.get("transactionId")
        updated_balance = float(result.get("updatedBalance") or 0)
    except Exception as ex:
        conn.rollback()
        return jsonify({"message": _sql_message(ex)}), 400
    finally:
        cur.close()
        conn.close()

    return jsonify(
        {
            "message": "Deposit completed successfully.",
            "transactionId": transaction_code,
            "accountNumber": account_number,
            "amount": amount,
            "updatedBalance": updated_balance,
            "performedBy": admin_session["username"],
        }
    )


@app.get("/api/personal-info")
def get_personal_info():
    cccd = request.args.get("cccd", "").strip()
    account_number = request.args.get("accountNumber", "").strip()
    if not cccd:
        return jsonify({"message": "cccd is required"}), 400

    conn = get_connection()
    cur = conn.cursor(dictionary=True)

    try:
        cur.callproc("api_get_personal_info", (cccd, account_number or None))
        sets = []
        for result in cur.stored_results():
            sets.append(result.fetchall())

        person = sets[0][0] if len(sets) > 0 and sets[0] else None
        phones = [r["So_dien_thoai"] for r in (sets[1] if len(sets) > 1 else [])]
        emails = [r["Tk_email"] for r in (sets[2] if len(sets) > 2 else [])]
        card_rows = sets[3] if len(sets) > 3 else []
        card_types = [row["Ten_the"] for row in card_rows]
        cards = [
            {
                "cardNumber": row["Ma_so_the"],
                "cardType": row["Ten_the"],
                "expiryDate": row["Ngay_het_han"],
                "accountNumber": row["So_tai_khoan"],
                "accountName": row["Ten_khach_hang"],
            }
            for row in card_rows
        ]
    finally:
        cur.close()
        conn.close()

    if not person:
        return jsonify({"message": "Customer not found"}), 404

    return jsonify(
        {
            "cccd": person["CCCD"],
            "fullName": " ".join(
                [
                    str(person.get("Ho") or "").strip(),
                    str(person.get("Ten_lot") or "").strip(),
                    str(person.get("Ten") or "").strip(),
                ]
            ).strip(),
            "nationality": person["Quoc_tich"],
            "gender": person["Gioi_tinh"],
            "dob": person["Ngay_sinh"],
            "referrerCccd": person.get("Nguoi_gioi_thieu"),
            "phones": phones,
            "emails": emails,
            "accountNumber": account_number or None,
            "cardTypes": card_types,
            "cards": cards,
        }
    )


@app.get("/api/admin/customers/search")
def admin_search_customers():
    _, error_response = _admin_session_or_error()
    if error_response:
        return error_response

    query = request.args.get("query", "").strip()
    if not query:
        return jsonify({"message": "query is required"}), 400

    wildcard = f"%{query}%"

    conn = get_connection()
    cur = conn.cursor(dictionary=True)

    try:
        rows = _call_proc_fetchall(cur, "api_admin_search_customers", (query,))
        for row in rows:
            raw = str(row.get("Trang_thai") or "").strip().lower()
            if raw in ("active", "hoat_dong", "hoat dong", "hoatdong"):
                row["Trang_thai"] = "Hoat_dong"
            elif raw in ("deactive", "ngung_kich_hoat", "khong_hoat_dong", "ngung kich hoat", "inactive"):
                row["Trang_thai"] = "Ngung_kich_hoat"
            else:
                row["Trang_thai"] = row.get("Trang_thai") or "-"
    finally:
        cur.close()
        conn.close()

    return jsonify(rows)


@app.get("/api/admin/promotions")
def admin_list_promotions():
    admin_session, error_response = _admin_session_or_error()
    if error_response:
        return error_response

    conn = get_connection()
    cur = conn.cursor(dictionary=True)

    try:
        rows = _call_proc_fetchall(cur, "api_admin_list_promotions", None)
        for row in rows:
            row["Ngay_bat_dau"] = str(row.get("Ngay_bat_dau")) if row.get("Ngay_bat_dau") else None
            row["Ngay_ket_thuc"] = str(row.get("Ngay_ket_thuc")) if row.get("Ngay_ket_thuc") else None
            row["So_luong"] = int(row.get("So_luong") or 0)
    finally:
        cur.close()
        conn.close()

    return jsonify(rows)


@app.post("/api/admin/promotions/assign")
def admin_assign_promotion_to_account():
    admin_session, error_response = _admin_session_or_error()
    if error_response:
        return error_response

    data: dict[str, Any] = request.get_json(silent=True) or {}
    account_number = str(data.get("accountNumber", "")).strip()
    promotion_code = str(data.get("promotionCode", "")).strip()

    if not account_number or not promotion_code:
        return jsonify({"message": "accountNumber and promotionCode are required."}), 400

    conn = get_connection()
    cur = conn.cursor(dictionary=True)

    try:
        cur.callproc("api_admin_assign_promotion", (account_number, promotion_code, admin_session["maSo"]))
        conn.commit()
    except Exception as ex:
        conn.rollback()
        return jsonify({"message": _sql_message(ex)}), 400
    finally:
        cur.close()
        conn.close()

    return jsonify(
        {
            "message": "Promotion assigned to account successfully.",
            "promotionCode": promotion_code,
            "accountNumber": account_number,
            "assignedBy": admin_session["maSo"],
            "assignedDate": datetime.now(GMT_PLUS_7).date().isoformat(),
        }
    )


@app.post("/api/admin/accounts/deactivate")
def admin_deactivate_account():
    admin_session, error_response = _admin_session_or_error()
    if error_response:
        return error_response

    data: dict[str, Any] = request.get_json(silent=True) or {}
    account_number = str(data.get("accountNumber", "")).strip()
    if not account_number:
        return jsonify({"message": "accountNumber is required."}), 400

    conn = get_connection()
    cur = conn.cursor(dictionary=True)

    try:
        try:
            cur.execute(
                "CALL vo_hieu_hoa_tai_khoan(%s, %s)",
                (admin_session["maSo"], account_number),
            )
        except Exception as ex:
            if not _is_missing_procedure_error(ex, "vo_hieu_hoa_tai_khoan"):
                raise

            _deactivate_account_fallback(
                cur,
                admin_ma_so=admin_session["maSo"],
                account_number=account_number,
            )

        conn.commit()

        cur.execute(
            "SELECT Trang_thai FROM Tai_khoan WHERE So_tai_khoan = %s LIMIT 1",
            (account_number,),
        )
        row = cur.fetchone() or {}
    except Exception as ex:
        conn.rollback()
        return jsonify({"message": _sql_message(ex)}), 400
    finally:
        cur.close()
        conn.close()

    return jsonify(
        {
            "message": "Account deactivated successfully.",
            "accountNumber": account_number,
            "status": row.get("Trang_thai") or "DEACTIVE",
        }
    )


@app.post("/api/admin/accounts/activate")
def admin_activate_account():
    admin_session, error_response = _admin_session_or_error()
    if error_response:
        return error_response

    data: dict[str, Any] = request.get_json(silent=True) or {}
    account_number = str(data.get("accountNumber", "")).strip()
    if not account_number:
        return jsonify({"message": "accountNumber is required."}), 400

    conn = get_connection()
    cur = conn.cursor(dictionary=True)

    try:
        try:
            cur.execute(
                "CALL kich_hoat_lai_tai_khoan(%s, %s)",
                (admin_session["maSo"], account_number),
            )
        except Exception as ex:
            if not _is_missing_procedure_error(ex, "kich_hoat_lai_tai_khoan"):
                raise

            _activate_account_fallback(
                cur,
                admin_ma_so=admin_session["maSo"],
                account_number=account_number,
            )

        conn.commit()

        cur.execute(
            "SELECT Trang_thai FROM Tai_khoan WHERE So_tai_khoan = %s LIMIT 1",
            (account_number,),
        )
        row = cur.fetchone() or {}
    except Exception as ex:
        conn.rollback()
        return jsonify({"message": _sql_message(ex)}), 400
    finally:
        cur.close()
        conn.close()

    return jsonify(
        {
            "message": "Account activated successfully.",
            "accountNumber": account_number,
            "status": row.get("Trang_thai") or "ACTIVE",
        }
    )


@app.get("/api/admin/personal-info")
def admin_personal_info():
    admin_session, error_response = _admin_session_or_error()
    if error_response:
        return error_response
    conn = get_connection()
    cur = conn.cursor(dictionary=True)

    try:
        cur.callproc("api_admin_personal_info", (admin_session["maSo"],))
        sets = []
        for result in cur.stored_results():
            sets.append(result.fetchall())

        row = sets[0][0] if len(sets) > 0 and sets[0] else None
        phones = [item["So_dien_thoai"] for item in (sets[1] if len(sets) > 1 else [])]
        emails = [item["Tk_email"] for item in (sets[2] if len(sets) > 2 else [])]
    finally:
        cur.close()
        conn.close()

    if not row:
        return jsonify({"message": "Admin profile not found."}), 404

    dob_raw = row.get("Ngay_sinh")
    dob_text = dob_raw.isoformat() if hasattr(dob_raw, "isoformat") and dob_raw else None

    return jsonify(
        {
            "maSo": row["Ma_so"],
            "username": row["Ten_dang_nhap"],
            "cccd": row["CCCD"],
            "fullName": " ".join(
                [
                    str(row.get("Ho") or "").strip(),
                    str(row.get("Ten_lot") or "").strip(),
                    str(row.get("Ten") or "").strip(),
                ]
            ).strip(),
            "gender": row.get("Gioi_tinh"),
            "nationality": row.get("Quoc_tich"),
            "dob": dob_text,
            "phones": phones,
            "emails": emails,
        }
    )


@app.delete("/api/admin/accounts/<account>/delete")
def admin_delete_account(account: str):
    admin_session, error_response = _admin_session_or_error()
    if error_response:
        return error_response

    account_number = account.strip()
    if not account_number:
        return jsonify({"message": "accountNumber is required."}), 400

    conn = get_connection()
    cur = conn.cursor(dictionary=True)

    try:
        cur.execute(
            "CALL delete_tai_khoan(%s, %s)",
            (admin_session["maSo"], account_number),
        )
        conn.commit()
    except Exception as ex:
        conn.rollback()
        return jsonify({"message": _sql_message(ex)}), 400
    finally:
        cur.close()
        conn.close()

    return jsonify(
        {
            "message": "Account deleted successfully.",
            "accountNumber": account_number,
        }
    )


@app.get("/api/accounts/<account>/transactions")
def get_account_transactions(account: str):
    account_number = account.strip()
    if not account_number:
        return jsonify({"message": "accountNumber is required"}), 400

    order_by = request.args.get("order", "DESC").strip().upper()
    if order_by not in ["ASC", "DESC"]:
        order_by = "DESC"

    conn = get_connection()
    cur = conn.cursor(dictionary=True)
    try:
        cur.callproc("get_account_transactions", [account_number, order_by])
        rows = []
        for result in cur.stored_results():
            rows = result.fetchall()
            break
        for row in rows:
            row["Ngay_gio"] = _format_datetime_gmt_plus_7(row.get("Ngay_gio"))
    except Exception as ex:
        return jsonify({"message": _sql_message(ex)}), 400
    finally:
        cur.close()
        conn.close()

    return jsonify(rows)

@app.get("/api/admin/loan-summary")
def admin_loan_summary():
    admin_session, error_response = _admin_session_or_error()
    if error_response:
        return error_response

    min_amount_str = request.args.get("min_amount", "0").strip()
    try:
        min_amount = float(min_amount_str)
    except ValueError:
        return jsonify({"message": "min_amount must be a valid number"}), 400

    conn = get_connection()
    cur = conn.cursor(dictionary=True)

    try:
        cur.execute(
            "CALL get_loan_summary_by_admin(%s, %s)",
            (admin_session["maSo"], min_amount),
        )
        rows = cur.fetchall()
    except Exception as ex:
        return jsonify({"message": _sql_message(ex)}), 400
    finally:
        cur.close()
        conn.close()

    return jsonify(rows)


@app.get("/api/loans/<account>/total-interest")
def get_loan_total_interest(account: str):
    account_number = account.strip()
    if not account_number:
        return jsonify({"message": "accountNumber is required"}), 400

    conn = get_connection()
    cur = conn.cursor(dictionary=True)

    try:
        cur.execute(
            "SELECT calculate_total_interest(%s) AS total_interest",
            (account_number,),
        )
        row = cur.fetchone() or {}
        total_interest = row.get("total_interest") or 0

        if total_interest == -1:
            return jsonify({"message": "Account not found"}), 404

        return jsonify({"accountNumber": account_number, "totalInterest": total_interest})
    except Exception as ex:
        return jsonify({"message": _sql_message(ex)}), 400
    finally:
        cur.close()
        conn.close()


@app.get("/api/loans-with-debt/<cccd>")
def get_loans_with_remaining_debt(cccd: str):
    """Get all loans for a customer with remaining debt calculated using TinhDuNoConLai function."""
    cccd_val = cccd.strip()
    if not cccd_val or len(cccd_val) != 12:
        return jsonify({"message": "cccd is required and must be 12 digits"}), 400

    conn = get_connection()
    cur = conn.cursor(dictionary=True)

    try:
        cur.execute(
            """
            SELECT kv.Ma_khoan_vay,
                   kv.Khoan_vay AS Tong_vay,
                   kv.Lai_suat,
                   kv.Thoi_han_vay,
                   kv.Ky_han_tra_goc,
                   kv.Trang_thai,
                   kv.Ngay_tao_khoan_vay,
                   kv.So_tai_khoan
            FROM Khoan_vay kv
            JOIN Tai_khoan tk ON tk.So_tai_khoan = kv.So_tai_khoan
            WHERE tk.CCCD = %s
            ORDER BY kv.Ma_khoan_vay
            """,
            (cccd_val,),
        )
        loans = cur.fetchall()
        
        # For each loan, calculate remaining debt using the function
        for loan in loans:
            try:
                cur.execute("SELECT TinhDuNoConLai(%s) AS du_no_con_lai", (loan["Ma_khoan_vay"],))
                debt_row = cur.fetchone() or {}
                loan["du_no_con_lai"] = float(debt_row.get("du_no_con_lai") or 0)
                loan["da_tra"] = float(loan.get("Tong_vay") or 0) - loan["du_no_con_lai"]
            except Exception:
                loan["du_no_con_lai"] = 0
                loan["da_tra"] = 0
        
        return jsonify({
            "cccd": cccd_val,
            "loans": loans,
            "totalLoans": len(loans),
            "message": "Loans retrieved successfully." if loans else "No loans found for this customer."
        })
    except Exception as ex:
        return jsonify({"message": _sql_message(ex)}), 400
    finally:
        cur.close()
        conn.close()


@app.get("/api/loan-statistics/<cccd>")
def get_loan_statistics(cccd: str):
    """Get loan statistics using ThongKeDuNoKhoanVay procedure.

    Optional query parameters:
      - status: one of 'Hoat_dong', 'Qua_han', 'Da_thanh_toan' (if omitted, all are returned)
      - min_paid: numeric minimum total principal paid (p_tong_da_tra_min)
    """
    cccd_val = cccd.strip()
    if not cccd_val or len(cccd_val) != 12:
        return jsonify({"message": "cccd is required and must be 12 digits"}), 400

    # optional query params
    status_param = request.args.get("status", "").strip()
    min_paid_str = request.args.get("min_paid", "0").strip()
    try:
        min_paid = float(min_paid_str) if min_paid_str != "" else 0.0
    except ValueError:
        return jsonify({"message": "min_paid must be a number"}), 400

    conn = get_connection()
    cur = conn.cursor(dictionary=True)

    try:
        # Find one account for this customer to filter procedure results
        cur.execute(
            """
            SELECT DISTINCT kv.So_tai_khoan
            FROM Khoan_vay kv
            JOIN Tai_khoan tk ON tk.So_tai_khoan = kv.So_tai_khoan
            WHERE tk.CCCD = %s
            LIMIT 1
            """,
            (cccd_val,),
        )
        account_row = cur.fetchone()
        if not account_row:
            return jsonify({"cccd": cccd_val, "statistics": [], "message": "No loans found for this customer."})

        all_statistics = []
        loan_statuses = [status_param] if status_param else ['Hoat_dong', 'Qua_han', 'Da_thanh_toan']

        for status in loan_statuses:
            try:
                cur.execute("CALL ThongKeDuNoKhoanVay(%s, %s)", (status, min_paid))
                status_results = cur.fetchall()
                # only include loans for this customer's account
                filtered_results = [r for r in status_results if r.get('So_tai_khoan') == account_row.get('So_tai_khoan')]
                all_statistics.extend(filtered_results)
                # consume remaining result sets
                while cur.nextset():
                    pass
            except Exception:
                # ignore failure for a single status and continue
                pass

        return jsonify({
            "cccd": cccd_val,
            "statistics": all_statistics,
            "totalLoans": len(all_statistics),
            "message": "Loan statistics retrieved successfully." if all_statistics else "No loans found."
        })
    except Exception as ex:
        return jsonify({"message": _sql_message(ex)}), 400
    finally:
        cur.close()
        conn.close()


@app.get("/api/admin/loans/<loan_id>")
def admin_get_loan(loan_id: str):
    admin_session, error_response = _admin_session_or_error()
    if error_response:
        return error_response

    loan_id_value = str(loan_id or "").strip()
    if not loan_id_value:
        return jsonify({"message": "loanId is required."}), 400

    conn = get_connection()
    cur = conn.cursor(dictionary=True)

    try:
        cur.execute(
            """
            SELECT kv.Ma_khoan_vay,
                   kv.Lai_suat,
                   kv.Khoan_vay,
                   kv.Thoi_han_vay,
                   kv.Ky_han_tra_goc,
                   kv.Trang_thai,
                   kv.So_tai_khoan,
                   kv.Ma_so,
                   tk.Ten_khach_hang,
                   tk.CCCD
            FROM Khoan_vay kv
            JOIN Tai_khoan tk ON tk.So_tai_khoan = kv.So_tai_khoan
            WHERE kv.Ma_khoan_vay = %s
            LIMIT 1
            """,
            (loan_id_value,),
        )
        row = cur.fetchone()
        if not row:
            return jsonify({"message": "Loan not found."}), 404

        return jsonify(
            {
                "loanId": row.get("Ma_khoan_vay"),
                "interestRate": float(row.get("Lai_suat") or 0),
                "loanAmount": _loan_amount_from_any(row.get("Khoan_vay")),
                "termMonths": int(row.get("Thoi_han_vay") or 0),
                "principalCycle": int(row.get("Ky_han_tra_goc") or 0),
                "status": row.get("Trang_thai") or "",
                "accountNumber": row.get("So_tai_khoan") or "",
                "maSo": row.get("Ma_so") or "",
                "customerName": row.get("Ten_khach_hang") or "",
                "cccd": row.get("CCCD") or "",
            }
        )
    except Exception as ex:
        return jsonify({"message": _sql_message(ex)}), 400
    finally:
        cur.close()
        conn.close()


@app.post("/api/admin/loans/update")
def admin_update_loan():
    admin_session, error_response = _admin_session_or_error()
    if error_response:
        return error_response

    data: dict[str, Any] = request.get_json(silent=True) or {}
    loan_id = str(data.get("loanId", "")).strip()
    admin_code = str(admin_session.get("maSo") or "").strip()

    if not loan_id:
        return jsonify({"message": "loanId is required."}), 400

    interest_rate = data.get("interestRate")
    term_months = data.get("termMonths")
    principal_cycle = data.get("principalCycle")
    status = str(data.get("status", "")).strip() or None

    try:
        interest_rate_value = None if interest_rate in (None, "") else float(interest_rate)
    except (TypeError, ValueError):
        return jsonify({"message": "interestRate must be a valid decimal."}), 400

    try:
        term_months_value = None if term_months in (None, "") else int(term_months)
    except (TypeError, ValueError):
        return jsonify({"message": "termMonths must be a valid integer."}), 400

    try:
        principal_cycle_value = None if principal_cycle in (None, "") else int(principal_cycle)
    except (TypeError, ValueError):
        return jsonify({"message": "principalCycle must be a valid integer."}), 400

    valid_statuses = {"Hoat_dong", "Qua_han", "Da_thanh_toan"}
    if status is not None and status not in valid_statuses:
        return jsonify({"message": "status must be one of Hoat_dong, Qua_han, or Da_thanh_toan."}), 400

    conn = get_connection()
    cur = conn.cursor(dictionary=True)

    try:
        cur.execute(
            "CALL sp_SuaKhoanVay(%s, %s, %s, %s, %s, %s)",
            (
                loan_id,
                interest_rate_value,
                term_months_value,
                principal_cycle_value,
                status,
                admin_code,
            ),
        )
        rows = cur.fetchall()
        message = (rows[0].get("Ket_qua") if rows else None) or f"Loan {loan_id} updated successfully."
        if cur.nextset():
            pass
        conn.commit()
        return jsonify({"message": message, "loanId": loan_id})
    except Exception as ex:
        conn.rollback()
        return jsonify({"message": _sql_message(ex)}), 400
    finally:
        cur.close()
        conn.close()


@app.delete("/api/admin/loans/delete")
def admin_delete_loan():
    admin_session, error_response = _admin_session_or_error()
    if error_response:
        return error_response

    data: dict[str, Any] = request.get_json(silent=True) or {}
    loan_id = str(data.get("loanId", "")).strip()
    reason = str(data.get("reason", "")).strip()
    admin_code = str(admin_session.get("maSo") or "").strip()

    if not loan_id:
        return jsonify({"message": "loanId is required."}), 400
    if not reason:
        return jsonify({"message": "reason is required."}), 400

    conn = get_connection()
    cur = conn.cursor(dictionary=True)

    try:
        cur.execute(
            "CALL sp_XoaKhoanVay(%s, %s, %s)",
            (loan_id, admin_code, reason),
        )
        rows = cur.fetchall()
        message = (rows[0].get("Ket_qua") if rows else None) or f"Loan {loan_id} deleted successfully."
        if cur.nextset():
            pass
        conn.commit()
        return jsonify({"message": message, "loanId": loan_id})
    except Exception as ex:
        conn.rollback()
        return jsonify({"message": _sql_message(ex)}), 400
    finally:
        cur.close()
        conn.close()


@app.get("/api/eligibility/<cccd>")
def check_eligibility(cccd: str):
    cccd_val = cccd.strip()
    if not cccd_val:
        return jsonify({"message": "cccd is required"}), 400

    conn = get_connection()
    cur = conn.cursor(dictionary=True)

    try:
        cur.execute(
            "SELECT check_loan_eligibility(%s) AS eligibility_status",
            (cccd_val,),
        )
        row = cur.fetchone() or {}
        status = row.get("eligibility_status") or "Unknown"

        return jsonify(
            {
                "cccd": cccd_val,
                "eligibilityStatus": status,
                "isEligible": status == "Du dieu kien vay",
            }
        )
    except Exception as ex:
        return jsonify({"message": _sql_message(ex)}), 400
    finally:
        cur.close()
        conn.close()


@app.get("/")
def serve_index():
    return send_from_directory(ROOT_DIR, "index.html")


@app.get("/<path:file_path>")
def serve_static(file_path: str):
    return send_from_directory(ROOT_DIR, file_path)


if __name__ == "__main__":
    port = int(os.getenv("FLASK_PORT", "8080"))
    app.run(host="0.0.0.0", port=port, debug=True)
