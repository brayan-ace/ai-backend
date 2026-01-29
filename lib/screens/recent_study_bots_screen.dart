import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/theme.dart';
import 'study_plan_chat_screen.dart';

/// Recent Study Bots Screen - Uses Firebase Firestore exactly like OnlineAiScreen
/// This mirrors the exact implementation pattern of OnlineAiScreen's chat storage
class RecentStudyBotsScreen extends StatefulWidget {
  const RecentStudyBotsScreen({Key? key}) : super(key: key);

  @override
  State<RecentStudyBotsScreen> createState() => _RecentStudyBotsScreenState();
}

class _RecentStudyBotsScreenState extends State<RecentStudyBotsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<Map<String, dynamic>> _bots = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadRecentBots();
  }

  /// Load recent bots from Firebase - EXACT same pattern as OnlineAiScreen
  Future<void> _loadRecentBots() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        setState(() {
          _errorMessage = 'Not authenticated';
          _isLoading = false;
        });
        return;
      }

      // Use StreamBuilder pattern like OnlineAiScreen
      final botsStream = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('study_bots')
          .orderBy('updatedAt', descending: true)
          .limit(50)
          .snapshots();

      botsStream.listen(
        (snapshot) {
          final bots = snapshot.docs.map((doc) {
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

          setState(() {
            _bots = bots;
            _isLoading = false;
          });
        },
        onError: (error) {
          setState(() {
            _errorMessage = 'Error loading bots: $error';
            _isLoading = false;
          });
        },
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  /// Delete bot from Firebase - EXACT same pattern as OnlineAiScreen.deleteChat
  Future<void> _deleteBot(int index, String botId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Delete all messages in the bot
      final messagesSnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('study_bots')
          .doc(botId)
          .collection('messages')
          .get();

      for (var doc in messagesSnapshot.docs) {
        await doc.reference.delete();
      }

      // Delete the bot document
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('study_bots')
          .doc(botId)
          .delete();

      setState(() {
        _bots.removeAt(index);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bot deleted successfully'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting bot: $e'),
            backgroundColor: AppTheme.primaryBlue,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// Rename bot - EXACT same pattern as OnlineAiScreen.updateChatTitle
  Future<void> _renameBot(Map<String, dynamic> bot, int index) async {
    final TextEditingController controller = TextEditingController(
      text: bot['name'] ?? '',
    );

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Bot'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Enter new name',
            border: OutlineInputBorder(),
          ),
          maxLength: 50,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final newName = controller.text.trim();

              if (newName.isNotEmpty) {
                try {
                  final user = _auth.currentUser;
                  if (user != null) {
                    await _firestore
                        .collection('users')
                        .doc(user.uid)
                        .collection('study_bots')
                        .doc(bot['bot_id'])
                        .update({
                          'name': newName,
                          'updatedAt': FieldValue.serverTimestamp(),
                        });

                    setState(() {
                      _bots[index]['name'] = newName;
                    });

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Bot renamed to "$newName"'),
                          backgroundColor: Colors.green,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error renaming bot: $e'),
                        backgroundColor: AppTheme.primaryBlue,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  /// Resume bot chat - navigate to chat screen
  Future<void> _resumeBot(Map<String, dynamic> bot) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StudyPlanChatScreen(
          botId: bot['bot_id'],
          botName: bot['name'],
          planName: bot['topic'],
          planDescription: bot['description'],
          systemInstructions: bot['system_instructions'],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDarkMode
              ? [
                  AppTheme.backgroundGradientStart,
                  AppTheme.backgroundGradientEnd,
                ]
              : [Color(0xFFFAFAFA), Color(0xFFF5F5F5)],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            'My Study Bots',
            style: TextStyle(
              color: isDarkMode ? Colors.white : Color(0xFF000000),
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: isDarkMode
              ? AppTheme.primaryBlue
              : Color(0xFFFFFFFF),
          elevation: 0,
          iconTheme: IconThemeData(
            color: isDarkMode ? Colors.white : Color(0xFF1F2937),
          ),
          flexibleSpace: Container(
            decoration: BoxDecoration(
              color: isDarkMode ? AppTheme.primaryBlue : Color(0xFFFFFFFF),
              border: Border(
                bottom: BorderSide(
                  color: isDarkMode ? Colors.transparent : Color(0xFFE5E7EB),
                  width: 0.5,
                ),
              ),
            ),
          ),
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
        ),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppTheme.primaryBlue.withOpacity(0.5)
                  : AppTheme.primaryBlue.withOpacity(0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'Error loading bots',
              style: AppTheme.headlineMedium.copyWith(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppTheme.primaryBlue
                    : Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage,
              style: AppTheme.bodyMedium.copyWith(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppTheme.textSecondary
                    : Color(0xFF6B7280),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadRecentBots,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: const Text('Retry', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }

    if (_bots.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.school_outlined,
              size: 64,
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppTheme.primaryBlue.withOpacity(0.5)
                  : AppTheme.primaryBlue.withOpacity(0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'No Study Bots Yet',
              style: AppTheme.headlineMedium.copyWith(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppTheme.primaryBlue
                    : Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first study bot to get started!',
              style: AppTheme.bodyMedium.copyWith(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppTheme.textSecondary
                    : Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadRecentBots,
      color: AppTheme.primaryBlue,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _bots.length,
        itemBuilder: (context, index) => _buildBotCard(_bots[index], index),
      ),
    );
  }

  Widget _buildBotCard(Map<String, dynamic> bot, int index) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final lastMessage = bot['last_message'] as String?;
    final lastMessageTime = bot['last_message_time'] as Timestamp?;
    final progressPercentage =
        (bot['progress_percentage'] as num?)?.toDouble() ?? 0.0;
    final messageCount = bot['message_count'] as int? ?? 0;

    String timeText = '';
    if (lastMessageTime != null) {
      final now = DateTime.now();
      final diff = now.difference(lastMessageTime.toDate());

      if (diff.inMinutes < 1) {
        timeText = 'Just now';
      } else if (diff.inHours < 1) {
        timeText = '${diff.inMinutes}m ago';
      } else if (diff.inDays < 1) {
        timeText = '${diff.inHours}h ago';
      } else {
        timeText = '${diff.inDays}d ago';
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: isDarkMode ? null : Color(0xFFFFFFFF),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDarkMode ? AppTheme.surfaceElevated : Color(0xFFE5E7EB),
          width: 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _resumeBot(bot),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.school,
                      color: AppTheme.primaryBlue,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          bot['name'] ?? 'Untitled Bot',
                          style: AppTheme.headlineSmall.copyWith(
                            color: isDarkMode
                                ? AppTheme.textPrimary
                                : Color(0xFF000000),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          bot['topic'] ?? 'No topic',
                          style: AppTheme.bodySmall.copyWith(
                            color: isDarkMode
                                ? AppTheme.textSecondary
                                : Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert,
                      color: isDarkMode
                          ? AppTheme.textSecondary
                          : Color(0xFF6B7280),
                    ),
                    onSelected: (value) {
                      if (value == 'rename') {
                        _renameBot(bot, index);
                      } else if (value == 'delete') {
                        _showDeleteConfirmation(bot, index);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'rename',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 18),
                            SizedBox(width: 8),
                            Text('Rename'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 18, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (lastMessage != null && lastMessage.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDarkMode ? Color(0xFF2A2A2A) : Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    lastMessage,
                    style: AppTheme.bodySmall.copyWith(
                      color: isDarkMode
                          ? AppTheme.textSecondary
                          : Color(0xFF6B7280),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  // Progress indicator
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Progress: ${progressPercentage.toStringAsFixed(0)}%',
                          style: AppTheme.bodySmall.copyWith(
                            color: AppTheme.primaryBlue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progressPercentage / 100,
                            minHeight: 4,
                            backgroundColor: AppTheme.primaryBlue.withOpacity(
                              0.2,
                            ),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppTheme.primaryBlue,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Stats
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$messageCount messages',
                        style: AppTheme.bodySmall.copyWith(
                          color: isDarkMode
                              ? AppTheme.textSecondary
                              : Color(0xFF6B7280),
                        ),
                      ),
                      if (timeText.isNotEmpty) const SizedBox(height: 2),
                      if (timeText.isNotEmpty)
                        Text(
                          timeText,
                          style: AppTheme.bodySmall.copyWith(
                            color: isDarkMode
                                ? AppTheme.textSecondary
                                : Color(0xFF9CA3AF),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmation(Map<String, dynamic> bot, int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Bot'),
        content: Text(
          'Are you sure you want to delete "${bot['name']}"? This will permanently delete all messages and progress.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteBot(index, bot['bot_id']);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
