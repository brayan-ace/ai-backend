import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Firebase Firestore service for Study Bot storage
/// This is the EXACT same pattern as ChatStorageService used by OnlineAiScreen
class StudyBotFirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get current user ID
  String? get _userId => _auth.currentUser?.uid;

  /// Create a new study bot
  Future<String> createBot({
    required String name,
    required String topic,
    String? description,
    String? gradeLevel,
    Map<String, dynamic>? systemInstructions,
  }) async {
    if (_userId == null) throw Exception('User not authenticated');

    final botDoc = await _firestore
        .collection('users')
        .doc(_userId)
        .collection('study_bots')
        .add({
          'name': name,
          'topic': topic,
          'description': description ?? '',
          'gradeLevel': gradeLevel ?? '',
          'systemInstructions': systemInstructions,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'messageCount': 0,
          'progressPercentage': 0,
          'currentModule': 0,
          'botState': 'intro',
          'lastMessage': null,
          'lastMessageTime': null,
        });

    return botDoc.id;
  }

  /// Save a message to a study bot chat
  Future<void> saveMessage({
    required String botId,
    required String text,
    required bool fromUser,
  }) async {
    if (_userId == null) throw Exception('User not authenticated');

    final botRef = _firestore
        .collection('users')
        .doc(_userId)
        .collection('study_bots')
        .doc(botId);

    // Add message to subcollection
    await botRef.collection('messages').add({
      'text': text,
      'fromUser': fromUser,
      'timestamp': FieldValue.serverTimestamp(),
    });

    // Update bot metadata
    await botRef.update({
      'updatedAt': FieldValue.serverTimestamp(),
      'messageCount': FieldValue.increment(1),
      'lastMessage': text.length > 100 ? '${text.substring(0, 100)}...' : text,
      'lastMessageTime': FieldValue.serverTimestamp(),
    });
  }

  /// Get all study bots for current user (most recent first)
  Stream<List<Map<String, dynamic>>> getBots() {
    if (_userId == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('users')
        .doc(_userId)
        .collection('study_bots')
        .orderBy('updatedAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'bot_id': doc.id,
              'name': data['name'] ?? 'Untitled Bot',
              'topic': data['topic'] ?? '',
              'description': data['description'] ?? '',
              'grade_level': data['gradeLevel'] ?? '',
              'progress_percentage': data['progressPercentage'] ?? 0,
              'current_module': data['currentModule'] ?? 0,
              'bot_state': data['botState'] ?? 'intro',
              'last_message': data['lastMessage'],
              'last_message_time': data['lastMessageTime'] as Timestamp?,
              'message_count': data['messageCount'] ?? 0,
              'created_at': data['createdAt'] as Timestamp?,
              'updated_at': data['updatedAt'] as Timestamp?,
              'system_instructions': data['systemInstructions'],
            };
          }).toList();
        });
  }

  /// Get messages for a specific bot
  Stream<List<Map<String, dynamic>>> getMessages(String botId) {
    if (_userId == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('users')
        .doc(_userId)
        .collection('study_bots')
        .doc(botId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'text': data['text'] ?? '',
              'fromUser': data['fromUser'] ?? false,
              'timestamp': data['timestamp'] as Timestamp?,
            };
          }).toList();
        });
  }

  /// Get messages as a one-time fetch (for AI context)
  Future<List<Map<String, dynamic>>> getMessagesOnce(String botId) async {
    if (_userId == null) return [];

    final snapshot = await _firestore
        .collection('users')
        .doc(_userId)
        .collection('study_bots')
        .doc(botId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        'text': data['text'] ?? '',
        'fromUser': data['fromUser'] ?? false,
        'timestamp': data['timestamp'] as Timestamp?,
      };
    }).toList();
  }

  /// Get conversation history formatted for AI
  Future<List<Map<String, String>>> getConversationHistoryForAI(
    String botId, {
    int limit = 20,
  }) async {
    if (_userId == null) return [];

    final snapshot = await _firestore
        .collection('users')
        .doc(_userId)
        .collection('study_bots')
        .doc(botId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .get();

    // Reverse to get chronological order
    final messages = snapshot.docs.reversed.map((doc) {
      final data = doc.data();
      final role = data['fromUser'] == true ? 'user' : 'assistant';
      return {'role': role, 'content': data['text'] as String? ?? ''};
    }).toList();

    return messages;
  }

  /// Delete a study bot and all its messages
  Future<void> deleteBot(String botId) async {
    if (_userId == null) throw Exception('User not authenticated');

    final botRef = _firestore
        .collection('users')
        .doc(_userId)
        .collection('study_bots')
        .doc(botId);

    // Delete all messages in the bot
    final messagesSnapshot = await botRef.collection('messages').get();
    for (var doc in messagesSnapshot.docs) {
      await doc.reference.delete();
    }

    // Delete the bot document
    await botRef.delete();
  }

  /// Update bot name
  Future<void> updateBotName(String botId, String name) async {
    if (_userId == null) throw Exception('User not authenticated');

    await _firestore
        .collection('users')
        .doc(_userId)
        .collection('study_bots')
        .doc(botId)
        .update({'name': name, 'updatedAt': FieldValue.serverTimestamp()});
  }

  /// Update bot progress
  Future<void> updateProgress({
    required String botId,
    double? progressPercentage,
    int? currentModule,
    String? botState,
    Map<String, dynamic>? studyPlan,
  }) async {
    if (_userId == null) throw Exception('User not authenticated');

    final updateData = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (progressPercentage != null) {
      updateData['progressPercentage'] = progressPercentage;
    }
    if (currentModule != null) {
      updateData['currentModule'] = currentModule;
    }
    if (botState != null) {
      updateData['botState'] = botState;
    }
    if (studyPlan != null) {
      updateData['studyPlan'] = studyPlan;
    }

    await _firestore
        .collection('users')
        .doc(_userId)
        .collection('study_bots')
        .doc(botId)
        .update(updateData);
  }

  /// Get a single bot by ID
  Future<Map<String, dynamic>?> getBot(String botId) async {
    if (_userId == null) return null;

    final doc = await _firestore
        .collection('users')
        .doc(_userId)
        .collection('study_bots')
        .doc(botId)
        .get();

    if (!doc.exists) return null;

    final data = doc.data()!;
    return {
      'bot_id': doc.id,
      'name': data['name'] ?? 'Untitled Bot',
      'topic': data['topic'] ?? '',
      'description': data['description'] ?? '',
      'grade_level': data['gradeLevel'] ?? '',
      'progress_percentage': data['progressPercentage'] ?? 0,
      'current_module': data['currentModule'] ?? 0,
      'bot_state': data['botState'] ?? 'intro',
      'last_message': data['lastMessage'],
      'system_instructions': data['systemInstructions'],
      'study_plan': data['studyPlan'],
    };
  }

  /// Check if bot exists
  Future<bool> botExists(String botId) async {
    if (_userId == null) return false;

    final doc = await _firestore
        .collection('users')
        .doc(_userId)
        .collection('study_bots')
        .doc(botId)
        .get();

    return doc.exists;
  }

  /// Save or update bot with specific ID (for syncing with backend)
  Future<void> saveBot({
    required String botId,
    required String name,
    required String topic,
    String? description,
    String? gradeLevel,
    Map<String, dynamic>? systemInstructions,
    double? progressPercentage,
    int? currentModule,
    String? botState,
    int? messageCount,
  }) async {
    if (_userId == null) throw Exception('User not authenticated');

    final botRef = _firestore
        .collection('users')
        .doc(_userId)
        .collection('study_bots')
        .doc(botId);

    final doc = await botRef.get();

    if (doc.exists) {
      // Update existing
      await botRef.update({
        'name': name,
        'topic': topic,
        'description': description ?? '',
        'gradeLevel': gradeLevel ?? '',
        'systemInstructions': systemInstructions,
        'progressPercentage': progressPercentage ?? 0,
        'currentModule': currentModule ?? 0,
        'botState': botState ?? 'intro',
        if (messageCount != null) 'messageCount': messageCount,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      // Create new with specific ID
      await botRef.set({
        'name': name,
        'topic': topic,
        'description': description ?? '',
        'gradeLevel': gradeLevel ?? '',
        'systemInstructions': systemInstructions,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'messageCount': messageCount ?? 0,
        'progressPercentage': progressPercentage ?? 0,
        'currentModule': currentModule ?? 0,
        'botState': botState ?? 'intro',
        'lastMessage': null,
        'lastMessageTime': null,
      });
    }
  }
}
