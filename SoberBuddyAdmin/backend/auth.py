from datetime import datetime, timezone
from functools import wraps

from firebase_admin import auth as firebase_auth
from flask import g, jsonify, request

from services.firestore_service import get_db, doc_to_dict

OTP_SESSION_SECONDS = 12 * 3600


def is_otp_session_valid(admin: dict | None) -> bool:
    if not admin:
        return False
    otp_verified_at = admin.get("otpVerifiedAt")
    if not otp_verified_at:
        return False
    if hasattr(otp_verified_at, "timestamp"):
        age = datetime.now(timezone.utc).timestamp() - otp_verified_at.timestamp()
        if age > OTP_SESSION_SECONDS:
            return False
    return True


def verify_firebase_token():
    header = request.headers.get("Authorization", "")
    if not header.startswith("Bearer "):
        return None, "Missing Authorization header"
    token = header.split(" ", 1)[1]
    try:
        decoded = firebase_auth.verify_id_token(token)
        return decoded, None
    except Exception as exc:
        return None, str(exc)


def require_admin(require_otp: bool = True):
    def decorator(fn):
        @wraps(fn)
        def wrapper(*args, **kwargs):
            decoded, error = verify_firebase_token()
            if error:
                return jsonify({"error": error}), 401

            uid = decoded["uid"]
            admin_doc = get_db().collection("admins").document(uid).get()
            admin = doc_to_dict(admin_doc)
            if not admin or not admin.get("isActive", True):
                return jsonify({"error": "Not authorized as admin"}), 403

            if require_otp:
                if not is_otp_session_valid(admin):
                    code = "OTP_EXPIRED" if admin.get("otpVerifiedAt") else "OTP_REQUIRED"
                    message = "OTP session expired" if code == "OTP_EXPIRED" else "OTP verification required"
                    return jsonify({"error": message, "code": code}), 403

            g.admin = admin
            g.admin_uid = uid
            g.token_decoded = decoded
            return fn(*args, **kwargs)

        return wrapper

    return decorator
