# SoberBuddy E2E QA Checklist

Run on a **physical Android device** after `flutter run` (debug) or release build. Mark each item when verified.

Scope: requirements **1–7, 9–18** (digital payment gateway #8 is out of scope).

## Auth (Req #2)

### Rider (`SoberBuddyRiderF`)
- [ ] Sign up with phone OTP (`9999999999` / `123456` test number)
- [ ] Login with same phone OTP navigates to home
- [ ] Resend OTP respects cooldown
- [ ] Driver account rejected (rider guard)
- [ ] Deleted account shows blocked message
- [ ] Sign out from profile

### Driver (`SoberBuddyDriverF`)
- [ ] Sign up with phone OTP (`8888888888` / `654321` test number)
- [ ] Login with same phone OTP navigates to dashboard (no auth race)
- [ ] Document upload screen shown after signup

### Admin (`SoberBuddyAdmin`)
- [ ] Email/password login + OTP second step
- [ ] Non-whitelisted user rejected

## Booking & assignment (Req #1, #15, #16–17)

- [ ] GPS pickup loads current location
- [ ] Manual pickup when GPS fails / timeout
- [ ] Places autocomplete suggests and selects address
- [ ] Map shows pickup/dropoff markers and route polyline
- [ ] Fare breakdown updates (distance, night surcharge)
- [ ] Vehicle type + transmission selection
- [ ] T&C checkbox + full terms screen
- [ ] Instant booking → finding driver → driver assigned via Cloud Function (or client fallback)
- [ ] Driver decline → rider reassigns automatically
- [ ] **Scheduled booking:** set future time → trip status `scheduled` → no immediate driver search
- [ ] Scheduled trip dispatched by cron / admin trigger when due
- [ ] Partner QR scan → `partnerId` stored on trip

## Trip lifecycle (Req #5, #12)

- [ ] Trip created in Firestore with correct fields
- [ ] Real-time status updates on trip details
- [ ] Driver location updates on map (8s stream)
- [ ] **ETA** shown on rider trip details (`etaMinutes`)
- [ ] Call driver opens dialer
- [ ] Cancel before accept — no fee
- [ ] Cancel after accept — ₹100 fee applied
- [ ] 3 post-accept cancellations → account blocked UI
- [ ] Pending fees added to next trip fare
- [ ] Trip completion navigates to payment summary
- [ ] Ride history on rider and driver apps

## Driver ops (Req #6, #13)

- [ ] Driver uploads KYC documents
- [ ] Admin approves documents → `documentStatus: approved`
- [ ] Driver can go online only after approval
- [ ] Online/offline toggle works

## Payment & rating (Req #8 partial, #14)

- [ ] Cash payment record created in Firestore (no gateway)
- [ ] Star rating required to submit (or skip)
- [ ] Both rider and driver can rate after trip

## Promos (Req #10)

- [ ] Admin creates promo code
- [ ] Rider applies promo at booking confirmation
- [ ] `usedCount` increments when trip accepted

## SOS (Req #11)

- [ ] Rider/driver SOS button creates `sos_events` doc
- [ ] Admin SOS center shows active events
- [ ] Admin can mark resolved

## Support (Req #18)

- [ ] Rider creates support ticket
- [ ] Admin inbox: assign, reply, close

## Payouts (Req #9)

- [ ] Admin creates payout record for driver
- [ ] Admin marks payout paid
- [ ] Driver earnings screen shows pending vs paid payouts (read-only)

## Push notifications (Req #3)

- [ ] Trip status change push (requires `onTripStatusChange` deployed)
- [ ] Admin promotional broadcast sends FCM to segment

## Admin dashboard (Req #7)

- [ ] Dashboard KPIs load
- [ ] Drivers: list, KYC approve/reject, block, force offline
- [ ] Customers: list, unblock
- [ ] Trips: list, live map, reassign/cancel
- [ ] Promos, Partners/QR, SOS, Tickets, Payouts, Notifications, Analytics, Scheduled modules

## Full E2E script

1. Admin approves driver KYC
2. Driver goes online
3. Rider books instant trip → driver accepts → trip completes → cash payment
4. Admin records payout → driver sees payout in earnings
5. Rider schedules future trip → cron dispatches at due time
6. Rider triggers SOS → admin resolves
7. Rider opens support ticket → admin closes
8. Admin creates partner + QR → rider scans and books

## Automated checks (CI/local)

```powershell
cd SoberBuddyRiderF
flutter analyze
flutter test

cd ..\SoberBuddyDriverF
flutter analyze
```

## Cloud Functions deploy

From repo root:

```powershell
cd functions
npm install
firebase deploy --only functions
```

Functions: `assignNearestDriver`, `reassignOnDecline`, `onTripStatusChange`, `validatePromoCode`, `onSosTriggered`, `scheduledTripDispatcher`, `scheduledTripDispatcherCron`

Last updated: 2026-07-18
