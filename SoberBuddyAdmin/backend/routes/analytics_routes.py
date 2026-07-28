from flask import Blueprint, jsonify

from auth import require_admin
from services.firestore_service import doc_to_dict, get_db

analytics_bp = Blueprint("analytics", __name__)


@analytics_bp.get("/summary")
@require_admin()
def summary():
    db = get_db()
    trips = list(db.collection("trips").limit(500).stream())
    drivers = list(db.collection("drivers").limit(500).stream())
    users = list(db.collection("users").where("userType", "==", "consumer").limit(500).stream())
    sos = list(db.collection("sos_events").where("status", "==", "active").limit(20).stream())
    tickets = list(db.collection("support_tickets").where("status", "==", "open").limit(20).stream())

    active_trips = 0
    completed_trips = 0
    revenue = 0.0
    for t in trips:
        data = t.to_dict() or {}
        status = data.get("status")
        if status in ("pending", "accepted", "in_progress"):
            active_trips += 1
        if status == "completed":
            completed_trips += 1
            revenue += float(data.get("finalTotalFare") or data.get("totalFare") or 0)

    online_drivers = sum(1 for d in drivers if (d.to_dict() or {}).get("isAvailable"))

    return jsonify(
        {
            "activeTrips": active_trips,
            "completedTrips": completed_trips,
            "totalRevenue": revenue,
            "onlineDrivers": online_drivers,
            "totalDrivers": len(drivers),
            "totalCustomers": len(users),
            "openSos": len(sos),
            "openTickets": len(tickets),
        }
    )
