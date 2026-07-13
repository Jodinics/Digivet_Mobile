import 'package:flutter/material.dart';

class PetRecordScreen extends StatelessWidget {
  final Map<String, dynamic> pet;

  const PetRecordScreen({super.key, required this.pet});

  @override
  Widget build(BuildContext context) {
    final records = pet['records'] as List<dynamic>? ?? [];
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
        title: const Text(
          "Pet Record",
          style: TextStyle(
            color: Color(0xFF1F2937),
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Unified Header Section
            _buildSectionHeader("OVERVIEW"),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: _cardDecoration(),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: brandRed.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.pets_rounded, color: brandRed, size: 36),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pet['pet_name']?.toString().toUpperCase() ?? "PET NAME",
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF111827),
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 16),
                            const SizedBox(width: 6),
                            Text(
                              "Verified Digital Record",
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Uniform Info Grid (Pet)
            _buildSectionHeader("PET DETAILS"),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: _cardDecoration(),
              child: Column(
                children: [
                  _buildUniformGrid([
                    _GridItem("ID", "#${pet['pet_id'] ?? 'N/A'}"),
                    _GridItem("Species", pet['pet_type'] ?? "N/A"),
                    _GridItem("Breed", pet['pet_breed'] ?? "N/A"),
                    _GridItem("Age", pet['pet_age']?.toString() ?? "N/A"),
                    _GridItem("Color", pet['pet_color'] ?? "N/A"),
                    _GridItem("Sex", pet['pet_sex'] ?? "N/A"),
                  ]),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Uniform Info Grid (Owner)
            _buildSectionHeader("OWNER INFORMATION"),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: _cardDecoration(),
              child: Column(
                children: [
                  _buildUniformGrid([
                    _GridItem("Name", pet['owner_name'] ?? "N/A"),
                    _GridItem("Contact", pet['contact_no'] ?? "N/A"),
                    _GridItem("Barangay", pet['barangay_name'] ?? "N/A"),
                    _GridItem("Status", "Registered Owner"),
                  ]),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Vaccination History List
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSectionHeader("VACCINATION LOG"),
                Text(
                  "${records.length} RECORDS",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: Colors.grey.shade400,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            if (records.isEmpty)
              _buildEmptyState()
            else
              ...records.map((record) => _buildVaccineListItem(record)).toList(),

            const SizedBox(height: 40),
            Center(
              child: Image.asset(
                'assets/images/logo (2).png', 
                height: 40, 
                opacity: const AlwaysStoppedAnimation(0.15)
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.03),
          blurRadius: 15,
          offset: const Offset(0, 4),
        ),
      ],
      border: Border.all(color: Colors.grey.shade100),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: Color(0xFF9E1B1B),
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildUniformGrid(List<_GridItem> items) {
    return Wrap(
      runSpacing: 24,
      spacing: 0,
      children: items.map((item) => SizedBox(
        width: 140, // Fixed width for uniformity in 2 columns
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.label.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade400,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              item.value,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Color(0xFF374151),
              ),
            ),
          ],
        ),
      )).toList(),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Icon(Icons.history_rounded, size: 48, color: Colors.grey.shade200),
          const SizedBox(height: 16),
          const Text(
            "No medical history found",
            style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildVaccineListItem(Map<String, dynamic> record) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.vaccines_rounded, color: Color(0xFF9E1B1B), size: 22),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record['vaccine_details'] ?? 'General Vaccine',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "Lot: ${record['manufacturer_no'] ?? 'N/A'}",
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                record['vaccine_date'] ?? 'N/A',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  "VERIFIED",
                  style: TextStyle(
                    color: Color(0xFF059669),
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GridItem {
  final String label;
  final String value;
  _GridItem(this.label, this.value);
}
