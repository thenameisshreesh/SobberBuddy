import json
import os
from functools import lru_cache

import firebase_admin
from firebase_admin import credentials, firestore, messaging, storage


@lru_cache(maxsize=1)
def init_firebase():
    if firebase_admin._apps:
        return
    cred_json = os.getenv("FIREBASE_SERVICE_ACCOUNT_JSON")
    cred_path = os.getenv("GOOGLE_APPLICATION_CREDENTIALS")
    project_id = os.getenv("FIREBASE_PROJECT_ID", "soberbuddy-8367f")
    options = {"storageBucket": f"{project_id}.firebasestorage.app"}
    if cred_json:
        firebase_admin.initialize_app(credentials.Certificate(json.loads(cred_json)), options)
    elif cred_path and os.path.isfile(cred_path):
        firebase_admin.initialize_app(credentials.Certificate(cred_path), options)
    else:
        firebase_admin.initialize_app(options={"projectId": project_id})


def get_db():
    init_firebase()
    return firestore.client()


def get_bucket():
    init_firebase()
    return storage.bucket()


def send_fcm(token: str, title: str, body: str, data: dict | None = None):
    init_firebase()
    messaging.send(
        messaging.Message(
            token=token,
            notification=messaging.Notification(title=title, body=body),
            data={k: str(v) for k, v in (data or {}).items()},
        )
    )


def doc_to_dict(doc):
    if not doc.exists:
        return None
    data = doc.to_dict() or {}
    data["id"] = doc.id
    return data


def serialize_value(value):
    if hasattr(value, "isoformat"):
        return value.isoformat()
    if hasattr(value, "latitude") and hasattr(value, "longitude"):
        return {"latitude": value.latitude, "longitude": value.longitude}
    if isinstance(value, dict):
        return {k: serialize_value(v) for k, v in value.items()}
    if isinstance(value, list):
        return [serialize_value(v) for v in value]
    return value


def serialize_doc(data: dict) -> dict:
    return {k: serialize_value(v) for k, v in data.items()}
