# Future Features Reference

This document catalogs **commented-out or incomplete features** from the React Native SoberBuddyDriver app. These were intentionally **not implemented** in the initial Flutter migration. Use this as a reference when you want to add them later.

---

## 1. Dashboard Today-Stats Cards

| Property | Value |
|----------|-------|
| RN file | `src/screens/dashboard/DashboardScreen.js` |
| Status | Commented out in RN |
| Description | Cards showing today's trips, earnings, and online hours on the dashboard overlay |

### UI elements
- Stats card with 3 columns: Trips / Earned / Online hours
- Driver tips card (bulb icon + earnings tip)
- Weekly goal progress card linking to Earnings tab

### Flutter implementation approach
1. Add `TodayStatsCard`, `TipsCard`, `GoalProgressCard` widgets in `lib/widgets/`
2. Call `TripService.getDriverEarningsStats()` (already ported) in `DashboardScreen`
3. Place below the status card in the dashboard overlay

### Dependencies
- None beyond existing `trip_service.dart`

---

## 2. Earnings Period Filters

| Property | Value |
|----------|-------|
| RN file | `src/screens/history/EarningsScreen.js` |
| Status | Commented out in RN |
| Description | Segmented control to filter earnings by Today / Week / Month / All Time |

### Flutter implementation approach
1. Use existing `FilterPills` widget in `EarningsScreen`
2. Port `getFilteredTrips()` and `getCurrentPeriodStats()` from RN
3. Stats data already available from `getDriverEarningsStats()`

### Dependencies
- None

---

## 3. Profile Notification Toggles

| Property | Value |
|----------|-------|
| RN file | `src/screens/profile/ProfileScreen.js` |
| Status | Commented out in RN |
| Description | Toggle switches for trip alerts, payment updates, and promotions |

### Dependencies
- `firebase_messaging` for real push notifications
- FCM setup in Firebase Console

---

## 4. Profile Help & Rating History Links

| Property | Value |
|----------|-------|
| RN file | `src/screens/profile/ProfileScreen.js` |
| Status | Commented out in RN |

### Flutter implementation
Add `ActionRow` widgets linking to `/help` and `/rating-history` (routes already exist).

---

## 5. TripHistory → TripDetails Navigation

| Property | Value |
|----------|-------|
| RN file | `src/screens/history/TripHistoryScreen.js` |
| Status | Commented out in RN |

### Flutter implementation
`context.push('/trip-details/${trip.id}')` on trip card tap.

---

## 6. ReportIssue Screen

| Property | Value |
|----------|-------|
| RN file | `src/screens/profile/HelpScreen.js` |
| Status | Route not registered in RN — would crash |

### Suggested implementation
Create `report_issue_screen.dart`, register `/report-issue` route, save to Firestore `issues` collection.

---

## 7. SafetyGuidelines Screen

| Property | Value |
|----------|-------|
| RN file | `src/screens/profile/HelpScreen.js` |
| Status | Route not registered in RN |

### Suggested implementation
Static content screen at `/safety-guidelines`.

---

## 8. TripAlert Standalone Component

Already consolidated into `lib/widgets/trip_alert_overlay.dart` in Flutter.

---

## 9. Push Notifications (FCM)

Not implemented in RN. Requires `firebase_messaging`, Cloud Functions, and FCM token storage in `drivers/{uid}`.

---

## 10. Dashboard Trip Countdown Timer

15-second auto-decline timer on trip alert (commented out in RN).

---

## 11. Profile Driver Stats Card

Shows total trips, earnings, rating (commented out in RN). Data available in `drivers/{uid}`.

---

## Priority Table

| Priority | Feature | Effort |
|----------|---------|--------|
| High | TripHistory → TripDetails tap | Low |
| High | Profile Help/Rating links | Low |
| Medium | Earnings period filters | Low |
| Medium | Dashboard today-stats | Medium |
| High (infra) | Push notifications | High |
