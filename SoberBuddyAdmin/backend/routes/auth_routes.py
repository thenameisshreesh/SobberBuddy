import os

from flask import Blueprint, g, jsonify, request
from firebase_admin import firestore

from auth import is_otp_session_valid, require_admin, verify_firebase_token
from services.firestore_service import doc_to_dict, get_db, serialize_doc

auth_bp = Blueprint("auth", __name__)


@auth_bp.get("/me")
@require_admin(require_otp=False)
def me():
    return jsonify({"admin": serialize_doc(g.admin)})


@auth_bp.post("/check-admin")
def check_admin():
    decoded, error = verify_firebase_token()
    if error:
        return jsonify({"error": error}), 401
    admin = doc_to_dict(get_db().collection("admins").document(decoded["uid"]).get())
    if not admin or not admin.get("isActive", True):
        return jsonify({"isAdmin": False}), 403
    return jsonify(
        {
            "isAdmin": True,
            "admin": serialize_doc(admin),
            "otpRequired": not is_otp_session_valid(admin),
        }
    )


@auth_bp.post("/verify-otp")
def verify_otp():
    decoded, error = verify_firebase_token()
    if error:
        return jsonify({"error": error}), 401
    uid = decoded["uid"]
    admin_ref = get_db().collection("admins").document(uid)
    admin = doc_to_dict(admin_ref.get())
    if not admin or not admin.get("isActive", True):
        return jsonify({"error": "Not authorized as admin"}), 403

    payload = request.get_json(silent=True) or {}
    dev_otp = os.getenv("DEV_ADMIN_OTP")
    if os.getenv("FLASK_ENV", "development") == "development" and dev_otp:
        if payload.get("code") != dev_otp:
            return jsonify({"error": "Invalid OTP"}), 400

    admin_ref.update({"otpVerifiedAt": firestore.SERVER_TIMESTAMP})
    updated = doc_to_dict(admin_ref.get())
    return jsonify({"success": True, "admin": serialize_doc(updated)})


@auth_bp.post("/logout")
@require_admin(require_otp=False)
def logout():
    get_db().collection("admins").document(g.admin_uid).update({"otpVerifiedAt": None})
    return jsonify({"success": True})
