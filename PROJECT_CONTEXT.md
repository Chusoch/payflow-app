# PayFlow Project Context & Technical Reference

## 1. Project Overview & Purpose

PayFlow is a production-minded Flutter fintech mobile application designed to model modern digital banking and financial payment workflows. 

The application exposes standard fintech capabilities including user onboarding, multi-factor authentication, security PINs, biometric authentication, wallet management, money transfers, bill payments, and user profile management.

The project follows clean, production-oriented mobile architecture, strict code quality standards, and systematic stage-by-stage development practices.

## 2. Current Flutter Architecture & Folder Structure

PayFlow adopts a **Feature-First Architecture** combined with a layered domain design:

- **Presentation Layer**: UI Views (`lib/features/[feature]/views/`) and ViewModels (`lib/features/[feature]/view_models/`) using Riverpod for state management.
- **Data & Domain Layer**: Repositories (`lib/features/[feature]/repositories/`) and Data Models (`lib/features/[feature]/models/`).
- **Core Infrastructure & Payment Platform**: Application-wide design system, shared widgets, dimensions, theme configurations, routing, and **Payment Provider Abstraction Layer** (`lib/core/payment/`).

```
lib/
├── main.dart             # Application entrypoint & MaterialApp.router binding
├── core/                 # Shared infrastructure used across multiple features
│   ├── constants/        # AppDimensions layout tokens and grid spacing
│   ├── payment/          # Stage 7 Payment Infrastructure, Provider Abstraction & Contracts
│   │   ├── docs/         # Webhook & Backend Integration contract specs
│   │   ├── models/       # PaymentStatus, PaymentRequest, Result, & Verification models
│   │   ├── providers/    # PaymentProvider contract, MockProvider, Interswitch boundary
│   │   └── services/     # PaymentService orchestrator & idempotency guard
│   ├── router/           # AppRouter configuration, ShellRoute & route guards
│   ├── theme/            # AppColors, AppTypography, AppTheme (Material 3)
│   └── widgets/          # Reusable PayFlow Buttons, TextFields, Cards, Badges
└── features/             # Feature-first domain modules
    ├── auth/             # Onboarding, Splash, Phone Entry, OTP, PIN, Biometrics
    ├── home/             # Home Dashboard launchpad, balance cards, & recent activity
    ├── wallet/           # Wallet accounts, virtual cards, top up, receive & transactions
    ├── transfer/         # Send money workflows, review & confirmation sheets
    ├── services/         # Airtime, Mobile Data, Electricity & Cable TV bill payments
    └── profile/          # Settings, Theme Preferences & Profile
```

## 3. Technology Stack & Packages

- **Framework**: Flutter (Dart SDK ^3.11.1)
- **State Management**: Flutter Riverpod (`flutter_riverpod: ^2.6.1`)
- **Navigation & Routing**: GoRouter (`go_router: ^17.5.0`) with `StatefulShellRoute.indexedStack` and route redirect guards
- **Design System**: Material 3 with Google Fonts Inter (`google_fonts: ^8.2.1`)
- **Local Persistence**: `shared_preferences: ^2.5.2`
- **Biometric Security**: `local_auth: ^2.3.0`

## 4. Completed Stages & Verification

### Stage 1 — Flutter Foundation: COMPLETE
- Initialized Flutter multi-platform application structure and established Core Design System.

### Stage 2 — Authentication & Onboarding Foundation: COMPLETE
- Splash screen, Onboarding carousel, Phone entry, 6-digit OTP, 4-digit PIN, Biometrics, Login flow, and GoRouter guards.

### Stage 3 — KYC Foundation & Account Setup: COMPLETE
- Account Tier system (Tier 1-3), Personal/Business forms, BVN/NIN verification, Selfie capture, and Document upload.

### Stage 4 — Home Dashboard Enhancement & UX Refinement: COMPLETE
- Streamlined Home Launchpad featuring Wallet Balance Card, Balance visibility toggle, Account display, Services Grid, and Banners.

### Stage 5 — Wallet & Money Transfer Workflows: COMPLETE
- `WalletViewModel` master state, Fund Wallet sheet, Receive Money sheet, Virtual Card management & freeze/unfreeze, and Send Money workflows.

### Stage 6 — Services & Utility Payments: COMPLETE
- Airtime, Mobile Data, Electricity, and Cable TV bill payments with reusable `ServiceReviewSheet` and `ServiceResultSheet`.

### Stage 7 — Payment Infrastructure & Provider Integration: COMPLETE

