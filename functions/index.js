const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onDocumentUpdated } = require('firebase-functions/v2/firestore');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');

initializeApp();
const db = getFirestore();

function haversineKm(lat1, lon1, lat2, lon2) {
  const R = 6371;
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLon = ((lon2 - lon1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLon / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

function parseLocation(data) {
  const loc = data?.lastKnownLocation;
  if (!loc) return null;
  if (loc.latitude != null && loc.longitude != null) {
    return { lat: loc.latitude, lng: loc.longitude };
  }
  if (loc._latitude != null && loc._longitude != null) {
    return { lat: loc._latitude, lng: loc._longitude };
  }
  return null;
}

function isDriverEligible(data, excludeIds = []) {
  if (!data.isAvailable) return false;
  if (data.currentTrip) return false;
  const status = data.documentStatus;
  if (status && status !== 'approved') return false;
  return true;
}

async function findNearestDriver(pickupLat, pickupLng, excludeDriverIds = []) {
  const snapshot = await db.collection('drivers').where('isAvailable', '==', true).get();
  const candidates = [];
  for (const doc of snapshot.docs) {
    if (excludeDriverIds.includes(doc.id)) continue;
    const data = doc.data();
    if (!isDriverEligible(data, excludeDriverIds)) continue;
    const loc = parseLocation(data);
    const distance = loc
      ? haversineKm(pickupLat, pickupLng, loc.lat, loc.lng)
      : 99999;
    candidates.push({ id: doc.id, data, distance });
  }
  candidates.sort((a, b) => a.distance - b.distance);
  return candidates;
}

async function lockDriverToTrip(tripId, driverId) {
  const tripRef = db.collection('trips').doc(tripId);
  const driverRef = db.collection('drivers').doc(driverId);
  await db.runTransaction(async (tx) => {
    const [tripSnap, driverSnap] = await Promise.all([
      tx.get(tripRef),
      tx.get(driverRef),
    ]);
    if (!tripSnap.exists) throw new HttpsError('not-found', 'Trip not found');
    const trip = tripSnap.data();
    if (!['pending', 'declined'].includes(trip.status)) {
      throw new HttpsError('failed-precondition', 'Trip not assignable');
    }
    const driver = driverSnap.data() || {};
    if (!isDriverEligible(driver)) {
      throw new HttpsError('aborted', 'Driver unavailable');
    }
    tx.update(tripRef, {
      driverId,
      status: 'pending',
      updatedAt: FieldValue.serverTimestamp(),
    });
    tx.update(driverRef, {
      currentTrip: tripId,
      isAvailable: false,
      updatedAt: FieldValue.serverTimestamp(),
    });
  });
  const driverDoc = await driverRef.get();
  return { id: driverId, ...driverDoc.data() };
}

async function offerTripToNearestDrivers(tripId, pickupLat, pickupLng, excludeDriverIds = [], limit = 5) {
  const drivers = await findNearestDriver(pickupLat, pickupLng, excludeDriverIds);
  if (drivers.length === 0) {
    await db.collection('trips').doc(tripId).update({
      status: 'no_drivers',
      offeredDriverIds: [],
      updatedAt: FieldValue.serverTimestamp(),
    });
    return { success: false, reason: 'no_drivers' };
  }

  const offeredDriverIds = drivers.slice(0, limit).map((d) => d.id);
  await db.collection('trips').doc(tripId).update({
    driverId: null,
    status: 'pending',
    offeredDriverIds,
    updatedAt: FieldValue.serverTimestamp(),
  });

  for (const driverId of offeredDriverIds) {
    await sendPushToUser(
      driverId,
      'drivers',
      'New trip request',
      'Open the app to accept or decline',
      { tripId, type: 'trip_offer' },
    );
  }

  return { success: true, mode: 'broadcast', offeredDriverIds, tripId };
}

exports.assignNearestDriver = onCall(async (request) => {
  const { tripId, pickupLat, pickupLng, excludeDriverIds = [] } = request.data || {};
  if (!tripId || pickupLat == null || pickupLng == null) {
    throw new HttpsError('invalid-argument', 'tripId and pickup coordinates required');
  }
  return offerTripToNearestDrivers(tripId, pickupLat, pickupLng, excludeDriverIds);
});

exports.reassignOnDecline = onCall(async (request) => {
  const { tripId } = request.data || {};
  if (!tripId) throw new HttpsError('invalid-argument', 'tripId required');

  const tripRef = db.collection('trips').doc(tripId);
  const tripSnap = await tripRef.get();
  if (!tripSnap.exists) throw new HttpsError('not-found', 'Trip not found');
  const trip = tripSnap.data();

  const declinedDriverId = trip.driverId;
  const declinedDriverIds = [...(trip.declinedDriverIds || [])];
  if (declinedDriverId && !declinedDriverIds.includes(declinedDriverId)) {
    declinedDriverIds.push(declinedDriverId);
  }

  if (declinedDriverId) {
    await db.collection('drivers').doc(declinedDriverId).update({
      isAvailable: true,
      currentTrip: null,
      updatedAt: FieldValue.serverTimestamp(),
    });
  }

  const pickup = trip.pickupCoords || {};
  const lat = pickup.latitude ?? pickup._latitude;
  const lng = pickup.longitude ?? pickup._longitude;
  if (lat == null || lng == null) {
    throw new HttpsError('failed-precondition', 'Trip missing pickup coordinates');
  }

  await tripRef.update({
    status: 'pending',
    driverId: null,
    declinedDriverIds,
    offeredDriverIds: [],
    updatedAt: FieldValue.serverTimestamp(),
  });

  return offerTripToNearestDrivers(tripId, lat, lng, declinedDriverIds);
});

async function sendPushToUser(userId, collection, title, body, data = {}) {
  const doc = await db.collection(collection).doc(userId).get();
  const token = doc.data()?.fcmToken;
  if (!token) return;
  await getMessaging().send({
    token,
    notification: { title, body },
    data: Object.fromEntries(Object.entries(data).map(([k, v]) => [k, String(v)])),
  });
}

exports.onTripStatusChange = onDocumentUpdated('trips/{tripId}', async (event) => {
  const before = event.data.before.data();
  const after = event.data.after.data();
  if (!before || !after || before.status === after.status) return;

  const tripId = event.params.tripId;
  const status = after.status;

  if (status === 'accepted' && after.promoCode && before.status !== 'accepted') {
    const promoSnap = await db.collection('promo_codes')
      .where('code', '==', String(after.promoCode).toUpperCase())
      .limit(1)
      .get();
    if (!promoSnap.empty) {
      await promoSnap.docs[0].ref.update({
        usedCount: FieldValue.increment(1),
        updatedAt: FieldValue.serverTimestamp(),
      });
    }
  }

  const messages = {
    accepted: { title: 'Driver accepted', body: 'Your driver is on the way!' },
    in_progress: { title: 'Ride started', body: 'Your trip has started.' },
    completed: { title: 'Ride completed', body: 'Thank you for riding with SoberBuddy.' },
    cancelled: { title: 'Trip cancelled', body: 'Your trip was cancelled.' },
    declined: { title: 'Finding new driver', body: 'We are assigning another driver.' },
    no_drivers: { title: 'No drivers available', body: 'Please try again shortly.' },
  };
  const msg = messages[status];
  if (!msg) return;

  if (after.consumerId) {
    await sendPushToUser(after.consumerId, 'users', msg.title, msg.body, { tripId, status });
  }
  if (after.driverId && ['pending', 'accepted'].includes(status)) {
    await sendPushToUser(after.driverId, 'drivers', 'Trip update', msg.body, { tripId, status });
  }
});

exports.validatePromoCode = onCall(async (request) => {
  const { code, userId } = request.data || {};
  if (!code) throw new HttpsError('invalid-argument', 'code required');
  const snap = await db.collection('promo_codes').where('code', '==', code.toUpperCase()).limit(1).get();
  if (snap.empty) throw new HttpsError('not-found', 'Invalid promo code');
  const promo = snap.docs[0].data();
  if (!promo.isActive) throw new HttpsError('failed-precondition', 'Promo code inactive');
  if (promo.expiresAt?.toDate?.() < new Date()) {
    throw new HttpsError('failed-precondition', 'Promo code expired');
  }
  if (promo.maxUses && promo.usedCount >= promo.maxUses) {
    throw new HttpsError('resource-exhausted', 'Promo code fully used');
  }
  if (promo.type === 'first_ride' && userId) {
    const userTrips = await db.collection('trips')
      .where('consumerId', '==', userId)
      .where('status', '==', 'completed')
      .limit(1)
      .get();
    if (!userTrips.empty) throw new HttpsError('failed-precondition', 'First ride only');
  }
  return {
    code: snap.docs[0].id,
    type: promo.type,
    value: promo.value,
    discount: promo.type === 'percentage'
      ? { type: 'percentage', value: promo.value }
      : { type: 'flat', value: promo.value },
  };
});

exports.onSosTriggered = onCall(async (request) => {
  const { tripId, userId, userType, latitude, longitude, emergencyContacts = [] } = request.data || {};
  if (!tripId || !userId) throw new HttpsError('invalid-argument', 'tripId and userId required');

  await db.collection('sos_events').add({
    tripId,
    userId,
    userType,
    latitude,
    longitude,
    emergencyContacts,
    createdAt: FieldValue.serverTimestamp(),
    status: 'active',
  });

  await db.collection('trips').doc(tripId).update({
    sosTriggered: true,
    updatedAt: FieldValue.serverTimestamp(),
  });

  return { success: true };
});

exports.scheduledTripDispatcher = onCall(async (request) => {
  return dispatchDueScheduledTrips();
});

async function dispatchDueScheduledTrips() {
  const now = new Date();
  const snapshot = await db.collection('trips')
    .where('bookingType', '==', 'scheduled')
    .where('status', '==', 'scheduled')
    .where('scheduledAt', '<=', now)
    .limit(20)
    .get();

  const results = [];
  for (const doc of snapshot.docs) {
    const trip = doc.data();
    const pickup = trip.pickupCoords || {};
    const lat = pickup.latitude ?? pickup._latitude;
    const lng = pickup.longitude ?? pickup._longitude;
    if (lat == null || lng == null) continue;
    await doc.ref.update({ status: 'pending', updatedAt: FieldValue.serverTimestamp() });
    const result = await offerTripToNearestDrivers(doc.id, lat, lng, []);
    results.push({ tripId: doc.id, ...result });
  }
  return { processed: results.length, results };
}

exports.scheduledTripDispatcherCron = onSchedule('every 5 minutes', async () => {
  await dispatchDueScheduledTrips();
});
