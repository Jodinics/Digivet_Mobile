import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/menu.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final supabase = Supabase.instance.client;
  final Color primaryRed = const Color(0xFF9E1B1B);

  bool _isSaving = false;

  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _contactController = TextEditingController();

  String _displayName = "";
  String _displayEmail = "";

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  void _loadProfile() {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final metadata = user.userMetadata;
    final fullName = metadata?['full_name']?.toString() ?? "";
    final phone = metadata?['phone']?.toString() ?? "";
    final email = user.email ?? "";

    setState(() {
      _fullNameController.text = fullName;
      _emailController.text = email;
      _contactController.text = phone;
      _displayName = fullName.isNotEmpty ? fullName : "No name set";
      _displayEmail = email;
    });
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

  Future<void> _handleSaveChanges() async {
    final fullName = _fullNameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _contactController.text.trim();

    if (fullName.isEmpty || email.isEmpty) {
      _showTopSnackBar("Full name and email cannot be empty", const Color(0xFFEF4444));
      return;
    }

    setState(() => _isSaving = true);

    try {
      final currentEmail = supabase.auth.currentUser?.email;

      // Update metadata (name, phone), and email if changed
      final attributes = UserAttributes(
        data: {
          'full_name': fullName,
          'phone': phone,
        },
        email: email != currentEmail ? email : null,
      );

      final response = await supabase.auth.updateUser(attributes);

      if (mounted && response.user != null) {
        setState(() {
          _displayName = fullName;
          _displayEmail = email;
        });

        if (email != currentEmail) {
          _showTopSnackBar("Profile updated. Check your new email to confirm the change.", const Color(0xFF10B981));
        } else {
          _showTopSnackBar("Profile updated successfully", const Color(0xFF10B981));
        }
      }
    } on AuthException catch (e) {
      _showTopSnackBar(e.message, const Color(0xFFEF4444));
    } catch (e) {
      _showTopSnackBar("Something went wrong. Please try again.", const Color(0xFFEF4444));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      drawer: const AppDrawer(currentRoute: 'profile'),

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
        title: const Text(
          "Profile",
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            Center(
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  color: const Color(0xFFDDE3F5),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.person_rounded,
                  size: 100,
                  color: primaryRed,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Name + email
            Center(
              child: Column(
                children: [
                  Text(
                    _displayName.isNotEmpty ? _displayName : "Loading...",
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _displayEmail,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Editable fields
            _buildTextField(
              controller: _fullNameController,
              label: "Full Name",
            ),
            const SizedBox(height: 20),
            _buildTextField(
              controller: _emailController,
              label: "Email",
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 20),
            _buildTextField(
              controller: _contactController,
              label: "Contact Number",
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 32),

            // Save button
            Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryRed,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _isSaving ? null : _handleSaveChanges,
                  child: _isSaving
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                  )
                      : const Text(
                    "Save Changes",
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF6B7280)),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFE5E7EB),
            contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: primaryRed, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}