# Business Rules

Preserve exactly — shared with driver app backend.

## Pricing (INR)

| Rule | Value |
|------|-------|
| Base fare | ₹350 for first 5 km OR 30 min |
| Extra distance | ₹20/km after base |
| Extra time | ₹5/min after base |
| Night charges | ₹200 (10 PM – 6 AM) |
| Cancellation fee | ₹100 (only after driver accepts) |
| Driver share | 80% |
| Company share | 20% |

Implementation: `lib/core/constants/pricing.dart`, `lib/core/utils/helpers.dart`

## Cancellation Policy

- Fee applies only when trip status is `accepted` or `in_progress`
- User `cancellationCount` increments on fee-applied cancellations
- Block user (`isBlocked: true`) after 3 post-acceptance cancellations
- Pending fees stored in `users.pendingCancellationFees`
- Fees rolled into next trip via `feesIncludedInTrip` on trip creation
- Fees cleared on successful trip completion

## User Eligibility

- `canUserBookTrip`: checks `users.isBlocked`, returns `pendingFees`
- Consumer-only: `userType` must be `consumer`
- Deleted accounts: `accountStatus === 'deleted'` or `isActive === false`

## Trip Status Flow

`pending` → `accepted` → `in_progress` → `completed`

Also: `cancelled`, `declined`

## Payment

- Methods: UPI / Cash (stored as `cash`)
- Payment record created on trip completion screen load
- Driver confirms cash receipt (driver app)
