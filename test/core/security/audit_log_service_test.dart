import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:payflow/core/notifications/notification_service.dart';
import 'package:payflow/core/security/audit_log_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuditLogService Secure Storage Tests', () {
    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
    });

    test('AuditLogService logs event and persists via FlutterSecureStorage', () async {
      final notifService = NotificationService();
      final auditService = AuditLogService(notifService);

      await auditService.log(
        eventType: AuditEventType.authentication,
        description: 'User logged in successfully',
      );

      expect(auditService.state.length, equals(1));
      expect(auditService.state.first.description, equals('User logged in successfully'));
      expect(auditService.state.first.eventType, equals(AuditEventType.authentication));

      const storage = FlutterSecureStorage();
      final storedData = await storage.read(key: 'payflow_audit_logs_secure');
      expect(storedData, isNotNull);
      expect(storedData, contains('User logged in successfully'));
    });
  });
}
