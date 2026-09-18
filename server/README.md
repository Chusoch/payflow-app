# PayFlow Backend Server & P2P Wallet Ledger

Production-oriented Node.js + TypeScript + Express backend service for **PayFlow Mobile Fintech Application**.

## System Overview & Architecture

The PayFlow Backend Server is divided into two distinct system domains:

```text
                                   ┌─────────────────────────────────────────┐
                                   │           PayFlow Mobile App            │
                                   └────────────────────┬────────────────────┘
                                                        │
                                   ┌────────────────────┴────────────────────┐
                                   │     Authorization: Bearer <ID_Token>    │
                                   └─────────┬──────────────────────┬────────┘
                                             │                      │
                                             ▼                      ▼
┌──────────────────────────────────────────────────────┐  ┌──────────────────────────────────────────────────────┐
│        Part A: Payment Provider Proxy & Webhooks      │  │           Part B: PayFlow P2P Wallet Ledger          │
├──────────────────────────────────────────────────────┤  ├──────────────────────────────────────────────────────┤
│ • Relays Paystack & VTPass API requests safely.      │  │ • Manages user-to-user (P2P) transfers.              │
│ • Keeps secret API keys out of client binaries.      │  │ • Atomic Firestore transactions.                     │
│ • Validates HMAC SHA512 webhook signatures.          │  │ • 64-bit integer Kobo balances (100 kobo = ₦1).      │
│ • Deduplicates incoming webhook events.              │  │ • Identity derived strictly from Firebase Auth token.│
└──────────────────────────────────────────────────────┘  └──────────────────────────────────────────────────────┘
```

---

## 1. How to Get Free Sandbox API Keys

