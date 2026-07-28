# SoberBuddy Admin Dashboard

React + Flask admin console for SoberBuddy (`soberbuddy-8367f`).

## Stack

- **Frontend:** React (Vite), React Router, TanStack Query, Leaflet map, mixed Driver/Rider theme
- **Backend:** Python Flask, Firebase Admin SDK
- **Auth:** Firebase email/password + OTP second step; admin whitelist in Firestore `admins` collection

## Setup

### 1. Firebase service account

1. Firebase Console → Project Settings → Service Accounts → Generate new private key
2. Save JSON outside repo (e.g. `SoberBuddyAdmin/backend/serviceAccountKey.json`)
3. Copy `backend/.env.example` to `backend/.env` and set `GOOGLE_APPLICATION_CREDENTIALS`

### 2. Seed first admin

In Firestore, create `admins/{firebase-auth-uid}`:

```json
{
  "email": "admin@soberbuddy.in",
  "name": "Admin",
  "role": "superadmin",
  "otpPhone": "+919999999999",
  "isActive": true
}
```

Create matching Firebase Auth user (email/password).

### 3. Backend

```powershell
cd SoberBuddyAdmin/backend
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
python app.py
```

Runs on http://localhost:5000

### 4. Frontend

```powershell
cd SoberBuddyAdmin/frontend
npm install
npm run dev
```

Open http://localhost:5173

**Development OTP:** In dev mode, admin second-step OTP is fixed to `123456` (no SMS). Set `DEV_ADMIN_OTP` in backend `.env` and `VITE_DEV_ADMIN_OTP` in `frontend/.env.development`.

## Deploy Firestore rules

From repo root:

```powershell
npx firebase deploy --only firestore:rules,firestore:indexes
```

## Modules

| Route | Purpose |
|-------|---------|
| `/` | Dashboard KPIs |
| `/drivers` | KYC approve/reject, force offline |
| `/customers` | Unblock riders |
| `/trips` | Live map + cancel trips |
| `/scheduled` | Scheduled bookings + dispatch |
| `/promos` | Promo code CRUD |
| `/partners` | Partner venues + QR |
| `/sos` | SOS event center |
| `/tickets` | Support tickets |
| `/payouts` | Manual driver payouts |
| `/notifications` | Promotional push broadcast |
| `/analytics` | Revenue & trip stats |

## Theme

- Driver teal: `#00D4AA`
- Rider blue: `#205090`
- Accent: `#FF6B35`
- Background: `#121212`

## Verification

See [`SoberBuddyRiderF/docs/E2E_QA.md`](../SoberBuddyRiderF/docs/E2E_QA.md) for the full cross-app checklist (Driver + Rider + Admin).

Deploy Cloud Functions from repo root:

```powershell
cd functions
npm install
firebase deploy --only functions
```

Deploy Firestore rules/indexes:

```powershell
npx firebase deploy --only firestore:rules,firestore:indexes
```
