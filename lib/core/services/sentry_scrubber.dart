import 'package:sentry_flutter/sentry_flutter.dart';

/// Sensitive field names to scrub from Sentry crash reports and breadcrumbs.
const Set<String> sensitiveFieldNames = {
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
  'fcm_token',
  'fcmtoken',
  'secret',
  'password',
  'pin',
};

/// Recursively scrubs sensitive key values from Dart maps/lists.
dynamic scrubSensitiveFields(dynamic data) {
  if (data == null) return null;

  if (data is String) {
    // Redact Bearer headers in plain strings
    return data.replaceAll(
      RegExp(r'Bearer\s+[A-Za-z0-9\-\._~\+\/]+=*', caseSensitive: false),
      'Bearer [REDACTED]',
    );
  }

  if (data is List) {
    return data.map((e) => scrubSensitiveFields(e)).toList();
  }

  if (data is Map) {
    final Map<String, dynamic> scrubbed = {};
    data.forEach((key, value) {
      final String keyString = key.toString();
      final String lowerKey = keyString.toLowerCase();
      final bool isSensitive = sensitiveFieldNames.any((pattern) => lowerKey.contains(pattern));

      if (isSensitive) {
        scrubbed[keyString] = '[REDACTED]';
      } else {
        scrubbed[keyString] = scrubSensitiveFields(value);
      }
    });
    return scrubbed;
  }

  return data;
}

/// Sentry beforeSend callback for Flutter enforcing field-name based PII scrubbing.
SentryEvent? sentryBeforeSendScrubber(SentryEvent event, Hint hint) {
  // ignore: deprecated_member_use
  if (event.extra != null) {
    // ignore: deprecated_member_use
    event.extra = scrubSensitiveFields(event.extra) as Map<String, dynamic>?;
  }

  if (event.breadcrumbs != null) {
    for (final b in event.breadcrumbs!) {
      if (b.data != null) {
        b.data = scrubSensitiveFields(b.data) as Map<String, dynamic>?;
      }
      if (b.message != null) {
        b.message = scrubSensitiveFields(b.message) as String?;
      }
    }
  }

  final req = event.request;
  if (req != null) {
    final scrubbed = scrubSensitiveFields(req.headers);
    if (scrubbed is Map) {
      req.headers.clear();
      scrubbed.forEach((k, v) => req.headers[k.toString()] = v.toString());
    }
  }

  return event;
}