- **What Was Implemented**:
  - **Payment Transaction Lifecycle (`PaymentStatus`)**: Established required lifecycle `Initiated → Pending → Provider Verification → Confirmed Success / Failed / Cancelled`.
  - **Provider Abstraction Interface (`PaymentProvider`)**: Created provider-agnostic contract defining `initializePayment()` and `verifyPayment()`.
  - **Mock Payment Provider (`MockPaymentProvider`)**: Active executable provider for development and testing.
  - **Paystack Integration Boundary (`PaystackPaymentProvider`)**: Client-side boundary for Paystack dedicated virtual accounts & bank transfers, tested against HTTP mock responses.
  - **VTPass Integration Boundary (`VTPassPaymentProvider`)**: Client-side boundary for VTPass airtime, data, and bill payments targeting `sandbox.vtpass.com`, tested against HTTP mock responses.
  - **Flutterwave Extension Point (`FlutterwavePaymentProvider`)**: Documented secondary/fallback provider boundary (Intentional Scope Decision: full implementation deferred to prioritize Paystack/VTPass free sandbox integration).
  - **Parked Interswitch Boundary (`InterswitchPaymentProvider`)**: Retained in codebase as parked/unused implementation.
  - **Payment Service Orchestrator (`PaymentService`)**: Riverpod state notifier handling provider selection, idempotency deduplication (rejecting duplicate transaction references), and balance safeguards.
  - **Security Rules Enforced**: Zero secret keys embedded in Flutter client source code, `dart-define` flags, or binary assets (preventing reverse-engineering key extraction).
  - **Backend Webhook Architecture (`webhook_contract.md`)**: Updated to document Paystack (`x-paystack-signature` HMAC SHA512) and VTPass callback webhook payload formats.

### Stage 11A — Feature Cleanup & Strict Naira Currency: COMPLETE

- **What Was Implemented**:
  - **Feature Removals**: Completely removed legacy features:
    - Receive Money / Receive flow (UI modal, action buttons, view models).
    - Virtual Cards & Card Management (UI carousel, models, state, freeze/unfreeze actions).
    - Savings, USD Vault, Savings Vault, Target Savings (models, repository methods, UI card).
    - Payflow Tag / `@username` style payments.
  - **Strict Naira (₦) Currency**: Updated all balance cards, transaction details, and input prompts to use ₦ (Naira symbol) exclusively. Removed foreign currency/multi-currency references.
  - **Transfer Recipient Simplification**: Transfer types restricted strictly to:
    a) `PayFlow User` (PayFlow → PayFlow via phone number or account ID, e.g. `08012345678`).
    b) `Bank Account` (PayFlow → Bank Account via 10-digit NUBAN + bank selection).
### Stage 11B — Recent Transactions Behaviour & Overflow Fixes: COMPLETE

- **What Was Implemented**:
  - **Compact Recent Transactions List**: Refactored Home & Wallet screens to show compact transaction lists (`take(5)` on Home, paginated/filtered list on Wallet) without inline expansion.
  - **Dedicated Transaction Detail / Receipt Sheet**:
    - Tapping any transaction opens `TransactionDetailSheet.show(context, tx)` displaying full receipt details: Type, Amount in ₦, Status, Timestamp, Reference (copyable), Recipient/Sender, and Description/Narration.
    - **Electricity Token Box**: Highlights prepaid electricity tokens (e.g. `'4920-1849-2048-1039'`) in a dedicated card box with a 1-tap "Copy" button.
    - **Download & Share Actions**: Added working "Share" (copies formatted text receipt to clipboard) and "Download PDF" (simulates receipt PDF generation with feedback toast) buttons.
### Stage 11C — Critical Services & Currency Fixes: COMPLETE

