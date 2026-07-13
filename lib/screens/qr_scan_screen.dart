import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../models/upi_qr_prefill.dart';

/// Scans a UPI QR code and pops with a [UpiQrPrefill] once a valid
/// `upi://pay?...` payload is found. Pops with null if the user backs out.
class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  UpiQrPrefill? _parse(String raw) {
    Uri uri;
    try {
      uri = Uri.parse(raw);
    } catch (_) {
      return null;
    }
    if (uri.scheme.toLowerCase() != 'upi') return null;

    final params = uri.queryParameters;
    final vpa = params['pa'];
    if (vpa == null || vpa.isEmpty || !vpa.contains('@')) return null;

    final amountStr = params['am'];
    return UpiQrPrefill(
      vpa: vpa,
      payeeName: (params['pn'] ?? '').trim().isNotEmpty ? params['pn']!.trim() : vpa,
      amount: amountStr != null ? double.tryParse(amountStr) : null,
      note: params['tn'],
    );
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null) continue;
      final prefill = _parse(raw);
      if (prefill != null) {
        _handled = true;
        Navigator.of(context).pop(prefill);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan UPI QR'),
        actions: [
          IconButton(
            icon: ValueListenableBuilder<MobileScannerState>(
              valueListenable: _controller,
              builder: (context, state, child) {
                return Icon(
                  state.torchState == TorchState.on ? Icons.flash_on : Icons.flash_off,
                );
              },
            ),
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          IgnorePointer(
            child: Center(
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 2),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 32,
            left: 24,
            right: 24,
            child: Text(
              'Point the camera at a UPI QR code',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                shadows: [Shadow(blurRadius: 8, color: Colors.black.withOpacity(0.8))],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
