# Stage 16 — VTPass Utility Verification (Meter & Smartcard) & Anti-Fraud Confirmation Plan

Implement VTPass merchant verification endpoints on backend (`POST /v1/vtpass/verify-meter`, `POST /v1/vtpass/verify-smartcard`, `GET /v1/vtpass/billers`) and wire pre-payment customer name anti-fraud verification in Flutter (`ElectricityFlowSheet`, `CableTvFlowSheet`).

## User Review Required

> [!IMPORTANT]
> 1. **Anti-Fraud Customer Resolution**: Before entering payment amounts or proceeding to PIN confirmation, `ElectricityFlowSheet` and `CableTvFlowSheet` will mandate customer verification against `/v1/vtpass/verify-meter` and `/v1/vtpass/verify-smartcard`.
> 2. **VTPass Error Surface**: On verification or payment failure, the actual VTPass `response_description` will be displayed to the user instead of generic error text.
> 3. **Unauthenticated 401 Testing**: In accordance with project rules, all 3 new endpoints (`/verify-meter`, `/verify-smartcard`, `/billers`) will be covered by 401 unauthenticated unit tests in `server/tests/vtpass.test.ts`.

## Proposed Changes

---

### Backend Components (`server/`)

#### [MODIFY] [vtpass.ts](file:///c:/Users/ChukwumaUgobueze/payflow-app/server/src/routes/vtpass.ts)
- Add `POST /v1/vtpass/verify-meter` endpoint (`requireAuth` middleware):
  - Accepts `{ billersCode, serviceID, type }`.
  - Proxies VTPass `merchant-verify` endpoint (`https://vtpass.com/api/merchant-verify`) when live API keys exist.
  - Returns mock customer object (`Customer_Name`, `Address`, `Meter_Number`) in sandbox mode or when mock keys are configured.
- Add `POST /v1/vtpass/verify-smartcard` endpoint (`requireAuth` middleware):
  - Accepts `{ billersCode, serviceID }`.
  - Proxies VTPass `merchant-verify` endpoint.
  - Returns mock customer object (`Customer_Name`, `Customer_Number`, `Current_Bouquet`) in sandbox mode.
- Add `GET /v1/vtpass/billers` endpoint (`requireAuth` middleware):
  - Accepts `?category=electricity|tv`.
  - Proxies VTPass biller category listing.

#### [MODIFY] [vtpass.test.ts](file:///c:/Users/ChukwumaUgobueze/payflow-app/server/tests/vtpass.test.ts)
- Add 401-with-no-auth-header tests for `POST /v1/vtpass/verify-meter`, `POST /v1/vtpass/verify-smartcard`, and `GET /v1/vtpass/billers`.
- Add authenticated success tests for all three routes.

---

### Flutter Components (`lib/features/services/`)

#### [MODIFY] [services_view_model.dart](file:///c:/Users/ChukwumaUgobueze/payflow-app/lib/features/services/view_models/services_view_model.dart)
- Add `verifyMeter({required String meterNumber, required String disco, required String type})` method calling `ApiClient.post('/v1/vtpass/verify-meter', ...)`.
- Add `verifySmartcard({required String smartcardNumber, required String provider})` method calling `ApiClient.post('/v1/vtpass/verify-smartcard', ...)`.
- Provide rich mock customer verification responses when `Env.isMockMode` is true.

#### [MODIFY] [electricity_flow_sheet.dart](file:///c:/Users/ChukwumaUgobueze/payflow-app/lib/features/services/widgets/electricity_flow_sheet.dart)
- Wire "Verify Meter" action on meter number entry.
- Display verified customer name card (`"CHUKWUMA UGOBUEZE"`) and address for confirmation before enabling amount input & review.
- Surface VTPass `response_description` on error.

#### [MODIFY] [cable_tv_flow_sheet.dart](file:///c:/Users/ChukwumaUgobueze/payflow-app/lib/features/services/widgets/cable_tv_flow_sheet.dart)
- Wire "Verify Smartcard" action on smartcard number entry.
- Display verified customer name card for anti-fraud confirmation before payment step.
- Surface VTPass `response_description` on error.

---

## Verification Plan

### Automated Tests
1. **Backend Tests**: `npm run test` in `/server` — confirm 401 unauthenticated tests and 200 success tests pass for `/verify-meter`, `/verify-smartcard`, and `/billers` (31+ backend tests passing).
2. **Flutter Analysis**: `dart analyze lib test` at project root (0 issues).
3. **Flutter Tests**: `flutter test` at project root (100% pass rate).

### Manual Verification
- Test meter verification flow in `ElectricityFlowSheet`.
- Test smartcard verification flow in `CableTvFlowSheet`.
- Verify error messages display VTPass `response_description` on invalid numbers.
