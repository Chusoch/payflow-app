import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../../features/home/models/transaction_item.dart';
import 'web_download_helper.dart';

class PdfGeneratorService {
  static String maskIdentifier(String value) {
    if (value.length <= 6) return value;
    final start = value.substring(0, 4);
    final end = value.substring(value.length - 4);
    return '$start****$end';
  }

  static String maskReference(String ref) {
    if (ref.length <= 8) return ref;
    final prefix = ref.substring(0, 6);
    final suffix = ref.substring(ref.length - 4);
    return '$prefix****$suffix';
  }

  /// Generates a PDF transaction receipt with masked sensitive details.
  static Future<Uint8List> generateReceiptPdf({
    required String title,
    required double amount,
    required String reference,
    required String status,
    required DateTime timestamp,
    String? providerName,
    String? identifier,
    String? token,
    String? narration,
    String? senderName,
    String? recipientName,
  }) async {
    final pdf = pw.Document();
    final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(timestamp);
    final maskedRef = maskReference(reference);
    final maskedId = identifier != null ? maskIdentifier(identifier) : null;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(32),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header Banner
                pw.Container(
                  padding: const pw.EdgeInsets.all(16),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.teal700,
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'PayFlow',
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        'OFFICIAL RECEIPT',
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 24),

                // Amount Display
                pw.Center(
                  child: pw.Column(
                    children: [
                      pw.Text(
                        'Transaction Amount',
                        style: const pw.TextStyle(
                          fontSize: 12,
                          color: PdfColors.grey700,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'NGN ${amount.toStringAsFixed(2)}',
                        style: pw.TextStyle(
                          fontSize: 28,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.teal900,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: pw.BoxDecoration(
                          color: status.toUpperCase() == 'COMPLETED' || status.toUpperCase() == 'SUCCESSFUL'
                              ? PdfColors.green100
                              : PdfColors.orange100,
                          borderRadius: pw.BorderRadius.circular(12),
                        ),
                        child: pw.Text(
                          status.toUpperCase(),
                          style: pw.TextStyle(
                            color: status.toUpperCase() == 'COMPLETED' || status.toUpperCase() == 'SUCCESSFUL'
                                ? PdfColors.green800
                                : PdfColors.orange800,
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 32),
                pw.Divider(color: PdfColors.grey300),
                pw.SizedBox(height: 16),

                // Receipt Details Table
                _pdfDetailRow('Transaction Description', title),
                _pdfDetailRow('Transaction Reference', maskedRef),
                _pdfDetailRow('Date & Time', dateStr),
                if (senderName != null && senderName.isNotEmpty) _pdfDetailRow('Sender', senderName),
                if (recipientName != null && recipientName.isNotEmpty) _pdfDetailRow('Recipient', recipientName),
                if (providerName != null && providerName != 'Transfer' && providerName != 'P2P') _pdfDetailRow('Provider / Biller', providerName),
                if (maskedId != null && maskedId != recipientName && maskedId != senderName) _pdfDetailRow('Recipient / Identifier', maskedId),
                if (narration != null && narration.isNotEmpty) _pdfDetailRow('Narration', narration),
                if (token != null && token.isNotEmpty) ...[
                  pw.SizedBox(height: 12),
                  pw.Container(
                    width: double.infinity,
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.amber50,
                      border: pw.Border.all(color: PdfColors.amber400),
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Prepaid Electricity Token',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.amber900,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          token,
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                pw.Spacer(),
                pw.Divider(color: PdfColors.grey300),
                pw.SizedBox(height: 8),
                pw.Center(
                  child: pw.Text(
                    'Generated securely by PayFlow Digital Banking System',
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey600,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Returns a clean plain-text summary of the transaction receipt.
  static String formatReceiptSummary(TransactionItem item) {
    final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(item.timestamp);
    final ref = item.reference ?? 'PF-TXN-${item.id}';
    final effectiveSender = item.senderName ?? (item.isCredit ? item.recipientOrSender : null);
    final effectiveRecipient = item.recipientName ?? (!item.isCredit ? item.recipientOrSender : null);
    final effectiveNarration = (item.narration != null && item.narration!.trim().isNotEmpty)
        ? item.narration!.trim()
        : ((item.description != null && item.description!.trim().isNotEmpty) ? item.description!.trim() : null);

    final buffer = StringBuffer()
      ..writeln('--- PayFlow Transaction Receipt ---')
      ..writeln('Description: ${item.title}')
      ..writeln('Amount: NGN ${item.amount.toStringAsFixed(2)}')
      ..writeln('Status: ${item.status}')
      ..writeln('Reference: $ref')
      ..writeln('Date: $dateStr');
    if (effectiveSender != null && effectiveSender.isNotEmpty) {
      buffer.writeln('Sender: $effectiveSender');
    }
    if (effectiveRecipient != null && effectiveRecipient.isNotEmpty) {
      buffer.writeln('Recipient: $effectiveRecipient');
    }
    if (effectiveNarration != null && effectiveNarration.isNotEmpty) {
      buffer.writeln('Narration: $effectiveNarration');
    }
    if (item.category.isNotEmpty) {
      buffer.writeln('Category: ${item.category}');
    }
    if (item.token != null && item.token!.isNotEmpty) {
      buffer.writeln('Token: ${item.token}');
    }
    return buffer.toString().trim();
  }

  /// Triggers platform-aware sharing for the transaction receipt:
  /// - On Web (kIsWeb): Copies receipt details text to clipboard and displays a SnackBar.
  /// - On Android/iOS: Launches native share sheet via Share.shareXFiles([XFile(path)]).
  static Future<void> shareReceiptPdf(
    TransactionItem item, {
    BuildContext? context,
    ScaffoldMessengerState? messenger,
    bool? isWebOverride,
  }) async {
    final isWeb = isWebOverride ?? kIsWeb;
    if (isWeb) {
      final summary = formatReceiptSummary(item);
      await Clipboard.setData(ClipboardData(text: summary));
      final scMessenger = messenger ?? (context != null && context.mounted ? ScaffoldMessenger.of(context) : null);
      scMessenger?.showSnackBar(
        const SnackBar(
          content: Text('Receipt details copied to clipboard!'),
        ),
      );
      return;
    }

    final effectiveSender = item.senderName ?? (item.isCredit ? item.recipientOrSender : null);
    final effectiveRecipient = item.recipientName ?? (!item.isCredit ? item.recipientOrSender : null);
    final effectiveNarration = (item.narration != null && item.narration!.trim().isNotEmpty)
        ? item.narration!.trim()
        : ((item.description != null && item.description!.trim().isNotEmpty) ? item.description!.trim() : null);

    final bytes = await generateReceiptPdf(
      title: item.title,
      amount: item.amount,
      reference: item.reference ?? 'PF-TXN-${item.id}',
      status: item.status,
      timestamp: item.timestamp,
      providerName: item.category,
      identifier: item.recipientOrSender,
      token: item.token,
      narration: effectiveNarration,
      senderName: effectiveSender,
      recipientName: effectiveRecipient,
    );

    final filename = 'PayFlow_Receipt_${maskReference(item.reference ?? item.id)}.pdf';
    final path = await savePdfToStorage(bytes: bytes, filename: filename, isWebOverride: isWebOverride);
    // ignore: deprecated_member_use
    await Share.shareXFiles(
      [XFile(path)],
      text: 'PayFlow Receipt: ${item.title}',
    );
  }

  /// Saves generated PDF bytes directly to local storage directory on mobile/desktop,
  /// or triggers a direct browser download of the PDF blob on web.
  static Future<String> savePdfToStorage({
    required Uint8List bytes,
    required String filename,
    bool? isWebOverride,
  }) async {
    final isWeb = isWebOverride ?? kIsWeb;
    if (isWeb) {
      downloadPdfBlobWeb(bytes, filename);
      return filename;
    }
    final sanitizedFilename = filename.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    Directory? dir;
    if (Platform.isAndroid) {
      dir = await getExternalStorageDirectory();
      dir ??= await getApplicationDocumentsDirectory();
    } else {
      dir = await getApplicationDocumentsDirectory();
    }
    final file = File('${dir.path}/$sanitizedFilename');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  /// Downloads/Saves the PDF receipt directly to device storage.
  static Future<String> downloadReceiptPdf(TransactionItem item, {bool? isWebOverride}) async {
    final effectiveSender = item.senderName ?? (item.isCredit ? item.recipientOrSender : null);
    final effectiveRecipient = item.recipientName ?? (!item.isCredit ? item.recipientOrSender : null);
    final effectiveNarration = (item.narration != null && item.narration!.trim().isNotEmpty)
        ? item.narration!.trim()
        : ((item.description != null && item.description!.trim().isNotEmpty) ? item.description!.trim() : null);

    final bytes = await generateReceiptPdf(
      title: item.title,
      amount: item.amount,
      reference: item.reference ?? 'PF-TXN-${item.id}',
      status: item.status,
      timestamp: item.timestamp,
      providerName: item.category,
      identifier: item.recipientOrSender,
      token: item.token,
      narration: effectiveNarration,
      senderName: effectiveSender,
      recipientName: effectiveRecipient,
    );

    final filename = 'PayFlow_Receipt_${maskReference(item.reference ?? item.id)}.pdf';
    return await savePdfToStorage(bytes: bytes, filename: filename, isWebOverride: isWebOverride);
  }

  /// Opens native print preview dialog for the PDF receipt.
  static Future<void> printReceiptPdf(TransactionItem item) async {
    final effectiveSender = item.senderName ?? (item.isCredit ? item.recipientOrSender : null);
    final effectiveRecipient = item.recipientName ?? (!item.isCredit ? item.recipientOrSender : null);
    final effectiveNarration = (item.narration != null && item.narration!.trim().isNotEmpty)
        ? item.narration!.trim()
        : ((item.description != null && item.description!.trim().isNotEmpty) ? item.description!.trim() : null);

    final bytes = await generateReceiptPdf(
      title: item.title,
      amount: item.amount,
      reference: item.reference ?? 'PF-TXN-${item.id}',
      status: item.status,
      timestamp: item.timestamp,
      providerName: item.category,
      identifier: item.recipientOrSender,
      token: item.token,
      narration: effectiveNarration,
      senderName: effectiveSender,
      recipientName: effectiveRecipient,
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => bytes,
      name: 'PayFlow_Receipt_${maskReference(item.reference ?? item.id)}.pdf',
    );
  }

  /// Generates a multi-page PDF Account Statement.
  static Future<Uint8List> generateStatementPdf({
    required List<TransactionItem> transactions,
    required DateTimeRange dateRange,
    required String categoryFilter,
    required double currentBalance,
  }) async {
    final pdf = pw.Document();
    final startDateStr = DateFormat('dd MMM yyyy').format(dateRange.start);
    final endDateStr = DateFormat('dd MMM yyyy').format(dateRange.end);

    final filtered = transactions.where((tx) {
      final matchesDate = tx.timestamp.isAfter(dateRange.start.subtract(const Duration(seconds: 1))) &&
          tx.timestamp.isBefore(dateRange.end.add(const Duration(days: 1)));
      if (!matchesDate) return false;

      if (categoryFilter.toLowerCase() == 'all') return true;
      if (categoryFilter.toLowerCase() == 'transfers' && tx.category.toLowerCase().contains('transfer')) return true;
      if (categoryFilter.toLowerCase() == 'airtime' && tx.category.toLowerCase().contains('airtime')) return true;
      if (categoryFilter.toLowerCase() == 'data' && tx.category.toLowerCase().contains('data')) return true;
      if (categoryFilter.toLowerCase() == 'bills' &&
          (tx.category.toLowerCase().contains('electricity') || tx.category.toLowerCase().contains('cable'))) {
        return true;
      }
      if (categoryFilter.toLowerCase() == 'wallet funding' &&
          (tx.category.toLowerCase().contains('top up') || tx.category.toLowerCase().contains('funding'))) {
        return true;
      }
      return tx.category.toLowerCase().contains(categoryFilter.toLowerCase());
    }).toList();

    double totalCredits = 0;
    double totalDebits = 0;
    for (final tx in filtered) {
      if (tx.isCredit) {
        totalCredits += tx.amount;
      } else {
        totalDebits += tx.amount;
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            // Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'PayFlow',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.teal800,
                      ),
                    ),
                    pw.Text(
                      'Account Statement',
                      style: const pw.TextStyle(
                        fontSize: 14,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Period: $startDateStr - $endDateStr',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      'Category: $categoryFilter',
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 16),
            pw.Divider(color: PdfColors.grey400),
            pw.SizedBox(height: 12),

            // Summary Cards Row
            pw.Row(
              children: [
                _summaryBox('Current Balance', 'NGN ${currentBalance.toStringAsFixed(2)}', PdfColors.teal50, PdfColors.teal800),
                pw.SizedBox(width: 12),
                _summaryBox('Total Credits', 'NGN ${totalCredits.toStringAsFixed(2)}', PdfColors.green50, PdfColors.green800),
                pw.SizedBox(width: 12),
                _summaryBox('Total Debits', 'NGN ${totalDebits.toStringAsFixed(2)}', PdfColors.red50, PdfColors.red800),
              ],
            ),
            pw.SizedBox(height: 20),

            // Transactions Table
            pw.Text(
              'Transaction History (${filtered.length} entries)',
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 8),

            pw.TableHelper.fromTextArray(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              headerStyle: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.teal800),
              cellStyle: const pw.TextStyle(fontSize: 8),
              cellAlignment: pw.Alignment.centerLeft,
              headerAlignment: pw.Alignment.centerLeft,
              data: [
                ['Date', 'Description', 'Category', 'Reference', 'Type', 'Amount (NGN)'],
                ...filtered.map((tx) {
                  final date = DateFormat('dd/MM/yyyy').format(tx.timestamp);
                  final maskedRef = maskReference(tx.reference ?? tx.id);
                  final typeStr = tx.isCredit ? 'CREDIT' : 'DEBIT';
                  final amountStr = '${tx.isCredit ? '+' : '-'}${tx.amount.toStringAsFixed(2)}';
                  return [
                    date,
                    tx.title,
                    tx.category,
                    maskedRef,
                    typeStr,
                    amountStr,
                  ];
                }),
              ],
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  /// Returns a clean plain-text summary of the account statement.
  static String formatStatementSummary({
    required List<TransactionItem> transactions,
    required DateTimeRange dateRange,
    required String categoryFilter,
    required double currentBalance,
  }) {
    final startDateStr = DateFormat('dd MMM yyyy').format(dateRange.start);
    final endDateStr = DateFormat('dd MMM yyyy').format(dateRange.end);
    final buffer = StringBuffer()
      ..writeln('--- PayFlow Account Statement ---')
      ..writeln('Period: $startDateStr - $endDateStr')
      ..writeln('Category: $categoryFilter')
      ..writeln('Current Balance: NGN ${currentBalance.toStringAsFixed(2)}')
      ..writeln('Total Transactions: ${transactions.length}');
    return buffer.toString().trim();
  }

  /// Launches platform-aware sharing for the generated PDF Account Statement:
  /// - On Web (kIsWeb): Copies statement details to clipboard and displays a SnackBar.
  /// - On Android/iOS: Launches native share sheet via Share.shareXFiles([XFile(path)]).
  static Future<void> shareStatementPdf({
    required List<TransactionItem> transactions,
    required DateTimeRange dateRange,
    required String categoryFilter,
    required double currentBalance,
    BuildContext? context,
    ScaffoldMessengerState? messenger,
    bool? isWebOverride,
  }) async {
    final isWeb = isWebOverride ?? kIsWeb;
    if (isWeb) {
      final summary = formatStatementSummary(
        transactions: transactions,
        dateRange: dateRange,
        categoryFilter: categoryFilter,
        currentBalance: currentBalance,
      );
      await Clipboard.setData(ClipboardData(text: summary));
      final scMessenger = messenger ?? (context != null && context.mounted ? ScaffoldMessenger.of(context) : null);
      scMessenger?.showSnackBar(
        const SnackBar(
          content: Text('Receipt details copied to clipboard!'),
        ),
      );
      return;
    }

    final bytes = await generateStatementPdf(
      transactions: transactions,
      dateRange: dateRange,
      categoryFilter: categoryFilter,
      currentBalance: currentBalance,
    );

    final filename = 'PayFlow_Statement_${DateFormat('yyyyMMdd').format(dateRange.start)}_${DateFormat('yyyyMMdd').format(dateRange.end)}.pdf';
    final path = await savePdfToStorage(bytes: bytes, filename: filename, isWebOverride: isWebOverride);
    // ignore: deprecated_member_use
    await Share.shareXFiles(
      [XFile(path)],
      text: 'PayFlow Account Statement',
    );
  }

  /// Downloads/Saves the PDF Account Statement directly to device storage.
  static Future<String> downloadStatementPdf({
    required List<TransactionItem> transactions,
    required DateTimeRange dateRange,
    required String categoryFilter,
    required double currentBalance,
    bool? isWebOverride,
  }) async {
    final bytes = await generateStatementPdf(
      transactions: transactions,
      dateRange: dateRange,
      categoryFilter: categoryFilter,
      currentBalance: currentBalance,
    );

    final filename = 'PayFlow_Statement_${DateFormat('yyyyMMdd').format(dateRange.start)}_${DateFormat('yyyyMMdd').format(dateRange.end)}.pdf';
    return await savePdfToStorage(bytes: bytes, filename: filename, isWebOverride: isWebOverride);
  }

  /// Opens native print preview dialog for the PDF Account Statement.
  static Future<void> printStatementPdf({
    required List<TransactionItem> transactions,
    required DateTimeRange dateRange,
    required String categoryFilter,
    required double currentBalance,
  }) async {
    final bytes = await generateStatementPdf(
      transactions: transactions,
      dateRange: dateRange,
      categoryFilter: categoryFilter,
      currentBalance: currentBalance,
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => bytes,
      name: 'PayFlow_Statement_${DateFormat('yyyyMMdd').format(dateRange.start)}_${DateFormat('yyyyMMdd').format(dateRange.end)}.pdf',
    );
  }

  static pw.Widget _pdfDetailRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }

  static pw.Widget _summaryBox(String label, String value, PdfColor bg, PdfColor text) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          color: bg,
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              label,
              style: pw.TextStyle(fontSize: 8, color: text, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              value,
              style: pw.TextStyle(fontSize: 10, color: text, fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
