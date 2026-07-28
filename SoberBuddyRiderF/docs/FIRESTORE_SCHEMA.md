# Firestore Schema

Do not rename fields — driver app depends on these.

## users

```
uid, name, email, mobile, phone, userType ('consumer')
accountStatus ('active'|'deleted'), isActive, isBlocked
cancellationCount, pendingCancellationFees, lastCancellationAt
feesIncludedInTrip, feesIncludedAmount
profilePicture (base64 data URI)
rating, totalRatings, createdAt, updatedAt, deletedAt
```

## drivers

```
name, phone, licenseNumber, isAvailable, currentTrip
rating, totalRatings, ratingDistribution
```

## trips

```
consumerId, driverId, pickup, dropoff
pickupCoords {latitude, longitude}, dropoffCoords
distance, estimatedDuration, isNightTime
fareBreakdown {baseFare, distanceCharge, timeCharge, nightCharge, total, cancellationFees}
totalFare, finalTotalFare, finalFareBreakdown
status, paymentMethod, vehiclePreference
consumerInfo {name, phone}, termsAccepted
stages {created, accepted, inProgress, completed}
cancellationFee, cancelledBy, cancelledAt, cancellationReason
createdAt, updatedAt, completedAt
```

## payments

```
tripId, consumerId, driverId, totalAmount
driverEarnings, companyEarnings, paymentMethod, status
fareBreakdown, createdAt, updatedAt, completedAt
```

## ratings

```
tripId, ratedBy, ratedUser, userType ('driver'|'consumer')
rating (1-5), comment, createdAt
```

## fees

```
tripId, consumerId, amount, type ('cancellation_fee')
status ('pending'), description
```

## Required Indexes

- trips: `consumerId` + `createdAt` desc
- trips: `consumerId` + `status` + `createdAt` desc
- ratings: `ratedUser` + `userType`
