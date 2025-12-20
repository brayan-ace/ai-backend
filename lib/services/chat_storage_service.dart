import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatStorageService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get current user ID
  String? get _userId => _auth.currentUser?.uid;

  /// Create a new chat session
  Future<String> createChat({String? title}) async {
    if (_userId == null) throw Exception('User not authenticated');

    final chatDoc = await _firestore
        .collection('users')
        .doc(_userId)
        .collection('chats')
        .add({
          'title': title ?? 'New Chat',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'messageCount': 0,
          'isStarred': false,
        });

    return chatDoc.id;
  }

  /// Save a message to a chat
  Future<void> saveMessage({
    required String chatId,
    required String text,
    required bool fromUser,
  }) async {
    if (_userId == null) throw Exception('User not authenticated');

    // Add message to subcollection
    await _firestore
        .collection('users')
        .doc(_userId)
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .add({
          'text': text,
          'fromUser': fromUser,
          'timestamp': FieldValue.serverTimestamp(),
        });

    // Update chat metadata
    await _firestore
        .collection('users')
        .doc(_userId)
        .collection('chats')
        .doc(chatId)
        .update({
          'updatedAt': FieldValue.serverTimestamp(),
          'messageCount': FieldValue.increment(1),
          // Update title based on first user message if not set
          if (fromUser)
            'title': text.length > 50 ? '${text.substring(0, 50)}...' : text,
        });
  }

  /// Get all chats for current user (starred first, then by most recent)
  Stream<List<Map<String, dynamic>>> getChats() {
    if (_userId == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('users')
        .doc(_userId)
        .collection('chats')
        .orderBy('updatedAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
          final chats = snapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'title': data['title'] ?? 'Untitled Chat',
              'updatedAt': data['updatedAt'] as Timestamp?,
              'messageCount': data['messageCount'] ?? 0,
              'isStarred': data['isStarred'] ?? false,
            };
          }).toList();

          // Sort: starred chats first, then by updatedAt
          chats.sort((a, b) {
            final aStarred = a['isStarred'] as bool;
            final bStarred = b['isStarred'] as bool;
            if (aStarred != bStarred) {
              return bStarred ? 1 : -1; // Starred items first
            }
            // Both have same starred status, sort by time
            final aTime = a['updatedAt'] as Timestamp?;
            final bTime = b['updatedAt'] as Timestamp?;
            if (aTime == null) return 1;
            if (bTime == null) return -1;
            return bTime.compareTo(aTime);
          });

          return chats;
        });
  }

  /// Get messages for a specific chat
  Stream<List<Map<String, dynamic>>> getMessages(String chatId) {
    if (_userId == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('users')
        .doc(_userId)
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'text': data['text'] ?? '',
              'fromUser': data['fromUser'] ?? false,
              'timestamp': data['timestamp'] as Timestamp?,
            };
          }).toList();
        });
  }

  /// Delete a chat
  Future<void> deleteChat(String chatId) async {
    if (_userId == null) throw Exception('User not authenticated');

    // Delete all messages in the chat
    final messagesSnapshot = await _firestore
        .collection('users')
        .doc(_userId)
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .get();

    for (var doc in messagesSnapshot.docs) {
      await doc.reference.delete();
    }

    // Delete the chat document
    await _firestore
        .collection('users')
        .doc(_userId)
        .collection('chats')
        .doc(chatId)
        .delete();
  }

  /// Toggle star status of a chat
  Future<void> toggleStar(String chatId, bool isStarred) async {
    if (_userId == null) throw Exception('User not authenticated');

    await _firestore
        .collection('users')
        .doc(_userId)
        .collection('chats')
        .doc(chatId)
        .update({'isStarred': isStarred});
  }

  /// Update chat title
  Future<void> updateChatTitle(String chatId, String title) async {
    if (_userId == null) throw Exception('User not authenticated');

    await _firestore
        .collection('users')
        .doc(_userId)
        .collection('chats')
        .doc(chatId)
        .update({'title': title});
  }
}