- **What Was Implemented**:
  - **Strict ₦ Currency Formatting**: Replaced `Icons.attach_money_rounded` in `PayFlowTextField` across Airtime, Electricity, and Fund Wallet input screens with `Icons.numbers_rounded`, ensuring 100% Naira (₦) formatting without dollar sign visuals.
  - **Modal Context Navigation Fix**: Fixed a Flutter context unmounting issue in `ServiceReviewSheet` by passing active `BuildContext` to `onConfirm(context)` and popping review sheets cleanly before opening `ServiceResultSheet`.
  - **Instant Wallet Debit**: Updated `payService(...)` in `WalletViewModel` to validate balance, debit `mainBalance` immediately upon payment confirmation, and prepend `newTx` to `transactions`.
  - **Prepaid Electricity Token Generation**:
    - Generates a 16-digit token (e.g. `'4920-1849-2048-1039'`) on successful electricity purchases.
    - Stores `token` on `TransactionItem` and passes it to `ServiceResultSheet`.
  - **Enhanced Success & Failure Screens**:
    - Success screen renders amount in ₦, green checkmark, provider/plan details, copyable reference, and a prominent highlighted **Token Box** with a 1-tap "Copy" button for Electricity.
    - Added working **Download Receipt** (simulates PDF download) and **Share Receipt** (copies formatted receipt text summary including electricity token) buttons.
    - Failure screen displays clear error message (e.g. `'Insufficient wallet balance for this purchase.'`) and guarantees zero wallet debit.
  - **Recent Transactions & History Sync**:
    - Updated `TransactionHistoryCard` on Home to watch `walletViewModelProvider` so all new service transactions (Airtime, Data, Electricity, Cable) immediately appear in Recent Transactions on Home and Transaction History on Wallet.

### Stage 13 — Firebase Auth Client Integration & Dedicated DVA Wallet Funding: COMPLETE

- **What Was Implemented**:
  - **Firebase Custom Token Backend Route (`server/src/routes/auth.ts`)**: Implemented `POST /v1/auth/custom-token` accepting `{ phone }` and issuing custom Firebase Auth tokens using the literal E.164 phone string as the `uid` parameter (`admin.auth().createCustomToken(e164Phone)`), matching `users/{phoneNumber}` Firestore keys and `req.user.phone_number` in `auth.ts` middleware 100%.
  - **Environment Configuration (`lib/core/config/env.dart`)**: Added `Env.backendApiBaseUrl` read via `String.fromEnvironment('BACKEND_API_BASE_URL')` with `isMockMode` helper getter.
  - **Centralized Network Client (`lib/core/network/api_client.dart`)**: Built HTTP client wrapper auto-fetching `FirebaseAuth.instance.currentUser?.getIdToken()` and injecting `Authorization: Bearer <token>` into request headers.
  - **Authentication Flow Custom Token Hook (`lib/features/auth/view_models/auth_view_model.dart`)**: Hooked `_exchangeCustomToken` into `verifyOtp` after OTP validation. Retries token exchange up to 3 times and blocks navigation to authenticated screens if exchange fails.
  - **Payment Provider Routing**: Refactored `PaystackPaymentProvider` and `VTPassPaymentProvider` to route backend HTTP proxy calls through `ApiClient`.
  - **Dev Payment Provider Toggle (`lib/features/profile/views/profile_screen.dart`)**: Added runtime SegmentedButton toggle between `mock` and `paystack` providers in ProfileScreen, hidden in production builds (`!kReleaseMode`).
  - **Dedicated Virtual Account Funding (`lib/features/wallet/widgets/fund_wallet_sheet.dart`)**: Added "Bank Transfer" DVA top-up flow calling `POST /v1/payments/paystack/dedicated-account`, displaying Wema Bank virtual account with 1-tap clipboard copy, and running a bounded 90-second verification polling loop (max 30 attempts, 3s interval) with manual status refresh fallback button.
### Stage 14 — PayFlow User P2P Transfer & Bank Account Transfers Integration: COMPLETE

- **What Was Implemented**:
  - **In-App PayFlow User P2P Real Money Transfer (`server/src/routes/wallet.ts`, `lib/features/transfer/views/transfer_screen.dart`)**:
    - Wired "PayFlow User" recipient mode to call `POST /v1/wallet/transfer` with body `{ toPhone, amount_kobo, reference }`.
    - Enforced strict sender identity security: `fromPhone` is derived solely from `req.user.uid` in `auth.ts` middleware server-side. Request body from client contains NO `fromPhone` field.
    - Pre-confirmation recipient display name resolution via `GET /v1/users/:phone/profile` returning `{ displayName }`.
    - Balance refreshed post-transfer via authoritative `GET /v1/wallet/balance/me`.
    - Atomic Firestore ledger transaction debits sender balance, credits receiver balance, and writes dual credit/debit transaction log entries.
  - **External Bank Account Transfer Proxy (`server/src/routes/transfers.ts`)**:
    - Built authenticated proxy endpoints: `GET /v1/transfers/banks` (Nigerian bank list), `POST /v1/transfers/resolve-account` (NUBAN account name resolution), `POST /v1/transfers/initiate` (Paystack Transfers API recipient creation + execution), and `GET /v1/transfers/verify/:reference`.
    - Wired "Bank Account" transfer mode in `TransferScreen` to fetch banks dynamically, auto-resolve 10-digit account numbers, and execute external transfers upon PIN validation.
  - **Beneficiary List Persistence (`lib/features/transfer/view_models/transfer_view_model.dart`)**:
    - Implemented `SharedPreferences` persistence under key `payflow_saved_beneficiaries` saving beneficiary name, phone/account, bank name, and bank code post-transfer.
  - **Security Cleanup & Balance Leak Closure**:
    - Completely deleted insecure `GET /v1/wallet/balance/:phone` endpoint from server. All client balance queries use `GET /v1/wallet/balance/me`.
    - Strict `req.user.uid` authorization enforced across all wallet, payment, user, and transfer routes.
  - **Verification & Test Suite**:
    - 23/23 backend Jest tests passed in `/server` (across `auth.test.ts`, `wallet.test.ts`, `payments.test.ts`, `transfers.test.ts`).
    - 0 `dart analyze lib test` issues.
    - 100% of Flutter test suite (100/100 tests) passed.

