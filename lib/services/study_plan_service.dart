import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class StudyPlanService {
  static const _key = 'myai_study_plans_v1';
  static const _chatKey = 'myai_study_plan_chats_v1';

  // Stored as a JSON list of maps:
  // {"id":"...","title":"...","context":"...","domainFilter":"...","createdAt":"..."}
  Future<List<Map<String, dynamic>>> getPlans() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> savePlan({
    required String title,
    required String context, // e.g., "Act as a biology professor teaching..."
    String domainFilter = '', // e.g., "biology" - if set, AI stays in domain
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final plans = await getPlans();
    final id = DateTime.now().toIso8601String();
    final plan = {
      'id': id,
      'title': title,
      'context': context,
      'domainFilter': domainFilter,
      'createdAt': DateTime.now().toIso8601String(),
    };
    final newList = <Map<String, dynamic>>[...plans, plan];
    await prefs.setString(_key, jsonEncode(newList));
  }

  /// Update an existing plan
  Future<void> updatePlan({
    required String id,
    String? title,
    String? context,
    String? domainFilter,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final plans = await getPlans();
    final index = plans.indexWhere((p) => p['id'] == id);
    if (index != -1) {
      plans[index] = {
        ...plans[index],
        if (title != null) 'title': title,
        if (context != null) 'context': context,
        if (domainFilter != null) 'domainFilter': domainFilter,
      };
      await prefs.setString(_key, jsonEncode(plans));
    }
  }

  Future<void> deletePlan(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final plans = await getPlans();
    final filtered = plans.where((p) => p['id'] != id).toList();
    await prefs.setString(_key, jsonEncode(filtered));
    // Also delete associated chat history
    await _deletePlanChats(id);
  }

  /// Get chat history for a study plan
  Future<List<Map<String, String>>> getPlanChats(String planId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('${_chatKey}_$planId');
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => Map<String, String>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Save a chat message in a study plan
  Future<void> saveChatMessage(
    String planId,
    String userMessage,
    String aiResponse,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final chats = await getPlanChats(planId);
    final message = {
      'user': userMessage,
      'ai': aiResponse,
      'timestamp': DateTime.now().toIso8601String(),
    };
    final newChats = <Map<String, String>>[...chats, message];
    await prefs.setString('${_chatKey}_$planId', jsonEncode(newChats));
  }

  Future<void> _deletePlanChats(String planId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('${_chatKey}_$planId');
  }
}
