/// Fields parsed off a scanned `upi://pay?...` QR code, handed from
/// [QrScanScreen] to [AddTransactionScreen] as route arguments.
class UpiQrPrefill {
  final String vpa;
  final String payeeName;
  final double? amount;
  final String? note;

  UpiQrPrefill({
    required this.vpa,
    required this.payeeName,
    this.amount,
    this.note,
  });
}
