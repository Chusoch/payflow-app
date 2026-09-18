# Chumazinho's PayFlow Learning Guide

Welcome to the **PayFlow Learning Guide**! This document serves as your technical companion to understand how PayFlow is built, why specific architectural choices were made, and how Flutter concepts fit together in a real-world fintech codebase.

---

## 1. What PayFlow Is

**PayFlow** is a modern Nigerian fintech mobile application built with Flutter. It models real-world digital banking products such as Kuda, OPay, and Moniepoint.

The application allows users to:
- Onboard and authenticate securely using phone numbers, OTP codes, 4-digit PINs, and biometrics (Face ID / Fingerprint).
- View wallet balances, card details, and recent transaction histories.
- Send and receive money instantly.
- Pay everyday bills, buy airtime, data bundles, and utility services.
- Manage personal security preferences and profile settings.

Instead of building a simple demo app, PayFlow is structured using production-grade software patterns so you can learn industry-standard Flutter development practices.

---

## 2. How the Project Is Organized

PayFlow uses a **Feature-First Architecture**. Code is grouped primarily by *what feature it belongs to*, rather than putting all screens in one giant folder and all models in another.

```
lib/
├── main.dart             # Application entrypoint & MaterialApp.router binding
├── core/                 # Shared infrastructure used across multiple features
│   ├── constants/        # Layout dimensions, grid spacing, border radii
│   ├── router/           # GoRouter configuration, navigation shell & route guards
│   ├── theme/            # Material 3 colors, Google Fonts typography & AppTheme
│   └── widgets/          # Shared PayFlow buttons, text fields, cards, badges
└── features/             # Business features
    ├── auth/             # Onboarding, Splash, Phone Entry, OTP, PIN, Biometrics
    ├── home/             # Dashboard overview, quick actions, transaction lists
    ├── wallet/           # Wallet accounts, virtual cards, balance toggles
    ├── transfer/         # Send money, recipient selection, transfer forms
    ├── services/         # Airtime, data, cable TV, electricity bill payments
    └── profile/          # Profile management, theme toggle, security settings
```

### Why This Structure Was Chosen

1. **Scalability**: As the app grows, adding a new feature (like KYC or Card Issuing) means creating a new folder under `lib/features/` without touching unrelated code.
2. **Maintainability**: Everything related to authentication lives in `lib/features/auth/`. If you need to edit the PIN setup, you know exactly where to look.
3. **Reusability**: Shared assets like buttons (`PayFlowButton`), colors (`AppColors`), and text fields (`PayFlowTextField`) live in `lib/core/` so any feature can use them consistently.

---

## 3. Stage 1 — Flutter Foundation

Stage 1 established the design system, navigation shell, and primary dashboard screens.

### Key Components Built in Stage 1

#### 1. Material 3 Theme System (`lib/core/theme/`)
- **WHAT**: A central theme definition (`AppTheme`) using Flutter's Material 3 design spec.
- **WHY**: Ensures consistent colors, typography, card shapes, and button styles across light and dark modes.
- **HOW IT FITS**: `AppColors` defines the custom palette (Royal Blue `#2563EB`, Indigo `#6366F1`, Emerald Green `#10B981`, Crimson Red `#EF4444`). `AppTypography` configures Google Fonts Inter.

#### 2. Reusable UI Components (`lib/core/widgets/`)
- **WHAT**: Custom widgets like `PayFlowButton`, `PayFlowTextField`, `PayFlowCard`, `PayFlowStatCard`, and `PayFlowBadge`.
- **WHY**: Prevents repeating 50 lines of button styling code across every screen.
- **HOW IT FITS**: When building a screen, you simply call `PayFlowButton(text: 'Continue', onPressed: ...)` and it automatically follows the app's design system.

#### 3. GoRouter & Navigation Shell (`lib/core/router/app_router.dart`)
- **WHAT**: Declarative routing using `go_router` and `StatefulShellRoute.indexedStack`.
- **WHY**: Maintains the bottom navigation bar state across tabs (`Home`, `Wallet`, `Transfer`, `Services`, `Profile`) without reloading tab screens when switching tabs.

---

## 4. Stage 1 Architecture

The architectural flow of a screen in PayFlow follows this unidirectional data flow:

