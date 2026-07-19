import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../widgets/menu.dart';
import '../widgets/skeleton_loader.dart';
import 'pet_record_screen.dart';

class AdminRecordsScreen extends StatefulWidget {
  const AdminRecordsScreen({super.key});

  @override
  State<AdminRecordsScreen> createState() => _AdminRecordsScreenState();
}

enum AdminFilter { all, recentOwners, recentPets, recentVaccines }

enum ViewType { owners, pets }

class _AdminRecordsScreenState extends State<AdminRecordsScreen> {
  final supabase = Supabase.instance.client;
  final String backendUrl = 'https://digivetonline-api.onrender.com';

  bool _isLoading = true;
  List<dynamic> _owners = [];
  List<dynamic> _pets = [];
  List<dynamic> _vaccines = [];
  List<dynamic> _filteredOwners = [];
  List<dynamic> _filteredPets = [];

  Map<int, List<dynamic>> _petsByOwner = {};
  Map<int, List<dynamic>> _vaccinesByPet = {};
  Map<int, Map<String, dynamic>> _ownerMap = {};
  Map<int, String> _barangayMap = {};

  AdminFilter _activeFilter = AdminFilter.all;
  ViewType _currentView = ViewType.owners;
  final TextEditingController _searchController = TextEditingController();

  static const brandRed = Color(0xFF9E1B1B);
  static const darkGrey = Color(0xFF111827);
  static const mediumGrey = Color(0xFF4B5563);
  static const lightBg = Color(0xFFF9FAFB);

