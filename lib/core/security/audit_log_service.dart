import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../notifications/notification_service.dart';
import '../../features/notifications/models/notification_item.dart';
import '../../features/notifications/view_models/notification_view_model.dart';

enum AuditEventType {
  authentication,
  pinChange,
  biometrics,
  kyc,
  payment,
}

class AuditLogEntry {
  final String id;
  final DateTime timestamp;
  final AuditEventType eventType;
  final String description;
  final String status;

  const AuditLogEntry({
    required this.id,
    required this.timestamp,
    required this.eventType,
    required this.description,
    this.status = 'SUCCESS',
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'eventType': eventType.name,
      'description': description,
      'status': status,
    };
  }

  factory AuditLogEntry.fromJson(Map<String, dynamic> json) {
    return AuditLogEntry(
      id: json['id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      eventType: AuditEventType.values.firstWhere(
        (e) => e.name == json['eventType'],
        orElse: () => AuditEventType.authentication,
      ),
      description: json['description'] as String,
      status: json['status'] as String? ?? 'SUCCESS',
    );
  }
}

class AuditLogService extends StateNotifier<List<AuditLogEntry>> {
  static const String _keyAuditLogs = 'payflow_audit_logs_secure';
  final NotificationService _notificationService;
  final FlutterSecureStorage _secureStorage;

  AuditLogService(
    this._notificationService, {
    FlutterSecureStorage? secureStorage,
  })  : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
        super([]) {
    _init();
  }

  Future<void> _init() async {
    try {
      final jsonStr = await _secureStorage.read(key: _keyAuditLogs);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(jsonStr);
        state = decoded.map((e) => AuditLogEntry.fromJson(e)).toList();
      }
    } catch (_) {}
  }

  Future<void> log({
    required AuditEventType eventType,
    required String description,
    String status = 'SUCCESS',
    Map<String, dynamic>? notificationPayload,
  }) async {
    final entry = AuditLogEntry(
      id: 'AUDIT-${DateTime.now().millisecondsSinceEpoch}',
      timestamp: DateTime.now(),
      eventType: eventType,
      description: description,
      status: status,
    );

    state = [entry, ...state];

    try {
      final jsonList = state.map((e) => e.toJson()).toList();
      await _secureStorage.write(
        key: _keyAuditLogs,
        value: jsonEncode(jsonList),
      );
    } catch (_) {}

    // Determine notification category
    NotificationCategory category;
    if (eventType == AuditEventType.payment) {
      category = NotificationCategory.transactions;
    } else {
      category = NotificationCategory.security;
    }

    // Automatically trigger notification display
    _notificationService.showNotification(
      title: _getCategoryTitle(eventType),
      body: description,
      category: category,
      payload: notificationPayload,
    );
  }

  String _getCategoryTitle(AuditEventType type) {
    switch (type) {
      case AuditEventType.authentication:
        return 'Authentication Alert';
      case AuditEventType.pinChange:
        return 'Security PIN Changed';
      case AuditEventType.biometrics:
        return 'Biometric Security Updated';
      case AuditEventType.kyc:
        return 'KYC Account Verification';
      case AuditEventType.payment:
        return 'Transaction Completed';
    }
  }
}

final auditLogServiceProvider =
    StateNotifierProvider<AuditLogService, List<AuditLogEntry>>((ref) {
  final notifService = ref.watch(notificationServiceProvider);
  return AuditLogService(notifService);
});