```
┌────────────────────────────────────────────────────────┐
│                       UI Screen                        │
│             (e.g., HomeScreen / ProfileScreen)          │
└───────────────────────────┬────────────────────────────┘
                            │ Reads State / Triggers Events
                            ▼
┌────────────────────────────────────────────────────────┐
│                   Riverpod ViewModel                   │
│          (e.g., ProfileViewModel / AuthViewModel)       │
└───────────────────────────┬────────────────────────────┘
                            │ Executes Business Logic / Calls
                            ▼
┌────────────────────────────────────────────────────────┐
│                      Repository                        │
│          (e.g., MockAuthRepository / ApiRepository)     │
└────────────────────────────────────────────────────────┘
```

### Explaining Riverpod Simply
- **Riverpod** is a state management library for Flutter.
- It holds app state (like whether a user is logged in or whether dark mode is active) outside of the widget tree so widgets can read, watch, or update state safely.
- `ref.watch(provider)` rebuilds a widget whenever the state changes.
- `ref.read(provider.notifier)` calls methods on the ViewModel to change state.

### Explaining GoRouter Simply
- **GoRouter** is Flutter's official declarative routing package.
- Instead of manually pushing screens onto a stack (`Navigator.push`), you define URLs like `/home` or `/login`.
- It supports route guards (redirecting unauthenticated users to `/login` automatically).

---

## 5. Stage 2 — Authentication & Onboarding

Stage 2 built the complete authentication and security foundation for PayFlow.

### The New User Onboarding Flow

```
Splash Screen (/splash)
      │ (Checks local storage)
      ▼
Onboarding Carousel (/onboarding)
      │ (3 pages: Send Money, Pay Bills, Manage Money)
      ▼
Phone Entry Screen (/phone-entry)
      │ (+234 Nigerian prefix badge & validation)
      ▼
OTP Verification Screen (/otp-verification)
      │ (6-digit OTP boxes, 30s timer, dev code 123456)
      ▼
Create PIN Screen (/create-pin)
      │ (4-digit setup, custom numeric keypad, masked dots)
      ▼
Confirm PIN Screen (/confirm-pin)
      │ (PIN comparison & validation)
      ▼
Biometric Setup Screen (/biometric-setup)
      │ (Face ID / Fingerprint setup using local_auth)
      ▼
Authenticated Home Screen (/home)
```

### The Existing User Login Flow

```
Login Screen (/login) ──► OTP Verification ──► Security PIN Screen (/pin-entry) ──► Home (/home)
                                                       ▲
                                                       │ (Or tap Fingerprint icon)
                                               Biometric Login
```

### Key Auth Modules Built in Stage 2

1. **`AuthState` (`lib/features/auth/models/auth_state.dart`)**:
   - An immutable data class holding authentication status (`initial`, `onboardingRequired`, `unauthenticated`, `awaitingOtp`, `awaitingPinSetup`, `awaitingBiometrics`, `authenticated`), current phone number, draft PIN, loading state, and error messages.

2. **`AuthRepository` & `MockAuthRepository` (`lib/features/auth/repositories/auth_repository.dart`)**:
   - Abstract interface defining auth operations (`sendOtp`, `verifyOtp`, `setupPin`, `verifyPin`, `canCheckBiometrics`, `authenticateWithBiometrics`).
   - `MockAuthRepository` simulates network delays and stores session preferences locally using `SharedPreferences`.

3. **`AuthViewModel` (`lib/features/auth/view_models/auth_view_model.dart`)**:
   - A Riverpod `StateNotifier` that manages all authentication business logic, countdown timers, PIN validations, and state transitions.

4. **Route Guarding (`lib/core/router/app_router.dart`)**:
   - `GoRouter` listens to `authViewModelProvider`. If an unauthenticated user tries to navigate directly to `/home` or `/wallet`, the router automatically redirects them to `/login` or `/onboarding`.

---

## 6. Why Stage 2 Uses Mock Authentication

In Stage 2, SMS sending, OTP codes (`123456`), and PIN checks (`1234`) are simulated locally.

### Why This Is Intentional
- **Focus on Architecture First**: Building the user interface, state management, screen flow, and route protection first ensures the frontend architecture is solid before coupling it to external APIs.
- **Cost & Speed**: Developing against live SMS APIs (like Termii or Twilio) or live backend servers during early UI development incurs costs and slows down testing.
- **Decoupled Design**: Because `AuthRepository` is an abstract interface, replacing `MockAuthRepository` with a real `ApiAuthRepository` in later stages requires **zero changes** to your UI screens!

---

## 7. What I Should Understand as a Flutter Developer

Here is a checklist of core Flutter and architecture concepts demonstrated in PayFlow:

