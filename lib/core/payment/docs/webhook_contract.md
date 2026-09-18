# PayFlow Payment Infrastructure — Webhook & Backend Integration Contract

## Overview

In accordance with PayFlow Security Rules, **production Paystack secret keys, VTPass API keys, HMAC webhook signing keys, and raw callback handlers MUST be hosted on a secure PayFlow Backend Server**.

Flutter mobile applications are client-side runtimes and must not process raw webhook payloads or store private cryptographic secret keys in client source code or committed repository files.

---

## 1. Paystack Webhook Contract (Wallet Funding & Transfers)

### Destination Endpoint
`POST https://api.payflow.app/v1/payments/webhooks/paystack`

### Signature Verification Header
`x-paystack-signature: <HMAC-SHA512 Signature>`

The PayFlow backend verifies the incoming HTTP request payload against the configured Paystack Secret Key using HMAC-SHA512 hashing:

```crypto
signature = HMAC-SHA512(request.rawBody, PAYSTACK_SECRET_KEY)
```

### Paystack Event Payload Schema (`charge.success`)

```json
{
  "event": "charge.success",
  "data": {
    "id": 302949201,
    "domain": "test",
    "status": "success",
    "reference": "PF-TOP-883920",
    "amount": 1000000,
    "gateway_response": "Successful",
    "paid_at": "2026-08-18T20:30:00.000Z",
    "channel": "dedicated_virtual_account",
    "currency": "NGN",
    "customer": {
      "id": 892019,
      "email": "alex.johnson@payflow.app",
      "phone": "+2348123456789"
    }
  }
}
```

---

## 2. VTPass Webhook / Callback Contract (Airtime, Data & Bill Payments)

### Destination Endpoint
`POST https://api.payflow.app/v1/payments/webhooks/vtpass`

### Callback Authentication Header
`X-VTPass-Signature: <HMAC-SHA256 Signature or Shared Callback Token>`

### VTPass Transaction Notification Payload Schema

```json
{
  "code": "000",
  "content": {
    "transactions": {
      "status": "delivered",
      "product_name": "MTN Data Topup",
      "transactionId": "1724012049102",
      "requestId": "VTP-883920192",
      "amount": 1000,
      "phone": "08123456789",
      "quantity": 1
    }
  },
  "response_description": "TRANSACTION SUCCESSFUL"
}
```

---

## 3. Idempotency & Deduplication

1. **Reference Lookup**: The backend checks if `data.reference` or `requestId` has already been reconciled in the primary database.
2. **Duplicate Event Rejection**: If `reference` or `requestId` was previously processed, the backend responds immediately with HTTP `200 OK` without re-crediting the wallet or repeating service fulfillment.
3. **Atomic State Mutation**: Wallet balance updates are executed inside an atomic database transaction.

---

## 4. Client Sync & Verification

1. Mobile clients send verification requests via `PaymentService.verifyPayment()`.
2. The backend responds with standardized `PaymentVerification` contracts.
3. Idempotency guards in `PaymentService` prevent double-crediting if both client polling and webhooks trigger verification simultaneously.
