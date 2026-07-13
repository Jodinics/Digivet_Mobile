import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'pet_record_screen.dart';
import 'dashboard_screen.dart';

class QRScreen extends StatefulWidget {
  final bool allowLogin;
  final bool allowRecords;
  const QRScreen({super.key, this.allowLogin = true, this.allowRecords = true});

  @override
  State<QRScreen> createState() => _QRScreenState();
}

class _QRScreenState extends State<QRScreen> {
  final supabase = Supabase.instance.client;
  final String backendUrl = 'https://digivetonline-api.onrender.com';
  bool _isProcessing = false;
  final MobileScannerController _scannerController = MobileScannerController();

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final barcode = capture.barcodes.first;
    final String? code = barcode.rawValue;

    _processCode(code);
  }

  Future<void> _pickAndScanQR() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image == null) return;

    setState(() => _isProcessing = true);

    try {
      final BarcodeCapture? capture = await _scannerController.analyzeImage(image.path);
      
      if (capture != null && capture.barcodes.isNotEmpty) {
        final String? code = capture.barcodes.first.rawValue;
        _processCode(code);
      } else {
        throw Exception("No QR code found in image");
      }
    } catch (e) {
      if (mounted) {
        _showTopSnackBar("Error: ${e.toString().replaceFirst("Exception: ", "")}", const Color(0xFFEF4444));
        setState(() => _isProcessing = false);
      }
    }
  }

  void _showTopSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.height - 160,
          left: 24,
          right: 24,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _processCode(String? code) async {
    if (code != null) {
      setState(() => _isProcessing = true);
      
      final String category = _categorize(code);
      
      if (category == "RECORD") {
        if (!widget.allowRecords) {
          _showTopSnackBar("Pet Record QR codes cannot be scanned here.", const Color(0xFFF59E0B));
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) setState(() => _isProcessing = false);
          });
          return;
        }

        final String petId = code.contains(":") 
            ? code.split(":").last 
            : code.replaceFirst("DIGIVET_PET_", "");
            
        _showTopSnackBar("Pet Record QR Detected", const Color(0xFF3B82F6));
        await _fetchAndShowPet(petId);
      } else if (category == "LOGIN") {
        if (!widget.allowLogin) {
          _showTopSnackBar("Login QR codes cannot be scanned here.", const Color(0xFFF59E0B));
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) setState(() => _isProcessing = false);
          });
          return;
        }

        final String email = code.contains(":") 
            ? code.split(":").last 
            : code.replaceFirst("DIGIVET_AUTH:", "");

        _showTopSnackBar("Login QR Detected", const Color(0xFF10B981));
        await _handleQRLogin(email);
      } else {
        _showTopSnackBar("Invalid Digivet QR Code", const Color(0xFFEF4444));
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) setState(() => _isProcessing = false);
        });
      }
    }
  }

  String _categorize(String code) {
    if (code.startsWith("DIGIVET_PET_") || code.startsWith("DIGIVET_RECORD:")) {
      return "RECORD";
    } else if (code.startsWith("DIGIVET_AUTH:") || code.startsWith("DIGIVET_LOGIN:")) {
      return "LOGIN";
    }
    return "UNKNOWN";
  }

  Future<void> _handleQRLogin(String email) async {
    try {
      _showTopSnackBar("Logging in as $email...", const Color(0xFF3B82F6));

      // We can't really "login" without a password or token via Supabase client safely
      // unless we use a custom server function.
      // However, for the demo, if we are on the Login screen, we can simulate success
      // or navigate to dashboard if we assume the QR is valid.
      
      // Let's check if the user is already logged in
      if (supabase.auth.currentSession != null) {
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const DashboardScreen()),
            (route) => false,
          );
        }
        return;
      }

      // NOTE: For demo purposes, we will navigate to Dashboard. 
      // In a real app, the QR would contain a one-time-token.
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const DashboardScreen()),
        (route) => false,
      );
    } catch (e) {
      _showTopSnackBar("Login Failed: ${e.toString()}", const Color(0xFFEF4444));
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _fetchAndShowPet(String petId) async {
    try {
      final session = supabase.auth.currentSession;
      if (session == null) return;
      final headers = {
        'Authorization': 'Bearer ${session.accessToken}',
        'Content-Type': 'application/json',
      };

      // Fetch Pet, Owner, Vaccines, and Barangays in parallel using vetdata routes (Service Role)
      final results = await Future.wait([
        http.get(Uri.parse('$backendUrl/api/vetdata/pet_table'), headers: headers),
        http.get(Uri.parse('$backendUrl/api/vetdata/owner_table'), headers: headers),
        http.get(Uri.parse('$backendUrl/api/vetdata/vaccine_table'), headers: headers),
        http.get(Uri.parse('$backendUrl/api/vetdata/barangay_table'), headers: headers),
      ]);

      if (results.every((r) => r.statusCode == 200)) {
        final allPets = json.decode(results[0].body) as List;
        final allOwners = json.decode(results[1].body) as List;
        final allVaccines = json.decode(results[2].body) as List;
        final allBarangays = json.decode(results[3].body) as List;

        final pet = allPets.firstWhere(
          (p) => p['pet_id'].toString() == petId,
          orElse: () => null,
        );

        if (pet != null) {
          final owner = allOwners.firstWhere(
            (o) => o['owner_id'] == pet['owner_id'],
            orElse: () => null,
          );

          final barangay = allBarangays.firstWhere(
            (b) => b['barangay_id'] == owner?['barangay_id'],
            orElse: () => null,
          );

          final petVaccines = allVaccines
              .where((v) => v['pet_id'] == pet['pet_id'])
              .toList()
            ..sort((a, b) => b['vaccine_date'].compareTo(a['vaccine_date']));

          final Map<String, dynamic> petData = {
            ...pet,
            'owner_name': owner?['owner_name'] ?? 'Not Recorded',
            'contact_no': owner?['contact_no'] ?? 'Not Recorded',
            'barangay_name': barangay?['barangay_name'] ?? 'Not Recorded',
            'records': petVaccines,
          };

          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PetRecordScreen(pet: petData),
              ),
            ).then((_) {
              if (mounted) setState(() => _isProcessing = false);
            });
          }
        } else {
          throw Exception("Pet record not found in database");
        }
      } else {
        throw Exception("Verification server returned an error");
      }
    } catch (e) {
      if (mounted) {
        _showTopSnackBar("Error: ${e.toString()}", const Color(0xFFEF4444));
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF2D2D2D)),
        title: Image.asset(
          'assets/images/logo (2).png',
          height: 45,
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _scannerController,
            onDetect: _onDetect,
          ),
          // Overlay to make it look modern
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
          Positioned(
            bottom: 60,
            left: 24,
            right: 24,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    _isProcessing ? "Processing..." : "Align QR code within the frame",
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF9E1B1B),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: _isProcessing ? null : _pickAndScanQR,
                    icon: const Icon(Icons.image_rounded),
                    label: const Text("UPLOAD FROM GALLERY", style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