- [x] **`StatelessWidget`**: A widget that does not hold mutable internal state. It builds UI purely based on parameters passed to it (e.g., `PayFlowBadge`).
- [x] **`ConsumerWidget`**: A Riverpod-enabled widget that gains access to a `WidgetRef` object to watch or read global state providers.
- [x] **`WidgetRef`**: The bridge between a widget and Riverpod providers. Used as `ref.watch()` (to rebuild on changes) or `ref.read()` (to call methods without rebuilding).
- [x] **Riverpod Providers**: Declared global instances (like `authViewModelProvider`) that expose state and ViewModels to the entire app safely.
- [x] **State Management**: The pattern of managing data changes (user login status, theme mode) and updating the UI automatically when data changes.
- [x] **ViewModel Pattern**: A class (`AuthViewModel`) that contains business logic and state, separating UI presentation from data processing.
- [x] **Repository Pattern**: An abstract data layer (`AuthRepository`) that hides where data comes from (local storage, mock data, or HTTP REST APIs).
- [x] **Routing (`GoRouter`)**: Navigating between screens using declarative URL paths (`/home`, `/login`) rather than imperative screen pushes.
- [x] **Route Guards**: Logic inside the router that intercepts navigation attempts based on user permission or authentication status.
- [x] **Local Persistence (`SharedPreferences`)**: Saving lightweight key-value pairs (like whether onboarding is completed) to the device storage so data survives app restarts.
- [x] **Reusable Components**: Building configurable UI building blocks (`PayFlowButton`) to maintain visual consistency and eliminate duplicate code.
- [x] **Material 3 Themes**: Utilizing Flutter's `ThemeData`, `ColorScheme`, and `TextTheme` to style widgets automatically.
- [x] **Feature-First Architecture**: Grouping code by feature domain (`lib/features/auth/`) to keep code modular and readable.
- [x] **Mock Repositories**: Providing realistic dummy implementations during development to test UI flows before backend integration.
- [x] **Separation of UI and Business Logic**: Ensuring UI widgets only render graphics and delegate logic (like validating phone numbers) to ViewModels.

---

## 8. Important Files I Should Know

| File Path | Description / Responsibility |
| :--- | :--- |
| `lib/main.dart` | App entrypoint; wraps the app in Riverpod's `ProviderScope` and binds `appRouterProvider`. |
| `lib/core/theme/app_theme.dart` | Material 3 light and dark theme definitions for PayFlow. |
| `lib/core/theme/app_colors.dart` | Core color palette (Royal Blue primary, Emerald income green, Crimson expense red). |
| `lib/core/router/app_router.dart` | Defines all app routes, bottom navigation tabs, and authentication redirect guards. |
| `lib/core/widgets/payflow_button.dart` | Shared button widget supporting primary, secondary, outline, text, and loading states. |
| `lib/features/auth/models/auth_state.dart` | Data model representing current authentication status and form parameters. |
| `lib/features/auth/repositories/auth_repository.dart` | Abstract interface and mock repository for OTP, PIN, biometrics, and local storage. |
| `lib/features/auth/view_models/auth_view_model.dart` | StateNotifier managing the authentication state machine, timers, and validation logic. |
| `lib/features/auth/views/splash_screen.dart` | Initial splash screen checking session state and navigating to the next flow. |
| `lib/features/auth/views/onboarding_screen.dart` | 3-page onboarding carousel with dot indicators and skip options. |
| `lib/features/auth/views/phone_entry_screen.dart` | Phone number entry screen with +234 Nigerian prefix and validation. |
| `lib/features/auth/views/otp_verification_screen.dart` | 6-digit OTP entry screen with countdown timer and dev helper hint. |
| `lib/features/auth/views/create_pin_screen.dart` | 4-digit PIN setup screen with custom numeric keypad. |
| `lib/features/auth/views/confirm_pin_screen.dart` | PIN confirmation screen validating entry against original draft PIN. |
| `lib/features/auth/views/biometric_setup_screen.dart` | Biometric setup screen introducing Face ID / Fingerprint login using `local_auth`. |
| `lib/features/auth/views/pin_entry_screen.dart` | Returning user PIN entry screen with quick biometric authentication option. |

---

## 9. What Has NOT Been Built Yet

To keep project boundaries clear, the following production capabilities have **intentionally not been implemented yet**:

