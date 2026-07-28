from flask import Blueprint, jsonify, request
from firebase_admin import firestore

from auth import require_admin
from services.firestore_service import doc_to_dict, get_db, serialize_doc

payouts_bp = Blueprint("payouts", __name__)


@payouts_bp.get("")
@require_admin()
def list_payouts():
    docs = get_db().collection("payouts").limit(100).stream()
    return jsonify({"payouts": [serialize_doc(doc_to_dict(d) or {}) for d in docs]})


@payouts_bp.post("")
@require_admin()
def create_payout():
    data = request.json or {}
    driver_id = data.get("driverId")
    amount = float(data.get("amount", 0))
    if not driver_id or amount <= 0:
        return jsonify({"error": "driverId and amount required"}), 400
    ref = get_db().collection("payouts").document()
    ref.set(
        {
            "driverId": driver_id,
            "amount": amount,
            "period": data.get("period", "manual"),
            "status": "pending",
            "createdAt": firestore.SERVER_TIMESTAMP,
            "createdBy": data.get("createdBy", "admin"),
        }
    )
    return jsonify({"payout": serialize_doc(doc_to_dict(ref.get()) or {})}), 201


@payouts_bp.post("/<payout_id>/mark-paid")
@require_admin()
def mark_paid(payout_id):
    ref = get_db().collection("payouts").document(payout_id)
    if not ref.get().exists:
        return jsonify({"error": "Not found"}), 404
    ref.update({"status": "completed", "paidAt": firestore.SERVER_TIMESTAMP})
    return jsonify({"success": True})
