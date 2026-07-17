import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../widgets/skeleton_loader.dart';
import 'vacc_history.dart';

class PetCareScreen extends StatefulWidget {
  const PetCareScreen({super.key});

  @override
  State<PetCareScreen> createState() => _PetCareScreenState();
}

class _PetCareScreenState extends State<PetCareScreen> {
  final supabase = Supabase.instance.client;
  final String backendUrl = 'https://digivetonline-api.onrender.com';
  static const Color brandRed = Color(0xFF9E1B1B);

  // Assumed interval between routine vaccinations, used to compute
  // each pet's next due date for the reminder list below.
  static const int vaccineIntervalDays = 365;

  bool _isLoading = true;
  List<Map<String, dynamic>> _pets = [];
  Map<int, Map<String, dynamic>> _latestVaccines = {};

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final session = supabase.auth.currentSession;
      if (session == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final accessToken = session.accessToken;

      final results = await Future.wait([
        http.get(
          Uri.parse('$backendUrl/api/pets/mine'),
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json',
          },
        ),
        http.get(
          Uri.parse('$backendUrl/api/pets/vaccinations'),
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json',
          },
        ),
      ]);

      if (results[0].statusCode == 200) {
        final List<dynamic> petsData = json.decode(results[0].body);
        _pets = List<Map<String, dynamic>>.from(petsData);
      }

      if (results[1].statusCode == 200) {
        final List<dynamic> vaccData = json.decode(results[1].body);
        final Map<int, Map<String, dynamic>> newVaccines = {};
        for (var v in vaccData) {
          final petId = v['pet_id'] as int;
          newVaccines[petId] = {
            'vaccine_date': v['last_vaccine_date'],
            'vaccine_details': v['last_vaccine_details'],
          };
        }
        _latestVaccines = newVaccines;
      }
    } catch (e) {
      debugPrint('Pet Care fetch error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Computes the vaccination status for a single pet based on its
  // last recorded vaccine date and the assumed yearly interval.
  ({String status, Color color, String message, int? daysUntil}) _statusFor(dynamic petId) {
    final latest = _latestVaccines[petId];
    final dateStr = latest?['vaccine_date'];
    if (dateStr == null) {
      return (
      status: 'No Record',
      color: Colors.grey,
      message: 'No vaccination record yet',
      daysUntil: null,
      );
    }

    final lastDate = DateTime.tryParse(dateStr);
    if (lastDate == null) {
      return (
      status: 'No Record',
      color: Colors.grey,
      message: 'No vaccination record yet',
      daysUntil: null,
      );
    }

    final dueDate = lastDate.add(const Duration(days: vaccineIntervalDays));
    final daysUntil = dueDate.difference(DateTime.now()).inDays;

    if (daysUntil < 0) {
      return (
      status: 'Overdue',
      color: const Color(0xFF9E1B1B),
      message: 'Overdue by ${-daysUntil} day(s)',
      daysUntil: daysUntil,
      );
    } else if (daysUntil <= 30) {
      return (
      status: 'Due Soon',
      color: const Color(0xFFC2410C),
      message: daysUntil == 0 ? 'Due today' : 'Due in $daysUntil day(s)',
      daysUntil: daysUntil,
      );
    } else {
      return (
      status: 'Up to Date',
      color: const Color(0xFF15803D),
      message: 'Next due in $daysUntil days',
      daysUntil: daysUntil,
      );
    }
  }

  // Sorts pets so overdue pets appear first, then due soon, then up to
  // date, then pets with no record at all.
  List<Map<String, dynamic>> get _sortedPets {
    final list = List<Map<String, dynamic>>.from(_pets);
    list.sort((a, b) {
      final sa = _statusFor(a['pet_id']);
      final sb = _statusFor(b['pet_id']);
      final da = sa.daysUntil ?? 999999;
      final db = sb.daysUntil ?? 999999;
      return da.compareTo(db);
    });
    return list;
  }

  Future<void> _contactClinic() async {
    final Uri url = Uri.parse('https://www.facebook.com/profile.php?id=100063921050657');
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Could not launch $url: $e');
      await launchUrl(url, mode: LaunchMode.platformDefault);
    }
  }

  @override
  Widget build(BuildContext context) {
    final needAttention = _pets
        .where((p) => (_statusFor(p['pet_id']).daysUntil ?? 999999) <= 30)
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
        title: const Text(
          "Pet Care",
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? _buildSkeleton()
          : RefreshIndicator(
        onRefresh: _fetchData,
        color: brandRed,
        child: _pets.isEmpty
            ? ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 120),
            Center(
              child: Text(
                "No pets found yet.",
                style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        )
            : ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          children: [
            _buildSummaryHeader(needAttention.length),
            const SizedBox(height: 24),
            const Text(
              "VACCINATION REMINDERS",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Color(0xFF6B7280),
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            ..._sortedPets.map(_buildPetReminderCard),
            const SizedBox(height: 32),
            _buildCareTips(),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryHeader(int attentionCount) {
    final bool needsAttention = attentionCount > 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: needsAttention
              ? [const Color(0xFF9E1B1B), const Color(0xFF7B1E1E)]
              : [const Color(0xFF15803D), const Color(0xFF166534)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              needsAttention ? Icons.vaccines_rounded : Icons.check_circle_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  needsAttention
                      ? "${attentionCount == 1 ? '1 pet needs' : '$attentionCount pets need'} attention"
                      : "All pets are up to date",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  needsAttention
                      ? "Review the reminders below and book a visit"
                      : "No vaccinations due in the next 30 days",
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.85),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPetReminderCard(Map<String, dynamic> pet) {
    final s = _statusFor(pet['pet_id']);
    final petType = (pet['pet_type'] ?? '').toString().toUpperCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: s.color.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.pets_rounded, color: s.color, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pet['pet_name'] ?? 'Pet',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      Text(
                        petType,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: s.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    s.status,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: s.color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              s.message,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => VaccHistoryScreen(initialPetId: pet['pet_id']),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFE5E7EB)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: const Text(
                      "View Records",
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1F2937)),
                    ),
                  ),
                ),
                if ((s.daysUntil ?? 999999) <= 30) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _contactClinic,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: brandRed,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: const Text(
                        "Book Visit",
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCareTips() {
    final tips = [
      (icon: Icons.restaurant_rounded, title: 'Nutrition', text: 'Feed age-appropriate portions on a consistent schedule.'),
      (icon: Icons.directions_walk_rounded, title: 'Exercise', text: 'Daily walks or playtime keep pets healthy and calm.'),
      (icon: Icons.content_cut_rounded, title: 'Grooming', text: 'Regular brushing and bathing prevents skin issues.'),
      (icon: Icons.medical_services_rounded, title: 'Checkups', text: 'Annual vet visits catch problems early.'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "CARE TIPS",
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: Color(0xFF6B7280),
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        ...tips.map((tip) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: brandRed.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(tip.icon, color: brandRed, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tip.title,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF1F2937)),
                    ),
                    Text(
                      tip.text,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ),
        )),
      ],
    );
  }

  Widget _buildSkeleton() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SkeletonLoader(width: double.infinity, height: 84, borderRadius: 24),
        const SizedBox(height: 24),
        const SkeletonLoader(width: 160, height: 14),
        const SizedBox(height: 12),
        ...List.generate(
          3,
              (i) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: SkeletonLoader(width: double.infinity, height: 140, borderRadius: 20),
          ),
        ),
      ],
    );
  }
}