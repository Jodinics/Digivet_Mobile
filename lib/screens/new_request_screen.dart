import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;

class NewRequestScreen extends StatefulWidget {
  const NewRequestScreen({super.key});

  @override
  State<NewRequestScreen> createState() => _NewRequestScreenState();
}

class _NewRequestScreenState extends State<NewRequestScreen> {
  final supabase = Supabase.instance.client;
  final String backendUrl = 'https://digivetonline-api.onrender.com';
  
  List<dynamic> _pets = [];
  Map<String, dynamic>? _selectedPet;
  bool _isLoading = true;
  bool _isSubmitting = false;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _typeController = TextEditingController();
  final _colorController = TextEditingController();
  final _ageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchPets();
  }

  Future<void> _fetchPets() async {
    try {
      final session = supabase.auth.currentSession;
      if (session == null) return;

      final res = await http.get(
        Uri.parse('$backendUrl/api/pets/mine'),
        headers: {'Authorization': 'Bearer ${session.accessToken}'},
      );

      if (res.statusCode == 200) {
        setState(() {
          _pets = json.decode(res.body);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error: $e");
      setState(() => _isLoading = false);
    }
  }

  void _onPetSelected(Map<String, dynamic> pet) {
    setState(() {
      _selectedPet = pet;
      _nameController.text = pet['pet_name'] ?? '';
      _typeController.text = pet['pet_type'] ?? '';
      _colorController.text = pet['pet_color'] ?? '';
      _ageController.text = pet['pet_age']?.toString() ?? '';
    });
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate() || _selectedPet == null) return;

    setState(() => _isSubmitting = true);

    try {
      final session = supabase.auth.currentSession;
      final res = await http.post(
        Uri.parse('$backendUrl/api/pets/edit-request'),
        headers: {
          'Authorization': 'Bearer ${session!.accessToken}',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'pet_id': _selectedPet!['pet_id'],
          'pet_name': _nameController.text.trim(),
          'pet_type': _typeController.text.trim(),
          'pet_color': _colorController.text.trim(),
          'pet_age': int.tryParse(_ageController.text.trim()) ?? 0,
        }),
      );

      if (res.statusCode == 200) {
        if (mounted) {
          _showTopSnackBar("Request submitted successfully!", const Color(0xFF10B981));
          Navigator.pop(context);
        }
      } else {
        final error = json.decode(res.body)['error'] ?? "Failed to submit request";
        _showTopSnackBar(error, const Color(0xFFEF4444));
      }
    } catch (e) {
      _showTopSnackBar("Connection error. Please try again.", const Color(0xFFEF4444));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showTopSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        dismissDirection: DismissDirection.up,
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.height - 100,
          left: 24,
          right: 24,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const brandRed = Color(0xFF9E1B1B);

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1F2937), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Edit Pet Details", style: TextStyle(color: Color(0xFF1F2937), fontWeight: FontWeight.w800, fontSize: 18)),
        centerTitle: true,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: brandRed))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("SELECT PET", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: brandRed, letterSpacing: 1.5)),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<Map<String, dynamic>>(
                        value: _selectedPet,
                        hint: const Text("Choose a pet to edit"),
                        isExpanded: true,
                        items: _pets.map((pet) {
                          return DropdownMenuItem<Map<String, dynamic>>(
                            value: pet,
                            child: Text(pet['pet_name'], style: const TextStyle(fontWeight: FontWeight.w600)),
                          );
                        }).toList(),
                        onChanged: (val) => val != null ? _onPetSelected(val) : null,
                      ),
                    ),
                  ),
                  if (_selectedPet != null) ...[
                    const SizedBox(height: 32),
                    const Text("PROPOSED CHANGES", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: brandRed, letterSpacing: 1.5)),
                    const SizedBox(height: 16),
                    _buildTextField("Pet Name", _nameController),
                    const SizedBox(height: 16),
                    _buildTextField("Species", _typeController, hint: "Dog, Cat, etc."),
                    const SizedBox(height: 16),
                    _buildTextField("Color", _colorController),
                    const SizedBox(height: 16),
                    _buildTextField("Age", _ageController, isNumber: true),
                    const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: brandRed,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        onPressed: _isSubmitting ? null : _submitRequest,
                        child: _isSubmitting 
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text("SUBMIT FOR APPROVAL", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Center(
                      child: Text(
                        "Changes will only be applied after Admin approval.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {bool isNumber = false, String? hint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF4B5563))),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          validator: (val) => (val == null || val.isEmpty) ? "Required" : null,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF9E1B1B), width: 2)),
          ),
        ),
      ],
    );
  }
}
