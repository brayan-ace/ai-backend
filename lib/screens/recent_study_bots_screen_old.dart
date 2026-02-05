import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/theme.dart';
import 'study_plan_chat_screen.dart';

class RecentStudyBotsScreen extends StatefulWidget {
  const RecentStudyBotsScreen({Key? key}) : super(key: key);

  @override
  State<RecentStudyBotsScreen> createState() => _RecentStudyBotsScreenState();
}

class _RecentStudyBotsScreenState extends State<RecentStudyBotsScreen> {
  List<Map<String, dynamic>> _bots = [];
  bool _isLoading = true;
  String _errorMessage = '';

  static const String _backendUrl =
      'https://ai-backend-production-65d6.up.railway.app';

  @override
  void initState() {
    super.initState();
    _loadRecentBots();
  }

  Future<void> _loadRecentBots() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _errorMessage = 'Not authenticated';
          _isLoading = false;
        });
        return;
      }

      final uri = Uri.parse('$_backendUrl/api/user-bots/${user.uid}');
      final response = await http.get(uri).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final bots = (body['bots'] as List? ?? [])
            .map((b) => Map<String, dynamic>.from(b as Map))
            .toList();

        setState(() {
          _bots = bots;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load bots (${response.statusCode})';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteBot(int index, String botId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final uri = Uri.parse('$_backendUrl/api/delete-bot/$botId');
      final response = await http
          .delete(uri)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        setState(() {
          _bots.removeAt(index);
        });
        // Silent delete - no notification shown
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

  Future<void> _renameBot(Map<String, dynamic> bot, int index) async {
    final TextEditingController controller = TextEditingController(
      text: bot['name'] ?? '',
    );

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceCard,
        title: Text(
          'Rename Bot',
          style: AppTheme.headlineSmall.copyWith(color: AppTheme.textPrimary),
        ),
        content: TextField(
          controller: controller,
          style: AppTheme.bodyMedium.copyWith(color: AppTheme.textPrimary),
          decoration: InputDecoration(
            hintText: 'Enter new name',
            hintStyle: AppTheme.bodyMedium.copyWith(
              color: AppTheme.textSecondary,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              borderSide: BorderSide(color: AppTheme.primaryBlue),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              borderSide: BorderSide(
                color: AppTheme.primaryBlue.withOpacity(0.5),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              borderSide: BorderSide(color: AppTheme.primaryBlue, width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty && newName != bot['name']) {
                try {
                  final botId = bot['bot_id'] as String?;
                  if (botId != null) {
                    final uri = Uri.parse('$_backendUrl/api/rename-bot/$botId');
                    final response = await http
                        .post(
                          uri,
                          headers: {'Content-Type': 'application/json'},
                          body: jsonEncode({'name': newName}),
                        )
                        .timeout(const Duration(seconds: 15));

                    if (response.statusCode == 200) {
                      setState(() {
                        _bots[index]['name'] = newName;
                      });
                      if (mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Bot renamed successfully'),
                            backgroundColor: Colors.green,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    } else {
                      if (mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Failed to rename bot'),
                            backgroundColor: Colors.red,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    }
                  }
                } catch (e) {
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: Colors.red,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                }
              } else {
                Navigator.pop(context);
              }
            },
            child: Text(
              'Rename',
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.primaryBlue,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _resumeBot(Map<String, dynamic> bot) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => StudyPlanChatScreen(
          botId: bot['bot_id'] as String?,
          botName: bot['name'] as String?,
          planName: bot['name'] as String?,
          planDescription: bot['description'] as String?,
          educationLevel: bot['grade_level'] as String?,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDeep,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppTheme.primaryBlue),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Study Bots',
          style: AppTheme.headlineSmall.copyWith(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 24,
          ),
        ),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: AppTheme.primaryBlue,
                strokeWidth: 2.5,
              ),
            )
          : _errorMessage.isNotEmpty
          ? _buildErrorState()
          : _bots.isEmpty
          ? _buildEmptyState()
          : _buildBotsList(),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red.withOpacity(0.6),
          ),
          SizedBox(height: AppTheme.spaceMd),
          Text(
            _errorMessage,
            style: AppTheme.bodyMedium.copyWith(
              color: Colors.red,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: AppTheme.spaceMd),
          ElevatedButton.icon(
            onPressed: _loadRecentBots,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                horizontal: AppTheme.spaceLg,
                vertical: AppTheme.spaceMd,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(AppTheme.spaceLg),
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.smart_toy_outlined,
              size: 64,
              color: AppTheme.primaryBlue.withOpacity(0.6),
            ),
          ),
          SizedBox(height: AppTheme.spaceMd),
          Text(
            'No Study Bots Yet',
            style: AppTheme.headlineSmall.copyWith(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          SizedBox(height: AppTheme.spaceSm),
          Text(
            'Create your first study bot to get started',
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBotsList() {
    return ListView.builder(
      padding: EdgeInsets.all(AppTheme.spaceMd),
      itemCount: _bots.length,
      itemBuilder: (context, index) {
        final bot = _bots[index];
        return Dismissible(
          key: Key(bot['bot_id'] as String? ?? 'bot_$index'),
          direction: DismissDirection.endToStart,
          background: Container(
            margin: EdgeInsets.only(bottom: AppTheme.spaceMd),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryBlue.withOpacity(0.1),
                  AppTheme.primaryBlue.withOpacity(0.8),
                ],
              ),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            alignment: Alignment.centerRight,
            padding: EdgeInsets.only(right: AppTheme.spaceLg),
            child: const Icon(
              Icons.delete_outline,
              color: Colors.white,
              size: 24,
            ),
          ),
          onDismissed: (direction) {
            _deleteBot(index, bot['bot_id'] as String? ?? '');
          },
          child: _buildBotCard(bot, index),
        );
      },
    );
  }

  Widget _buildBotCard(Map<String, dynamic> bot, int index) {
    return Container(
      margin: EdgeInsets.only(bottom: AppTheme.spaceMd),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _resumeBot(bot),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          splashColor: AppTheme.primaryBlue.withOpacity(0.1),
          highlightColor: AppTheme.primaryBlue.withOpacity(0.05),
          child: Padding(
            padding: EdgeInsets.all(AppTheme.spaceMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Bot Icon
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.primaryBlue.withOpacity(0.15),
                            AppTheme.primaryBlue.withOpacity(0.05),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.smart_toy,
                        color: AppTheme.primaryBlue,
                        size: 26,
                      ),
                    ),
                    SizedBox(width: AppTheme.spaceMd),
                    // Bot Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  bot['name'] ?? 'Unnamed Bot',
                                  style: AppTheme.bodyMedium.copyWith(
                                    color: AppTheme.textPrimary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              PopupMenuButton(
                                color: AppTheme.surfaceCard,
                                itemBuilder: (context) => [
                                  PopupMenuItem(
                                    onTap: () {
                                      Future.delayed(
                                        const Duration(milliseconds: 200),
                                        () => _renameBot(bot, index),
                                      );
                                    },
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.edit_outlined,
                                          color: AppTheme.primaryBlue,
                                          size: 18,
                                        ),
                                        SizedBox(width: AppTheme.spaceSm),
                                        Text(
                                          'Rename',
                                          style: AppTheme.bodySmall.copyWith(
                                            color: AppTheme.textPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    left: AppTheme.spaceSm,
                                  ),
                                  child: Icon(
                                    Icons.more_vert,
                                    color: AppTheme.textSecondary,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 4),
                          Text(
                            bot['topic'] ?? 'No topic',
                            style: AppTheme.bodySmall.copyWith(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: AppTheme.spaceSm),
                    Icon(
                      Icons.arrow_forward_ios,
                      color: AppTheme.primaryBlue.withOpacity(0.6),
                      size: 16,
                    ),
                  ],
                ),
                // Last Message Preview
                if (bot['last_message'] != null &&
                    (bot['last_message'] as String).isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(top: AppTheme.spaceSm, left: 50),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        bot['last_message'] ?? '',
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.textSecondary,
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                // Progress and Grade Level Row
                Padding(
                  padding: EdgeInsets.only(top: AppTheme.spaceSm, left: 50),
                  child: Row(
                    children: [
                      // Progress indicator
                      if (bot['progress_percentage'] != null &&
                          (bot['progress_percentage'] as num) > 0) ...[
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryBlue.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.trending_up,
                                size: 12,
                                color: AppTheme.primaryBlue,
                              ),
                              SizedBox(width: 4),
                              Text(
                                '${(bot['progress_percentage'] as num).toInt()}%',
                                style: AppTheme.bodySmall.copyWith(
                                  color: AppTheme.primaryBlue,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 8),
                      ],
                      Icon(
                        Icons.school_outlined,
                        size: 13,
                        color: AppTheme.textSecondary.withOpacity(0.6),
                      ),
                      SizedBox(width: 6),
                      Text(
                        bot['grade_level'] ?? 'N/A',
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.textSecondary.withOpacity(0.7),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