  @override
  void initState() {
    super.initState();
    _fetchData();
    _searchController.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _applyFilters() {
    setState(() {
      final query = _searchController.text.toLowerCase();

      if (_currentView == ViewType.owners) {
        List<dynamic> baseList = List.from(_owners);

        // Apply Special Filters First
        if (_activeFilter == AdminFilter.recentOwners) {
          baseList.sort((a, b) => (b['owner_id'] as int).compareTo(a['owner_id'] as int));
        } else if (_activeFilter == AdminFilter.recentPets) {
          final recentPetOwnerIds = List.from(_pets)
            ..sort((a, b) => (b['pet_id'] as int).compareTo(a['pet_id'] as int));
          final topOwnerIds = recentPetOwnerIds.take(10).map((p) => p['owner_id']).toSet();
          baseList = _owners.where((o) => topOwnerIds.contains(o['owner_id'])).toList();
        } else if (_activeFilter == AdminFilter.recentVaccines) {
          final recentVaccines = List.from(_vaccines)
            ..sort((a, b) => (b['vaccine_id'] as int).compareTo(a['vaccine_id'] as int));
          final recentPetIds = recentVaccines.take(10).map((v) => v['pet_id']).toSet();
          final recentOwnerIds = _pets.where((p) => recentPetIds.contains(p['pet_id'])).map((p) => p['owner_id']).toSet();
          baseList = _owners.where((o) => recentOwnerIds.contains(o['owner_id'])).toList();
        }

        // Apply Search Query
        _filteredOwners = baseList.where((owner) {
          final name = owner['owner_name']?.toString().toLowerCase() ?? '';
          final email = owner['email']?.toString().toLowerCase() ?? '';
          final contact = (owner['contact_number'] ?? owner['contact_no'])?.toString().toLowerCase() ?? '';
          final brgyId = owner['barangay_id'];
          final brgyName = (_barangayMap[brgyId] ?? owner['barangay_name'] ?? '').toString().toLowerCase();

          final ownerId = owner['owner_id'];
          final hasMatchingPet = (_petsByOwner[ownerId] ?? []).any((pet) {
            final petName = pet['pet_name']?.toString().toLowerCase() ?? '';
            return petName.contains(query);
          });

          return name.contains(query) ||
              email.contains(query) ||
              contact.contains(query) ||
              brgyName.contains(query) ||
              hasMatchingPet;
        }).toList();
      } else {
        // Pets view filtering
        List<dynamic> baseList = List.from(_pets);

        if (_activeFilter == AdminFilter.recentPets) {
          baseList.sort((a, b) => (b['pet_id'] as int).compareTo(a['pet_id'] as int));
        }

        _filteredPets = baseList.where((pet) {
          final petName = pet['pet_name']?.toString().toLowerCase() ?? '';
          final petType = pet['pet_type']?.toString().toLowerCase() ?? '';

          final ownerId = pet['owner_id'];
          final owner = _ownerMap[ownerId];
          final ownerName = owner?['owner_name']?.toString().toLowerCase() ?? '';

          return petName.contains(query) ||
              petType.contains(query) ||
              ownerName.contains(query);
        }).toList();
      }
    });
  }

  Future<void> _fetchData() async {
    final session = supabase.auth.currentSession;
    if (session == null) return;

    setState(() => _isLoading = true);

    final headers = {
      'Authorization': 'Bearer ${session.accessToken}',
      'Content-Type': 'application/json',
    };

    try {
      final results = await Future.wait([
        http.get(Uri.parse('$backendUrl/api/vetdata/owner_table'), headers: headers),
        http.get(Uri.parse('$backendUrl/api/vetdata/pet_table'), headers: headers),
        http.get(Uri.parse('$backendUrl/api/vetdata/vaccine_table'), headers: headers),
        http.get(Uri.parse('$backendUrl/api/vetdata/barangay_table'), headers: headers),
      ]);

      if (results.every((r) => r.statusCode == 200)) {
        _owners = json.decode(results[0].body);
        _pets = json.decode(results[1].body);
        _vaccines = json.decode(results[2].body);
        final barangays = json.decode(results[3].body) as List;

        _barangayMap = {for (var b in barangays) b['barangay_id']: b['barangay_name']};

        _processData();
        _applyFilters();
      }
    } catch (e) {
      debugPrint("Fetch error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _processData() {
    _petsByOwner = {};
    _ownerMap = {};
    for (var owner in _owners) {
      _ownerMap[owner['owner_id']] = owner;
    }

    for (var pet in _pets) {
      final ownerId = pet['owner_id'];
      if (ownerId != null) {
        _petsByOwner.putIfAbsent(ownerId, () => []).add(pet);
      }
    }

    _vaccinesByPet = {};
    for (var vax in _vaccines) {
      final petId = vax['pet_id'];
      if (petId != null) {
        _vaccinesByPet.putIfAbsent(petId, () => []).add(vax);
      }
    }
  }

  // ---------------------------------------------------------------------
  // OWNER EDIT / DELETE  (direct Supabase calls)
  // ---------------------------------------------------------------------

  Map<String, String> _authHeaders() {
    final session = supabase.auth.currentSession;
    return {
      'Authorization': 'Bearer ${session?.accessToken ?? ''}',
      'Content-Type': 'application/json',
    };
  }

  // NOTE: writes go through the backend (which can use a service-role key
  // and its own auth check) instead of calling Supabase directly from the
  // app. Direct Supabase writes were being silently blocked by RLS since
  // there's no policy mapping auth.uid() to an admin in user_table.
  // These assume PUT/DELETE routes exist alongside the existing GET ones —
  // adjust the paths below if your backend names them differently.

  Future<bool> _updateOwner(int ownerId, Map<String, dynamic> data) async {
    try {

      final response = await http.patch(
      Uri.parse('$backendUrl/api/vetdata/owner_table/$ownerId'),
      headers: _authHeaders(),
      body: json.encode(data),
    );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint("Update owner error: ${response.statusCode} ${response.body}");
        _lastErrorMessage = _extractBackendError(response.body) ?? "Failed to update owner (${response.statusCode})";
        return false;
      }
      await _fetchData();
      return true;
    } catch (e) {
      debugPrint("Update owner error: $e");
      _lastErrorMessage = null;
      return false;
    }
  }

  Future<bool> _deleteOwner(int ownerId) async {
    try {
      final response = await http.delete(
        Uri.parse('$backendUrl/api/vetdata/owner_table/$ownerId'),
        headers: _authHeaders(),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint("Delete owner error: ${response.statusCode} ${response.body}");
        _lastErrorMessage = _extractBackendError(response.body) ?? "Failed to delete owner (${response.statusCode})";
        return false;
      }
      await _fetchData();
      return true;
    } catch (e) {
      debugPrint("Delete owner error: $e");
      _lastErrorMessage = null;
      return false;
    }
  }

  String? _extractBackendError(String body) {
    try {
      final decoded = json.decode(body);
      if (decoded is Map && decoded['message'] != null) return decoded['message'].toString();
      if (decoded is Map && decoded['error'] != null) return decoded['error'].toString();
    } catch (_) {}
    return null;
  }

  // ---------------------------------------------------------------------
  // PET EDIT / DELETE  (direct Supabase calls)
  // ---------------------------------------------------------------------

  Future<bool> _updatePet(int petId, Map<String, dynamic> data) async {
    try {
      final response = await http.patch(
        Uri.parse('$backendUrl/api/vetdata/pet_table/$petId'),
        headers: _authHeaders(),
        body: json.encode(data),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint("Update pet error: ${response.statusCode} ${response.body}");
        _lastErrorMessage = _extractBackendError(response.body) ?? "Failed to update pet (${response.statusCode})";
        return false;
      }
      await _fetchData();
      return true;
    } catch (e) {
      debugPrint("Update pet error: $e");
      _lastErrorMessage = null;
      return false;
    }
  }

  Future<bool> _deletePet(int petId) async {
    try {
      final response = await http.delete(
        Uri.parse('$backendUrl/api/vetdata/pet_table/$petId'),
        headers: _authHeaders(),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint("Delete pet error: ${response.statusCode} ${response.body}");
        _lastErrorMessage = _extractBackendError(response.body) ?? "Failed to delete pet (${response.statusCode})";
        return false;
      }
      await _fetchData();
      return true;
    } catch (e) {
      debugPrint("Delete pet error: $e");
      _lastErrorMessage = null;
      return false;
    }
  }

  // Holds the most recent Supabase error message so the snackbar can show
  // something more useful than a generic "failed" (e.g. RLS or FK errors).
  String? _lastErrorMessage;

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: isError ? Colors.red.shade600 : darkGrey,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showEditOwnerSheet(Map<String, dynamic> owner) {
    final nameController = TextEditingController(text: owner['owner_name']?.toString() ?? '');
    final emailController = TextEditingController(text: owner['email']?.toString() ?? '');
    final contactController = TextEditingController(
      text: (owner['contact_number'] ?? owner['contact_no'] ?? '').toString(),
    );
    int? selectedBarangayId = owner['barangay_id'];
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    "Edit Owner",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: darkGrey),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Update this owner's information",
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 24),
                  _buildEditTextField(nameController, "Owner Name", Icons.person_rounded),
                  const SizedBox(height: 14),
                  _buildEditTextField(emailController, "Email", Icons.email_rounded,
                      keyboardType: TextInputType.emailAddress),
                  const SizedBox(height: 14),
                  _buildEditTextField(contactController, "Contact Number", Icons.phone_rounded,
                      keyboardType: TextInputType.phone),
                  const SizedBox(height: 14),
                  _buildBarangayDropdown(
                    selectedBarangayId,
                        (val) => setModalState(() => selectedBarangayId = val),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: isSaving ? null : () => Navigator.pop(sheetContext),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: BorderSide(color: Colors.grey.shade300),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: Text("Cancel",
                              style: TextStyle(fontWeight: FontWeight.w800, color: Colors.grey.shade600)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: isSaving
                              ? null
                              : () async {
                            if (nameController.text.trim().isEmpty) {
                              _showSnack("Owner name cannot be empty", isError: true);
                              return;
                            }
                            setModalState(() => isSaving = true);
                            final success = await _updateOwner(owner['owner_id'], {
                              'owner_name': nameController.text.trim(),
                              'email': emailController.text.trim(),
                              'contact_number': contactController.text.trim(),
                              'barangay_id': selectedBarangayId,
                            });
                            if (!sheetContext.mounted) return;
                            if (success) {
                              Navigator.pop(sheetContext);
                              _showSnack("Owner updated successfully");
                            } else {
                              setModalState(() => isSaving = false);
                              _showSnack(
                                _lastErrorMessage ?? "Failed to update owner",
                                isError: true,
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: brandRed,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: isSaving
                              ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                              : const Text("Save Changes",
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showEditPetSheet(Map<String, dynamic> pet) {
    final nameController = TextEditingController(text: pet['pet_name']?.toString() ?? '');
    final typeController = TextEditingController(text: pet['pet_type']?.toString() ?? '');
    final ageController = TextEditingController(text: pet['pet_age']?.toString() ?? '');
    final colorController = TextEditingController(text: pet['pet_color']?.toString() ?? '');
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    "Edit Pet",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: darkGrey),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Update this pet's information",
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 24),
                  _buildEditTextField(nameController, "Pet Name", Icons.pets_rounded),
                  const SizedBox(height: 14),
                  _buildEditTextField(typeController, "Type (e.g. Dog, Cat)", Icons.category_rounded),
                  const SizedBox(height: 14),
                  _buildEditTextField(ageController, "Age (e.g. 2 Years)", Icons.cake_rounded),
                  const SizedBox(height: 14),
                  _buildEditTextField(colorController, "Color", Icons.palette_rounded),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: isSaving ? null : () => Navigator.pop(sheetContext),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: BorderSide(color: Colors.grey.shade300),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: Text("Cancel",
                              style: TextStyle(fontWeight: FontWeight.w800, color: Colors.grey.shade600)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: isSaving
                              ? null
                              : () async {
                            if (nameController.text.trim().isEmpty) {
                              _showSnack("Pet name cannot be empty", isError: true);
                              return;
                            }
                            setModalState(() => isSaving = true);
                            final success = await _updatePet(pet['pet_id'], {
                              'pet_name': nameController.text.trim(),
                              'pet_type': typeController.text.trim(),
                              'pet_age': ageController.text.trim(),
                              'pet_color': colorController.text.trim(),
                            });
                            if (!sheetContext.mounted) return;
                            if (success) {
                              Navigator.pop(sheetContext);
                              _showSnack("Pet updated successfully");
                            } else {
                              setModalState(() => isSaving = false);
                              _showSnack(
                                _lastErrorMessage ?? "Failed to update pet",
                                isError: true,
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: brandRed,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: isSaving
                              ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                              : const Text("Save Changes",
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEditTextField(TextEditingController controller, String label, IconData icon,
      {TextInputType? keyboardType}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(fontWeight: FontWeight.w600, color: darkGrey),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w600),
        prefixIcon: Icon(icon, color: mediumGrey, size: 20),
        filled: true,
        fillColor: lightBg,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      ),
    );
  }

  Widget _buildBarangayDropdown(int? selectedId, ValueChanged<int?> onChanged) {
    final validValue = _barangayMap.containsKey(selectedId) ? selectedId : null;
    return Container(
      decoration: BoxDecoration(color: lightBg, borderRadius: BorderRadius.circular(14)),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          isExpanded: true,
          value: validValue,
          hint: Text("Select Barangay",
              style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
          icon: const Icon(Icons.arrow_drop_down_rounded, color: mediumGrey),
          items: _barangayMap.entries
              .map((e) => DropdownMenuItem<int>(
            value: e.key,
            child: Text(e.value, style: const TextStyle(fontWeight: FontWeight.w600, color: darkGrey)),
          ))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  void _confirmDeleteOwner(Map<String, dynamic> owner) {
    final ownerId = owner['owner_id'];
    final petCount = (_petsByOwner[ownerId] ?? []).length;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_rounded, color: Colors.red.shade600),
            const SizedBox(width: 8),
            const Text("Delete Owner?", style: TextStyle(fontWeight: FontWeight.w900, color: darkGrey)),
          ],
        ),
        content: Text(
          petCount > 0
              ? "${owner['owner_name'] ?? 'This owner'} has $petCount pet(s) on record. Deleting this owner may also affect their pets' records. This action cannot be undone."
              : "Are you sure you want to delete ${owner['owner_name'] ?? 'this owner'}? This action cannot be undone.",
          style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w500),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text("Cancel", style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w700)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final success = await _deleteOwner(ownerId);
              _showSnack(
                success
                    ? "Owner deleted successfully"
                    : (_lastErrorMessage ?? "Failed to delete owner"),
                isError: !success,
              );
            },
            child: Text("Delete", style: TextStyle(color: Colors.red.shade600, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  void _confirmDeletePet(Map<String, dynamic> pet) {
    final petId = pet['pet_id'];
    final vaccineCount = (_vaccinesByPet[petId] ?? []).length;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_rounded, color: Colors.red.shade600),
            const SizedBox(width: 8),
            const Text("Delete Pet?", style: TextStyle(fontWeight: FontWeight.w900, color: darkGrey)),
          ],
        ),
        content: Text(
          vaccineCount > 0
              ? "${pet['pet_name'] ?? 'This pet'} has $vaccineCount vaccine record(s). Deleting this pet may also affect those records. This action cannot be undone."
              : "Are you sure you want to delete ${pet['pet_name'] ?? 'this pet'}? This action cannot be undone.",
          style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w500),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text("Cancel", style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w700)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final success = await _deletePet(petId);
              _showSnack(
                success
                    ? "Pet deleted successfully"
                    : (_lastErrorMessage ?? "Failed to delete pet"),
                isError: !success,
              );
            },
            child: Text("Delete", style: TextStyle(color: Colors.red.shade600, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  Widget _buildOwnerActionRow(Map<String, dynamic> owner) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        _buildActionChip(Icons.edit_rounded, "Edit", Colors.blue.shade700, () => _showEditOwnerSheet(owner)),
        const SizedBox(width: 8),
        _buildActionChip(Icons.delete_rounded, "Delete", Colors.red.shade600, () => _confirmDeleteOwner(owner)),
      ],
    );
  }

  Widget _buildPetActionRow(Map<String, dynamic> pet) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        _buildActionChip(Icons.edit_rounded, "Edit", Colors.blue.shade700, () => _showEditPetSheet(pet)),
        const SizedBox(width: 8),
        _buildActionChip(Icons.delete_rounded, "Delete", Colors.red.shade600, () => _confirmDeletePet(pet)),
      ],
    );
  }

  Widget _buildActionChip(IconData icon, String label, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color)),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              "Filter Records",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: darkGrey),
            ),
            const SizedBox(height: 8),
            Text(
              "Choose how you want to sort and filter your records list",
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 24),
            _buildFilterOption(AdminFilter.all, "All Records", Icons.all_inclusive_rounded),
            _buildFilterOption(AdminFilter.recentOwners, "Recently Added Owners", Icons.person_add_rounded),
            _buildFilterOption(AdminFilter.recentPets, "Recently Added Pets", Icons.pets_rounded),
            _buildFilterOption(AdminFilter.recentVaccines, "Recent Vaccinations", Icons.vaccines_rounded),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterOption(AdminFilter type, String label, IconData icon) {
    final bool isSelected = _activeFilter == type;
    return InkWell(
      onTap: () {
        setState(() => _activeFilter = type);
        _applyFilters();
        Navigator.pop(context);
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isSelected ? brandRed.withOpacity(0.05) : lightBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? brandRed.withOpacity(0.2) : Colors.grey.shade100),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected ? brandRed : Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: isSelected ? Colors.white : Colors.grey.shade400, size: 20),
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? brandRed : darkGrey,
              ),
            ),
            const Spacer(),
            if (isSelected) const Icon(Icons.check_circle_rounded, color: brandRed, size: 22),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightBg,
      drawer: const AppDrawer(currentRoute: 'records'),
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(
            child: Column(
              children: [
                _buildHeaderStats(),
                _buildViewSwitcher(),
                _buildSearchBar(),
                if (_activeFilter != AdminFilter.all) _buildActiveFilterChip(),
              ],
            ),
          ),
          SliverFillRemaining(
            child: _isLoading ? _buildLoadingList() : _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      floating: true,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.white,
      iconTheme: const IconThemeData(color: darkGrey),
      title: const Text(
        "Records",
        style: TextStyle(color: darkGrey, fontWeight: FontWeight.w900, fontSize: 24),
      ),
      centerTitle: false,
      actions: [
        IconButton(
          onPressed: _fetchData,
          icon: const Icon(Icons.refresh_rounded),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildHeaderStats() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      color: Colors.white,
      child: Row(
        children: [
          _buildMiniStatCard("Owners", _owners.length.toString(), Icons.people_outline_rounded, Colors.blue),
          const SizedBox(width: 12),
          _buildMiniStatCard("Pets", _pets.length.toString(), Icons.pets_rounded, brandRed),
          const SizedBox(width: 12),
          _buildMiniStatCard("Vaccines", _vaccines.length.toString(), Icons.vaccines_rounded, Colors.teal),
        ],
      ),
    );
  }

  Widget _buildMiniStatCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: darkGrey),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: mediumGrey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewSwitcher() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: lightBg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            _buildSwitchItem(ViewType.owners, "Owners", Icons.people_rounded),
            _buildSwitchItem(ViewType.pets, "Pets", Icons.pets_rounded),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchItem(ViewType type, String label, IconData icon) {
    final bool isSelected = _currentView == type;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _currentView = type;
            _applyFilters();
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: isSelected ? brandRed : Colors.grey),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? darkGrey : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveFilterChip() {
    String label = "";
    switch (_activeFilter) {
      case AdminFilter.recentOwners: label = "Recent Owners"; break;
      case AdminFilter.recentPets: label = "Recent Pets"; break;
      case AdminFilter.recentVaccines: label = "Recent Vaccinations"; break;
      default: label = "";
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: brandRed.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.filter_list_rounded, size: 14, color: brandRed),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: const TextStyle(color: brandRed, fontSize: 12, fontWeight: FontWeight.w800),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () {
                    setState(() => _activeFilter = AdminFilter.all);
                    _applyFilters();
                  },
                  child: const Icon(Icons.close_rounded, size: 14, color: brandRed),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: lightBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: _currentView == ViewType.owners ? "Search owners, contact, barangay..." : "Search pet name, species...",
                  hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14, fontWeight: FontWeight.w500),
                  prefixIcon: const Icon(Icons.search_rounded, color: Colors.grey, size: 22),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _showFilterSheet,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _activeFilter != AdminFilter.all ? brandRed : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _activeFilter != AdminFilter.all ? brandRed : Colors.grey.shade200),
              ),
              child: Icon(
                Icons.tune_rounded,
                color: _activeFilter != AdminFilter.all ? Colors.white : mediumGrey,
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return _currentView == ViewType.owners ? _buildOwnersList() : _buildPetsList();
  }

  Widget _buildOwnersList() {
    if (_filteredOwners.isEmpty) return _buildEmptyState();

    return RefreshIndicator(
      onRefresh: _fetchData,
      color: brandRed,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _filteredOwners.length,
        itemBuilder: (context, index) {
          final owner = _filteredOwners[index] as Map<String, dynamic>;
          return _buildOwnerModernCard(owner);
        },
      ),
    );
  }

  Widget _buildPetsList() {
    if (_filteredPets.isEmpty) return _buildEmptyState();

    return RefreshIndicator(
      onRefresh: _fetchData,
      color: brandRed,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _filteredPets.length,
        itemBuilder: (context, index) {
          final pet = _filteredPets[index] as Map<String, dynamic>;
          final owner = _ownerMap[pet['owner_id']];
          return _buildPetStandaloneCard(pet, owner);
        },
      ),
    );
  }

  Widget _buildOwnerModernCard(Map<String, dynamic> owner) {
    final ownerId = owner['owner_id'];
    final ownerPets = _petsByOwner[ownerId] ?? [];
    final name = owner['owner_name'] ?? 'Unknown Owner';
    final initials = name.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          iconColor: brandRed,
          collapsedIconColor: Colors.grey.shade400,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [brandRed, brandRed.withOpacity(0.8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                initials,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
              ),
            ),
          ),
          title: Text(
            name,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: darkGrey),
          ),
          subtitle: Row(
            children: [
              Icon(Icons.pets_rounded, size: 12, color: Colors.grey.shade400),
              const SizedBox(width: 4),
              Text(
                "${ownerPets.length} pets",
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 12),
              Icon(Icons.location_on_rounded, size: 12, color: Colors.grey.shade400),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  _barangayMap[owner['barangay_id']] ?? owner['barangay_name'] ?? 'No Address',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 32),
                  _buildOwnerActionRow(owner),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (owner['contact_number'] != null || owner['contact_no'] != null)
                        _buildContactAction(Icons.phone_rounded, "Call", () {
                          final phone = owner['contact_number'] ?? owner['contact_no'];
                          launchUrl(Uri.parse('tel:$phone'));
                        }),
                      if (owner['email'] != null && owner['email'].toString().isNotEmpty)
                        _buildContactAction(Icons.email_rounded, "Email", () {
                          launchUrl(Uri.parse('mailto:${owner['email']}'));
                        }),
                      if (owner['contact_number'] != null || owner['contact_no'] != null)
                        _buildContactAction(Icons.message_rounded, "SMS", () {
                          final phone = owner['contact_number'] ?? owner['contact_no'];
                          launchUrl(Uri.parse('sms:$phone'));
                        }),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "REGISTERED PETS",
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.grey.shade400, letterSpacing: 1.2),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: lightBg, borderRadius: BorderRadius.circular(6)),
                        child: Text("${ownerPets.length}", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: mediumGrey)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (ownerPets.isEmpty)
                    _buildEmptyInnerState("No pets registered under this owner")
                  else
                    ...ownerPets.map((pet) => _buildPetListTile(pet, owner)).toList(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactAction(IconData icon, String label, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: lightBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              Icon(icon, size: 18, color: brandRed),
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: darkGrey)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPetListTile(Map<String, dynamic> pet, Map<String, dynamic> owner) {
    final petId = pet['pet_id'];
    final petVaccines = _vaccinesByPet[petId] ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: lightBg,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => _navigateToPetDetail(pet, owner, petVaccines),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.pets_rounded, size: 20, color: brandRed),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pet['pet_name'] ?? 'Pet',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: darkGrey),
                      ),
                      Text(
                        "${pet['pet_type'] ?? 'N/A'}",
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                _buildActionChip(Icons.edit_rounded, "", Colors.blue.shade700, () => _showEditPetSheet(pet)),
                const SizedBox(width: 6),
                _buildActionChip(Icons.delete_rounded, "", Colors.red.shade600, () => _confirmDeletePet(pet)),
                const SizedBox(width: 6),
                const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPetStandaloneCard(Map<String, dynamic> pet, Map<String, dynamic>? owner) {
    final petId = pet['pet_id'];
    final petVaccines = _vaccinesByPet[petId] ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToPetDetail(pet, owner ?? {}, petVaccines),
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: brandRed.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(Icons.pets_rounded, color: brandRed, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pet['pet_name'] ?? 'Pet',
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: darkGrey),
                          ),
                          Text(
                            "${pet['pet_type'] ?? 'N/A'}",
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: lightBg, borderRadius: BorderRadius.circular(8)),
                      child: Text("#$petId", style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: mediumGrey)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildPetActionRow(pet),
                const Divider(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildPetStat("AGE", "${pet['pet_age'] ?? '?'} Yrs"),
                    _buildPetStat("COLOR", pet['pet_color'] ?? 'N/A'),
                    _buildPetStat("VACCINES", petVaccines.length.toString()),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: lightBg, borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      const Icon(Icons.person_outline_rounded, size: 14, color: mediumGrey),
                      const SizedBox(width: 8),
                      Text(
                        "Owner: ",
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        owner?['owner_name'] ?? 'N/A',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: darkGrey),
                      ),
                      const Spacer(),
                      const Icon(Icons.arrow_forward_rounded, size: 14, color: brandRed),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPetStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.grey.shade400, letterSpacing: 0.5)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: darkGrey)),
      ],
    );
  }

  void _navigateToPetDetail(Map<String, dynamic> pet, Map<String, dynamic> owner, List<dynamic> vaccines) {
    final fullPetData = Map<String, dynamic>.from(pet);
    fullPetData['owner_name'] = owner['owner_name'];
    fullPetData['contact_no'] = owner['contact_number'] ?? owner['contact_no'];
    fullPetData['barangay_name'] = _barangayMap[owner['barangay_id']] ?? owner['barangay_name'];
    fullPetData['records'] = vaccines;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PetRecordScreen(pet: fullPetData),
      ),
    );
  }

  Widget _buildLoadingList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: SkeletonLoader(
            width: double.infinity,
            height: _currentView == ViewType.owners ? 100 : 180,
            borderRadius: 24
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: Colors.grey.shade100)),
            child: Icon(Icons.search_off_rounded, size: 48, color: Colors.grey.shade300),
          ),
          const SizedBox(height: 20),
          const Text("No records found", style: TextStyle(color: darkGrey, fontWeight: FontWeight.w900, fontSize: 18)),
          const SizedBox(height: 8),
          Text("Try adjusting your search or filters", style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildEmptyInnerState(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Text(message, style: TextStyle(color: Colors.grey.shade400, fontSize: 12, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
    );
  }
}