import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Note model for storing saved content from chats or manual notes
class SavedNote {
  final String id;
  final String userId;
  final String title;
  final String content;
  final String source; // 'manual', 'chat_message', 'chat_history'
  final String? botId; // For chat-sourced notes
  final String? botName; // For context
  final DateTime createdAt;
  final DateTime updatedAt;

  SavedNote({
    required this.id,
    required this.userId,
    required this.title,
    required this.content,
    required this.source,
    this.botId,
    this.botName,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Convert to Firestore JSON
  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'title': title,
    'content': content,
    'source': source,
    'botId': botId,
    'botName': botName,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  /// Create from Firestore JSON
  factory SavedNote.fromJson(Map<String, dynamic> json) => SavedNote(
    id: json['id'] as String,
    userId: json['userId'] as String,
    title: json['title'] as String,
    content: json['content'] as String,
    source: json['source'] as String,
    botId: json['botId'] as String?,
    botName: json['botName'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
  );

  /// Copy with method
  SavedNote copyWith({
    String? id,
    String? userId,
    String? title,
    String? content,
    String? source,
    String? botId,
    String? botName,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SavedNote(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      content: content ?? this.content,
      source: source ?? this.source,
      botId: botId ?? this.botId,
      botName: botName ?? this.botName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Service for managing saved notes from chats and manual notes
/// Stores notes in Firestore for persistence across devices
/// Also uses SharedPreferences for local caching and instant UI updates
class NotesService {
  static final NotesService _instance = NotesService._internal();

  factory NotesService() => _instance;

  NotesService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const String _notesCollection = 'user_notes';
  static const String _localNotesKey = 'saved_notes_local';

  /// Get current user ID
  String? get userId => _auth.currentUser?.uid;

  /// Save note to local storage (SharedPreferences)
  Future<void> _saveNoteLocally(SavedNote note) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notesJson = prefs.getString(_localNotesKey) ?? '[]';
      final notesList = List<Map<String, dynamic>>.from(
        json.decode(notesJson) as List,
      );

      // Add the new note
      notesList.add(note.toJson());

      await prefs.setString(_localNotesKey, json.encode(notesList));
      print('[NotesService] ✅ Saved note to local storage');
    } catch (e) {
      print('[NotesService] ⚠️ Error saving to local storage: $e');
    }
  }

  /// Load notes from local storage
  Future<List<SavedNote>> _loadNotesLocally() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notesJson = prefs.getString(_localNotesKey) ?? '[]';
      final notesData = List<Map<String, dynamic>>.from(
        json.decode(notesJson) as List,
      );

      return notesData
          .map((data) => SavedNote.fromJson(data))
          .toList()
          .cast<SavedNote>();
    } catch (e) {
      print('[NotesService] ⚠️ Error loading from local storage: $e');
      return [];
    }
  }

  /// Save a note from a chat message
  /// Preserves all formatting (markdown, tables, etc.)
  Future<SavedNote> saveChatMessageAsNote({
    required String messageContent,
    required String botId,
    required String? botName,
    String? customTitle,
  }) async {
    print('[NotesService] DEBUG: saveChatMessageAsNote called');
    print('[NotesService] DEBUG: Current userId: $userId');
    print('[NotesService] DEBUG: Message length: ${messageContent.length}');

    if (userId == null) {
      print('[NotesService] ❌ User ID is null - not authenticated');
      throw Exception('User not authenticated');
    }

    try {
      final now = DateTime.now();
      final noteId = _firestore.collection(_notesCollection).doc().id;

      // Auto-generate title from first 50 chars of message if not provided
      final title = customTitle ?? _generateTitleFromContent(messageContent);

      final note = SavedNote(
        id: noteId,
        userId: userId!,
        title: title,
        content: messageContent,
        source: 'chat_message',
        botId: botId,
        botName: botName,
        createdAt: now,
        updatedAt: now,
      );

      print('[NotesService] DEBUG: Note object created:');
      print('[NotesService] DEBUG: - id: ${note.id}');
      print('[NotesService] DEBUG: - userId: ${note.userId}');
      print('[NotesService] DEBUG: - title: ${note.title}');
      print('[NotesService] DEBUG: - source: ${note.source}');

      // IMPORTANT: Save to local storage FIRST for instant UI update
      await _saveNoteLocally(note);
      print('[NotesService] ✅ Saved to local storage (instant)');

      // Then save to Firestore in background (don't await)
      final jsonData = note.toJson();
      print('[NotesService] DEBUG: Saving to Firestore...');
      _firestore
          .collection(_notesCollection)
          .doc(noteId)
          .set(jsonData)
          .then((_) {
            print('[NotesService] ✅ Saved to Firestore: $noteId');
          })
          .catchError((e) {
            print('[NotesService] ❌ Error saving to Firestore: $e');
          });

      return note;
    } catch (e) {
      print('[NotesService] ❌ Error saving chat message: $e');
      print('[NotesService] ❌ Stack trace: ${StackTrace.current}');
      rethrow;
    }
  }

  /// Save entire chat conversation as a note
  /// Concatenates all messages with proper formatting
  Future<SavedNote> saveChatHistoryAsNote({
    required List<Map<String, dynamic>> messages,
    required String botId,
    required String? botName,
    String? customTitle,
  }) async {
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    try {
      final now = DateTime.now();
      final noteId = _firestore.collection(_notesCollection).doc().id;

      // Format conversation with sender labels
      final formattedContent = _formatConversation(messages);

      // Auto-generate title
      final title =
          customTitle ?? 'Chat with ${botName ?? 'Bot'} - ${_formatDate(now)}';

      final note = SavedNote(
        id: noteId,
        userId: userId!,
        title: title,
        content: formattedContent,
        source: 'chat_history',
        botId: botId,
        botName: botName,
        createdAt: now,
        updatedAt: now,
      );

      // Save to local storage first
      await _saveNoteLocally(note);
      print('[NotesService] ✅ Saved chat history to local storage');

      // Save to Firestore in background
      _firestore
          .collection(_notesCollection)
          .doc(noteId)
          .set(note.toJson())
          .then((_) {
            print('[NotesService] ✅ Saved chat history to Firestore: $noteId');
          })
          .catchError((e) {
            print('[NotesService] ❌ Error saving to Firestore: $e');
          });

      return note;
    } catch (e) {
      print('[NotesService] ❌ Error saving chat history: $e');
      rethrow;
    }
  }

  /// Save a manual note
  Future<SavedNote> saveManualNote({
    required String title,
    required String content,
  }) async {
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    try {
      final now = DateTime.now();
      final noteId = _firestore.collection(_notesCollection).doc().id;

      final note = SavedNote(
        id: noteId,
        userId: userId!,
        title: title,
        content: content,
        source: 'manual',
        createdAt: now,
        updatedAt: now,
      );

      // Save to local storage first
      await _saveNoteLocally(note);
      print('[NotesService] ✅ Saved manual note to local storage');

      // Save to Firestore in background
      _firestore
          .collection(_notesCollection)
          .doc(noteId)
          .set(note.toJson())
          .then((_) {
            print('[NotesService] ✅ Saved manual note to Firestore: $noteId');
          })
          .catchError((e) {
            print('[NotesService] ❌ Error saving to Firestore: $e');
          });

      return note;
    } catch (e) {
      print('[NotesService] ❌ Error saving manual note: $e');
      rethrow;
    }
  }

  /// Get all notes for current user
  Future<List<SavedNote>> getAllNotes() async {
    print('[NotesService] DEBUG: Entering getAllNotes()');
    print('[NotesService] DEBUG: userId = $userId');

    try {
      // FIRST: Load from local storage (instant UI update)
      final localNotes = await _loadNotesLocally();
      print(
        '[NotesService] DEBUG: Loaded ${localNotes.length} notes from local storage',
      );

      // Return local notes immediately if available
      if (localNotes.isNotEmpty) {
        print(
          '[NotesService] ✅ Returning ${localNotes.length} notes from cache',
        );

        // Then sync with Firestore in the background
        _syncNotesWithFirestore();

        return localNotes;
      }

      // If no local notes, try to fetch from Firestore
      if (userId == null) {
        print('[NotesService] DEBUG: userId is NULL, returning empty list');
        return [];
      }

      print(
        '[NotesService] DEBUG: Querying Firestore for notes with userId: $userId',
      );

      final snapshot = await _firestore
          .collection(_notesCollection)
          .where('userId', isEqualTo: userId)
          .orderBy('updatedAt', descending: true)
          .get();

      print(
        '[NotesService] DEBUG: Firestore returned ${snapshot.docs.length} documents',
      );

      if (snapshot.docs.isEmpty) {
        print(
          '[NotesService] DEBUG: No documents found in user_notes collection',
        );
        return [];
      }

      final notes = <SavedNote>[];
      for (final doc in snapshot.docs) {
        try {
          print('[NotesService] DEBUG: Processing doc ${doc.id}');
          final note = SavedNote.fromJson(doc.data());
          print(
            '[NotesService] DEBUG: Successfully deserialized note: "${note.title}"',
          );
          notes.add(note);
        } catch (e) {
          print('[NotesService] ❌ Error deserializing note: $e');
        }
      }

      print(
        '[NotesService] DEBUG: Successfully loaded ${notes.length} notes from Firestore',
      );

      // Cache notes locally
      await _cacheNotesLocally(notes);

      return notes;
    } catch (e) {
      print('[NotesService] ❌ Error fetching notes: $e');
      // Try to return cached notes even if Firestore fails
      return await _loadNotesLocally();
    }
  }

  /// Cache notes to local storage
  Future<void> _cacheNotesLocally(List<SavedNote> notes) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notesJson = notes.map((n) => n.toJson()).toList();
      await prefs.setString(_localNotesKey, json.encode(notesJson));
      print('[NotesService] ✅ Cached ${notes.length} notes locally');
    } catch (e) {
      print('[NotesService] ⚠️ Error caching notes: $e');
    }
  }

  /// Sync notes with Firestore in the background
  Future<void> _syncNotesWithFirestore() async {
    if (userId == null) return;

    try {
      print('[NotesService] DEBUG: Syncing with Firestore...');
      final snapshot = await _firestore
          .collection(_notesCollection)
          .where('userId', isEqualTo: userId)
          .orderBy('updatedAt', descending: true)
          .get();

      final notes = <SavedNote>[];
      for (final doc in snapshot.docs) {
        try {
          notes.add(SavedNote.fromJson(doc.data()));
        } catch (e) {
          print('[NotesService] ⚠️ Error deserializing: $e');
        }
      }

      await _cacheNotesLocally(notes);
      print('[NotesService] ✅ Synced ${notes.length} notes from Firestore');
    } catch (e) {
      print('[NotesService] ⚠️ Background sync failed: $e');
    }
  }

  /// Get notes from a specific source type
  Future<List<SavedNote>> getNotesBySource(String source) async {
    if (userId == null) {
      return [];
    }

    try {
      final snapshot = await _firestore
          .collection(_notesCollection)
          .where('userId', isEqualTo: userId)
          .where('source', isEqualTo: source)
          .orderBy('updatedAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => SavedNote.fromJson(doc.data()))
          .toList();
    } catch (e) {
      print('[NotesService] ❌ Error fetching notes by source: $e');
      return [];
    }
  }

  /// Update a note
  Future<void> updateNote(SavedNote note) async {
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    try {
      final updatedNote = note.copyWith(updatedAt: DateTime.now());
      await _firestore
          .collection(_notesCollection)
          .doc(note.id)
          .update(updatedNote.toJson());

      print('[NotesService] ✅ Updated note: ${note.id}');
    } catch (e) {
      print('[NotesService] ❌ Error updating note: $e');
      rethrow;
    }
  }

  /// Delete a note
  Future<void> deleteNote(String noteId) async {
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    try {
      await _firestore.collection(_notesCollection).doc(noteId).delete();

      print('[NotesService] ✅ Deleted note: $noteId');
    } catch (e) {
      print('[NotesService] ❌ Error deleting note: $e');
      rethrow;
    }
  }

  /// Helper: Generate title from content
  String _generateTitleFromContent(String content) {
    String cleaned = content
        .replaceAll(RegExp(r'[#*_`]'), '')
        .replaceAll(RegExp(r'\n+'), ' ')
        .trim();

    if (cleaned.length > 50) {
      return cleaned.substring(0, 50) + '...';
    }
    return cleaned;
  }

  /// Helper: Format conversation with sender labels
  String _formatConversation(List<Map<String, dynamic>> messages) {
    final buffer = StringBuffer();

    for (final msg in messages) {
      final sender = msg['senderType'] == 'bot' ? '🤖 Bot' : '👤 You';
      final text = msg['text'] ?? '';

      buffer.writeln('**$sender:**');
      buffer.writeln(text);
      buffer.writeln();
    }

    return buffer.toString();
  }

  /// Helper: Format date nicely
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