- Real backend servers / databases (Supabase, Firebase Auth, Node.js/Python REST API).
- Real SMS / OTP delivery providers (Termii, Twilio).
- Real identity verification / KYC (BVN, NIN, Tiered verification).
- Payment gateways (Paystack, Flutterwave).
- Utility payment APIs (VTPass).
- Real financial transactions or bank integrations.
- Production secrets or API keys.

These capabilities belong to Stage 3 and later stages.

---

## 10. Development Workflow

---

## 10. Stage 3 — KYC & Account Setup Foundation

Stage 3 built the complete KYC (Know Your Customer) and tiered identity verification foundation for PayFlow.

### The KYC Verification User Flow

```text
Authenticated Home Dashboard (/home)
       │
       ▼
KYC Intro & Tier Overview (/kyc/intro)
       │ (Tier 1: ₦50k/day, Tier 2: ₦200k/day, Tier 3: ₦5M/day)
       ▼
Select Account Type (/kyc/account-type)
       ├── Individual Account ──► Personal Info (/kyc/personal-info)
       └── Business Account   ──► Business Details (/kyc/personal-info)
       │
       ▼
Address Information (/kyc/address)
       │ (Street, City, State, Country)
       ▼
Identity Verification (/kyc/identity)
       │ (11-digit BVN & NIN verification with state feedback)
       ▼
Liveness Selfie UI (/kyc/liveness)
       │ (Camera frame oval overlay & face capture simulation)
       ▼
Document Upload (/kyc/documents)
       │ (ID type selection & mock file picker/preview)
       ▼
Review Information (/kyc/review)
       │ (Sectioned summary with edit links)
       ▼
Submit Verification (/kyc/status)
       │ (Tier upgrade status dashboard & return home)
       ▼
Home Dashboard (/home)
```

### Key KYC Modules Built in Stage 3

1. **`KycState` & `KycTier` (`lib/features/kyc/models/`)**:
   - Holds account category (Individual vs Business), personal/business fields, address details, BVN/NIN verification flags, liveness status, document attachment details, current step index, submission status (`notStarted`, `inProgress`, `pending`, `verified`, `failed`), and active `KycTierLevel` (`tier1`, `tier2`, `tier3`).

2. **`KycRepository` & `MockKycRepository` (`lib/features/kyc/repositories/`)**:
   - Abstract contract defining identity verification (`verifyBvn`, `verifyNin`, `verifyLiveness`, `uploadDocument`, `submitKyc`).
   - `MockKycRepository` handles async server latency, validates 11-digit BVN/NIN formats, triggers mock failures for test code `00000000000`, and persists state locally via `SharedPreferences`.

3. **`KycViewModel` (`lib/features/kyc/view_models/kyc_view_model.dart`)**:
   - Riverpod `StateNotifier` managing multi-step form validation, async verification calls, state mutations, and persistence.

---

## 11. Important Files Added in Stage 3

| File Path | Description / Responsibility |
| :--- | :--- |
| `lib/features/kyc/models/kyc_tier.dart` | Defines `KycTierLevel`, `KycStatus`, `AccountType`, and `KycTierInfo` limit metadata. |
| `lib/features/kyc/models/kyc_state.dart` | Immutable Riverpod state model managing complete multi-step KYC data. |
| `lib/features/kyc/repositories/kyc_repository.dart` | Abstract interface for identity verification and KYC state persistence. |
| `lib/features/kyc/repositories/mock_kyc_repository.dart` | Mock implementation simulating BVN/NIN check latency and `SharedPreferences` storage. |
| `lib/features/kyc/view_models/kyc_view_model.dart` | StateNotifier executing validation rules, verification steps, and tier upgrades. |
| `lib/features/kyc/views/kyc_intro_screen.dart` | Displays Tier 1, Tier 2, and Tier 3 limits & requirements with start button. |
| `lib/features/kyc/views/kyc_account_type_screen.dart` | Selection screen for Individual vs Business account categories. |
| `lib/features/kyc/views/kyc_personal_info_screen.dart` | Form screen collecting personal or business details with validation. |
| `lib/features/kyc/views/kyc_address_screen.dart` | Form screen collecting residential or business address (defaulting to Nigeria). |
| `lib/features/kyc/views/kyc_identity_screen.dart` | Form for BVN & NIN entry with security rationale, loading states, and error retries. |
| `lib/features/kyc/views/kyc_liveness_screen.dart` | Camera viewport oval UI frame providing liveness selfie capture simulation. |
| `lib/features/kyc/views/kyc_document_upload_screen.dart` | Document type dropdown, mock file attachment dropzone, and thumbnail preview. |
| `lib/features/kyc/views/kyc_review_screen.dart` | Sectioned summary of entered details with quick edit links before submission. |
| `lib/features/kyc/views/kyc_status_screen.dart` | Verification completion screen showing upgraded Tier level, limits, and return CTA. |

