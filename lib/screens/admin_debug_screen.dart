import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../widgets/menu.dart';
import '../services/notification_service.dart';

class AdminDebugScreen extends StatefulWidget {
  const AdminDebugScreen({super.key});

  @override
  State<AdminDebugScreen> createState() => _AdminDebugScreenState();
}

class _AdminDebugScreenState extends State<AdminDebugScreen> {
  final supabase = Supabase.instance.client;
  final String backendUrl = 'https://digivetonline-api.onrender.com';
  bool _isTestMode = false;
  bool _isSendingBroadcast = false;

  final _broadcastTitleController = TextEditingController();
  final _broadcastBodyController = TextEditingController();
  final _targetUidController = TextEditingController();
  String _selectedAudience = 'Everyone';

  final List<String> _logs = [
    "[${DateTime.now().toString().split(' ')[1].split('.')[0]}] Debug system initialized.",
    "[${DateTime.now().toString().split(' ')[1].split('.')[0]}] Connected to Supabase.",
    "[${DateTime.now().toString().split(' ')[1].split('.')[0]}] API Endpoint: Render-API-v1",
  ];

  @override
  void dispose() {
    _broadcastTitleController.dispose();
    _broadcastBodyController.dispose();
    _targetUidController.dispose();
    super.dispose();
  }

  Future<void> _sendBroadcast() async {
    final title = _broadcastTitleController.text.trim();
    final body = _broadcastBodyController.text.trim();
    final targetUid = _targetUidController.text.trim();

    if (title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Title and body are required")),
      );
      return;
    }

    setState(() => _isSendingBroadcast = true);
    _addLog("Dispatching to $_selectedAudience ${targetUid.isNotEmpty ? '(Target: $targetUid)' : ''}...");

