import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'pet_record_screen.dart';
import 'dashboard_screen.dart';
import 'admin_dashboard_screen.dart';

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

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing || capture.barcodes.isEmpty) return;

    final String? code = capture.barcodes.first.rawValue;
    if (code == null) return;

    // Immediately lock processing to prevent frame-spamming
    setState(() => _isProcessing = true);
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
    // Clear any existing snackbars to prevent alert spamming/queuing
    ScaffoldMessenger.of(context).clearSnackBars();
    
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

  void _navigateToDashboard(User user) {
    if (!mounted) return;
    
    _showTopSnackBar("Welcome back!", const Color(0xFF10B981));
    final role = user.userMetadata?['role']?.toString().toLowerCase();
    
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => (role == 'admin' || role == 'vet' || role == 'veterinarian') 
            ? const AdminDashboardScreen() 
            : const DashboardScreen(),
      ),
      (route) => false,
    );
  }

  void _processCode(String? code) async {
    if (code == null) {
      setState(() => _isProcessing = false);
      return;
    }
    
    debugPrint("Processing Code: $code");
    
    try {
      // 1. New V2 Secure Format
      if (code.startsWith("DIGIVET_V2:")) {
        if (!widget.allowLogin) {
          _showTopSnackBar("Login QR codes cannot be scanned here.", const Color(0xFFF59E0B));
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) setState(() => _isProcessing = false);
          });
          return;
        }
        try {
          final encoded = code.substring(11);
          final decoded = utf8.decode(base64Decode(encoded));
          final data = json.decode(decoded);
          
          if (data is Map && data.containsKey('e') && data.containsKey('p')) {
            _showTopSnackBar("Secure Login Detected. Authenticating...", const Color(0xFF3B82F6));
            
            final response = await supabase.auth.signInWithPassword(
              email: data['e'],
              password: data['p'],
            );

            if (mounted && response.session != null) {
              _navigateToDashboard(response.session!.user);
              return;
            }
          }
        } catch (e) {
          debugPrint("V2 Decode Error: $e");
        }
      }

      // 2. Try Token Login (Primary Method)
      if (code.startsWith("DIGIVET_TOKEN:")) {
        if (!widget.allowLogin) {
          _showTopSnackBar("Login QR codes cannot be scanned here.", const Color(0xFFF59E0B));
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) setState(() => _isProcessing = false);
          });
          return;
        }
        final String token = code.replaceFirst("DIGIVET_TOKEN:", "");
        await _handleTokenLogin(token);
        return;
      }

      // 3. Try JSON processing (Legacy JSON)
      try {
        final data = json.decode(code);
        if (data is Map) {
          // Case A: Full Credentials (from Web Welcome screen)
          if (data.containsKey('email') && data.containsKey('password')) {
            if (!widget.allowLogin) {
              _showTopSnackBar("Login QR codes cannot be scanned here.", const Color(0xFFF59E0B));
              setState(() => _isProcessing = false);
              return;
            }

            _showTopSnackBar("QR Credentials Detected. Logging in...", const Color(0xFF3B82F6));
            
            final response = await supabase.auth.signInWithPassword(
              email: data['email'],
              password: data['password'],
            );

            if (mounted && response.session != null) {
              _navigateToDashboard(response.session!.user);
              return;
            }
          }
          // ... (keep Case B)
          
          // Case B: Profile Data (Record view only)
          if (data['type'] == 'DIGIVET_OWNER') {
            if (!widget.allowRecords) {
              _showTopSnackBar("Pet Record QR codes cannot be scanned here.", const Color(0xFFF59E0B));
              setState(() => _isProcessing = false);
              return;
            }
            
            if (data['pets'] != null && (data['pets'] as List).isNotEmpty) {
               _showTopSnackBar("Owner Record Detected", const Color(0xFF3B82F6));
               _showTopSnackBar("Please scan an individual Pet QR for full medical history.", const Color(0xFFF59E0B));
               Future.delayed(const Duration(seconds: 2), () {
                 if (mounted) setState(() => _isProcessing = false);
               });
               return;
            }
          }
        }
      } catch (_) {}

      // 3. Prefix Check for Records or Legacy/Auth
      if (code.startsWith("DIGIVET_PET_") || code.startsWith("DIGIVET_RECORD:")) {
        if (!widget.allowRecords) {
          _showTopSnackBar("Pet Record QR codes cannot be scanned here.", const Color(0xFFF59E0B));
          setState(() => _isProcessing = false);
          return;
        }
        final String petId = code.contains(":") ? code.split(":").last : code.replaceFirst("DIGIVET_PET_", "");
        _showTopSnackBar("Pet Record QR Detected", const Color(0xFF3B82F6));
        await _fetchAndShowPet(petId);
      } else if (code.startsWith("DIGIVET_AUTH:") || code.startsWith("DIGIVET_LOGIN:")) {
         _showTopSnackBar("This QR format is outdated. Please use the QR code from App Settings.", const Color(0xFFF59E0B));
         Future.delayed(const Duration(seconds: 2), () {
           if (mounted) setState(() => _isProcessing = false);
         });
      } else {
        _showTopSnackBar("Invalid Digivet QR Code", const Color(0xFFEF4444));
        // Add a delay before re-enabling scanning to prevent continuous "Invalid" alerts
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) setState(() => _isProcessing = false);
        });
      }
    } catch (e) {
      _showTopSnackBar("Error: ${e.toString()}", const Color(0xFFEF4444));
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _isProcessing = false);
      });
    }
  }

  Future<void> _handleTokenLogin(String token) async {
    try {
      final res = await http.post(
        Uri.parse('$backendUrl/api/auth/qr-login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'qr_token': token}),
      );

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final String email = data['email'];
        final String otpToken = data['token'];

        final authRes = await supabase.auth.verifyOTP(
          email: email,
          token: otpToken,
          type: OtpType.magiclink,
        );

        if (mounted && authRes.session != null) {
          _navigateToDashboard(authRes.session!.user);
        }
      } else {
        final err = json.decode(res.body)['error'] ?? "Login failed";
        _showTopSnackBar(err, const Color(0xFFEF4444));
        setState(() => _isProcessing = false);
      }
    } catch (e) {
      _showTopSnackBar("Connection error", const Color(0xFFEF4444));
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
    final screenSize = MediaQuery.of(context).size;
    // Precisely center the scan window in the physical screen
    final scanWindow = Rect.fromCenter(
      center: Offset(screenSize.width / 2, screenSize.height / 2),
      width: 260,
      height: 260,
    );

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "QR SCANNER",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _scannerController,
            onDetect: _onDetect,
            scanWindow: scanWindow,
          ),
          // Darkened background with cutout
          ColorFiltered(
            colorFilter: ColorFilter.mode(
              Colors.black.withOpacity(0.7),
              BlendMode.srcOut,
            ),
            child: Stack(
              children: [
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    backgroundBlendMode: BlendMode.dstOut,
                  ),
                ),
                Center(
                  child: Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Visual guide box
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Stack(
                children: [
                  // Corner accents
                  ..._buildCorners(),
                  // Animated scan line
                  const _ScannerLine(width: 260),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 60,
            left: 24,
            right: 24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _isProcessing ? "Verifying..." : "Point at a Digivet QR Code",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: _buildActionButton(
                        icon: Icons.image_rounded,
                        label: "Gallery",
                        onTap: _isProcessing ? null : _pickAndScanQR,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildActionButton(
                        icon: Icons.flashlight_on_rounded,
                        label: "Flash",
                        onTap: () => _scannerController.toggleTorch(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCorners() {
    const double cornerSize = 40;
    const double thickness = 6;
    const Color color = Colors.white;

    return [
      // Top Left
      Positioned(
        top: 0, left: 0,
        child: Container(
          width: cornerSize, height: thickness,
          decoration: const BoxDecoration(color: color, borderRadius: BorderRadius.horizontal(left: Radius.circular(3))),
        ),
      ),
      Positioned(
        top: 0, left: 0,
        child: Container(
          width: thickness, height: cornerSize,
          decoration: const BoxDecoration(color: color, borderRadius: BorderRadius.vertical(top: Radius.circular(3))),
        ),
      ),
      // Top Right
      Positioned(
        top: 0, right: 0,
        child: Container(
          width: cornerSize, height: thickness,
          decoration: const BoxDecoration(color: color, borderRadius: BorderRadius.horizontal(right: Radius.circular(3))),
        ),
      ),
      Positioned(
        top: 0, right: 0,
        child: Container(
          width: thickness, height: cornerSize,
          decoration: const BoxDecoration(color: color, borderRadius: BorderRadius.vertical(top: Radius.circular(3))),
        ),
      ),
      // Bottom Left
      Positioned(
        bottom: 0, left: 0,
        child: Container(
          width: cornerSize, height: thickness,
          decoration: const BoxDecoration(color: color, borderRadius: BorderRadius.horizontal(left: Radius.circular(3))),
        ),
      ),
      Positioned(
        bottom: 0, left: 0,
        child: Container(
          width: thickness, height: cornerSize,
          decoration: const BoxDecoration(color: color, borderRadius: BorderRadius.vertical(bottom: Radius.circular(3))),
        ),
      ),
      // Bottom Right
      Positioned(
        bottom: 0, right: 0,
        child: Container(
          width: cornerSize, height: thickness,
          decoration: const BoxDecoration(color: color, borderRadius: BorderRadius.horizontal(right: Radius.circular(3))),
        ),
      ),
      Positioned(
        bottom: 0, right: 0,
        child: Container(
          width: thickness, height: cornerSize,
          decoration: const BoxDecoration(color: color, borderRadius: BorderRadius.vertical(bottom: Radius.circular(3))),
        ),
      ),
    ];
  }

  Widget _buildActionButton({required IconData icon, required String label, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 28),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _ScannerLine extends StatefulWidget {
  final double width;
  const _ScannerLine({required this.width});

  @override
  State<_ScannerLine> createState() => _ScannerLineState();
}

class _ScannerLineState extends State<_ScannerLine> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Positioned(
          top: _controller.value * widget.width,
          left: 0,
          right: 0,
          child: Container(
            height: 2,
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(0.5),
                  blurRadius: 4,
                  spreadRadius: 2,
                ),
              ],
              gradient: const LinearGradient(
                colors: [Colors.transparent, Colors.red, Colors.transparent],
              ),
            ),
          ),
        );
      },
    );
  }
}
