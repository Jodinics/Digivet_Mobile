import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Service responsible for dispatching notifications to both in-app and push channels.
class NotificationService {
  static final _supabase = Supabase.instance.client;
  static const String _backendUrl = 'https://digivetonline-api.onrender.com';

  static Future<void> send({
    required String title,
    required String body,
    String? recipientUserId,
    String? recipientRole,
    String type = 'general',
  }) async {
    try {
      if (recipientUserId != null && recipientUserId.isNotEmpty) {
        await _insertNotification(title, body, recipientUserId, null, type);
      } else if (recipientRole != null) {
        // 1. Attempt forensic fan-out to all known UIDs
        await _tryFanOut(title, body, recipientRole, type);

        // 2. Redundant Role Broadcast (The "Safety Net")
        // We send to all synonyms to ensure coverage
        if (recipientRole == 'client' || recipientRole == 'pet_owner' || recipientRole == 'user') {
          await _insertNotification(title, body, null, 'client', type);
          await _insertNotification(title, body, null, 'pet_owner', type);
          await _insertNotification(title, body, null, 'user', type);
        } else {
          await _insertNotification(title, body, null, recipientRole, type);
        }
      } else {
        await _insertNotification(title, body, null, 'all', type);
      }
    } catch (e) {
      debugPrint('NotificationService.send Error: $e');
      rethrow;
    }
  }

  /// Internal helper to insert a notification row.
  static Future<void> _insertNotification(String title, String body, String? uid, String? role, String type) async {
    await _supabase.from('notifications').insert({
      'title': title,
      'body': body,
      'recipient_user_id': uid,
      'recipient_role': role,
      'type': type,
      'is_read': false,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// Records the current user's presence so the Admin can find them for broadcasts.
  static Future<void> checkIn() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    
    try {
      // "Phone Home" - User sends a discovery packet addressed to 'admin'.
      // Since Admins can see 'admin' role notifications, they will find this UID.
      await _supabase.from('notifications').insert({
        'title': 'DISCOVERY_UID',
        'body': user.id, // We put the UID in the body
        'recipient_user_id': null,
        'recipient_role': 'admin', // Addressed to admins
        'type': 'discovery',
        'is_read': true, // Mark as read so it doesn't alert the admin
        'created_at': DateTime.now().toIso8601String(),
      });
      debugPrint('Discovery check-in sent for UID: ${user.id}');
    } catch (e) {
      debugPrint('Discovery check-in failed: $e');
    }
  }

  /// Tries to find all relevant users and create individual notifications for them.
  static Future<bool> _tryFanOut(String title, String body, String role, String type) async {
    try {
      Set<String> uids = {};

      // 1. Discovery via Discovery Packets (Phone Home rows)
      try {
        final res = await _supabase
            .from('notifications')
            .select('body')
            .eq('type', 'discovery')
            .eq('recipient_role', 'admin');
        
        for (var n in res) {
          final uid = n['body']?.toString();
          if (uid != null && uid.length > 20) uids.add(uid);
        }
      } catch (_) {}

      // 2. Discovery via History: Look for any notification that was successfully received
      try {
        final res = await _supabase
            .from('notifications')
            .select('recipient_user_id')
            .not('recipient_user_id', 'is', null)
            .limit(200);
        
        for (var n in res) {
          final uid = n['recipient_user_id']?.toString();
          if (uid != null && uid.length > 20) uids.add(uid);
        }
      } catch (_) {}

      if (uids.isEmpty) return false;

      debugPrint('Fanning out to ${uids.length} discovered UIDs');

      final List<Map<String, dynamic>> batch = uids.map((uid) => {
        'title': title,
        'body': body,
        'recipient_user_id': uid,
        'recipient_role': null,
        'type': type,
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
      }).toList();

      for (var i = 0; i < batch.length; i += 100) {
        final chunk = batch.sublist(i, i + 100 > batch.length ? batch.length : i + 100);
        await _supabase.from('notifications').insert(chunk);
      }
      return true;
    } catch (e) { return false; }
  }

  /// Fetches unread count for the current user.
  static Future<int> getUnreadCount() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return 0;

    final uid = user.id;
    final role = user.userMetadata?['role']?.toString().toLowerCase() ?? '';
    final isAdmin = role == 'admin' || role == 'vet' || role == 'veterinarian';

    String roleFilters = 'recipient_user_id.eq.$uid,recipient_role.eq.all';
    if (isAdmin) {
      roleFilters += ',recipient_role.eq.admin';
    } else {
      roleFilters += ',recipient_role.eq.pet_owner,recipient_role.eq.client';
    }

    final response = await _supabase
        .from('notifications')
        .select('id')
        .or(roleFilters)
        .eq('is_read', false);
    
    return (response as List).length;
  }
}