---

---

## 12. Stage 4 — Home Dashboard Enhancement & UX Refinement

Stage 4 transformed the primary Home Dashboard into a clean, modern fintech launchpad. Home now acts as a uncluttered launchpad containing the Wallet Balance Card with primary money actions (**Send**, **Bank Transfer**, **Top Up**), a compact Services grid (**Airtime**, **Data**, **Bills**, **More**), an auto-sliding Promotional Banner Carousel (with touch-pause handling), and a single-card entry point for **Transaction History** (`/wallet`).

### Key Modules Built & Refined in Stage 4

1. **Services Grid (`lib/features/home/widgets/quick_actions_section.dart`)**:
   - Compact visual entry section for everyday services (Airtime, Data, Bills, and More navigating to `/services`).

2. **Auto-Sliding Promotional Banner Carousel (`lib/features/home/widgets/promo_banner_carousel.dart`)**:
   - Horizontal `PageView.builder` with automatic 4-second sliding, touch-pause gesture listener, smooth animated page dots, and gradient card styling.

3. **Transaction History Access Card (`lib/features/home/widgets/transaction_history_card.dart`)**:
   - Replaced cluttering inline transaction previews on Home with a single `TransactionHistoryCard` navigating directly to `/wallet`.

4. **Home Data Repository (`lib/features/home/repositories/`)**:
   - `HomeRepository` abstract contract and `MockHomeRepository` implementation decoupling promotional banners, savings details, and transactions from UI screens.

---

## 13. Important Files Added in Stage 4

| File Path | Description / Responsibility |
| :--- | :--- |
| `lib/features/home/models/transaction_item.dart` | Financial transaction data model. |
| `lib/features/home/models/promo_banner.dart` | Promotional banner card data model. |
| `lib/features/home/models/savings_summary.dart` | Savings & investments summary data model. |
| `lib/features/home/repositories/home_repository.dart` | Abstract interface for fetching home dashboard data. |
| `lib/features/home/repositories/mock_home_repository.dart` | Mock repository providing static financial, banner, and savings data. |
| `lib/features/home/widgets/quick_actions_section.dart` | Compact Services grid widget (Airtime, Data, Bills, More). |
| `lib/features/home/widgets/promo_banner_carousel.dart` | Auto-sliding horizontal banner carousel with touch pause & animated dots. |
| `lib/features/home/widgets/transaction_history_card.dart` | Single card entry point navigating to full transaction history (`/wallet`). |


---

## 14. Development Workflow

Every stage in PayFlow follows a strict quality workflow:

1. **Review Project Context**: Understand the stage goals and boundaries in `PROJECT_CONTEXT.md`.
2. **Understand Requirements**: Review screen flows, user interactions, and architecture expectations.
3. **Implement Stage**: Write code following the existing feature-first structure and design system.
4. **Run Static Analysis**: Execute `dart analyze` and resolve all linter warnings/errors.
5. **Run Automated Tests**: Execute `flutter test` to ensure existing and new tests pass.
6. **Build Application**: Execute `flutter build apk --debug` to verify the Android build succeeds.
7. **Manually Verify Flows**: Test screen navigation, edge cases, and layout responsiveness.
8. **Update Documentation**: Record completed work in `PROJECT_CONTEXT.md` and walkthroughs.
9. **Commit Changes**: Create a clean Git commit for the completed stage.
10. **Push to GitHub**: Push the branch commit to the remote repository.
11. **Proceed**: Move to the next stage only after full completion and explicit user direction.

---

## 15. Current Project Status

- **Stage 1 — Flutter Foundation**: COMPLETE
- **Stage 2 — Authentication & Onboarding Foundation**: COMPLETE
- **Stage 3 — KYC Foundation & Account Setup**: COMPLETE
- **Stage 4 — Home Dashboard Enhancement**: COMPLETE
- **Stage 5 — Wallet & Money Transfer Workflows**: NOT STARTED

**GitHub Repository**: https://github.com/chumazinho/payflow-app

---

## 16. What Comes Next

When instructed to begin **Stage 5**, the project will focus on core wallet transactions, virtual card management, and money transfer workflows.

No Stage 5 code should be implemented until Stage 5 is explicitly authorized.

