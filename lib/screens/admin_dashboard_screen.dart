import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import '../widgets/menu.dart';
import '../widgets/skeleton_loader.dart';
import '../services/notification_service.dart';
import 'admin_debug_screen.dart';
import 'admin_records_screen.dart';
import 'approval_requests.dart';
import 'qr_screen.dart';
import 'notifications_screen.dart';

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
  int _unreadCount = 0; // <-- 1. Added state variable for notification badge
  List<dynamic> _recentRequests = [];
  Map<int, String> _petNames = {};

  @override
  void initState() {
    super.initState();
    _fetchAdminStats();
  }

  Future<void> _fetchAdminStats() async {
    try {
      final session = supabase.auth.currentSession;
      final uid = supabase.auth.currentUser?.id;
      if (session == null || uid == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final headers = {
        'Authorization': 'Bearer ${session.accessToken}',
        'Content-Type': 'application/json',
      };

      // Fetch dashboard overview data & unread notifications count in parallel
      final results = await Future.wait([
        http.get(Uri.parse('$backendUrl/api/pets/all-requests'), headers: headers).timeout(const Duration(seconds: 10)),
        http.get(Uri.parse('$backendUrl/api/vetdata/pet_table'), headers: headers).timeout(const Duration(seconds: 10)),
        http.get(Uri.parse('$backendUrl/api/vetdata/vaccine_table'), headers: headers).timeout(const Duration(seconds: 10)),
        NotificationService.getUnreadCount(),
      ]);

      if (results[0] is http.Response &&
          (results[0] as http.Response).statusCode == 200) {

        final dynamic reqData = json.decode((results[0] as http.Response).body);
        final dynamic petData = json.decode((results[1] as http.Response).body);
        final dynamic vaccData = json.decode((results[2] as http.Response).body);
        final int unreadCount = results[3] as int;

        if (reqData is List && petData is List && vaccData is List) {
          setState(() {
            _petNames = {for (var p in petData) p['pet_id']: p['pet_name']};
            _pendingCount = reqData.where((r) => r['status'] == 'pending').length;
            _totalPets = petData.length;
            _totalVaccinations = vaccData.length;
            _recentRequests = reqData.take(3).toList();
            _unreadCount = unreadCount;
          });
        }
      } else {
        debugPrint("Admin API Error: Status codes matched failure.");
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
      backgroundColor: const Color(0xFFF9FAFB),
      drawer: const AppDrawer(currentRoute: 'overview'),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1F2937)),
        title: Image.asset('assets/images/logo (2).png', height: 45),
        centerTitle: true,
        actions: [
          // <-- 3. Notification Bell Icon with dynamic badge in AppBar
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_rounded, color: Color(0xFF1F2937)),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const NotificationsScreen()),
                  ).then((_) {
                    // Refresh stats & notification badge when returning to dashboard
                    _fetchAdminStats();
                  });
                },
              ),
              if (_unreadCount > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(color: brandRed, shape: BoxShape.circle),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
        ],
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
              const Text("Admin portal", style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500)),
              const Text("Dashboard", style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFF111827))),
              const SizedBox(height: 24),
              _buildSearchBar(),
              const SizedBox(height: 32),

              // Stats Grid
              Row(
                children: [
                  _buildStatCard("Pending", _pendingCount.toString(), Icons.how_to_reg_rounded, Colors.orange, onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const ApprovalRequestsScreen()));
                  }),
                  const SizedBox(width: 12),
                  _buildStatCard("Pets", _totalPets.toString(), Icons.pets_rounded, brandRed, onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminRecordsScreen()));
                  }),
                  const SizedBox(width: 12),
                  _buildStatCard("Vaccinations", _totalVaccinations.toString(), Icons.vaccines_rounded, Colors.blue, onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminRecordsScreen()));
                  }),
                ],
              ),

              const SizedBox(height: 32),
              _buildSectionHeader("Quick actions"),
              const SizedBox(height: 16),
              _buildQuickActions(),

              const SizedBox(height: 32),
              _buildSectionHeader("Recent requests", onSeeAll: () {
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
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          const SkeletonLoader(width: 100, height: 14),
          const SizedBox(height: 8),
          const SkeletonLoader(width: 200, height: 32),
          const SizedBox(height: 24),
          const SkeletonLoader(width: double.infinity, height: 50, borderRadius: 16),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(child: const SkeletonLoader(width: double.infinity, height: 100, borderRadius: 24)),
              const SizedBox(width: 12),
              Expanded(child: const SkeletonLoader(width: double.infinity, height: 100, borderRadius: 24)),
              const SizedBox(width: 12),
              Expanded(child: const SkeletonLoader(width: double.infinity, height: 100, borderRadius: 24)),
            ],
          ),
          const SizedBox(height: 32),
          const SkeletonLoader(width: 120, height: 14),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(4, (index) => const SkeletonLoader(width: 64, height: 64, borderRadius: 20)),
          ),
          const SizedBox(height: 32),
          const SkeletonLoader(width: 140, height: 14),
          const SizedBox(height: 16),
          ...List.generate(3, (index) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: const SkeletonLoader(width: double.infinity, height: 80, borderRadius: 20),
          )),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        decoration: InputDecoration(
          hintText: "Search patients, owners, requests",
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 15),
          prefixIcon: Icon(Icons.search_rounded, color: Colors.grey.shade400, size: 22),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color, {VoidCallback? onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.grey.shade100),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 12),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF111827),
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, {VoidCallback? onSeeAll}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: Colors.grey.shade600,
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

  Widget _buildQuickActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildActionItem(Icons.qr_code_scanner_rounded, "Scanner", () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const QRScreen(allowLogin: false)));
        }),
        _buildActionItem(Icons.how_to_reg_rounded, "Approvals", () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const ApprovalRequestsScreen()));
        }, badgeCount: _pendingCount),
        _buildActionItem(Icons.shield_rounded, "Vets", () {}),
        _buildActionItem(Icons.storage_rounded, "Records", () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminRecordsScreen()));
        }),
      ],
    );
  }

  Widget _buildActionItem(IconData icon, String label, VoidCallback onTap, {int badgeCount = 0}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade100),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Icon(icon, color: const Color(0xFF9E1B1B), size: 26),
              ),
              if (badgeCount > 0)
                Positioned(
                  top: -5,
                  right: -5,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Color(0xFF9E1B1B),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      badgeCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1F2937),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestItem(Map<String, dynamic> req) {
    final petName = _petNames[req['pet_id']] ?? "Unknown";
    final initials = petName.length >= 2 ? petName.substring(0, 2).toUpperCase() : petName.toUpperCase();
    final status = req['status']?.toString().toLowerCase() ?? 'pending';

    Color statusColor;
    Color statusBg;
    if (status == 'approved') {
      statusColor = const Color(0xFF10B981);
      statusBg = const Color(0xFFECFDF5);
    } else if (status == 'rejected') {
      statusColor = const Color(0xFFEF4444);
      statusBg = const Color(0xFFFEF2F2);
    } else {
      statusColor = const Color(0xFFF59E0B);
      statusBg = const Color(0xFFFFF7ED);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF9E1B1B).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                initials,
                style: const TextStyle(
                  color: Color(0xFF9E1B1B),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "$petName · vaccination record",
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "Owner: ${req['owner_id']}",
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              status[0].toUpperCase() + status.substring(1),
              style: TextStyle(
                color: statusColor,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
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