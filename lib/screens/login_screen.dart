import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'qr_screen.dart';
import 'dashboard_screen.dart';
import 'admin_dashboard_screen.dart';
import 'register_screen.dart';


class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final supabase = Supabase.instance.client;
  final String backendUrl = 'https://digivetonline-api.onrender.com';
  bool isQrLogin = false;
  bool _isLoading = false;
  String? _errorMessage;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final Color primaryRed = const Color(0xFF9E1B1B);

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

  Future<void> _pickAndScanQR() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image == null) return;

    setState(() => _isLoading = true);

    try {
      final MobileScannerController controller = MobileScannerController();
      final BarcodeCapture? capture = await controller.analyzeImage(image.path);

      if (capture != null && capture.barcodes.isNotEmpty) {
        final String? code = capture.barcodes.first.rawValue;
        if (code != null) {
          debugPrint("Scanned QR: $code");

          // 1. New V2 Secure Format
          if (code.startsWith("DIGIVET_V2:")) {
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

          // 2. Try Token Login (New Secure Method)
          if (code.startsWith("DIGIVET_TOKEN:")) {
            final String token = code.replaceFirst("DIGIVET_TOKEN:", "");
            _handleTokenLogin(token);
            return;
          }

          // 3. Try JSON Login (Web Welcome)
          try {
            final data = json.decode(code);
            if (data is Map && data.containsKey('email') && data.containsKey('password')) {
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
          } catch (_) {}

          // 4. Legacy Check
          if (code.startsWith("DIGIVET_AUTH:") || code.startsWith("DIGIVET_LOGIN:")) {
            throw Exception("This QR format is outdated. Please re-generate the QR code from your App Settings.");
          }

          if (code.startsWith("DIGIVET_PET_") || code.startsWith("DIGIVET_RECORD:")) {
            throw Exception("Pet Record QR codes cannot be scanned for login.");
          }

          throw Exception("Invalid Digivet Login QR");
        }
      } else {
        throw Exception("No QR code found in image");
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst("Exception: ", "");
          _isLoading = false;
        });
      }
    }
  }

  void _navigateToDashboard(User user) {
    if (!mounted) return;

    _showTopSnackBar("Welcome back!", const Color(0xFF10B981));

    final metadata = user.userMetadata;
    final role = metadata?['role']?.toString().toLowerCase();

    // Log for debugging
    debugPrint("Login Successful: ${user.email}, Role: $role");

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

  Future<void> _handleTokenLogin(String token) async {
    setState(() => _isLoading = true);
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

        // Verify with Supabase
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
      }
    } catch (e) {
      _showTopSnackBar("Connection error", const Color(0xFFEF4444));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleLogin() async {
    if (_emailController.text.trim().isEmpty || _passwordController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = "Please enter both email and password";
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (mounted && response.session != null) {
        _navigateToDashboard(response.session!.user);
      }
    } on AuthException catch (e) {
      setState(() {
        if (e.message.toLowerCase().contains('invalid login credentials')) {
          _errorMessage = "Incorrect email or password. Please try again.";
        } else {
          _errorMessage = e.message;
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = "Connection error. Please check your internet.";
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ---- Card container: logo, welcome text, form ----
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(28, 36, 28, 28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 30,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Image.asset(
                      'assets/images/logo (2).png',
                      height: 90,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "Welcome back",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1F2937),
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Sign in to access your pet's records",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildToggleButton(
                              title: "Password",
                              isActive: !isQrLogin,
                              onTap: () => setState(() {
                                isQrLogin = false;
                                _errorMessage = null;
                              }),
                            ),
                          ),
                          Expanded(
                            child: _buildToggleButton(
                              title: "QR Code",
                              isActive: isQrLogin,
                              onTap: () => setState(() {
                                isQrLogin = true;
                                _errorMessage = null;
                              }),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (_errorMessage != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFFEE2E2)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(color: Color(0xFF991B1B), fontSize: 14, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (!isQrLogin) ...[
                      _buildTextField(
                        controller: _emailController,
                        label: "Email Address",
                        icon: Icons.email_outlined,
                        hint: "name@example.com",
                      ),
                      const SizedBox(height: 20),
                      _buildTextField(
                        controller: _passwordController,
                        label: "Password",
                        icon: Icons.lock_outline_rounded,
                        hint: "••••••••",
                        isPassword: true,
                      ),
                      const SizedBox(height: 40),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryRed,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: _isLoading ? null : _handleLogin,
                          child: _isLoading
                              ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                          )
                              : const Text(
                            "SIGN IN",
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 1),
                          ),
                        ),
                      ),
                    ] else ...[
                      Column(
                        children: [
                          const Icon(Icons.qr_code_scanner_rounded, size: 80, color: Color(0xFFD1D5DB)),
                          const SizedBox(height: 20),
                          const Text(
                            "Scan Login QR",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1F2937)),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Position your personal QR code within the scanner or upload an image.",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey.shade500, height: 1.5),
                          ),
                          const SizedBox(height: 32),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryRed,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const QRScreen(allowRecords: false, allowLogin: true))),
                              icon: const Icon(Icons.qr_code_scanner_rounded),
                              label: const Text("USE SCANNER", style: TextStyle(fontWeight: FontWeight.w800)),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: primaryRed,
                                side: BorderSide(color: primaryRed, width: 2),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              onPressed: _pickAndScanQR,
                              icon: const Icon(Icons.image_rounded),
                              label: const Text("UPLOAD IMAGE", style: TextStyle(fontWeight: FontWeight.w800)),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 32),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const RegisterScreen()),
                        );
                      },
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(color: Color(0xFF6B7280), fontSize: 14),
                          children: [
                            const TextSpan(text: "Don't have an account? "),
                            TextSpan(
                              text: "Register here",
                              style: TextStyle(color: primaryRed, fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // ---- End card container ----
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToggleButton({required String title, required bool isActive, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isActive
              ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]
              : [],
        ),
        child: Center(
          child: Text(
            title,
            style: TextStyle(
              color: isActive ? primaryRed : const Color(0xFF6B7280),
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    bool isPassword = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF374151)),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: isPassword,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            prefixIcon: Icon(icon, color: Colors.grey.shade400, size: 20),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: primaryRed, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}