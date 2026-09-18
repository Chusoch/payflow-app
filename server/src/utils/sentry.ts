import * as Sentry from '@sentry/node';
import { config } from '../config';

/**
 * List of sensitive payload field names (case-insensitive substring match)
 * to scrub from Sentry crash reports & breadcrumbs.
 */
const SENSITIVE_FIELD_PATTERNS = [
  'bvn',
  'nin',
  'accountnumber',
  'account_number',
  'accountno',
  'account_no',
  'meternumber',
  'meter_number',
  'billerscode',
  'billers_code',
  'authorization',
  'auth_token',
  'authtoken',
  'secret',
  'password',
  'pin',
];

/**
 * Recursively scrubs sensitive values from object fields based on key names.
 */
export function scrubSensitiveFields(data: any): any {
  if (data === null || data === undefined) return data;

  if (typeof data === 'string') {
    // Redact Bearer tokens in string values if present
    return data.replace(/Bearer\s+[A-Za-z0-9\-\._~\+\/]+=*/gi, 'Bearer [REDACTED]');
  }

  if (Array.isArray(data)) {
    return data.map((item) => scrubSensitiveFields(item));
  }

  if (typeof data === 'object') {
    const scrubbed: Record<string, any> = {};
    for (const key of Object.keys(data)) {
      const lowerKey = key.toLowerCase();
      const isSensitive = SENSITIVE_FIELD_PATTERNS.some((pattern) => lowerKey.includes(pattern));
      if (isSensitive) {
        scrubbed[key] = '[REDACTED]';
      } else {
        scrubbed[key] = scrubSensitiveFields(data[key]);
      }
    }
    return scrubbed;
  }

  return data;
}

/**
 * Initializes Backend Sentry Node SDK with field-name based beforeSend PII scrubbing.
 */
export function initBackendSentry(): void {
  if (!config.sentryDsn) return;

  Sentry.init({
    dsn: config.sentryDsn,
    environment: config.nodeEnv,
    tracesSampleRate: 0.2,
    beforeSend(event) {
      if (event.request) {
        if (event.request.headers) {
          event.request.headers = scrubSensitiveFields(event.request.headers);
        }
        if (event.request.data) {
          event.request.data = scrubSensitiveFields(event.request.data);
        }
      }
      if (event.extra) {
        event.extra = scrubSensitiveFields(event.extra);
      }
      if (event.breadcrumbs) {
        event.breadcrumbs = event.breadcrumbs.map((b) => ({
          ...b,
          data: b.data ? scrubSensitiveFields(b.data) : b.data,
          message: b.message ? scrubSensitiveFields(b.message) : b.message,
        }));
      }
      return event;
    },
  });
}
