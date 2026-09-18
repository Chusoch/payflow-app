import dotenv from 'dotenv';
import path from 'path';

// Load environment variables from .env file
dotenv.config({ path: path.resolve(__dirname, '../.env') });

export const config = {
  port: parseInt(process.env.PORT || '3000', 10),
  host: process.env.HOST || '0.0.0.0',
  nodeEnv: process.env.NODE_ENV || 'development',
  firebaseProjectId: process.env.FIREBASE_PROJECT_ID || 'payflow-dev-4fd8d',
  googleApplicationCredentials: process.env.GOOGLE_APPLICATION_CREDENTIALS || '',
  allowDevEndpoints: process.env.ALLOW_DEV_ENDPOINTS === 'true',
  allowMockTokens: process.env.ALLOW_MOCK_TOKENS === 'true' || process.env.ALLOW_MOCK_AUTH === 'true',

  // Provider Secret Keys (Server-only)
  paystackSecretKey: process.env.PAYSTACK_SECRET_KEY || '',
  paystackPublicKey: process.env.PAYSTACK_PUBLIC_KEY || '',
  flutterwaveSecretKey: process.env.FLUTTERWAVE_SECRET_KEY || '',
  vtpassApiKey: (process.env.VTPASS_API_KEY || '').trim(),
  vtpassSecretKey: (process.env.VTPASS_SECRET_KEY || '').trim(),
  vtpassPublicKey: (process.env.VTPASS_PUBLIC_KEY || '').trim(),
  vtpassBaseUrl: (process.env.VTPASS_BASE_URL || 'https://sandbox.vtpass.com/api').trim().replace(/\/+$/, ''),

  // Webhook Verification Secrets
  paystackWebhookSecret: process.env.PAYSTACK_WEBHOOK_SECRET || '',
  vtpassWebhookSecret: process.env.VTPASS_WEBHOOK_SECRET || '',

  // Error Monitoring (Sentry)
  sentryDsn: process.env.SENTRY_DSN || '',

  // CORS Configuration
  corsAllowedOrigins: process.env.CORS_ALLOWED_ORIGINS
    ? process.env.CORS_ALLOWED_ORIGINS.split(',').map((o) => o.trim()).filter(Boolean)
    : [],

  // Termii OTP Integration
  termiiApiKey: process.env.TERMII_API_KEY || '',
  termiiSenderId: process.env.TERMII_SENDER_ID || 'N-Alert',
  termiiBaseUrl: (process.env.TERMII_BASE_URL || 'https://api.ng.termii.com').replace(/\/+$/, ''),

  // Dojah KYC Identity Provider
  dojahAppId: process.env.DOJAH_APP_ID || '',
  dojahSecretKey: process.env.DOJAH_SECRET_KEY || '',
  dojahBaseUrl: (process.env.DOJAH_BASE_URL || 'https://sandbox.dojah.io').replace(/\/+$/, ''),
};

