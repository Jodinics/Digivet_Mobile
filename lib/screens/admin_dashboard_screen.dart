import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import '../widgets/menu.dart';
import '../widgets/skeleton_loader.dart';
import 'approval_requests.dart';
import 'qr_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final supabase = Supabase.instance.client;
  final String backendUrl = 'https://digivetonline-api.onrender.com';
  
  bool _isLoading = true;
  int _pendingCount = 0;
  int _totalPets = 0;
  int _totalVaccinations = 0;
  List<dynamic> _recentRequests = [];

  @override
  void initState() {
    super.initState();
    _fetchAdminStats();
  }

  Future<void> _fetchAdminStats() async {
    try {
      final session = supabase.auth.currentSession;
      if (session == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      
      final headers = {
        'Authorization': 'Bearer ${session.accessToken}',
        'Content-Type': 'application/json',
      };

      // Fetch overview data in parallel
      final results = await Future.wait([
        http.get(Uri.parse('$backendUrl/api/vetdata/pet_edit_requests'), headers: headers).timeout(const Duration(seconds: 10)),
        http.get(Uri.parse('$backendUrl/api/vetdata/pet_table'), headers: headers).timeout(const Duration(seconds: 10)),
        http.get(Uri.parse('$backendUrl/api/vetdata/vaccine_table'), headers: headers).timeout(const Duration(seconds: 10)),
      ]);

      if (results.every((r) => r.statusCode == 200)) {
        final dynamic reqData = json.decode(results[0].body);
        final dynamic petData = json.decode(results[1].body);
        final dynamic vaccData = json.decode(results[2].body);

        if (reqData is List && petData is List && vaccData is List) {
          setState(() {
            _pendingCount = reqData.where((r) => r['status'] == 'pending').length;
            _totalPets = petData.length;
            _totalVaccinations = vaccData.length;
            _recentRequests = reqData
                .where((r) => r['status'] == 'pending')
                .take(3)
                .toList();
          });
        }
      } else {
        debugPrint("Admin API Error: ${results.map((r) => r.statusCode).toList()}");
      }
    } catch (e) {
      debugPrint("Admin Stats Exception: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const brandRed = Color(0xFF9E1B1B);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      drawer: const AppDrawer(currentRoute: 'overview'),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1F2937)),
        title: Image.asset('assets/images/logo (2).png', height: 45),
        centerTitle: true,
      ),
      body: _isLoading 
        ? _buildAdminSkeleton()
        : RefreshIndicator(
            onRefresh: _fetchAdminStats,
            color: brandRed,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  const Text("Admin Portal", style: TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.w500)),
                  const Text("DASHBOARD", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF111827))),
                  const SizedBox(height: 32),
                  
                  // Stats Grid
                  Row(
                    children: [
                      _buildStatCard("PENDING", _pendingCount.toString(), Icons.pending_actions_rounded, Colors.orange),
                      const SizedBox(width: 16),
                      _buildStatCard("PETS", _totalPets.toString(), Icons.pets_rounded, brandRed),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildStatCard("VACCINATIONS", _totalVaccinations.toString(), Icons.vaccines_rounded, Colors.blue, fullWidth: true),
                  
                  const SizedBox(height: 32),
                  _buildSectionHeader("QUICK ACTIONS"),
                  const SizedBox(height: 16),
                  _buildQuickActions(),
                  
                  const SizedBox(height: 32),
                  _buildSectionHeader("RECENT REQUESTS", onSeeAll: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const ApprovalRequestsScreen()));
                  }),
                  const SizedBox(height: 16),
                  if (_recentRequests.isEmpty)
                    _buildEmptyRequests()
                  else
                    ..._recentRequests.map((req) => _buildRequestItem(req)).toList(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildAdminSkeleton() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          const SkeletonLoader(width: 100, height: 16),
          const SizedBox(height: 8),
          const SkeletonLoader(width: 180, height: 32),
          const SizedBox(height: 32),
          Row(
            children: [
              const Expanded(child: SkeletonLoader(width: double.infinity, height: 140, borderRadius: 28)),
              const SizedBox(width: 16),
              const Expanded(child: SkeletonLoader(width: double.infinity, height: 140, borderRadius: 28)),
            ],
          ),
          const SizedBox(height: 16),
          const SkeletonLoader(width: double.infinity, height: 140, borderRadius: 28),
          const SizedBox(height: 32),
          const SkeletonLoader(width: 120, height: 12),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(4, (i) => const SkeletonLoader(width: 68, height: 68, borderRadius: 24)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color, {bool fullWidth = false}) {
    Widget card = Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 16),
          Text(value, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFF111827))),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.grey.shade500, letterSpacing: 1)),
        ],
      ),
    );

    if (fullWidth) return card;
    return Expanded(child: card);
  }

  Widget _buildSectionHeader(String title, {VoidCallback? onSeeAll}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.grey.shade500, letterSpacing: 1.2)),
        if (onSeeAll != null)
          GestureDetector(
            onTap: onSeeAll,
            child: const Text("See all", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF9E1B1B))),
          ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildActionItem(Icons.qr_code_scanner_rounded, "Scanner", () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const QRScreen(allowLogin: false)));
        }),
        _buildActionItem(Icons.how_to_reg_rounded, "Approvals", () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const ApprovalRequestsScreen()));
        }),
        _buildActionItem(Icons.add_moderator_rounded, "Vets", () {}),
        _buildActionItem(Icons.analytics_rounded, "Reports", () {}),
      ],
    );
  }

  Widget _buildActionItem(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 68, height: 68,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.grey.shade200)),
            child: Icon(icon, color: const Color(0xFF9E1B1B), size: 28),
          ),
          const SizedBox(height: 10),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF4B5563))),
        ],
      ),
    );
  }

  Widget _buildRequestItem(Map<String, dynamic> req) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.edit_note_rounded, color: Colors.orange),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Edit Request #${req['request_id']}", style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1F2937))),
                Text("Pet ID: ${req['pet_id']}", style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: Colors.grey),
        ],
      ),
    );
  }

  Widget _buildEmptyRequests() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
      child: const Text("All caught up! No pending requests.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
    );
  }
}
