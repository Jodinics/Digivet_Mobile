import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../widgets/menu.dart';
import 'vacc_history.dart';
import 'qr_screen.dart';
import 'settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final supabase = Supabase.instance.client;
  final String backendUrl = 'https://digivetonline-api.onrender.com';
  
  List<Map<String, dynamic>> _pets = [];
  Map<int, Map<String, dynamic>> _latestVaccines = {};
  String? _ownerName;
  bool _isLoading = true;
  int _currentPetPage = 0;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _fetchDashboardData() async {
    try {
      final session = supabase.auth.currentSession;
      if (session == null) return;

      final accessToken = session.accessToken;
      _ownerName = session.user.userMetadata?['full_name'];

      final petsResponse = await http.get(
        Uri.parse('$backendUrl/api/pets/mine'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      );

      if (petsResponse.statusCode == 200) {
        final List<dynamic> petsData = json.decode(petsResponse.body);
        _pets = List<Map<String, dynamic>>.from(petsData);
      }

      if (_pets.isNotEmpty) {
        final vaccResponse = await http.get(
          Uri.parse('$backendUrl/api/pets/vaccinations'),
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json',
          },
        );

        if (vaccResponse.statusCode == 200) {
          final List<dynamic> vaccData = json.decode(vaccResponse.body);
          for (var v in vaccData) {
            final petId = v['pet_id'] as int;
            _latestVaccines[petId] = {
              'vaccine_date': v['last_vaccine_date'],
              'vaccine_details': v['last_vaccine_details'],
            };
          }
        }
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching dashboard data: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      drawer: const AppDrawer(currentRoute: 'overview'),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1F2937)),
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
              icon: const Icon(Icons.notifications_none_rounded, color: Color(0xFF1F2937)),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF9E1B1B)))
          : RefreshIndicator(
              onRefresh: _fetchDashboardData,
              color: const Color(0xFF9E1B1B),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    _buildGreeting(),
                    const SizedBox(height: 32),
                    _buildSectionHeader("MY PETS", onSeeAll: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const VaccHistoryScreen()),
                      );
                    }),
                    const SizedBox(height: 16),
                    _buildPetSection(),
                    const SizedBox(height: 32),
                    _buildSectionHeader("QUICK ACTIONS"),
                    const SizedBox(height: 16),
                    _buildQuickActions(),
                    const SizedBox(height: 32),
                    _buildSectionHeader("RECENT ACTIVITY", onSeeAll: () {
                       Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const VaccHistoryScreen()),
                      );
                    }),
                    const SizedBox(height: 16),
                    _buildActivityList(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildGreeting() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Welcome back,",
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _ownerName ?? "Pet Owner",
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: Color(0xFF111827),
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, {VoidCallback? onSeeAll}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: Colors.grey.shade500,
            letterSpacing: 1.2,
          ),
        ),
        if (onSeeAll != null)
          GestureDetector(
            onTap: onSeeAll,
            child: const Text(
              "See all",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF9E1B1B),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPetSection() {
    return Column(
      children: [
        SizedBox(
          height: 220,
          child: PageView.builder(
            controller: _pageController,
            itemCount: _pets.length + 1,
            onPageChanged: (index) {
              setState(() {
                _currentPetPage = index;
              });
            },
            itemBuilder: (context, index) {
              if (index < _pets.length) {
                return _buildHeroPetCard(_pets[index]);
              } else {
                return _buildScheduledDriveCard();
              }
            },
          ),
        ),
        const SizedBox(height: 16),
        _buildPageIndicator(),
      ],
    );
  }

  Widget _buildPageIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_pets.length + 1, (index) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          height: 8,
          width: _currentPetPage == index ? 24 : 8,
          decoration: BoxDecoration(
            color: _currentPetPage == index ? const Color(0xFF9E1B1B) : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }

  Widget _buildScheduledDriveCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFF9E1B1B).withOpacity(0.1), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () async {
          final Uri url = Uri.parse('https://www.facebook.com/profile.php?id=100063921050657');
          try {
            await launchUrl(url, mode: LaunchMode.externalApplication);
          } catch (e) {
            debugPrint('Could not launch $url: $e');
            // Fallback to internal webview if external fails
            await launchUrl(url, mode: LaunchMode.platformDefault);
          }
        },
        borderRadius: BorderRadius.circular(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1877F2).withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.facebook_rounded,
                size: 40,
                color: Color(0xFF1877F2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "LCVO Updates",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                "Follow our Facebook page for real-time announcements",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroPetCard(Map<String, dynamic> pet) {
    final petType = (pet['pet_type'] ?? '').toString().toUpperCase();
    final imageAsset = petType.contains('CAT') ? 'assets/images/cat.png' : 'assets/images/dog.png';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF9E1B1B), Color(0xFF7B1E1E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9E1B1B).withOpacity(0.25),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Stack(
          children: [
            Positioned(
              right: -20,
              bottom: -20,
              child: Icon(
                Icons.pets,
                size: 180,
                color: Colors.white.withOpacity(0.08),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(28),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pet['pet_name'] ?? 'Pet',
                          style: const TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          "${pet['pet_color']} • ${petType}",
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withOpacity(0.85),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 28),
                        ElevatedButton(
                          onPressed: () {
                             Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => VaccHistoryScreen(initialPetId: pet['pet_id']),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF9E1B1B),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          ),
                          child: const Text(
                            "View Records",
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Image.asset(
                    imageAsset,
                    width: 120,
                    height: 120,
                    fit: BoxFit.contain,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildActionCard(
          icon: Icons.qr_code_scanner_rounded, 
          label: "Scanner", 
          color: const Color(0xFFFEF2F2), 
          iconColor: const Color(0xFF9E1B1B),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const QRScreen(allowLogin: false))),
        ),
        _buildActionCard(
          icon: Icons.history_edu_rounded, 
          label: "History", 
          color: const Color(0xFFFEF2F2), 
          iconColor: const Color(0xFF9E1B1B),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const VaccHistoryScreen())),
        ),
        _buildActionCard(
          icon: Icons.medical_services_rounded, 
          label: "Vets", 
          color: const Color(0xFFFEF2F2), 
          iconColor: const Color(0xFF9E1B1B),
          onTap: () {},
        ),
        _buildActionCard(
          icon: Icons.settings_rounded, 
          label: "Settings", 
          color: const Color(0xFFFEF2F2),
          iconColor: const Color(0xFF9E1B1B),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen())),
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required IconData icon, 
    required String label, 
    required Color color, 
    required Color iconColor,
    required VoidCallback onTap
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFFEE2E2), width: 1),
            ),
            child: Icon(icon, color: iconColor, size: 28),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF4B5563),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityList() {
    if (_pets.isEmpty) return const SizedBox.shrink();

    return Column(
      children: _pets.take(3).map((pet) {
        final latest = _latestVaccines[pet['pet_id']];
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => VaccHistoryScreen(initialPetId: pet['pet_id']),
                ),
              );
            },
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFEE2E2)),
                    ),
                    child: const Icon(Icons.vaccines_rounded, color: Color(0xFF9E1B1B), size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pet['pet_name'] ?? 'Pet',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          latest != null ? "Vaccinated on ${latest['vaccine_date']}" : "No records yet",
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, size: 24, color: Colors.grey.shade300),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

}
