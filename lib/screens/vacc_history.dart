import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import '../widgets/menu.dart';

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

        // Filter vaccines for only my pets and group them
        final myPetIds = myPets.map((p) => p['pet_id']).toSet();
        
        // Structure data to match the previous grouped format
        final List<Map<String, dynamic>> groupedRecords = [];
        for (var pet in myPets) {
          final petVaccines = allVaccines
              .where((v) => v['pet_id'] == pet['pet_id'])
              .toList()
            ..sort((a, b) => b['vaccine_date'].compareTo(a['vaccine_date']));
          
          groupedRecords.add({
            'pet_id': pet['pet_id'],
            'pet_name': pet['pet_name'],
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
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.pets, color: Color(0xFF9E1B1B)),
          ),
          title: Text(
            pet['pet_name'] ?? 'Unknown Pet',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1F2937),
            ),
          ),
          subtitle: Text(
            "${records.length} Vaccination Records",
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            if (records.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text("No doses recorded for this pet.", style: TextStyle(color: Colors.grey)),
              )
            else
              ...records.map((record) => _buildVaccineCard(pet['pet_name'], record)).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildVaccineCard(String petName, Map<String, dynamic> record) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: InkWell(
        onTap: () => _showVaccineDetails(petName, record),
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
              const Icon(Icons.info_outline_rounded, color: Colors.grey, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _showVaccineDetails(String petName, Map<String, dynamic> record) {
    // Lookup Vet Name
    final vetName = _vetMap[record['vet_id']] ?? "Unknown Veterinarian";
    
    // Lookup Barangay Name via Session
    String location = "Office Visit";
    if (record['is_office_visit'] != true) {
      final brgyId = _sessionToBarangayMap[record['session_id']];
      location = _barangayMap[brgyId] ?? "Barangay Drive";
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.vaccines_rounded, color: Color(0xFF9E1B1B), size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record['vaccine_details'] ?? 'General Vaccine',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF111827),
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          "Administered",
                          style: TextStyle(
                            color: Color(0xFF059669),
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            const Divider(height: 1),
            const SizedBox(height: 24),
            _buildDetailRow("Pet Name", petName, Icons.pets_rounded),
            _buildDetailRow("Date Given", record['vaccine_date'] ?? 'N/A', Icons.calendar_today_rounded),
            _buildDetailRow("Administered By", vetName, Icons.medical_services_rounded),
            _buildDetailRow(
              "Location", 
              location, 
              Icons.location_on_rounded
            ),
            _buildDetailRow(
              "Manufacturer Lot #", 
              record['manufacturer_no']?.toString().isNotEmpty == true ? record['manufacturer_no'] : "Not specified", 
              Icons.tag_rounded
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF3F4F6),
                  foregroundColor: const Color(0xFF1F2937),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text("Close", style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
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
