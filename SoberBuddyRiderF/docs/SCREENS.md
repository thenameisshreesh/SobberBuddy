# Screens Reference

RN → Flutter mapping for UI parity.

| RN Screen | Flutter File | Route |
|-----------|--------------|-------|
| LoginScreen.js | `features/auth/presentation/login_screen.dart` | `/login` |
| SignupScreen.js | `features/auth/presentation/signup_screen.dart` | `/signup` |
| ForgotPasswordScreen.js | `features/auth/presentation/forgot_password_screen.dart` | `/forgot-password` |
| HomeScreen.js | `features/booking/presentation/home_screen.dart` | `/home` |
| BookingConfirmationScreen.js | `features/booking/presentation/booking_confirmation_screen.dart` | `/booking-confirmation` |
| TermsConditionsScreen.js | `features/booking/presentation/terms_conditions_screen.dart` | `/terms` |
| BookingScreen.js | `features/booking/presentation/booking_screen.dart` | `/booking` |
| TripDetailsScreen.js | `features/trip/presentation/trip_details_screen.dart` | `/trip-details` |
| PaymentSummaryScreen.js | `features/payment/presentation/payment_summary_screen.dart` | `/payment-summary` |
| HistoryScreen.js | `features/history/presentation/history_screen.dart` | `/history` |
| ProfileScreen.js | `features/profile/presentation/profile_screen.dart` | `/profile` |

## Navigation Extras

### `/booking-confirmation`
`pickup`, `dropoff`, `pickupCoords`, `dropoffCoords`, `distance`, `fareBreakdown`, `isNightTime`

### `/booking`
Above + `paymentMethod`, `termsAccepted`, `vehiclePreference`

### `/trip-details`
`tripId`, `driver` (Map), `tripData` (Map)

### `/payment-summary`
`tripData`, `driver`
