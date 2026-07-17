import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/menu.dart';
import '../widgets/skeleton_loader.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final supabase = Supabase.instance.client;
  static const brandRed = Color(0xFF9E1B1B);

  bool _isLoading = true;
  List<Map<String, dynamic>> _notifications = [];
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
    _subscribeToRealtime();
  }

  @override
  void dispose() {
    if (_channel != null) {
      supabase.removeChannel(_channel!);
    }
    super.dispose();
  }

  Future<void> _fetchNotifications() async {
    try {
      final uid = supabase.auth.currentUser?.id;
      if (uid == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // Admins see broadcast ('admin') notifications plus anything
      // targeted specifically at them.
      final data = await supabase
          .from('notifications')
          .select()
          .or('recipient_role.eq.admin,recipient_user_id.eq.$uid')
          .order('created_at', ascending: false)
          .limit(100);

      if (mounted) {
        setState(() {
          _notifications = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Notifications fetch error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Live updates: new notifications appear instantly while the
  // app/site is open, no manual refresh needed.
  void _subscribeToRealtime() {
    _channel = supabase
        .channel('public:notifications')
        .onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'notifications',
      callback: (payload) {
        final newRow = payload.newRecord;
        final uid = supabase.auth.currentUser?.id;
        final isForMe = newRow['recipient_role'] == 'admin' ||
            newRow['recipient_user_id'] == uid;
        if (isForMe && mounted) {
          setState(() {
            _notifications.insert(0, newRow);
          });
        }
      },
    )
        .onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'notifications',
      callback: (payload) {
        final updated = payload.newRecord;
        if (!mounted) return;
        setState(() {
          final idx = _notifications.indexWhere((n) => n['id'] == updated['id']);
          if (idx != -1) _notifications[idx] = updated;
        });
      },
    )
        .subscribe();
  }

  Future<void> _markAsRead(Map<String, dynamic> notif) async {
    if (notif['is_read'] == true) return;
    setState(() => notif['is_read'] = true);
    try {
      await supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notif['id']);
    } catch (e) {
      debugPrint("Mark as read error: $e");
    }
  }

  String _timeAgo(String createdAt) {
    final date = DateTime.tryParse(createdAt);
    if (date == null) return '';
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}/${(date.year % 100).toString().padLeft(2, '0')}';
  }

  ({IconData icon, Color color}) _iconFor(String type) {
    switch (type) {
      case 'new_request':
        return (icon: Icons.person_rounded, color: brandRed);
      case 'record_updated':
        return (icon: Icons.folder_shared_rounded, color: Colors.blue);
      case 'request_success':
        return (icon: Icons.pets_rounded, color: Colors.orange);
      case 'approval_needed':
        return (icon: Icons.verified_rounded, color: Colors.green);
      default:
        return (icon: Icons.notifications_rounded, color: Colors.grey);
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((n) => n['is_read'] != true).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      drawer: const AppDrawer(currentRoute: 'notifications'),
      appBar: AppBar(
        backgroundColor: brandRed,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
        title: const Text(
          "Lipa City Veterinary Office",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
        ),
        actions: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_rounded),
                onPressed: () {},
              ),
              if (unreadCount > 0)
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
        ],
      ),
      body: _isLoading
          ? _buildSkeleton()
          : RefreshIndicator(
        onRefresh: _fetchNotifications,
        color: brandRed,
        child: _notifications.isEmpty
            ? ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 120),
            Center(
              child: Text(
                "All caught up!\nNo notifications yet.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        )
            : ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Text(
                "Notifications",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF111827)),
              ),
            ),
            ..._notifications.map(_buildNotificationTile),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationTile(Map<String, dynamic> notif) {
    final meta = _iconFor(notif['type'] ?? 'general');
    final isRead = notif['is_read'] == true;

    return InkWell(
      onTap: () => _markAsRead(notif),
      child: Container(
        color: isRead ? Colors.transparent : brandRed.withOpacity(0.04),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: meta.color.withOpacity(0.12), shape: BoxShape.circle),
              child: Icon(meta.icon, color: meta.color, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notif['title'] ?? '',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: isRead ? FontWeight.w600 : FontWeight.w800,
                      color: const Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _timeAgo(notif['created_at'] ?? ''),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            if (!isRead)
              Container(
                margin: const EdgeInsets.only(top: 6, left: 8),
                width: 8,
                height: 8,
                decoration: const BoxDecoration(color: brandRed, shape: BoxShape.circle),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeleton() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SkeletonLoader(width: 160, height: 28),
        const SizedBox(height: 20),
        ...List.generate(
          5,
              (i) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                const SkeletonLoader(width: 44, height: 44, borderRadius: 22),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      SkeletonLoader(width: double.infinity, height: 14),
                      SizedBox(height: 6),
                      SkeletonLoader(width: 60, height: 12),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}