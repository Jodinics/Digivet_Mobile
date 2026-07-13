import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/login_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/admin_dashboard_screen.dart';
import '../screens/approval_requests.dart';
import '../screens/vacc_history.dart';
import '../screens/settings_screen.dart';

class AppDrawer extends StatelessWidget {
  final String currentRoute;
  const AppDrawer({super.key, this.currentRoute = 'overview'});

  @override
  Widget build(BuildContext context) {
    const brandRed = Color(0xFF9E1B1B);
    const darkRed = Color(0xFF7B1E1E);
    
    final session = Supabase.instance.client.auth.currentSession;
    final role = session?.user.userMetadata?['role']?.toString().toLowerCase();
    final bool isAdmin = role == 'admin' || role == 'vet' || role == 'veterinarian';

    return Drawer(
      backgroundColor: brandRed,
      child: Column(
        children: [
          // Header Section
          Container(
            padding: const EdgeInsets.fromLTRB(24, 60, 24, 32),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [brandRed, darkRed],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Image.asset(
                    'assets/images/logo (2).png',
                    width: 48,
                    height: 48,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'DIGIVET',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        'ONLINE SYSTEM',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Navigation Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildDrawerItem(
                  context,
                  icon: Icons.grid_view_rounded,
                  title: 'Overview',
                  isSelected: currentRoute == 'overview',
                  onTap: () {
                    Navigator.pop(context);
                    if (currentRoute != 'overview') {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => isAdmin 
                              ? const AdminDashboardScreen() 
                              : const DashboardScreen(),
                        ),
                      );
                    }
                  },
                ),
                // Only show Vaccination History for Pet Owners
                if (!isAdmin)
                  _buildDrawerItem(
                    context,
                    icon: Icons.history_edu_rounded,
                    title: 'Vaccination History',
                    isSelected: currentRoute == 'history',
                    onTap: () {
                      Navigator.pop(context);
                      if (currentRoute != 'history') {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => const VaccHistoryScreen()),
                        );
                      }
                    },
                  ),
                _buildDrawerItem(
                  context,
                  icon: isAdmin ? Icons.how_to_reg_rounded : Icons.pending_actions_rounded,
                  title: isAdmin ? 'Approvals' : 'Approval Requests',
                  isSelected: currentRoute == 'approvals',
                  onTap: () {
                    Navigator.pop(context);
                    if (currentRoute != 'approvals') {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => const ApprovalRequestsScreen()),
                      );
                    }
                  },
                ),
                // Add an Admin-specific Analytics/Reports placeholder if needed
                if (isAdmin)
                   _buildDrawerItem(
                    context,
                    icon: Icons.analytics_rounded,
                    title: 'Reports',
                    isSelected: false,
                    onTap: () {
                      Navigator.pop(context);
                      // Placeholder for future reports
                    },
                  ),
              ],
            ),
          ),
          
          // Footer / Settings & Logout
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                const Divider(color: Colors.white24, height: 1),
                const SizedBox(height: 8),
                _buildDrawerItem(
                  context,
                  icon: Icons.settings_rounded,
                  title: 'Settings',
                  isSelected: currentRoute == 'settings',
                  onTap: () {
                    Navigator.pop(context);
                    if (currentRoute != 'settings') {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => const SettingsScreen()),
                      );
                    }
                  },
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.logout_rounded,
                  title: 'Logout',
                  isSelected: false,
                  isLogout: true,
                  onTap: () => _showLogoutDialog(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
    bool isLogout = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: isSelected ? Colors.white.withOpacity(0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          splashColor: Colors.white.withOpacity(0.1),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isSelected ? Colors.white : Colors.white70,
                  size: 22,
                ),
                const SizedBox(width: 16),
                Text(
                  title,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white70,
                    fontSize: 15,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: const Text("Sign Out", style: TextStyle(fontWeight: FontWeight.w900)),
        content: const Text("Are you sure you want to log out of your account?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel", style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF9E1B1B),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            child: const Text("Logout", style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}
