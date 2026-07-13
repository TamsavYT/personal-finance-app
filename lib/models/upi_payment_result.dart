/// Outcome of a UPI intent handoff.
///
/// [pending] covers two cases that must be handled identically by callers:
/// the PSP explicitly returned `Status=SUBMITTED` (bank hasn't confirmed yet),
/// or the app returned no usable `response` extra at all - which GPay/PhonePe
/// commonly do for P2P (non-merchant) transfers even when the payment
/// succeeded. Neither case should be logged as a transaction directly; both
/// need reconciliation against the payment-app notification.
enum UpiPaymentStatus { success, failure, cancelled, pending }

class UpiPaymentResult {
  final UpiPaymentStatus status;
  final String? txnId;
  final String? txnRef;
  final String? approvalRefNo;
  final String? responseCode;
  final String? rawResponse;

  const UpiPaymentResult({
    required this.status,
    this.txnId,
    this.txnRef,
    this.approvalRefNo,
    this.responseCode,
    this.rawResponse,
  });

  /// [resultCode] is the raw Android Activity result code (-1 = RESULT_OK,
  /// 0 = RESULT_CANCELED). [response] is the PSP's `response` extra, when any.
  factory UpiPaymentResult.parse({required int resultCode, String? response}) {
    final fields = _parseFields(response);
    final rawStatus = (fields['status'] ?? fields['txnstatus'] ?? '').toUpperCase();

    UpiPaymentStatus status;
    if (rawStatus == 'SUCCESS') {
      status = UpiPaymentStatus.success;
    } else if (rawStatus == 'FAILURE' || rawStatus == 'FAILED') {
      status = UpiPaymentStatus.failure;
    } else if (rawStatus == 'SUBMITTED') {
      status = UpiPaymentStatus.pending;
    } else if (response == null || response.trim().isEmpty) {
      // No status field at all: RESULT_CANCELED with nothing usually means
      // the user backed out before picking an app / completing the flow.
      // RESULT_OK with nothing means the PSP just didn't report back -
      // treat as pending so it can be reconciled, not silently dropped.
      status = resultCode == 0 ? UpiPaymentStatus.cancelled : UpiPaymentStatus.pending;
    } else {
      status = UpiPaymentStatus.pending;
    }

    return UpiPaymentResult(
      status: status,
      txnId: fields['txnid'],
      txnRef: fields['txnref'],
      approvalRefNo: fields['approvalrefno'],
      responseCode: fields['responsecode'] ?? fields['code'],
      rawResponse: response,
    );
  }

  static Map<String, String> _parseFields(String? response) {
    if (response == null || response.trim().isEmpty) return {};
    final text = response.trim();
    final out = <String, String>{};
    try {
      final query = text.contains('?') ? text.split('?').last : text;
      Uri.splitQueryString(query).forEach((key, value) {
        out[key.toLowerCase()] = value;
      });
      if (out.isNotEmpty) return out;
    } catch (_) {
      // fall through to manual parsing below
    }
    for (final pair in text.split('&')) {
      final idx = pair.indexOf('=');
      if (idx <= 0) continue;
      final key = pair.substring(0, idx).trim().toLowerCase();
      final value = pair.substring(idx + 1).trim();
      if (key.isNotEmpty) out[key] = value;
    }
    return out;
  }

  @override
  String toString() =>
      'UpiPaymentResult(status: $status, txnId: $txnId, txnRef: $txnRef, raw: $rawResponse)';
}
