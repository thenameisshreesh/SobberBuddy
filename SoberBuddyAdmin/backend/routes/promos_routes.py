from flask import Blueprint, jsonify, request
from firebase_admin import firestore

from auth import require_admin
from services.firestore_service import doc_to_dict, get_db, serialize_doc

promos_bp = Blueprint("promos", __name__)


@promos_bp.get("")
@require_admin()
def list_promos():
    docs = get_db().collection("promo_codes").stream()
    return jsonify({"promos": [serialize_doc(doc_to_dict(d) or {}) for d in docs]})


@promos_bp.post("")
@require_admin()
def create_promo():
    data = request.json or {}
    code = str(data.get("code", "")).upper().strip()
    if not code:
        return jsonify({"error": "code required"}), 400
    ref = get_db().collection("promo_codes").document(code)
    ref.set(
        {
            "code": code,
            "type": data.get("type", "flat"),
            "value": float(data.get("value", 0)),
            "maxUses": int(data.get("maxUses", 100)),
            "usedCount": 0,
            "isActive": bool(data.get("isActive", True)),
            "expiresAt": data.get("expiresAt"),
            "referralUserId": data.get("referralUserId"),
            "createdAt": firestore.SERVER_TIMESTAMP,
        }
    )
    return jsonify({"promo": serialize_doc(doc_to_dict(ref.get()) or {})}), 201


@promos_bp.patch("/<code>")
@require_admin()
def update_promo(code):
    data = request.json or {}
    ref = get_db().collection("promo_codes").document(code.upper())
    if not ref.get().exists:
        return jsonify({"error": "Not found"}), 404
    allowed = {"type", "value", "maxUses", "isActive", "expiresAt", "referralUserId"}
    updates = {k: v for k, v in data.items() if k in allowed}
    updates["updatedAt"] = firestore.SERVER_TIMESTAMP
    ref.update(updates)
    return jsonify({"promo": serialize_doc(doc_to_dict(ref.get()) or {})})


@promos_bp.delete("/<code>")
@require_admin()
def delete_promo(code):
    ref = get_db().collection("promo_codes").document(code.upper())
    ref.update({"isActive": False, "updatedAt": firestore.SERVER_TIMESTAMP})
    return jsonify({"success": True})
