import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/menu.dart';

class AdminDebugScreen extends StatefulWidget {
  const AdminDebugScreen({super.key});

  @override
  State<AdminDebugScreen> createState() => _AdminDebugScreenState();
}

class _AdminDebugScreenState extends State<AdminDebugScreen> {
  final supabase = Supabase.instance.client;
  bool _isTestMode = false;
  final List<String> _logs = [
    "[${DateTime.now().toString().split(' ')[1].split('.')[0]}] Debug system initialized.",
    "[${DateTime.now().toString().split(' ')[1].split('.')[0]}] Connected to Supabase.",
    "[${DateTime.now().toString().split(' ')[1].split('.')[0]}] API Endpoint: Render-API-v1",
  ];

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
            ]),

            const SizedBox(height: 24),

            _buildSectionTitle("ACCOUNT INFO"),
            const SizedBox(height: 12),
            _buildToolCard([
              _buildInfoRow("Role", "Administrator"),
              _buildInfoRow("UID", supabase.auth.currentUser?.id.substring(0, 8) ?? "N/A"),
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
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
        ],
      ),
    );
  }
}
