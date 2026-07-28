from flask import Blueprint, jsonify, request
from firebase_admin import firestore

from auth import require_admin
from services.firestore_service import doc_to_dict, get_db, serialize_doc

customers_bp = Blueprint("customers", __name__)


@customers_bp.get("")
@require_admin()
def list_customers():
    limit = int(request.args.get("limit", 50))
    docs = (
        get_db()
        .collection("users")
        .where("userType", "==", "consumer")
        .limit(limit)
        .stream()
    )
    return jsonify({"customers": [serialize_doc(doc_to_dict(d) or {}) for d in docs]})


@customers_bp.get("/<customer_id>")
@require_admin()
def get_customer(customer_id):
    user = doc_to_dict(get_db().collection("users").document(customer_id).get())
    if not user:
        return jsonify({"error": "Customer not found"}), 404
    trips = (
        get_db()
        .collection("trips")
        .where("consumerId", "==", customer_id)
        .limit(20)
        .stream()
    )
    return jsonify(
        {
            "customer": serialize_doc(user),
            "trips": [serialize_doc(doc_to_dict(t) or {}) for t in trips],
        }
    )


@customers_bp.post("/<customer_id>/unblock")
@require_admin()
def unblock_customer(customer_id):
    get_db().collection("users").document(customer_id).update(
        {
            "isBlocked": False,
            "blockedAt": None,
            "blockedReason": None,
            "cancellationCount": 0,
            "updatedAt": firestore.SERVER_TIMESTAMP,
        }
    )
    return jsonify({"success": True})