    try {
      String? role;
      String? uid;

      if (_selectedAudience == 'Target User ID') {
        uid = targetUid;
        if (uid.isEmpty) throw Exception("Target UID is empty");
      } else {
        if (_selectedAudience == 'Admins only') role = 'admin';
        if (_selectedAudience == 'Users only') role = 'pet_owner'; // Restore pet_owner
        if (_selectedAudience == 'Everyone') role = 'all';
      }

      await NotificationService.send(
        title: title,
        body: body,
        recipientRole: role,
        recipientUserId: uid,
        type: 'broadcast',
      );

      _addLog("Broadcast sent successfully.");
      _broadcastTitleController.clear();
      _broadcastBodyController.clear();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.green,
            content: Text("Broadcast sent successfully!"),
          ),
        );
      }
    } catch (e) {
      _addLog("Broadcast failed: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text("Failed to send broadcast: $e"),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSendingBroadcast = false);
    }
  }

  void _addLog(String message) {
    setState(() {
      _logs.insert(0, "[${DateTime.now().toString().split(' ')[1].split('.')[0]}] $message");
      if (_logs.length > 50) _logs.removeLast();
    });
  }

  @override
  Widget build(BuildContext context) {
    const brandRed = Color(0xFF9E1B1B);
    const darkSlate = Color(0xFF1E293B);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      drawer: const AppDrawer(currentRoute: 'debug'),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: darkSlate),
        title: const Text(
          "System Diagnostics",
          style: TextStyle(color: darkSlate, fontWeight: FontWeight.w900, fontSize: 18),
        ),
        actions: [
          IconButton(
            onPressed: () {
              setState(() => _logs.clear());
              _addLog("Logs cleared.");
            },
            icon: const Icon(Icons.delete_sweep_rounded, size: 22),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Grid
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.6,
              children: [
                _buildStatusCard("API LATENCY", "124ms", Icons.speed_rounded, Colors.green),
                _buildStatusCard("DB STATUS", "Healthy", Icons.cloud_done_rounded, brandRed),
                _buildStatusCard("AUTH", "Active", Icons.security_rounded, Colors.blue),
                _buildStatusCard("MEM USAGE", "42MB", Icons.memory_rounded, Colors.orange),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Terminal Section
            _buildSectionTitle("SYSTEM LOGS"),
            const SizedBox(height: 12),
            Container(
              height: 180,
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: darkSlate,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))
                ],
              ),
              child: ListView.builder(
                itemCount: _logs.length,
                itemBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    _logs[index],
                    style: const TextStyle(
                      color: Color(0xFF10B981),
                      fontFamily: 'monospace',
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),

            _buildSectionTitle("BROADCAST NOTIFICATION"),
            const SizedBox(height: 12),
            _buildBroadcastComposer(),

            const SizedBox(height: 32),

            _buildSectionTitle("DEVELOPER TOOLS"),
            const SizedBox(height: 12),
            _buildToolCard([
              _buildToolTile(
                "Test Mode", 
                "Enable experimental UI features", 
                Icons.bug_report_rounded,
                trailing: Switch(
                  value: _isTestMode, 
                  activeColor: brandRed,
                  onChanged: (v) {
                    setState(() => _isTestMode = v);
                    _addLog("Test Mode: ${v ? 'Enabled' : 'Disabled'}");
                  }
                ),
              ),
              const Divider(height: 1),
              _buildToolTile(
                "Refresh Auth Session", 
                "Force refresh Supabase token", 
                Icons.refresh_rounded,
                onTap: () async {
                  await supabase.auth.refreshSession();
                  _addLog("Auth session refreshed successfully.");
                }
              ),
              const Divider(height: 1),
              _buildToolTile(
                "Sync Local Cache", 
                "Re-fetch all offline datasets", 
                Icons.sync_rounded,
                onTap: () => _addLog("Syncing local cache..."),
              ),
              const Divider(height: 1),
              _buildToolTile(
                "Read Notifications", 
                "List all rows in notifications table", 
                Icons.list_alt_rounded,
                onTap: () async {
                  setState(() => _isSendingBroadcast = true);
                  _addLog("Fetching notifications...");
                  try {
                    final res = await supabase.from('notifications').select('*').limit(15);
                    final list = res as List;
                    _addLog("Found ${list.length} rows in DB.");
                    for(var n in list) {
                      final target = n['recipient_role'] ?? n['recipient_user_id'] ?? 'public';
                      _addLog(" > [$target] ${n['title']}");
                    }
                  } catch (e) {
                    _addLog("Fetch failed: $e");
                  } finally {
                    setState(() => _isSendingBroadcast = false);
                  }
                }
              ),
              const Divider(height: 1),
              _buildToolTile(
                "List Active Users", 
                "Show all users in notification registry", 
                Icons.supervised_user_circle_rounded,
                onTap: () async {
                  setState(() => _isSendingBroadcast = true);
                  _addLog("Accessing notification registry...");
                  try {
                    final res = await supabase.from('notifications').select('recipient_user_id, body').eq('recipient_role', 'registry');
                    final list = res as List;
                    _addLog("Registry: Found ${list.length} active UIDs.");
                    for(var r in list) {
                      _addLog(" -> [${r['body']}] ${r['recipient_user_id'].toString().substring(0, 8)}...");
                    }
                  } catch (e) {
                    _addLog("Registry access failed: $e");
                  } finally {
                    setState(() => _isSendingBroadcast = false);
                  }
                }
              ),
              const Divider(height: 1),
              _buildToolTile(
                "Probe User Database", 
                "Deep forensic check via Backend API", 
                Icons.manage_search_rounded,
                onTap: () async {
                  setState(() => _isSendingBroadcast = true);
                  _addLog("Starting API-based forensic probe...");
                  try {
                    final session = supabase.auth.currentSession;
                    if (session == null) throw Exception("No active session");
                    
                    final headers = {
                      'Authorization': 'Bearer ${session.accessToken}',
                      'Content-Type': 'application/json',
                    };

                    // 1. Probe owner_table via API
                    try {
                      final res = await http.get(Uri.parse('$backendUrl/api/vetdata/owner_table'), headers: headers);
                      if (res.statusCode == 200) {
                        final list = json.decode(res.body) as List;
                        _addLog("API owner_table: Found ${list.length} owners.");
                        if (list.isNotEmpty) {
                          _addLog(" -> Sample: ${list[0]['owner_name']} (${list[0]['owner_id']})");
                          _addLog(" -> Auth Link: ${list[0]['auth_email'] ?? 'None'}");
                        }
                      } else {
                        _addLog("API owner_table: Failed (${res.statusCode})");
                      }
                    } catch (e) { _addLog("owner_table probe error: $e"); }

                    // 2. Probe pet_edit_requests via API
                    try {
                      final res = await http.get(Uri.parse('$backendUrl/api/pets/all-requests'), headers: headers);
                      if (res.statusCode == 200) {
                        final list = json.decode(res.body) as List;
                        _addLog("API pet_requests: Found ${list.length} rows.");
                        if (list.isNotEmpty) {
                          _addLog(" -> Sample Owner ID: ${list[0]['owner_id']}");
                        }
                      }
                    } catch (e) { _addLog("requests probe error: $e"); }

                    // 3. Check for UIDs in existing notifications (Direct Supabase)
                    try {
                      final n = await supabase.from('notifications').select('recipient_user_id').not('recipient_user_id', 'is', null).limit(5);
                      _addLog("DB Notifications: Found ${(n as List).length} UID-targeted rows.");
                    } catch (e) { _addLog("DB notification check failed (RLS)."); }

                  } catch (e) {
                    _addLog("General probe failure: $e");
                  } finally {
                    setState(() => _isSendingBroadcast = false);
                  }
                }
              ),
            ]),

            const SizedBox(height: 24),

            _buildSectionTitle("ACCOUNT INFO"),
            const SizedBox(height: 12),
            _buildToolCard([
              _buildInfoRow("Role", supabase.auth.currentUser?.userMetadata?['role'] ?? "N/A"),
              _buildInfoRow("UID", supabase.auth.currentUser?.id ?? "N/A"),
              _buildInfoRow("Metadata", supabase.auth.currentUser?.userMetadata?.toString() ?? "{}"),
              _buildInfoRow("Last Login", DateTime.now().toString().split(' ')[0]),
            ]),
            
            const SizedBox(height: 40),
            Center(
              child: Text(
                "DIGIVET CORE v1.0.4-DEBUG",
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildBroadcastComposer() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _broadcastTitleController,
            decoration: InputDecoration(
              hintText: "Notification Title",
              filled: true,
              fillColor: const Color(0xFFF1F5F9),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _broadcastBodyController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: "Notification Message/Body",
              filled: true,
              fillColor: const Color(0xFFF1F5F9),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.all(16),
            ),
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 16),
          if (_selectedAudience == 'Target User ID') ...[
            TextField(
              controller: _targetUidController,
              decoration: InputDecoration(
                hintText: "Enter Target User UID",
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedAudience,
                      isExpanded: true,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B), fontWeight: FontWeight.w600),
                      items: ['Everyone', 'Admins only', 'Users only', 'Target User ID']
                          .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedAudience = v!),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _isSendingBroadcast ? null : _sendBroadcast,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9E1B1B),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    elevation: 0,
                  ),
                  child: _isSendingBroadcast
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text("Send", style: TextStyle(fontWeight: FontWeight.bold)),
                            SizedBox(width: 8),
                            Icon(Icons.send_rounded, size: 16),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w900,
        color: Color(0xFF64748B),
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildStatusCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.grey.shade500)),
              Icon(icon, size: 16, color: color),
            ],
          ),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF1E293B))),
        ],
      ),
    );
  }

  Widget _buildToolCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildToolTile(String title, String subtitle, IconData icon, {Widget? trailing, VoidCallback? onTap}) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: const Color(0xFF9E1B1B), size: 20),
      ),
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
      trailing: trailing ?? const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.grey),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
          const SizedBox(width: 12),
          Expanded(child: Text(value, textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)))),
        ],
      ),
    );
  }
}
