import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import '../models/study_bot.dart';
import '../models/study_bot_state.dart';

class StudyPlanService {
  static const _key = 'myai_study_plans_v1';
  static const _chatKey = 'myai_study_plan_chats_v1';
  static const _botsKey = 'myai_study_bots_v1';
  static const _botStateKey = 'myai_bot_states_v1'; // Phase 2: State storage

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

  // ============= STUDY BOT METHODS =============

  /// Get all saved Study Bots
  Future<List<StudyBot>> getBots() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_botsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => StudyBot.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Get a specific Study Bot by ID
  Future<StudyBot?> getBot(String botId) async {
    final bots = await getBots();
    try {
      return bots.firstWhere((bot) => bot.id == botId);
    } catch (_) {
      return null;
    }
  }

  /// Save a new Study Bot
  Future<String> saveBot({
    required String planName,
    required String planDescription,
    required String botName,
    required String educationLevel,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final bots = await getBots();
    final id = DateTime.now().toIso8601String();
    final bot = StudyBot(
      id: id,
      planName: planName,
      planDescription: planDescription,
      botName: botName,
      educationLevel: educationLevel,
      createdAt: DateTime.now(),
    );
    final newList = <StudyBot>[...bots, bot];
    await prefs.setString(
      _botsKey,
      jsonEncode(newList.map((b) => b.toJson()).toList()),
    );
    return id;
  }

  /// Update an existing Study Bot
  Future<void> updateBot({
    required String botId,
    String? botName,
    String? educationLevel,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final bots = await getBots();
    final index = bots.indexWhere((bot) => bot.id == botId);
    if (index != -1) {
      final updatedBot = bots[index].copyWith(
        botName: botName ?? bots[index].botName,
        educationLevel: educationLevel ?? bots[index].educationLevel,
      );
      bots[index] = updatedBot;
      await prefs.setString(
        _botsKey,
        jsonEncode(bots.map((b) => b.toJson()).toList()),
      );
    }
  }

  /// Delete a Study Bot
  Future<void> deleteBot(String botId) async {
    final prefs = await SharedPreferences.getInstance();
    final bots = await getBots();
    final filtered = bots.where((bot) => bot.id != botId).toList();
    await prefs.setString(
      _botsKey,
      jsonEncode(filtered.map((b) => b.toJson()).toList()),
    );
    // Also delete bot state
    await _deleteBotState(botId);
  }

  // ============= PHASE 2: STUDY BOT STATE METHODS =============

  /// Get all Study Bot states
  Future<Map<String, StudyBotState>> getBotStates() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_botStateKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map.map(
        (key, value) => MapEntry(
          key,
          StudyBotState.fromJson(Map<String, dynamic>.from(value as Map)),
        ),
      );
    } catch (_) {
      return {};
    }
  }

  /// Get Study Bot state by session ID
  Future<StudyBotState?> getBotState(String sessionId) async {
    final states = await getBotStates();
    return states[sessionId];
  }

  /// Save or update Study Bot state
  Future<void> saveBotState(StudyBotState state) async {
    final prefs = await SharedPreferences.getInstance();
    final states = await getBotStates();
    states[state.sessionId] = state;
    await prefs.setString(
      _botStateKey,
      jsonEncode(states.map((key, value) => MapEntry(key, value.toJson()))),
    );
  }

  /// Delete bot state
  Future<void> _deleteBotState(String botId) async {
    final prefs = await SharedPreferences.getInstance();
    final states = await getBotStates();
    states.removeWhere((_, state) => state.botId == botId);
    if (states.isEmpty) {
      await prefs.remove(_botStateKey);
    } else {
      await prefs.setString(
        _botStateKey,
        jsonEncode(states.map((key, value) => MapEntry(key, value.toJson()))),
      );
    }
  }

  /// Get all states for a specific bot
  Future<List<StudyBotState>> getBotStatesByBotId(String botId) async {
    final states = await getBotStates();
    return states.values.where((state) => state.botId == botId).toList();
  }
}