### Stage 15 — VTPass Airtime & Data Services Integration & MSISDN Network Detection: COMPLETE

- **What Was Implemented**:
  - **Backend VTPass Proxy Routes (`server/src/routes/vtpass.ts`, `server/src/app.ts`)**:
    - Created `GET /v1/vtpass/services?identifier=airtime|data` and `GET /v1/vtpass/data-plans?network=mtn|glo|airtel|9mobile` endpoints protected by `requireAuth` middleware.
    - Proxies VTPass service-categories and service-variations when live keys are configured, or returns structured mock plan variations.
    - Added unauthenticated (no auth header) 401 error tests for both new routes in `server/tests/vtpass.test.ts`.
  - **Nigerian MSISDN Network Detection Table (`lib/core/constants/network_prefixes.dart`)**:
    - Created `NetworkPrefixes` constants file containing MSISDN prefix mappings for Nigerian operators (MTN, Glo, Airtel, 9mobile).
  - **Dynamic Data Plans Catalog (`lib/features/services/view_models/services_view_model.dart`)**:
    - Replaced hardcoded static data plans with dynamic `fetchDataPlans(network)` method routed via `ApiClient` (`defaultApiClient`), attaching `Authorization: Bearer <token>` automatically.
    - Added `isLoadingDataPlans` and `dataPlansError` state properties for catalog UI handling.
  - **Mobile Data Flow Sheet UX (`lib/features/services/widgets/mobile_data_flow_sheet.dart`)**:
    - Auto-detects operator network on phone input changes.
    - Added loading skeleton state while fetching plans and retry-on-error banner.
    - Buy button routes purchases through `PaymentService.processPayment` with providerType `vtpass`.
  - **Verification & Test Suite**:
    - Passed 28/28 backend Jest tests in `/server` (across 5 test suites: `auth.test.ts`, `wallet.test.ts`, `payments.test.ts`, `transfers.test.ts`, `vtpass.test.ts`).
    - 0 `dart analyze lib test` static analysis issues.
    - 100% of Flutter test suite (100/100 tests) passed.

### Stage 16 — VTPass Utility Verification (Meter & Smartcard) & Anti-Fraud Confirmation: COMPLETE

- **What Was Implemented**:
  - **VTPass Config & Base URL Configurable (`server/src/config.ts`)**:
    - Configured `config.vtpassBaseUrl` defaulting to `https://sandbox.vtpass.com/api` (configurable via `VTPASS_BASE_URL` env var).
  - **Backend Proxy & Verification Endpoints (`server/src/routes/vtpass.ts`)**:
    - Created `POST /v1/vtpass/verify-meter`, `POST /v1/vtpass/verify-smartcard`, and `GET /v1/vtpass/billers` endpoints protected by `requireAuth`.
    - Routes requests to `${config.vtpassBaseUrl}` when credentials exist using presence checks `if (config.vtpassApiKey && config.vtpassSecretKey)`.
    - Added unauthenticated 401 error tests for all 3 new routes in `server/tests/vtpass.test.ts`.
  - **Services ViewModel Verification Methods (`lib/features/services/view_models/services_view_model.dart`)**:
    - Added `verifyMeter` and `verifySmartcard` actions calling `/v1/vtpass/verify-meter` and `/v1/vtpass/verify-smartcard` via `ApiClient`.
  - **Anti-Fraud Customer Resolution Cards (`ElectricityFlowSheet` & `CableTvFlowSheet`)**:
    - Wired `ElectricityFlowSheet` to verify meter numbers before amount entry, surfacing resolved customer name and address in a green anti-fraud confirmation card.
    - Wired `CableTvFlowSheet` to verify smartcards before payment, surfacing subscriber name and active bouquet in an anti-fraud card.
    - Surfaced actual VTPass `response_description` on verification errors with inline retry capability.
  - **Verification & Test Suite**:
    - 35/35 backend Jest tests passed in `/server` across 5 test suites.
    - 0 `dart analyze lib test` static analysis issues.
    - 100/100 Flutter unit and widget tests passed.

