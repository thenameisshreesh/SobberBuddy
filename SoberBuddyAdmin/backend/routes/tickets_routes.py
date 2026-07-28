from flask import Blueprint, jsonify, request
from firebase_admin import firestore

from auth import require_admin
from services.firestore_service import doc_to_dict, get_db, serialize_doc

tickets_bp = Blueprint("tickets", __name__)


@tickets_bp.get("")
@require_admin()
def list_tickets():
    status = request.args.get("status")
    query = get_db().collection("support_tickets")
    if status:
        query = query.where("status", "==", status)
    docs = query.limit(50).stream()
    return jsonify({"tickets": [serialize_doc(doc_to_dict(d) or {}) for d in docs]})


@tickets_bp.patch("/<ticket_id>")
@require_admin()
def update_ticket(ticket_id):
    data = request.json or {}
    ref = get_db().collection("support_tickets").document(ticket_id)
    if not ref.get().exists:
        return jsonify({"error": "Not found"}), 404
    updates = {"updatedAt": firestore.SERVER_TIMESTAMP}
    if "status" in data:
        updates["status"] = data["status"]
        if data["status"] == "closed":
            updates["resolvedAt"] = firestore.SERVER_TIMESTAMP
    if "adminReply" in data:
        updates["adminReply"] = data["adminReply"]
    if "assignedTo" in data:
        updates["assignedTo"] = data["assignedTo"]
    ref.update(updates)
    return jsonify({"ticket": serialize_doc(doc_to_dict(ref.get()) or {})})
