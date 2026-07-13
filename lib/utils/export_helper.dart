import 'dart:io';

import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/account.dart';
import '../models/category.dart';
import '../models/transaction.dart';

/// Exports transaction data to CSV files.
///
/// Resolves category and account IDs to human-readable names before
/// writing the file to the app's documents directory.
class ExportHelper {
  ExportHelper._();

  /// Exports a list of [transactions] to a CSV file.
  ///
  /// [categories] and [accounts] are used to resolve the numeric IDs
  /// stored in each transaction to their display names.
  /// Optional [startDate] and [endDate] filter transactions by date range.
  ///
  /// Returns the absolute path of the generated CSV file.
  static Future<String> exportToCsv(
    List<TransactionRecord> transactions,
    List<Category> categories,
    List<Account> accounts, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    // Build lookup maps for O(1) name resolution.
    final categoryMap = {
      for (final c in categories) c.id: c.name,
    };
    final accountMap = {
      for (final a in accounts) a.id: a.name,
    };

    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

    // Filter by date range if provided.
    var filtered = transactions;
    if (startDate != null || endDate != null) {
      filtered = transactions.where((txn) {
        final txDate = txn.date;
        if (startDate != null && txDate.isBefore(startDate)) return false;
        if (endDate != null && txDate.isAfter(endDate)) return false;
        return true;
      }).toList();
    }

    // Header row.
    final List<List<dynamic>> rows = [
      ['Date', 'Type', 'Category', 'Account', 'To Account', 'Amount', 'Note'],
    ];

    // Data rows.
    for (final txn in filtered) {
      rows.add([
        dateFormat.format(txn.date),
        txn.type,
        categoryMap[txn.categoryId] ?? '',
        accountMap[txn.accountId] ?? '',
        txn.toAccountId != null ? (accountMap[txn.toAccountId] ?? '') : '',
        txn.amount.toStringAsFixed(2),
        txn.note ?? '',
      ]);
    }

    // Convert to CSV string.
    final csvString = csv.encode(rows);

    // Write to documents directory.
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateFormat('yyyyMMdd').format(DateTime.now());
    final filePath = '${directory.path}/expense_ledger_export_$timestamp.csv';
    final file = File(filePath);
    await file.writeAsString(csvString);

    return filePath;
  }

  /// Exports a list of [transactions] to a beautifully styled PDF file.
  /// Optional [startDate] and [endDate] filter transactions by date range.
  static Future<String> exportToPdf(
    List<TransactionRecord> transactions,
    List<Category> categories,
    List<Account> accounts, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final pdf = pw.Document();

    final categoryMap = {for (final c in categories) c.id: c.name};
    final accountMap = {for (final a in accounts) a.id: a.name};
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');

    // Filter by date range if provided.
    var filtered = transactions;
    if (startDate != null || endDate != null) {
      filtered = transactions.where((txn) {
        final txDate = txn.date;
        if (startDate != null && txDate.isBefore(startDate)) return false;
        if (endDate != null && txDate.isAfter(endDate)) return false;
        return true;
      }).toList();
    }

    // Format date range for report header.
    String dateRangeText = 'Generated: ${DateFormat('yyyy-MM-dd').format(DateTime.now())}';
    if (startDate != null || endDate != null) {
      final start = startDate != null ? DateFormat('yyyy-MM-dd').format(startDate) : 'Start';
      final end = endDate != null ? DateFormat('yyyy-MM-dd').format(endDate) : 'End';
      dateRangeText += ' (Period: $start to $end)';
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Expense Ledger Report', textScaleFactor: 2),
                  pw.Text(dateRangeText),
                ]
              ),
            ),
            pw.SizedBox(height: 20),
            pw.TableHelper.fromTextArray(
              context: context,
              headers: ['Date', 'Type', 'Category', 'Account', 'Amount', 'Note'],
              data: filtered.map((txn) {
                return [
                  dateFormat.format(txn.date),
                  txn.type.toUpperCase(),
                  categoryMap[txn.categoryId] ?? '-',
                  accountMap[txn.accountId] ?? '-',
                  '${txn.amount.toStringAsFixed(2)}',
                  txn.note ?? '-',
                ];
              }).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
              rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
              cellAlignment: pw.Alignment.centerLeft,
            ),
          ];
        },
      ),
    );

    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final filePath = '${directory.path}/expense_report_$timestamp.pdf';
    final file = File(filePath);
    await file.writeAsBytes(await pdf.save());

    return filePath;
  }

  /// Parses a CSV file (in the same format produced by [exportToCsv]) into
  /// [TransactionRecord]s. Category and account names are resolved to IDs
  /// via [categories] and [accounts]; rows referencing an unknown category
  /// or account name are skipped and reported in [ImportResult.skipped].
  static Future<ImportResult> importFromCsv(
    String filePath,
    List<Category> categories,
    List<Account> accounts,
  ) async {
    final file = File(filePath);
    final content = await file.readAsString();
    final rows = Csv(lineDelimiter: '\n').decode(content);

    if (rows.isEmpty) {
      return ImportResult(transactions: [], skipped: 0, total: 0);
    }

    final categoryMap = {for (final c in categories) c.name: c.id};
    final accountMap = {for (final a in accounts) a.name: a.id};
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

    final transactions = <TransactionRecord>[];
    int skipped = 0;

    // Skip header row.
    for (final row in rows.skip(1)) {
      if (row.length < 6) {
        skipped++;
        continue;
      }

      try {
        final type = row[1].toString().trim();
        final categoryId = categoryMap[row[2].toString().trim()];
        final accountId = accountMap[row[3].toString().trim()];
        final toAccountName = row[4].toString().trim();
        final toAccountId =
            toAccountName.isNotEmpty ? accountMap[toAccountName] : null;

        if (categoryId == null || accountId == null) {
          skipped++;
          continue;
        }

        final now = DateTime.now();
        transactions.add(TransactionRecord(
          date: dateFormat.parse(row[0].toString().trim()),
          type: type,
          categoryId: categoryId,
          accountId: accountId,
          toAccountId: toAccountId,
          amount: double.parse(row[5].toString().trim()),
          note: row.length > 6 && row[6].toString().isNotEmpty
              ? row[6].toString()
              : null,
          createdAt: now,
        ));
      } catch (_) {
        skipped++;
      }
    }

    return ImportResult(
      transactions: transactions,
      skipped: skipped,
      total: rows.length - 1,
    );
  }
}

/// Result of parsing a CSV import file.
class ImportResult {
  final List<TransactionRecord> transactions;
  final int skipped;
  final int total;

  const ImportResult({
    required this.transactions,
    required this.skipped,
    required this.total,
  });
}
