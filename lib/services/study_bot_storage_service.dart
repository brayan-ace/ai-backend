import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Firebase Firestore service for Study Bot chat storage and conversation history
/// This mirrors the ChatStorageService but is specifically for study bots
class StudyBotStorageService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get current user ID
  String? get _userId => _auth.currentUser?.uid;

  /// Get or create a study bot chat session
  /// Uses botId as the document ID for easy retrieval
  Future<String> getOrCreateBotChat({
    required String botId,
    required String botName,
    String? topic,
    String? description,
  }) async {
    if (_userId == null) throw Exception('User not authenticated');

    final docRef = _firestore
        .collection('users')
        .doc(_userId)
        .collection('study_bot_chats')
        .doc(botId);

    final doc = await docRef.get();
    
    if (!doc.exists) {
      // Create new chat session for this bot
      await docRef.set({
        'botId': botId,
        'botName': botName,
        'topic': topic,
        'description': description,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'messageCount': 0,
        'progressPercentage': 0,
        'currentModule': 0,
        'botState': 'intro',
      });
    }

    return botId;
  }

  /// Save a message to a study bot chat
  Future<void> saveMessage({
    required String botId,
    required String text,
    required bool fromUser,
    Map<String, dynamic>? metadata,
  }) async {
    if (_userId == null) throw Exception('User not authenticated');

    final chatRef = _firestore
        .collection('users')
        .doc(_userId)
        .collection('study_bot_chats')
        .doc(botId);

    // Add message to subcollection
    await chatRef.collection('messages').add({
      'text': text,
      'fromUser': fromUser,
      'senderType': fromUser ? 'user' : 'bot',
      'timestamp': FieldValue.serverTimestamp(),
      'metadata': metadata,
    });

    // Update chat metadata
    final updateData = {
      'updatedAt': FieldValue.serverTimestamp(),
      'messageCount': FieldValue.increment(1),
      'lastMessage': text.length > 100 ? '${text.substring(0, 100)}...' : text,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastMessageFromUser': fromUser,
    };

    await chatRef.update(updateData);
  }

  /// Get all messages for a study bot (for conversation history)
  Future<List<Map<String, dynamic>>> getMessages(String botId) async {
    if (_userId == null) return [];

    final snapshot = await _firestore
        .collection('users')
        .doc(_userId)
        .collection('study_bot_chats')
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
        'senderType': data['senderType'] ?? (data['fromUser'] == true ? 'user' : 'bot'),
        'timestamp': data['timestamp'] as Timestamp?,
        'metadata': data['metadata'],
      };
    }).toList();
  }

  /// Get messages as a stream (real-time updates)
  Stream<List<Map<String, dynamic>>> getMessagesStream(String botId) {
    if (_userId == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('users')
        .doc(_userId)
        .collection('study_bot_chats')
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
              'senderType': data['senderType'] ?? (data['fromUser'] == true ? 'user' : 'bot'),
              'timestamp': data['timestamp'] as Timestamp?,
              'metadata': data['metadata'],
            };
          }).toList();
        });
  }

  /// Get conversation history formatted for AI context
  /// Returns last N messages in the format expected by the AI
  Future<List<Map<String, String>>> getConversationHistoryForAI(
    String botId, {
    int limit = 20,
  }) async {
    if (_userId == null) return [];

    final snapshot = await _firestore
        .collection('users')
        .doc(_userId)
        .collection('study_bot_chats')
        .doc(botId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .get();

    // Reverse to get chronological order and format for AI
    final messages = snapshot.docs.reversed.map((doc) {
      final data = doc.data();
      final role = data['fromUser'] == true ? 'user' : 'assistant';
      return {
        'role': role,
        'content': data['text'] as String? ?? '',
      };
    }).toList();

    return messages;
  }

  /// Get all study bot chats for the user
  Stream<List<Map<String, dynamic>>> getStudyBotChats() {
    if (_userId == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('users')
        .doc(_userId)
        .collection('study_bot_chats')
        .orderBy('updatedAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'botId': doc.id,
              'botName': data['botName'] ?? 'Study Bot',
              'topic': data['topic'],
              'description': data['description'],
              'lastMessage': data['lastMessage'],
              'lastMessageTime': data['lastMessageTime'] as Timestamp?,
              'messageCount': data['messageCount'] ?? 0,
              'progressPercentage': data['progressPercentage'] ?? 0,
              'currentModule': data['currentModule'] ?? 0,
              'botState': data['botState'] ?? 'intro',
              'updatedAt': data['updatedAt'] as Timestamp?,
              'createdAt': data['createdAt'] as Timestamp?,
            };
          }).toList();
        });
  }

  /// Update bot progress in Firebase
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
        .collection('study_bot_chats')
        .doc(botId)
        .update(updateData);
  }

  /// Delete a study bot chat and all its messages
  Future<void> deleteBotChat(String botId) async {
    if (_userId == null) throw Exception('User not authenticated');

    final chatRef = _firestore
        .collection('users')
        .doc(_userId)
        .collection('study_bot_chats')
        .doc(botId);

    // Delete all messages
    final messagesSnapshot = await chatRef.collection('messages').get();
    for (var doc in messagesSnapshot.docs) {
      await doc.reference.delete();
    }

    // Delete the chat document
    await chatRef.delete();
  }

  /// Clear all messages but keep the chat
  Future<void> clearMessages(String botId) async {
    if (_userId == null) throw Exception('User not authenticated');

    final chatRef = _firestore
        .collection('users')
        .doc(_userId)
        .collection('study_bot_chats')
        .doc(botId);

    // Delete all messages
    final messagesSnapshot = await chatRef.collection('messages').get();
    for (var doc in messagesSnapshot.docs) {
      await doc.reference.delete();
    }

    // Reset message count
    await chatRef.update({
      'messageCount': 0,
      'lastMessage': null,
      'lastMessageTime': null,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
