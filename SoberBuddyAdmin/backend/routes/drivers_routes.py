from flask import Blueprint, jsonify, request
from firebase_admin import firestore

from auth import require_admin
from services.firestore_service import doc_to_dict, get_db, serialize_doc

drivers_bp = Blueprint("drivers", __name__)


@drivers_bp.get("")
@require_admin()
def list_drivers():
    limit = int(request.args.get("limit", 50))
    docs = get_db().collection("drivers").limit(limit).stream()
    return jsonify({"drivers": [serialize_doc(doc_to_dict(d) or {}) for d in docs]})


@drivers_bp.get("/<driver_id>")
@require_admin()
def get_driver(driver_id):
    driver = doc_to_dict(get_db().collection("drivers").document(driver_id).get())
    user = doc_to_dict(get_db().collection("users").document(driver_id).get())
    if not driver:
        return jsonify({"error": "Driver not found"}), 404
    return jsonify({"driver": serialize_doc(driver), "user": serialize_doc(user or {})})


@drivers_bp.post("/<driver_id>/approve-docs")
@require_admin()
def approve_docs(driver_id):
    notes = request.json.get("notes", "") if request.is_json else ""
    get_db().collection("drivers").document(driver_id).update(
        {
            "documentStatus": "approved",
            "approvalNotes": notes,
            "updatedAt": firestore.SERVER_TIMESTAMP,
        }
    )
    return jsonify({"success": True})


@drivers_bp.post("/<driver_id>/reject-docs")
@require_admin()
def reject_docs(driver_id):
    notes = request.json.get("notes", "Documents rejected") if request.is_json else "Documents rejected"
    get_db().collection("drivers").document(driver_id).update(
        {
            "documentStatus": "rejected",
            "approvalNotes": notes,
            "updatedAt": firestore.SERVER_TIMESTAMP,
        }
    )
    return jsonify({"success": True})


@drivers_bp.post("/<driver_id>/force-offline")
@require_admin()
def force_offline(driver_id):
    get_db().collection("drivers").document(driver_id).update(
        {"isAvailable": False, "updatedAt": firestore.SERVER_TIMESTAMP}
    )
    return jsonify({"success": True})
