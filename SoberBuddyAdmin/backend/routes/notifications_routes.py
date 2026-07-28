from flask import Blueprint, jsonify, request
from firebase_admin import firestore

from auth import require_admin
from services.firestore_service import doc_to_dict, get_db, send_fcm, serialize_doc

notifications_bp = Blueprint("notifications", __name__)


@notifications_bp.post("/broadcast")
@require_admin()
def broadcast():
    data = request.json or {}
    title = data.get("title", "SoberBuddy")
    body = data.get("body", "")
    audience = data.get("audience", "all")
    if not body:
        return jsonify({"error": "body required"}), 400

    collections = []
    if audience in ("all", "riders"):
        collections.append("users")
    if audience in ("all", "drivers"):
        collections.append("drivers")

    sent = 0
    errors = 0
    for col in collections:
        for doc in get_db().collection(col).limit(500).stream():
            token = (doc.to_dict() or {}).get("fcmToken")
            if not token:
                continue
            try:
                send_fcm(token, title, body, {"type": "promotional"})
                sent += 1
            except Exception:
                errors += 1

    get_db().collection("notifications").add(
        {
            "title": title,
            "body": body,
            "audience": audience,
            "sentCount": sent,
            "errorCount": errors,
            "createdAt": firestore.SERVER_TIMESTAMP,
        }
    )
    return jsonify({"sent": sent, "errors": errors})


@notifications_bp.get("/history")
@require_admin()
def history():
    docs = get_db().collection("notifications").limit(50).stream()
    return jsonify({"campaigns": [serialize_doc(doc_to_dict(d) or {}) for d in docs]})
