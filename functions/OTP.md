# 2Factor OTP (Rider & Driver)

Phone OTP for Rider and Driver apps is sent/verified through **2Factor.in** via Cloud Functions. Apps then sign in with a Firebase **custom token**.

## Callables

| Function | Purpose |
|----------|---------|
| `sendPhoneOtp` | Sends SMS OTP via approved template `SoberBuddy` (`AUTOGEN/SoberBuddy`); returns `{ sessionId }` |
| `verifyPhoneOtp` | Verifies OTP; creates/finds Firebase Auth user by phone; returns `{ customToken, uid }` |

SMS template (2Factor Home > SMS OTP > OTP Templates, approved):

- Name: `SoberBuddy` (must match OTP Templates name exactly; DLT may show `Sober_Buddy`)
- Sender: `SBRBDY`
- PE ID: `1101379460000098472`
- CT ID: `1177179065844820611`
- Body: `XXXX is your otp for login or signup. - SoberBuddy -SoberBuddy`

Region: `us-central1` (same as promo/SOS/trips).

## One-time secret setup

Store the 2Factor API key as a Firebase Functions secret (never in Flutter / git):

```powershell
cd M:\me\Projects\SoberBuddyF
firebase functions:secrets:set TWOFACTOR_API_KEY
# Paste the key from https://2factor.in dashboard when prompted
```

## IAM (required for login after OTP)

`verifyPhoneOtp` mints a Firebase custom token. The Cloud Functions runtime SA needs **Service Account Token Creator**:

1. Open [IAM for soberbuddy-8367f](https://console.cloud.google.com/iam-admin/iam?project=soberbuddy-8367f)
2. Find `411558557396-compute@developer.gserviceaccount.com` (Default compute service account)
3. Edit → add role **Service Account Token Creator** → Save

Without this, OTP can verify with 2Factor but the app shows **INTERNAL** / login fails.

If you have `gcloud`:

```powershell
gcloud projects add-iam-policy-binding soberbuddy-8367f `
  --member="serviceAccount:411558557396-compute@developer.gserviceaccount.com" `
  --role="roles/iam.serviceAccountTokenCreator"
```

## Deploy

```powershell
cd M:\me\Projects\SoberBuddyF
firebase deploy --only functions:sendPhoneOtp,functions:verifyPhoneOtp
```

Or deploy all functions:

```powershell
firebase deploy --only functions
```

## Smoke test

1. Deploy functions with the secret set.
2. Rider / Driver app → Send OTP to a real Indian mobile.
3. Enter the SMS code → Verify.
4. Confirm login reaches home/drive and Firestore profile loads (proves custom-token auth works).

## Notes

- API key must remain only in `TWOFACTOR_API_KEY`. Rotate in the 2Factor dashboard if it was exposed.
- Firebase Console **Phone** provider is no longer required for Rider/Driver SMS (optional to disable later).
- Ensure 2Factor SMS OTP balance / DLT template is active for production delivery.
