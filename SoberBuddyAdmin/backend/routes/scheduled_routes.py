from flask import Blueprint, jsonify
from firebase_admin import firestore

from auth import require_admin
from services.firestore_service import doc_to_dict, get_db, serialize_doc

scheduled_bp = Blueprint("scheduled", __name__)


@scheduled_bp.get("")
@require_admin()
def list_scheduled():
    docs = (
        get_db()
        .collection("trips")
        .where("bookingType", "==", "scheduled")
        .limit(50)
        .stream()
    )
    return jsonify({"trips": [serialize_doc(doc_to_dict(d) or {}) for d in docs]})


@scheduled_bp.post("/dispatch")
@require_admin()
def trigger_dispatch():
    now_docs = (
        get_db()
        .collection("trips")
        .where("bookingType", "==", "scheduled")
        .where("status", "==", "scheduled")
        .limit(20)
        .stream()
    )
    processed = 0
    for doc in now_docs:
        doc.reference.update({"status": "pending", "updatedAt": firestore.SERVER_TIMESTAMP})
        processed += 1
    return jsonify({"processed": processed})
