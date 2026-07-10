import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QRScreen extends StatelessWidget {
  const QRScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("QR Login"),
        backgroundColor: const Color(0xFF7B1E1E),
        foregroundColor: Colors.white,
      ),
      body: MobileScanner(
        onDetect: (capture) {
          final barcode = capture.barcodes.first;

          if (barcode.rawValue != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("QR Code: ${barcode.rawValue}"),
              ),
            );
          }
        },
      ),
    );
  }
}