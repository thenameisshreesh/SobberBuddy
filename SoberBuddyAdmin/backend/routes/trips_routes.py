from flask import Blueprint, jsonify, request
from firebase_admin import firestore

from auth import require_admin
from services.firestore_service import doc_to_dict, get_db, serialize_doc

trips_bp = Blueprint("trips", __name__)


@trips_bp.get("")
@require_admin()
def list_trips():
    status = request.args.get("status")
    limit = int(request.args.get("limit", 100))
    query = get_db().collection("trips")
    if status:
        query = query.where("status", "==", status)
    docs = (
        query.order_by("createdAt", direction=firestore.Query.DESCENDING)
        .limit(limit)
        .stream()
    )
    return jsonify({"trips": [serialize_doc(doc_to_dict(d) or {}) for d in docs]})


@trips_bp.get("/live")
@require_admin()
def live_data():
    active_statuses = ["pending", "accepted", "in_progress", "no_drivers", "scheduled"]
    trips = []
    for status in active_statuses:
        docs = get_db().collection("trips").where("status", "==", status).limit(30).stream()
        trips.extend([serialize_doc(doc_to_dict(d) or {}) for d in docs])

    drivers = []
    docs = get_db().collection("drivers").where("isAvailable", "==", True).limit(50).stream()
    for d in docs:
        data = doc_to_dict(d)
        if data:
            drivers.append(serialize_doc(data))
    return jsonify({"trips": trips, "drivers": drivers})


@trips_bp.get("/<trip_id>")
@require_admin()
def get_trip(trip_id):
    trip = doc_to_dict(get_db().collection("trips").document(trip_id).get())
    if not trip:
        return jsonify({"error": "Trip not found"}), 404
    return jsonify({"trip": serialize_doc(trip)})


@trips_bp.post("/<trip_id>/cancel")
@require_admin()
def cancel_trip(trip_id):
    reason = request.json.get("reason", "Cancelled by admin") if request.is_json else "Cancelled by admin"
    trip_ref = get_db().collection("trips").document(trip_id)
    trip = doc_to_dict(trip_ref.get())
    if not trip:
        return jsonify({"error": "Trip not found"}), 404

    driver_id = trip.get("driverId")
    trip_ref.update(
        {
            "status": "cancelled",
            "cancelledBy": "admin",
            "cancellationReason": reason,
            "cancelledAt": firestore.SERVER_TIMESTAMP,
            "updatedAt": firestore.SERVER_TIMESTAMP,
        }
    )
    if driver_id:
        get_db().collection("drivers").document(driver_id).update(
            {"isAvailable": True, "currentTrip": None, "updatedAt": firestore.SERVER_TIMESTAMP}
        )
    return jsonify({"success": True})


@trips_bp.post("/<trip_id>/assign-driver")
@require_admin()
def assign_driver(trip_id):
    body = request.get_json(silent=True) or {}
    driver_id = body.get("driverId")
    if not driver_id:
        return jsonify({"error": "driverId required"}), 400

    db = get_db()
    trip_ref = db.collection("trips").document(trip_id)
    driver_ref = db.collection("drivers").document(driver_id)

    @firestore.transactional
    def assign_in_transaction(transaction):
        trip_snap = trip_ref.get(transaction=transaction)
        driver_snap = driver_ref.get(transaction=transaction)
        if not trip_snap.exists:
            raise ValueError("Trip not found")
        trip = trip_snap.to_dict() or {}
        if trip.get("status") not in ("pending", "scheduled", "no_drivers"):
            raise ValueError("Trip not assignable")
        driver = driver_snap.to_dict() or {}
        if not driver.get("isAvailable") or driver.get("currentTrip"):
            raise ValueError("Driver unavailable")
        doc_status = driver.get("documentStatus")
        if doc_status is not None and doc_status != "approved":
            raise ValueError("Driver documents not approved")

        previous_driver_id = trip.get("driverId")
        if previous_driver_id and previous_driver_id != driver_id:
            prev_ref = db.collection("drivers").document(previous_driver_id)
            transaction.update(
                prev_ref,
                {
                    "isAvailable": True,
                    "currentTrip": None,
                    "updatedAt": firestore.SERVER_TIMESTAMP,
                },
            )

        offered = list(trip.get("offeredDriverIds") or [])
        if driver_id not in offered:
            offered = [driver_id]

        transaction.update(
            trip_ref,
            {
                "driverId": None,
                "offeredDriverIds": offered,
                "status": "pending",
                "updatedAt": firestore.SERVER_TIMESTAMP,
            },
        )

    try:
        assign_in_transaction(db.transaction())
    except ValueError as exc:
        return jsonify({"error": str(exc)}), 400
    return jsonify({"success": True})