### Paystack Sandbox (Test Mode)
1. Sign up for a free developer account at [dashboard.paystack.com](https://dashboard.paystack.com).
2. Navigate to **Settings > API Keys & Webhooks**.
3. Copy your `Test Secret Key` (`sk_test_...`) and `Test Public Key` (`pk_test_...`).
4. Set your Webhook URL to `https://<your-ngrok-domain>/v1/payments/webhooks/paystack` and set a Secret Key.

### Flutterwave Sandbox (Test Mode)
1. Sign up for a free developer account at [dashboard.flutterwave.com](https://dashboard.flutterwave.com).
2. Navigate to **Settings > API**.
3. Copy your `Test Secret Key` (`FLWSECK_TEST-...`) and `Test Public Key` (`FLWPUBK_TEST-...`).

### VTPass Sandbox (Free Developer Testing)
1. Sign up for free sandbox access at [sandbox.vtpass.com](https://sandbox.vtpass.com).
2. Access your developer credentials in the portal (`api-key`, `secret-key`, `public-key`).
3. VTPass Sandbox endpoints do not debit real money.

---

## 2. Environment Setup (`.env`)

1. Copy `.env.example` to `.env`:
   ```bash
   cp .env.example .env
   ```

2. Fill in your server configuration and sandbox keys in `.env`:
   ```ini
   PORT=3000
   NODE_ENV=development
   FIREBASE_PROJECT_ID=payflow-dev-4fd8d
   GOOGLE_APPLICATION_CREDENTIALS=C:\Users\Username\payflow-app\server\serviceAccountKey.json
   ALLOW_DEV_ENDPOINTS=true
   ALLOW_MOCK_TOKENS=false

   PAYSTACK_SECRET_KEY=sk_test_...
   PAYSTACK_PUBLIC_KEY=pk_test_...
   VTPASS_API_KEY=...
   VTPASS_SECRET_KEY=...
   PAYSTACK_WEBHOOK_SECRET=paystack_webhook_secret_key
   ```

---

## 2.1 Firebase Admin SDK Service Account Setup (Crucial for Auth)

The backend server uses Firebase Admin SDK to mint cryptographically signed custom authentication tokens (`auth.createCustomToken()`) when users verify their phone via OTP. Without real credentials, custom token minting fails, preventing client authentication and causing `401 Unauthorized` errors on all subsequent requests.

### Step 1: Generate Private Key from Firebase Console
1. Open the [Firebase Console](https://console.firebase.google.com/).
2. Select your Firebase project (e.g. **payflow-dev-4fd8d**).
3. Click the gear icon ⚙️ next to **Project Overview** in the left sidebar and choose **Project settings**.
4. Navigate to the **Service accounts** tab.
5. Under the **Firebase Admin SDK** section, make sure **Node.js** is selected.
6. Click the blue **Generate new private key** button.
7. A confirmation dialog appears. Click **Generate key**.
8. A JSON file will download to your machine (e.g. `payflow-dev-4fd8d-firebase-adminsdk-xxxxx-xxxxxxxxxx.json`).

### Step 2: Store the Key Safely & Securely
1. Move the downloaded JSON file into your `server/` directory and rename it to `serviceAccountKey.json` (or place it in a secure local secrets folder).
   ```bash
   # Example:
   mv ~/Downloads/payflow-dev-*-firebase-adminsdk-*.json server/serviceAccountKey.json
   ```
2. **SECURITY WARNING**: This file contains private RSA signing keys that grant full administrative access to your Firebase project.
   - **NEVER** commit this file to Git.
   - The file is already included in `server/.gitignore` (`*firebase-adminsdk*.json`, `serviceAccountKey.json`, `secrets/*.json`). Verify with `git status` that the key file is untracked.

### Step 3: Configure `GOOGLE_APPLICATION_CREDENTIALS`
Set the `GOOGLE_APPLICATION_CREDENTIALS` environment variable to the **absolute path** of your JSON key file:

- **In `server/.env` (Recommended for Local Dev):**
  - **Windows (Command Prompt / PowerShell paths):**
    ```ini
    GOOGLE_APPLICATION_CREDENTIALS=C:\Users\<YourUsername>\payflow-app\server\serviceAccountKey.json
    ```
  - **macOS / Linux:**
    ```ini
    GOOGLE_APPLICATION_CREDENTIALS=/home/<yourusername>/payflow-app/server/serviceAccountKey.json
    ```

- **In Terminal / PowerShell (Optional manual export):**
  - **PowerShell:**
    ```powershell
    $env:GOOGLE_APPLICATION_CREDENTIALS="C:\Users\<YourUsername>\payflow-app\server\serviceAccountKey.json"
    ```
  - **Bash / Zsh:**
    ```bash
    export GOOGLE_APPLICATION_CREDENTIALS="/home/<yourusername>/payflow-app/server/serviceAccountKey.json"
    ```

### Step 4: Configuring for ngrok & Deployment
- **Local testing via ngrok**: The backend server runs locally on port 3000 where it loads `GOOGLE_APPLICATION_CREDENTIALS` from `server/.env`. Ngrok simply forwards HTTP traffic from your public URL to localhost:3000 — no extra credential setup is required in ngrok itself.
- **Production / Cloud Deployment (Render, Railway, Cloud Run, Docker)**:
  - **Option A (Secret File Mount)**: In platforms like Render or Kubernetes, upload the JSON as a Secret File mounted at `/etc/secrets/serviceAccountKey.json`, and set `GOOGLE_APPLICATION_CREDENTIALS=/etc/secrets/serviceAccountKey.json`.
  - **Option B (GCP Native)**: If deploying to Google Cloud Run, App Engine, or Compute Engine in the same GCP project, Application Default Credentials (ADC) are automatically provided by the GCP metadata server; `GOOGLE_APPLICATION_CREDENTIALS` is optional.

### Step 5: How to Verify Success in the Logs
After setting `GOOGLE_APPLICATION_CREDENTIALS` and restarting the server (`npm run dev`), check the console:

**✅ Successful Initialization (Real Credentials Loaded):**
```text
[Firebase] ✅ Firebase Admin SDK initialized successfully with applicationDefault() credentials.
[Firebase]    Service Account Key: C:\Users\...\server\serviceAccountKey.json
[Firebase]    Project ID: payflow-dev-4fd8d
```

**✅ Successful OTP Verification & Token Minting:**
```text
[auth/verify-otp] ✅ Minted genuine Firebase custom token for +2348012345678
[auth/verify-otp] Verification complete. Returning customToken for +2348012345678
```
The client receives a cryptographically signed JWT (`customToken: "eyJhbGciOi..."`), calls `FirebaseAuth.instance.signInWithCustomToken()`, successfully restores `currentUser`, and passes all authenticated endpoints without 401 errors.

**❌ Previous Silent-Failure Log Signature (For Comparison):**
```text
[auth/verify-otp] ❌ auth.createCustomToken FAILED: Could not load default credentials
[auth/verify-otp] ⚠️ Generating mock custom token fallback for mock session: +2348012345678
```
Previously, the backend silently fell back to returning `mock_custom_token_...`. The Flutter client detected this fake token, skipped signing in, left `currentUser == null`, and failed every subsequent authenticated request with `401 Unauthorized: Missing or malformed Authorization header`.

**❌ Current Error Behavior (If Credentials Missing / Misconfigured):**
If `GOOGLE_APPLICATION_CREDENTIALS` is unset or points to an invalid path:
- Startup prints a loud `[Firebase] ⚠️ WARNING` or `🚨 CRITICAL CONFIGURATION ERROR` banner.
- OTP verification fails with a loud `[auth/verify-otp] ❌ CRITICAL AUTH FAILURE` banner with remediation instructions and returns HTTP 500, preventing silent fallback.
- Mock tokens will **only** ever be minted if you explicitly set `ALLOW_MOCK_TOKENS=true` in `.env`.

## 3. Running the Backend Server Locally

### Installation & Build
```bash
# Install dependencies
npm install

# Run in TypeScript development mode with hot reload
npm run dev

# Run automated Jest unit & integration test suite
npm run test

# Build production bundle
npm run build

# Start production server
npm start
```

---

## 4. Connecting Flutter Mobile App via ngrok Tunnel

To allow your Flutter mobile app running on an emulator or physical device to reach your local backend server:

1. Install ngrok (`npm install -g ngrok` or download from [ngrok.com](https://ngrok.com)).
2. Start an HTTP tunnel pointing to port `3000`:
   ```bash
   ngrok http 3000
   ```
3. Copy your HTTPS forwarding URL (e.g. `https://a1b2c3d4.ngrok-free.app`).
4. Configure your Flutter client provider base URL or backend proxy URL pointing to this ngrok URL:
   ```dart
   final provider = PaystackPaymentProvider(
     backendApiBaseUrl: 'https://a1b2c3d4.ngrok-free.app',
   );
   ```

---

## 5. API Reference & Authentication

All API endpoints (except Webhook endpoints) require a valid **Firebase Auth ID Token** sent in the Authorization header:

```http
Authorization: Bearer <Firebase_ID_Token>
```

### Part A — Provider Proxy Routes

| Endpoint | Method | Auth Required | Description |
| :--- | :--- | :--- | :--- |
| `/v1/payments/paystack/initialize` | `POST` | Yes (`Bearer`) | Initializes Paystack checkout transaction. |
| `/v1/payments/paystack/verify/:reference` | `GET` | Yes (`Bearer`) | Verifies Paystack transaction by reference. |
| `/v1/payments/paystack/dedicated-account` | `POST` | Yes (`Bearer`) | Generates dedicated virtual account (DVA) for wallet top up. |
| `/v1/payments/vtpass/pay` | `POST` | Yes (`Bearer`) | Executes VTPass airtime, data, or bill payment. |
| `/v1/payments/webhooks/paystack` | `POST` | No (HMAC SHA512) | Receives Paystack `charge.success` webhooks. Verifies `x-paystack-signature`. |
| `/v1/payments/webhooks/vtpass` | `POST` | No (Signature) | Receives VTPass transaction notifications. Verifies signature. |

### Part B — P2P Wallet Ledger Routes

| Endpoint | Method | Auth Required | Description |
| :--- | :--- | :--- | :--- |
| `/v1/wallet/transfer` | `POST` | Yes (`Bearer`) | Executes atomic PayFlow-to-PayFlow transfer. Derives `fromPhone` from auth token. |
| `/v1/wallet/balance/:phone` | `GET` | Yes (`Bearer`) | Returns integer kobo balance (`walletBalance`) for given phone number. |
| `/v1/wallet/seed` | `POST` | Yes (`Bearer`) | Dev-only endpoint to fund test account (gated by `ALLOW_DEV_ENDPOINTS=true`). |

---

## 6. Difference Between Provider Proxy vs. Wallet Ledger

- **Part A (Provider Proxy)**: Acts strictly as a secure gateway for external money movement in/out of PayFlow via Paystack or VTPass. It never mutates internal PayFlow user balances directly.
- **Part B (Wallet Ledger)**: The single source of truth for internal PayFlow-to-PayFlow balances. Stores amounts as integer kobo to eliminate floating-point bugs, uses E.164 phone numbers as document keys, and executes all transfers inside isolated, atomic Firestore transactions with idempotency deduplication.