## 5. Current Application Functionality

- Full interactive onboarding and authentication user flow (Splash → Onboarding → Phone Entry → OTP → Create PIN → Confirm PIN → Biometric Setup → Authenticated App).
- Existing user login flow (Login → Phone Entry → OTP → Security PIN / Biometrics → Authenticated App).
- End-to-end KYC & Account Setup workflow (Home/Profile KYC Banner → Intro → Account Type → Personal/Business Info → Address → BVN/NIN Verification → Liveness Check → Document Upload → Review → Status & Tier Upgrade).
- Persistent KYC status and tier limits across app restarts via `SharedPreferences`.
- Fully navigable main app shell (Home, Wallet, Transfer, Services, Profile) when authenticated.

## 6. Known Limitations

- **Mock Authentication Only**: OTP verification (dev code `123456`) and PIN authentication (default dev PIN `1234`) are simulated locally. No SMS gateway or remote backend server is connected yet.
- **Mock KYC Verification Only**: BVN, NIN, liveness selfie capture, and document upload verification operate against local mock repository abstractions.
- **Mock Financial Data**: Dashboard balances, transactions, and services display local structured mock data.

## 7. Boundaries for Future Stages

Stage 1, Stage 2, and Stage 3 contain UI layout, local state persistence, mock authentication, and mock KYC foundation only.

Do **NOT** implement in current stage:
- Real Paystack or Flutterwave payment gateway integration
- Real VTPass or bill payment APIs
- Real SMS/OTP providers (Termii, Twilio)
- Real third-party KYC, BVN, or NIN API integration (Smile Identity, Identitypass, Prembly)
- Real bank transfers or payment processing
- Production secrets or production backend credentials

## 8. Development Workflow

Every project stage adheres to the following workflow:

1. Review `PROJECT_CONTEXT.md` and stage requirements.
2. Implement features following the established architecture and design system.
3. Run static analysis (`dart analyze`) and resolve all warnings and errors.
4. Run automated unit/widget tests (`flutter test`).
5. Build the application (`flutter build apk --debug`).
6. Perform manual flow verification.
7. Update project documentation.
8. Commit changes to Git.
9. Push commits to GitHub.
10. Proceed to the next stage only after full completion and approval.

## 9. Git Repository Information

- **Repository**: `chumazinho/payflow-app`
- **Branch**: `main`

## 10. Completed Stages Status Summary

- **Stage 1 — Flutter Foundation**: COMPLETE
- **Stage 2 — Authentication & Onboarding Foundation**: COMPLETE
- **Stage 3 — KYC Foundation & Account Setup**: COMPLETE
- **Stage 4 — Home Dashboard Enhancement**: COMPLETE
- **Stage 5 — Wallet & Money Transfer Workflows**: COMPLETE
- **Stage 6 — Services & Utility Payments**: COMPLETE
- **Stage 7 — Payment Infrastructure & Provider Integration**: COMPLETE
- **Stage 8 — Production Readiness & Account Reliability**: COMPLETE
- **Stage 9 — Profile Security Settings & Digital Receipts**: COMPLETE
- **Stage 10 — Push Notifications & Notification Center**: COMPLETE
- **Stage 11A — Feature Cleanup & Strict Naira Currency**: COMPLETE
- **Stage 11B — Recent Transactions & Receipt Detail**: COMPLETE
- **Stage 11C — Fix Airtime / Data / Electricity Flow**: COMPLETE
- **Stage 12 — Node.js Express Backend & P2P Ledger**: COMPLETE
- **Stage 13 — Firebase Auth Integration & DVA Wallet Funding**: COMPLETE
- **Stage 14 — PayFlow User Transfer & Bank Transfers Integration**: COMPLETE
- **Stage 15 — VTPass Airtime & Data Services Integration & MSISDN Network Detection**: COMPLETE

## 11. Next Planned Stage

Stage 16 — Advanced Analytics, Export Statements & Production Deployment Readiness.
