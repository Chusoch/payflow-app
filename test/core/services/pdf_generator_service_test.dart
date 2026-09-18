import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:payflow/core/services/pdf_generator_service.dart';
import 'package:payflow/features/home/models/transaction_item.dart';

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

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('pdf_test_');
    PathProviderPlatform.instance = MockPathProviderPlatform(tempDir.path);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('PdfGeneratorService Tests', () {
    final sampleTx = TransactionItem(
      id: 'TXN-9988',
      title: 'Electricity Bill Payment',
      category: 'Power',
      amount: 15000.0,
      timestamp: DateTime(2026, 8, 20, 14, 30),
      isCredit: false,
      status: 'Completed',
      reference: 'PF-ELE-12345678',
      recipientOrSender: '0123456789',
      token: '4432-8812-9901-2210',
      narration: 'Prepaid token purchase',
    );

    test('maskIdentifier and maskReference mask values appropriately', () {
      expect(PdfGeneratorService.maskIdentifier('0123456789'), '0123****6789');
      expect(PdfGeneratorService.maskReference('PF-ELE-12345678'), 'PF-ELE****5678');
    });

    test('generateReceiptPdf returns non-empty PDF bytes', () async {
      final bytes = await PdfGeneratorService.generateReceiptPdf(
        title: sampleTx.title,
        amount: sampleTx.amount,
        reference: sampleTx.reference!,
        status: sampleTx.status,
        timestamp: sampleTx.timestamp,
        providerName: sampleTx.category,
        identifier: sampleTx.recipientOrSender,
        token: sampleTx.token,
        narration: sampleTx.narration,
      );

      expect(bytes, isNotEmpty);
      expect(bytes.length, greaterThan(100));
    });

    test('generateStatementPdf produces multi-page statement bytes', () async {
      final bytes = await PdfGeneratorService.generateStatementPdf(
        transactions: [sampleTx],
        dateRange: DateTimeRange(
          start: DateTime(2026, 8, 1),
          end: DateTime(2026, 8, 30),
        ),
        categoryFilter: 'All',
        currentBalance: 250000.0,
      );

      expect(bytes, isNotEmpty);
      expect(bytes.length, greaterThan(100));
    });

    test('downloadReceiptPdf saves PDF directly to local storage file', () async {
      final savedPath = await PdfGeneratorService.downloadReceiptPdf(sampleTx);
      expect(savedPath, contains(tempDir.path));

      final file = File(savedPath);
      expect(await file.exists(), isTrue);
      expect(await file.length(), greaterThan(100));
    });

    test('downloadStatementPdf saves statement PDF directly to local storage file', () async {
      final savedPath = await PdfGeneratorService.downloadStatementPdf(
        transactions: [sampleTx],
        dateRange: DateTimeRange(
          start: DateTime(2026, 8, 1),
          end: DateTime(2026, 8, 30),
        ),
        categoryFilter: 'All',
        currentBalance: 250000.0,
      );
      expect(savedPath, contains(tempDir.path));

      final file = File(savedPath);
      expect(await file.exists(), isTrue);
      expect(await file.length(), greaterThan(100));
    });

    test('formatReceiptSummary formats receipt text with masked values and token', () {
      final summary = PdfGeneratorService.formatReceiptSummary(sampleTx);
      expect(summary, contains('PayFlow Transaction Receipt'));
      expect(summary, contains('Electricity Bill Payment'));
      expect(summary, contains('NGN 15000.00'));
      expect(summary, contains('PF-ELE-12345678'));
      expect(summary, contains('0123****6789'));
      expect(summary, contains('4432-8812-9901-2210'));
      expect(summary, contains('Prepaid token purchase'));
    });

    test('formatStatementSummary formats statement text correctly', () {
      final summary = PdfGeneratorService.formatStatementSummary(
        transactions: [sampleTx],
        dateRange: DateTimeRange(
          start: DateTime(2026, 8, 1),
          end: DateTime(2026, 8, 30),
        ),
        categoryFilter: 'Power',
        currentBalance: 250000.0,
      );
      expect(summary, contains('PayFlow Account Statement'));
      expect(summary, contains('Category: Power'));
      expect(summary, contains('Current Balance: NGN 250000.00'));
      expect(summary, contains('Total Transactions: 1'));
    });
  });
}
