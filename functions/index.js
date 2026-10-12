const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onDocumentUpdated } = require('firebase-functions/v2/firestore');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { defineSecret } = require('firebase-functions/params');
const { initializeApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');

initializeApp();
const db = getFirestore();
const auth = getAuth();

const twoFactorApiKey = defineSecret('TWOFACTOR_API_KEY');
/** Approved 2Factor SMS OTP template name (Home > SMS OTP > OTP Templates). */
const TWOFACTOR_OTP_TEMPLATE = 'SoberBuddy';
const OTP_SEND_COOLDOWN_MS = 30 * 1000;
/** @type {Map<string, number>} */
const otpSendCooldownByPhone = new Map();

function normalizeIndianPhone(phoneInput) {
  const digits = String(phoneInput || '').replace(/\D/g, '');
  let local = digits;
  if (digits.length === 12 && digits.startsWith('91')) {
    local = digits.substring(2);
  } else if (digits.length === 11 && digits.startsWith('0')) {
    local = digits.substring(1);
  }
  if (local.length !== 10 || !/^[6-9]\d{9}$/.test(local)) {
    return null;
  }
  return {
    local,
    e164: `+91${local}`,
    twoFactor: `91${local}`,
  };
}

async function callTwoFactor(path) {
  const apiKey = twoFactorApiKey.value();
  if (!apiKey) {
    throw new HttpsError('failed-precondition', 'OTP service is not configured.');
  }
  // Always use SMS OTP API (never /VOICE/...). Template forces SMS body via SBRBDY.
  const url = `https://2factor.in/API/V1/${apiKey}/${path}`;
  let response;
  try {
    response = await fetch(url);
  } catch (_) {
    throw new HttpsError('unavailable', 'Unable to reach OTP service. Please try again.');
  }
  let data;
  try {
    data = await response.json();
  } catch (_) {
    throw new HttpsError('internal', 'Invalid response from OTP service.');
  }
  return data;
}

function mapTwoFactorSendError(data) {
  const detail = String(data?.Details || data?.Status || 'OTP send failed');
  const lower = detail.toLowerCase();
  if (lower.includes('balance') || lower.includes('credit') || lower.includes('insufficient')) {
    return new HttpsError('resource-exhausted', 'SMS OTP balance exhausted. Please try again later.');
  }
  if (lower.includes('dlt') || lower.includes('template') || lower.includes('header')) {
    return new HttpsError(
      'failed-precondition',
      'SMS OTP template is not ready for delivery. Please contact support.',
    );
  }
  return new HttpsError('internal', detail);
}

exports.sendPhoneOtp = onCall(
  { secrets: [twoFactorApiKey], region: 'us-central1' },
  async (request) => {
    const phoneInfo = normalizeIndianPhone(request.data?.phone);
    if (!phoneInfo) {
      throw new HttpsError(
        'invalid-argument',
        'Enter a valid 10-digit Indian mobile number.',
      );
    }

    const now = Date.now();
    const lastSent = otpSendCooldownByPhone.get(phoneInfo.twoFactor) || 0;
    if (now - lastSent < OTP_SEND_COOLDOWN_MS) {
      const waitSecs = Math.ceil((OTP_SEND_COOLDOWN_MS - (now - lastSent)) / 1000);
      throw new HttpsError(
        'resource-exhausted',
        `Please wait ${waitSecs} seconds before requesting another OTP.`,
      );
    }

    // SMS-only: /SMS/.../AUTOGEN/{template} using approved SoberBuddy (SBRBDY) template.
    const data = await callTwoFactor(
      `SMS/${phoneInfo.twoFactor}/AUTOGEN/${encodeURIComponent(TWOFACTOR_OTP_TEMPLATE)}`,
    );
    console.log('2Factor SMS send', {
      phone: phoneInfo.twoFactor,
      template: TWOFACTOR_OTP_TEMPLATE,
      status: data?.Status,
      details: data?.Details,
    });
    if (String(data?.Status || '').toLowerCase() !== 'success' || !data?.Details) {
      throw mapTwoFactorSendError(data);
    }

    otpSendCooldownByPhone.set(phoneInfo.twoFactor, now);
    return {
      sessionId: String(data.Details),
      channel: 'sms',
      template: TWOFACTOR_OTP_TEMPLATE,
    };
  },
);

exports.verifyPhoneOtp = onCall(
  { secrets: [twoFactorApiKey], region: 'us-central1' },
  async (request) => {
    const phoneInfo = normalizeIndianPhone(request.data?.phone);
    const sessionId = String(request.data?.sessionId || '').trim();
    const otp = String(request.data?.otp || '').trim();

    if (!phoneInfo) {
      throw new HttpsError(
        'invalid-argument',
        'Enter a valid 10-digit Indian mobile number.',
      );
    }
    if (!sessionId) {
      throw new HttpsError('failed-precondition', 'Please request OTP first.');
    }
    if (!/^\d{4,6}$/.test(otp)) {
      throw new HttpsError('invalid-argument', 'Enter a valid OTP.');
    }

    const data = await callTwoFactor(`SMS/VERIFY/${encodeURIComponent(sessionId)}/${otp}`);
    if (String(data?.Status || '').toLowerCase() !== 'success') {
      const detail = String(data?.Details || '').toLowerCase();
      if (detail.includes('expired')) {
        throw new HttpsError('deadline-exceeded', 'OTP expired. Tap Resend OTP to get a new code.');
      }
      if (detail.includes('mismatch') || detail.includes('not matched') || detail.includes('invalid')) {
        throw new HttpsError('invalid-argument', 'Incorrect OTP. Please check the code and try again.');
      }
      throw new HttpsError(
        'permission-denied',
        data?.Details ? String(data.Details) : 'OTP verification failed.',
      );
    }

    let user;
    try {
      user = await auth.getUserByPhoneNumber(phoneInfo.e164);
    } catch (error) {
      if (error?.code !== 'auth/user-not-found') {
        console.error('getUserByPhoneNumber failed', error);
        throw new HttpsError('internal', 'Unable to look up account. Please try again.');
      }
      try {
        user = await auth.createUser({ phoneNumber: phoneInfo.e164 });
      } catch (createError) {
        console.error('createUser failed', createError);
        throw new HttpsError('internal', 'Unable to create account. Please try again.');
      }
    }

    try {
      const customToken = await auth.createCustomToken(user.uid);
      return { customToken, uid: user.uid };
    } catch (tokenError) {
      console.error('createCustomToken failed', tokenError);
      throw new HttpsError(
        'internal',
        'Login session could not be created. Please try again in a moment.',
      );
    }
  },
);

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
