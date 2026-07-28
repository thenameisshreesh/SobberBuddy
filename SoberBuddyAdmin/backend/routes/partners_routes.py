from flask import Blueprint, jsonify, request
from firebase_admin import firestore

from auth import require_admin
from services.firestore_service import doc_to_dict, get_db, serialize_doc

partners_bp = Blueprint("partners", __name__)


@partners_bp.get("")
@require_admin()
def list_partners():
    docs = get_db().collection("partners").stream()
    return jsonify({"partners": [serialize_doc(doc_to_dict(d) or {}) for d in docs]})


@partners_bp.post("")
@require_admin()
def create_partner():
    data = request.json or {}
    name = data.get("name", "").strip()
    if not name:
        return jsonify({"error": "name required"}), 400
    ref = get_db().collection("partners").document()
    payload = {
        "name": name,
        "contact": data.get("contact", ""),
        "commissionRate": float(data.get("commissionRate", 10)),
        "isActive": bool(data.get("isActive", True)),
        "location": data.get("location"),
        "createdAt": firestore.SERVER_TIMESTAMP,
    }
    ref.set(payload)
    partner = doc_to_dict(ref.get()) or {}
    partner["qrUrl"] = f"soberbuddy://partner/{ref.id}"
    return jsonify({"partner": serialize_doc(partner)}), 201


@partners_bp.patch("/<partner_id>")
@require_admin()
def update_partner(partner_id):
    data = request.json or {}
    ref = get_db().collection("partners").document(partner_id)
    if not ref.get().exists:
        return jsonify({"error": "Not found"}), 404
    allowed = {"name", "contact", "commissionRate", "isActive", "location"}
    updates = {k: v for k, v in data.items() if k in allowed}
    updates["updatedAt"] = firestore.SERVER_TIMESTAMP
    ref.update(updates)
    partner = doc_to_dict(ref.get()) or {}
    partner["qrUrl"] = f"soberbuddy://partner/{partner_id}"
    return jsonify({"partner": serialize_doc(partner)})


@partners_bp.get("/<partner_id>/qr")
@require_admin()
def partner_qr(partner_id):
    ref = get_db().collection("partners").document(partner_id)
    if not ref.get().exists:
        return jsonify({"error": "Not found"}), 404
    return jsonify({"qrUrl": f"soberbuddy://partner/{partner_id}"})
