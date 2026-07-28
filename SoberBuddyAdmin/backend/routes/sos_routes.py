from flask import Blueprint, jsonify, request
from firebase_admin import firestore

from auth import require_admin
from services.firestore_service import doc_to_dict, get_db, serialize_doc

sos_bp = Blueprint("sos", __name__)


@sos_bp.get("")
@require_admin()
def list_sos():
    status = request.args.get("status", "active")
    query = get_db().collection("sos_events")
    if status:
        query = query.where("status", "==", status)
    docs = query.limit(50).stream()
    return jsonify({"events": [serialize_doc(doc_to_dict(d) or {}) for d in docs]})


@sos_bp.post("/<event_id>/resolve")
@require_admin()
def resolve_sos(event_id):
    ref = get_db().collection("sos_events").document(event_id)
    if not ref.get().exists:
        return jsonify({"error": "Not found"}), 404
    ref.update(
        {
            "status": "resolved",
            "resolvedAt": firestore.SERVER_TIMESTAMP,
            "resolvedBy": request.json.get("resolvedBy", "admin") if request.is_json else "admin",
        }
    )
    return jsonify({"success": True})
