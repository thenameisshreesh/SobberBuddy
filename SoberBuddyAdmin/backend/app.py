import os

from dotenv import load_dotenv
from flask import Flask, jsonify
from flask_cors import CORS

from routes.analytics_routes import analytics_bp
from routes.auth_routes import auth_bp
from routes.customers_routes import customers_bp
from routes.drivers_routes import drivers_bp
from routes.notifications_routes import notifications_bp
from routes.partners_routes import partners_bp
from routes.payouts_routes import payouts_bp
from routes.promos_routes import promos_bp
from routes.scheduled_routes import scheduled_bp
from routes.sos_routes import sos_bp
from routes.tickets_routes import tickets_bp
from routes.trips_routes import trips_bp
from services.firestore_service import init_firebase

load_dotenv()


def create_app():
    app = Flask(__name__)
    origins = os.getenv("CORS_ORIGINS", "http://localhost:5173").split(",")
    CORS(app, origins=origins, supports_credentials=True)
    init_firebase()

    app.register_blueprint(auth_bp, url_prefix="/api/auth")
    app.register_blueprint(drivers_bp, url_prefix="/api/drivers")
    app.register_blueprint(customers_bp, url_prefix="/api/customers")
    app.register_blueprint(trips_bp, url_prefix="/api/trips")
    app.register_blueprint(promos_bp, url_prefix="/api/promos")
    app.register_blueprint(partners_bp, url_prefix="/api/partners")
    app.register_blueprint(sos_bp, url_prefix="/api/sos")
    app.register_blueprint(tickets_bp, url_prefix="/api/tickets")
    app.register_blueprint(payouts_bp, url_prefix="/api/payouts")
    app.register_blueprint(notifications_bp, url_prefix="/api/notifications")
    app.register_blueprint(analytics_bp, url_prefix="/api/analytics")
    app.register_blueprint(scheduled_bp, url_prefix="/api/scheduled")

    @app.get("/api/health")
    def health():
        return jsonify({"status": "ok", "project": os.getenv("FIREBASE_PROJECT_ID", "soberbuddy-8367f")})

    return app


if __name__ == "__main__":
    app = create_app()
    app.run(host="0.0.0.0", port=int(os.getenv("FLASK_PORT", 5000)), debug=True)
