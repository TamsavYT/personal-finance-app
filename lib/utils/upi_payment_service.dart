import 'dart:developer';
import 'package:flutter/services.dart';
import '../database/database_helper.dart';
import '../models/transaction.dart';
import '../models/upi_payment_result.dart';

class UpiAppNotFoundException implements Exception {
  final String message;
  UpiAppNotFoundException([this.message = 'No UPI app found on this device']);

  @override
  String toString() => message;
}

class _PendingUpiPayment {
  final double amount;
  final String payeeVpa;
  final String payeeName;
  final String? note;
  final int accountId;
  final int categoryId;
  final DateTime createdAt;
  String? txnId;
  String? txnRef;

  _PendingUpiPayment({
    required this.amount,
    required this.payeeVpa,
    required this.payeeName,
    this.note,
    required this.accountId,
    required this.categoryId,
    required this.createdAt,
  });

  bool get isExpired =>
      DateTime.now().difference(createdAt) > UpiPaymentService._reconcileWindow;
}

/// Drives P2P UPI payments through the device's installed UPI apps and logs
/// the result to the ledger.
///
/// GPay/PhonePe frequently return no usable response for P2P (non-merchant)
/// transfers even when the payment succeeded - the Activity Result callback
/// alone cannot be trusted to log every successful payment. When the callback
/// is ambiguous, the payment is parked in a short-lived pending list and
/// completed later by [NotificationService], which already listens for GPay/
/// PhonePe/Paytm debit notifications. This mirrors how the app already
/// handles the same gap for manually-made UPI payments.
class UpiPaymentService {
  static final UpiPaymentService _instance = UpiPaymentService._internal();

  factory UpiPaymentService() => _instance;

  UpiPaymentService._internal();

  static UpiPaymentService get instance => _instance;

  static const MethodChannel _channel =
      MethodChannel('com.sankar.expense_ledger/upi');
  static const Duration _reconcileWindow = Duration(minutes: 3);
  static const double _amountTolerance = 0.5; // rupees, rounding slack in notification text
  // Bounds the wait for the Activity-result callback. The Android side can
  // lose the pending callback for good if MainActivity is process-killed
  // while the UPI app is foregrounded - without this the "Waiting for UPI
  // app..." spinner would hang forever. Long enough that a normal payment
  // (user unlocks GPay, enters their PIN) always finishes well within it.
  static const Duration _resultTimeout = Duration(minutes: 2);

  final List<_PendingUpiPayment> _pending = [];
  final List<_PendingUpiPayment> _recentlyCompleted = [];

  String buildUpiUri({
    required String payeeVpa,
    required String payeeName,
    required double amount,
    String? note,
    String? transactionRefId,
  }) {
    final params = <String, String>{
      'pa': payeeVpa,
      'pn': payeeName,
      'am': amount.toStringAsFixed(2),
      'cu': 'INR',
      if (note != null && note.isNotEmpty) 'tn': note,
      if (transactionRefId != null && transactionRefId.isNotEmpty) 'tr': transactionRefId,
    };
    final query =
        params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
    return 'upi://pay?$query';
  }

  /// Launches the UPI app chooser and waits for the handoff to return.
  /// Throws [UpiAppNotFoundException] if no UPI app is installed.
  Future<UpiPaymentResult> payViaUpi({
    required String payeeVpa,
    required String payeeName,
    required double amount,
    String? note,
    required int accountId,
    required int categoryId,
  }) async {
    _sweepExpired();

    final pending = _PendingUpiPayment(
      amount: amount,
      payeeVpa: payeeVpa,
      payeeName: payeeName,
      note: note,
      accountId: accountId,
      categoryId: categoryId,
      createdAt: DateTime.now(),
    );

    final uri = buildUpiUri(
      payeeVpa: payeeVpa,
      payeeName: payeeName,
      amount: amount,
      note: note,
    );

    Map<dynamic, dynamic>? raw;
    bool timedOut = false;
    try {
      raw = await _channel
          .invokeMapMethod<dynamic, dynamic>('pay', {'uri': uri})
          .timeout(_resultTimeout, onTimeout: () => null);
      if (raw == null) timedOut = true;
    } on PlatformException catch (e) {
      if (e.code == 'NO_UPI_APP') {
        throw UpiAppNotFoundException();
      }
      rethrow;
    }

    final result = timedOut
        ? const UpiPaymentResult(status: UpiPaymentStatus.pending)
        : UpiPaymentResult.parse(
            resultCode: raw?['resultCode'] as int? ?? 0,
            response: raw?['response'] as String?,
          );

    switch (result.status) {
      case UpiPaymentStatus.success:
        pending.txnId = result.txnId;
        pending.txnRef = result.txnRef ?? result.approvalRefNo;
        await _commit(pending);
        _recentlyCompleted.add(pending);
        break;
      case UpiPaymentStatus.failure:
      case UpiPaymentStatus.cancelled:
        // Nothing was charged (or the app told us it failed) - nothing to log.
        break;
      case UpiPaymentStatus.pending:
        // Ambiguous response: park it for NotificationService to reconcile.
        _pending.add(pending);
        break;
    }

    return result;
  }

  Future<void> _commit(_PendingUpiPayment p) async {
    final tx = TransactionRecord(
      type: 'expense',
      amount: p.amount,
      categoryId: p.categoryId,
      accountId: p.accountId,
      note: (p.note?.isNotEmpty ?? false)
          ? p.note
          : 'UPI payment to ${p.payeeName} (${p.payeeVpa})',
      date: DateTime.now(),
      createdAt: DateTime.now(),
      txnId: p.txnId,
      txnRef: p.txnRef,
    );
    await DatabaseHelper.instance.insertTransaction(tx);
    log('UPI payment logged: ${p.amount} to ${p.payeeVpa}');
  }

  /// Called by [NotificationService] for GPay/PhonePe/Paytm debit
  /// notifications. If [notifiedAmount] matches a pending payment we
  /// initiated, logs it using the account/category/note picked in the UPI
  /// screen and returns true. Returns false when the notification is
  /// unrelated to our flow, so the generic auto-tracker can handle it.
  Future<bool> tryReconcile(double notifiedAmount) async {
    _sweepExpired();

    final candidates = _pending
        .where((p) => (p.amount - notifiedAmount).abs() <= _amountTolerance)
        .toList();
    if (candidates.isEmpty) return false;

    // With multiple ambiguous payments of a similar amount in flight, prefer
    // the exact amount match, then the oldest payment - the bank/PSP
    // notification for an earlier payment is expected to land first.
    candidates.sort((a, b) {
      final exactA = a.amount == notifiedAmount ? 0 : 1;
      final exactB = b.amount == notifiedAmount ? 0 : 1;
      if (exactA != exactB) return exactA - exactB;
      return a.createdAt.compareTo(b.createdAt);
    });

    final p = candidates.first;
    _pending.remove(p);
    await _commit(p);
    _recentlyCompleted.add(p);
    return true;
  }

  /// True if [notifiedAmount] was already logged via a clean SUCCESS
  /// callback (or a prior reconcile) - lets the generic notification
  /// auto-tracker skip it instead of double-logging the same payment.
  bool wasAlreadyLogged(double notifiedAmount) {
    _sweepExpired();
    return _recentlyCompleted
        .any((p) => (p.amount - notifiedAmount).abs() <= _amountTolerance);
  }

  void _sweepExpired() {
    _pending.removeWhere((p) => p.isExpired);
    _recentlyCompleted.removeWhere((p) => p.isExpired);
  }
}
