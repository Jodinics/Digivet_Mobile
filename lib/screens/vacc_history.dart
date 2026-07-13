import 'dart:convert';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gal/gal.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:qr_flutter/qr_flutter.dart';
import '../widgets/menu.dart';
import 'pet_record_screen.dart';

class VaccHistoryScreen extends StatefulWidget {
  final int? initialPetId;
  const VaccHistoryScreen({super.key, this.initialPetId});

  @override
  State<VaccHistoryScreen> createState() => _VaccHistoryScreenState();
}

class _VaccHistoryScreenState extends State<VaccHistoryScreen> {
  final supabase = Supabase.instance.client;
  final String backendUrl = 'https://digivetonline-api.onrender.com';
  
  List<dynamic> _vaccineRecords = [];
  Map<int, String> _vetMap = {};
  Map<int, String> _barangayMap = {};
  Map<int, int> _sessionToBarangayMap = {};
  
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAllData();
  }

  Future<void> _fetchAllData() async {
    try {
      final session = supabase.auth.currentSession;
      if (session == null) return;
      final accessToken = session.accessToken;
      final headers = {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      };

      // 1. Fetch Reference Data (Vets, Barangays, Sessions) using existing /api/vetdata routes
      final results = await Future.wait([
        http.get(Uri.parse('$backendUrl/api/vetdata/vet_table'), headers: headers),
        http.get(Uri.parse('$backendUrl/api/vetdata/barangay_table'), headers: headers),
        http.get(Uri.parse('$backendUrl/api/vetdata/drive_session_table'), headers: headers),
        // 2. Fetch the actual vaccine records (using the vetdata route for full columns)
        http.get(Uri.parse('$backendUrl/api/vetdata/vaccine_table'), headers: headers),
        // 3. Fetch user's pets to filter the vaccines
        http.get(Uri.parse('$backendUrl/api/pets/mine'), headers: headers),
      ]);

      if (results.every((r) => r.statusCode == 200)) {
        final vets = json.decode(results[0].body) as List;
        final barangays = json.decode(results[1].body) as List;
        final sessions = json.decode(results[2].body) as List;
        final allVaccines = json.decode(results[3].body) as List;
        final myPets = json.decode(results[4].body) as List;

        // Build lookup maps
        _vetMap = {for (var v in vets) v['vet_id']: v['vet_name']};
        _barangayMap = {for (var b in barangays) b['barangay_id']: b['barangay_name']};
        _sessionToBarangayMap = {for (var s in sessions) s['session_id']: s['barangay_id']};

        // Fetch additional owner data to populate the record screen
        final ownerResponse = await http.get(Uri.parse('$backendUrl/api/vetdata/owner_table'), headers: headers);
        List<dynamic> allOwners = [];
        if (ownerResponse.statusCode == 200) {
          allOwners = json.decode(ownerResponse.body) as List;
        }

        // Structure data to match the previous grouped format
        final List<Map<String, dynamic>> groupedRecords = [];
        for (var pet in myPets) {
          final petVaccines = allVaccines
              .where((v) => v['pet_id'] == pet['pet_id'])
              .toList()
            ..sort((a, b) => b['vaccine_date'].compareTo(a['vaccine_date']));
          
          final owner = allOwners.firstWhere(
            (o) => o['owner_id'] == pet['owner_id'],
            orElse: () => null,
          );

          final barangayName = owner != null 
              ? _barangayMap[owner['barangay_id']] ?? 'N/A' 
              : 'N/A';

          groupedRecords.add({
            ...pet, // include all pet details (breed, color, etc)
            'owner_name': owner?['owner_name'] ?? 'Not Recorded',
            'contact_no': owner?['contact_no'] ?? 'Not Recorded',
            'barangay_name': barangayName,
            'records': petVaccines,
          });
        }

        setState(() {
          _vaccineRecords = groupedRecords;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error fetching data: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      drawer: const AppDrawer(currentRoute: 'history'),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF2D2D2D)),
        title: Image.asset(
          'assets/images/logo (2).png',
          height: 45,
        ),
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: () {},
              icon: const Icon(Icons.notifications_none_rounded, color: Color(0xFF2D2D2D)),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF9E1B1B)))
          : RefreshIndicator(
              onRefresh: _fetchAllData,
              color: const Color(0xFF9E1B1B),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    const Text(
                      "Vaccination",
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFF9CA3AF),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Text(
                      "History",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1F2937),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 32),
                    if (_vaccineRecords.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text("No vaccination records found.", textAlign: TextAlign.center),
                      )
                    else
                      ..._vaccineRecords.map((pet) => _buildPetExpansionTile(pet)).toList(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildPetExpansionTile(Map<String, dynamic> pet) {
    final records = pet['records'] as List<dynamic>;
    final bool initiallyExpanded = widget.initialPetId != null && pet['pet_id'] == widget.initialPetId;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          leading: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PetRecordScreen(pet: pet),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.pets, color: Color(0xFF9E1B1B)),
            ),
          ),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PetRecordScreen(pet: pet),
                      ),
                    );
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pet['pet_name'] ?? 'Unknown Pet',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      Text(
                        "${records.length} Vaccination Records",
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                onPressed: () => _showPetQRCode(pet),
                icon: const Icon(Icons.qr_code_2_rounded, color: Color(0xFF9E1B1B)),
                tooltip: "Show Pet QR Code",
              ),
            ],
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            if (records.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text("No doses recorded for this pet.", style: TextStyle(color: Colors.grey)),
              )
            else
              ...records.map((record) => _buildVaccineCard(pet, record)).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildVaccineCard(Map<String, dynamic> pet, Map<String, dynamic> record) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PetRecordScreen(pet: pet),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.vaccines_rounded, color: Color(0xFF9E1B1B), size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record['vaccine_details'] ?? 'General Vaccine',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Date: ${record['vaccine_date']}",
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  final GlobalKey _qrKey = GlobalKey();

  Future<void> _downloadQR(String petName) async {
    try {
      final RenderRepaintBoundary boundary = _qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final Uint8List pngBytes = byteData!.buffer.asUint8List();

      final directory = await getTemporaryDirectory();
      final String path = '${directory.path}/PET_QR_${petName.replaceAll(' ', '_')}.png';
      final File imgFile = File(path);
      await imgFile.writeAsBytes(pngBytes);

      await Gal.putImage(path);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("QR Code saved to Gallery!")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to save QR Code: $e")),
        );
      }
    }
  }

  void _showPetQRCode(Map<String, dynamic> pet) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF1F2937)),
                ),
              ),
            ),
            const Text(
              "PET RECORD QR",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: Color(0xFF111827),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Present this to the Vet during check-up",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 40),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFEE2E2)),
              ),
              child: const Text(
                "PET RECORD",
                style: TextStyle(
                  color: Color(0xFF9E1B1B),
                  fontWeight: FontWeight.w900,
                  fontSize: 10,
                  letterSpacing: 1,
                ),
              ),
            ),
            const SizedBox(height: 16),
            RepaintBoundary(
              key: _qrKey,
              child: GestureDetector(
                onTap: () => _showFullscreenQR(pet),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                    border: Border.all(color: Colors.grey.shade100),
                  ),
                  child: QrImageView(
                    data: "DIGIVET_RECORD:${pet['pet_id']}",
                    version: QrVersions.auto,
                    size: 200.0,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: Color(0xFF9E1B1B),
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Color(0xFF9E1B1B),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "Tap to enlarge",
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade400,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF9E1B1B),
                  side: const BorderSide(color: Color(0xFF9E1B1B), width: 2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () => _downloadQR(pet['pet_name'] ?? "Pet"),
                icon: const Icon(Icons.download_rounded),
                label: const Text("SAVE TO GALLERY", style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              pet['pet_name'] ?? "Pet",
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 20), 
          ],
        ),
      ),
    );
  }

  void _showFullscreenQR(Map<String, dynamic> pet) {
    showDialog(
      context: context,
      builder: (context) => Dialog.fullscreen(
        backgroundColor: Colors.white,
        child: Column(
          children: [
            AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.close_rounded, color: Color(0xFF1F2937), size: 30),
                onPressed: () => Navigator.pop(context),
              ),
              title: const Text(
                "Pet Record QR",
                style: TextStyle(
                  color: Color(0xFF111827),
                  fontWeight: FontWeight.w900,
                ),
              ),
              centerTitle: true,
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.all(32),
              margin: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(40),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
                border: Border.all(color: Colors.grey.shade100),
              ),
              child: QrImageView(
                data: "DIGIVET_RECORD:${pet['pet_id']}",
                version: QrVersions.auto,
                size: MediaQuery.of(context).size.width * 0.7,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Color(0xFF9E1B1B),
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Color(0xFF9E1B1B),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              pet['pet_name'] ?? "Pet",
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                "Official Digivet Record",
                style: TextStyle(
                  color: Color(0xFF9E1B1B),
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ),
            const Spacer(flex: 2),
          ],
        ),
      ),
    );
  }

  void _showVaccineDetails(String petName, Map<String, dynamic> record) {
    // This method is now unused, as we navigate to PetRecordScreen
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade400),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade500,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF374151),
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
