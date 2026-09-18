import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:payflow/core/services/pdf_generator_service.dart';
import 'package:payflow/features/home/models/transaction_item.dart';
import 'package:payflow/features/wallet/widgets/statement_export_sheet.dart';
import 'package:payflow/features/wallet/widgets/transaction_detail_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockPathProviderPlatform extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  final String path;
  MockPathProviderPlatform(this.path);

  @override
  Future<String?> getApplicationDocumentsPath() async => path;

  @override
  Future<String?> getExternalStoragePath() async => path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  String? mockClipboardText;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('share_test_');
    PathProviderPlatform.instance = MockPathProviderPlatform(tempDir.path);
    mockClipboardText = null;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (MethodCall methodCall) async {
      if (methodCall.method == 'Clipboard.setData') {
        mockClipboardText = (methodCall.arguments as Map)['text'] as String?;
        return null;
      } else if (methodCall.method == 'Clipboard.getData') {
        return <String, dynamic>{'text': mockClipboardText};
      }
      return null;
    });
  });

  tearDown(() async {
    try {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    } catch (_) {}
  });

  final sampleTx = TransactionItem(
    id: 'TXN-5544',
    title: 'Electricity Token Purchase',
    category: 'Electricity',
    amount: 5000.0,
    timestamp: DateTime(2026, 8, 15, 10, 30),
    isCredit: false,
    status: 'Completed',
    reference: 'PF-ELE-99887766',
    recipientOrSender: '08012345678',
    token: '1234-5678-9012-3456',
    narration: 'Token for prepaid meter',
  );

  group('Platform-Aware Receipt & Statement Share Handler Tests', () {
    testWidgets('1. TransactionDetailSheet renders Share and Download buttons', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () => TransactionDetailSheet.show(context, sampleTx, isWeb: true),
                  child: const Text('Open Sheet'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('Electricity Token Purchase'), findsOneWidget);
      expect(find.text('Share'), findsOneWidget);
      expect(find.text('Download PDF'), findsOneWidget);
    });

    testWidgets('2. Tapping Share on Web copies receipt details and displays SnackBar', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () => TransactionDetailSheet.show(context, sampleTx, isWeb: true),
                  child: const Text('Open Sheet'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      // Ensure button is visible in scroll view and tap
      await tester.ensureVisible(find.text('Share'));
      await tester.tap(find.text('Share'));
      await tester.pump(const Duration(milliseconds: 350));

      // SnackBar with required text appears
      expect(find.text('Receipt details copied to clipboard!'), findsOneWidget);

      // Verify clipboard content
      final clipData = await Clipboard.getData(Clipboard.kTextPlain);
      expect(clipData?.text, contains('PayFlow Transaction Receipt'));
      expect(clipData?.text, contains('Electricity Token Purchase'));
      expect(clipData?.text, contains('NGN 5000.00'));
      expect(clipData?.text, contains('PF-ELE-99887766'));
      expect(clipData?.text, contains('08012345678'));
      expect(clipData?.text, contains('1234-5678-9012-3456'));

      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('3. Tapping Download on Web triggers direct blob download flow', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () => TransactionDetailSheet.show(context, sampleTx, isWeb: true),
                  child: const Text('Open Sheet'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      // Tap Download on web
      await tester.ensureVisible(find.text('Download PDF'));
      await tester.tap(find.text('Download PDF'));
      await tester.pump(const Duration(milliseconds: 350));

      // Download SnackBar displays clean web format
      expect(find.textContaining('Receipt downloaded: PayFlow_Receipt_'), findsOneWidget);

      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('4. StatementExportSheet on Web copies statement details and shows SnackBar', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () => StatementExportSheet.show(context, isWeb: true),
                    child: const Text('Open Statement Sheet'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Statement Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('Account Statement'), findsOneWidget);
      expect(find.text('Share'), findsOneWidget);
      expect(find.text('Download PDF'), findsOneWidget);

      // Tap Share on web
      await tester.ensureVisible(find.text('Share'));
      await tester.tap(find.text('Share'));
      await tester.pump(const Duration(milliseconds: 350));

      // SnackBar shows
      expect(find.text('Receipt details copied to clipboard!'), findsOneWidget);

      // Clipboard content contains statement details
      final clipData = await Clipboard.getData(Clipboard.kTextPlain);
      expect(clipData?.text, contains('PayFlow Account Statement'));
      expect(clipData?.text, contains('Current Balance'));

      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('5. StatementExportSheet on Web downloads PDF blob directly', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () => StatementExportSheet.show(context, isWeb: true),
                    child: const Text('Open Statement Sheet'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Statement Sheet'));
      await tester.pumpAndSettle();

      // Tap Download PDF
      await tester.ensureVisible(find.text('Download PDF'));
      await tester.tap(find.text('Download PDF'));
      await tester.pump(const Duration(milliseconds: 350));

      // SnackBar shows web download format
      expect(find.textContaining('Statement downloaded: PayFlow_Statement_'), findsOneWidget);

      await tester.pump(const Duration(seconds: 4));
    });

    test('6. PdfGeneratorService platform-aware share & save directly handles isWebOverride', () async {
      // On web, savePdfToStorage triggers blob download and returns filename without throwing or calling printing
      final filename = 'test_receipt.pdf';
      final bytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      final savedWebPath = await PdfGeneratorService.savePdfToStorage(
        bytes: bytes,
        filename: filename,
        isWebOverride: true,
      );
      expect(savedWebPath, equals(filename));

      // On native, savePdfToStorage writes bytes to physical file
      final savedNativePath = await PdfGeneratorService.savePdfToStorage(
        bytes: bytes,
        filename: filename,
        isWebOverride: false,
      );
      expect(savedNativePath, contains(tempDir.path));
      expect(File(savedNativePath).existsSync(), isTrue);
    });

    testWidgets('7. TransactionDetailSheet explicitly renders Narration row with entered value', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final umbrellaTx = TransactionItem(
        id: 'TXN-UMB-123',
        title: 'Transfer to Chukwuma',
        category: 'Transfer',
        amount: 3500.0,
        timestamp: DateTime(2026, 9, 15, 12, 0),
        isCredit: false,
        status: 'Completed',
        reference: 'PF-TXN-UMB-123',
        narration: 'umbrella',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () => TransactionDetailSheet.show(context, umbrellaTx, isWeb: true),
                  child: const Text('Open Sheet'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('Narration'), findsOneWidget);
      expect(find.text('umbrella'), findsOneWidget);
    });
  });
}
