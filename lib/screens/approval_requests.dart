import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import '../widgets/menu.dart';
import '../widgets/skeleton_loader.dart';
import 'new_request_screen.dart';

class ApprovalRequestsScreen extends StatefulWidget {
  const ApprovalRequestsScreen({super.key});

  @override
  State<ApprovalRequestsScreen> createState() => _ApprovalRequestsScreenState();
}

class _ApprovalRequestsScreenState extends State<ApprovalRequestsScreen> {
  final supabase = Supabase.instance.client;
  final String backendUrl = 'https://digivetonline-api.onrender.com';
  List<dynamic> _requests = [];
  Map<int, String> _petNames = {};
  bool _isLoading = true;
  bool _isAdmin = false;
  String _selectedFilter = 'all'; // 'all', 'pending', 'approved', 'rejected'
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _checkRoleAndFetch();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _checkRoleAndFetch() async {
    final session = supabase.auth.currentSession;
    if (session != null) {
      final role = session.user.userMetadata?['role']?.toString().toLowerCase();
      _isAdmin = role == 'admin' || role == 'vet' || role == 'veterinarian';
    }
    await _fetchRequests();
  }

  Future<void> _fetchRequests() async {
    try {
      final session = supabase.auth.currentSession;
      if (session == null) return;
      final headers = {
        'Authorization': 'Bearer ${session.accessToken}',
        'Content-Type': 'application/json',
      };

      // 1. Fetch Pets to get names
      final petsUrl = _isAdmin ? '$backendUrl/api/vetdata/pet_table' : '$backendUrl/api/pets/mine';
      final petsRes = await http.get(Uri.parse(petsUrl), headers: headers);
      if (petsRes.statusCode == 200) {
        final List pets = json.decode(petsRes.body);
        _petNames = {for (var p in pets) p['pet_id']: p['pet_name']};
      }

      // 2. Fetch Edit Requests using specific role-based endpoints
      final String requestsUrl = _isAdmin 
          ? '$backendUrl/api/pets/all-requests' 
          : '$backendUrl/api/pets/edit-requests';
          
      final reqRes = await http.get(Uri.parse(requestsUrl), headers: headers);
      
      if (reqRes.statusCode == 200) {
        final List allReqs = json.decode(reqRes.body);
        setState(() {
          _requests = allReqs..sort((a, b) => b['created_at'].compareTo(a['created_at']));
        });
      }

      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint("Error fetching requests: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleReview(dynamic requestId, String action) async {
    final TextEditingController noteController = TextEditingController();
    
    // Show confirmation dialog with note field
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text("${action[0].toUpperCase()}${action.substring(1)} Request"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Are you sure you want to $action this pet information update?"),
            const SizedBox(height: 16),
            TextField(
              controller: noteController,
              decoration: InputDecoration(
                hintText: "Add a note (optional)",
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: action == 'approved' ? const Color(0xFF10B981) : const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            child: Text("Confirm ${action[0].toUpperCase()}${action.substring(1)}"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      final session = supabase.auth.currentSession;
      final res = await http.post(
        Uri.parse('$backendUrl/api/pets/review-request'),
        headers: {
          'Authorization': 'Bearer ${session!.accessToken}',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'request_id': requestId, // Use the ID exactly as it comes from the DB
          'action': action,
          'reviewer_note': noteController.text.trim(),
        }),
      );

      if (res.statusCode == 200) {
        _showTopSnackBar("Request ${action} successfully!", const Color(0xFF10B981));
        _fetchRequests();
      } else {
        throw Exception("Failed to process review");
      }
    } catch (e) {
      _showTopSnackBar("Error: $e", const Color(0xFFEF4444));
      setState(() => _isLoading = false);
    }
  }

  void _showTopSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(bottom: MediaQuery.of(context).size.height - 160, left: 24, right: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      drawer: const AppDrawer(currentRoute: 'approvals'),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF2D2D2D)),
        title: Image.asset(
          'assets/images/logo (2).png',
          height: 45,
        ),
        centerTitle: true,
      ),
      body: _isLoading 
        ? _buildSkeleton()
        : RefreshIndicator(
            onRefresh: _fetchRequests,
            color: const Color(0xFF9E1B1B),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  Text(_isAdmin ? "Moderation" : "Manage", style: const TextStyle(fontSize: 16, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500)),
                  Text(_isAdmin ? "Admin Approvals" : "Approval Requests", style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF1F2937), letterSpacing: -0.5)),
                  const SizedBox(height: 24),
                  if (_isAdmin) ...[
                    _buildSearchBar(),
                    const SizedBox(height: 16),
                  ],
                  _buildFilterButton(),
                  const SizedBox(height: 24),
                  if (_getFilteredRequests().isEmpty)
                    _buildEmptyState()
                  else
                    ..._getFilteredRequests().map((req) => _buildRequestCard(req)).toList(),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
      floatingActionButton: _isAdmin ? null : FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const NewRequestScreen()),
          ).then((_) => _fetchRequests());
        },
        backgroundColor: const Color(0xFF9E1B1B),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        elevation: 4,
        child: const Icon(Icons.add_rounded, size: 32),
      ),
    );
  }

  List<dynamic> _getFilteredRequests() {
    List<dynamic> filtered = _requests;
    
    if (_selectedFilter != 'all') {
      filtered = filtered.where((req) => req['status']?.toString().toLowerCase() == _selectedFilter).toList();
    }

    if (_isAdmin && _searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((req) {
        final petName = (req['pet_name'] ?? '').toString().toLowerCase();
        final petType = (req['pet_type'] ?? '').toString().toLowerCase();
        final ownerId = (req['owner_id'] ?? '').toString().toLowerCase();
        final petNameFromMap = (_petNames[req['pet_id']] ?? '').toLowerCase();

        return petName.contains(query) || 
               petType.contains(query) || 
               ownerId.contains(query) ||
               petNameFromMap.contains(query);
      }).toList();
    }
    
    return filtered;
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _searchQuery = value),
        decoration: InputDecoration(
          hintText: "Search by Name, Type or Owner ID",
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF9E1B1B), size: 20),
          suffixIcon: _searchQuery.isNotEmpty 
            ? IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
              )
            : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }

  Widget _buildFilterButton() {
    return Row(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade100),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: PopupMenuButton<String>(
            initialValue: _selectedFilter,
            onSelected: (String value) {
              setState(() => _selectedFilter = value);
            },
            offset: const Offset(0, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            itemBuilder: (context) => [
              _buildPopupItem("All Requests", 'all', Icons.format_list_bulleted_rounded),
              _buildPopupItem("Pending", 'pending', Icons.access_time_filled_rounded),
              _buildPopupItem("Approved", 'approved', Icons.check_circle_rounded),
              _buildPopupItem("Rejected", 'rejected', Icons.cancel_rounded),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.tune_rounded, size: 18, color: Color(0xFF9E1B1B)),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text("FILTER BY", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1)),
                      Text(
                        _selectedFilter.toUpperCase(),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: Colors.grey),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  PopupMenuItem<String> _buildPopupItem(String label, String value, IconData icon) {
    final bool isSelected = _selectedFilter == value;
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF9E1B1B).withOpacity(0.1) : const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: isSelected ? const Color(0xFF9E1B1B) : Colors.grey.shade600),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected ? const Color(0xFF9E1B1B) : const Color(0xFF1F2937),
              fontSize: 14,
            ),
          ),
          if (isSelected) ...[
            const Spacer(),
            const Icon(Icons.check_rounded, size: 16, color: Color(0xFF9E1B1B)),
          ],
        ],
      ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> req) {
    final status = req['status']?.toString().toLowerCase();
    Color statusColor;
    IconData statusIcon;
    String statusLabel;

    switch (status) {
      case 'approved':
        statusColor = const Color(0xFF10B981);
        statusIcon = Icons.check_circle_rounded;
        statusLabel = "APPROVED";
        break;
      case 'rejected':
        statusColor = const Color(0xFFEF4444);
        statusIcon = Icons.cancel_rounded;
        statusLabel = "REJECTED";
        break;
      default:
        statusColor = const Color(0xFFF59E0B);
        statusIcon = Icons.access_time_filled_rounded;
        statusLabel = "PENDING";
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: Icon(statusIcon, color: statusColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _petNames[req['pet_id']] ?? "Unknown Pet",
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1F2937)),
                    ),
                    if (_isAdmin)
                      Text("Owner ID: ${req['owner_id']}", style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Text(statusLabel, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          _buildInfoRow("Proposed Name", req['pet_name'] ?? "-"),
          _buildInfoRow("Proposed Type", req['pet_type'] ?? "-"),
          _buildInfoRow("Proposed Color", req['pet_color'] ?? "-"),
          _buildInfoRow("Proposed Age", req['pet_age']?.toString() ?? "-"),
          _buildInfoRow("Request Date", req['created_at']?.toString().split('T')[0] ?? "-"),
          
          if (status == 'pending' && _isAdmin) ...[
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _handleReview(req['request_id'], 'rejected'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFEF4444),
                      side: const BorderSide(color: Color(0xFFEF4444)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text("REJECT", style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _handleReview(req['request_id'], 'approved'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text("APPROVE", style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ],

          if (status != 'pending' && req['reviewer_note'] != null && req['reviewer_note'].toString().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: status == 'approved' ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: status == 'approved' ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isAdmin ? "YOUR NOTE" : "ADMIN NOTE",
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: status == 'approved' ? const Color(0xFF059669) : const Color(0xFF991B1B),
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    req['reviewer_note'],
                    style: TextStyle(
                      fontSize: 13,
                      color: status == 'approved' ? const Color(0xFF059669) : const Color(0xFF991B1B),
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.w500)),
          Text(value, style: const TextStyle(color: Color(0xFF4B5563), fontSize: 13, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28)),
      child: Column(
        children: [
          Container(padding: const EdgeInsets.all(16), decoration: const BoxDecoration(color: Color(0xFFF3F4F6), shape: BoxShape.circle), child: const Icon(Icons.pending_actions_rounded, size: 40, color: Color(0xFF9CA3AF))),
          const SizedBox(height: 24),
          const Text("No pending requests", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1F2937))),
          const SizedBox(height: 8),
          Text("You don't have any pet edit requests awaiting approval at the moment.", textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.grey.shade500, fontWeight: FontWeight.w500, height: 1.5)),
        ],
      ),
    );
  }

  Widget _buildSkeleton() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          const SkeletonLoader(width: 80, height: 16),
          const SizedBox(height: 8),
          const SkeletonLoader(width: 200, height: 32),
          const SizedBox(height: 32),
          ...List.generate(3, (i) => const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: SkeletonLoader(width: double.infinity, height: 160, borderRadius: 24),
          )),
        ],
      ),
    );
  }
}
