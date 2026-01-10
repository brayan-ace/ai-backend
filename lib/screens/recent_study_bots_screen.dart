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

  static const String _backendUrl = 'https://ai-backend-vf75.onrender.com';

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
          'Recent Study Bots',
          style: AppTheme.headlineSmall.copyWith(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: AppTheme.primaryBlue),
            )
          : _errorMessage.isNotEmpty
          ? Center(
              child: Text(
                _errorMessage,
                style: AppTheme.bodyMedium.copyWith(color: Colors.red),
              ),
            )
          : _bots.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inbox_outlined,
                    size: 64,
                    color: AppTheme.textSecondary.withOpacity(0.5),
                  ),
                  SizedBox(height: AppTheme.spaceMd),
                  Text(
                    'No study bots yet',
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: EdgeInsets.all(AppTheme.spaceMd),
              itemCount: _bots.length,
              itemBuilder: (context, index) {
                final bot = _bots[index];
                return Padding(
                  padding: EdgeInsets.only(bottom: AppTheme.spaceMd),
                  child: GestureDetector(
                    onTap: () => _resumeBot(bot),
                    child: Container(
                      padding: EdgeInsets.all(AppTheme.spaceMd),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceCard,
                        border: Border.all(
                          color: AppTheme.primaryBlue.withOpacity(0.2),
                        ),
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryBlue.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.smart_toy,
                                  color: AppTheme.primaryBlue,
                                  size: 24,
                                ),
                              ),
                              SizedBox(width: AppTheme.spaceMd),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      bot['name'] ?? 'Unnamed Bot',
                                      style: AppTheme.bodyMedium.copyWith(
                                        color: AppTheme.textPrimary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      bot['topic'] ?? 'No topic',
                                      style: AppTheme.bodySmall.copyWith(
                                        color: AppTheme.textSecondary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward_ios,
                                color: AppTheme.primaryBlue,
                                size: 18,
                              ),
                            ],
                          ),
                          if (bot['description'] != null)
                            Padding(
                              padding: EdgeInsets.only(top: AppTheme.spaceSm),
                              child: Text(
                                bot['description'] ?? '',
                                style: AppTheme.bodySmall.copyWith(
                                  color: AppTheme.textSecondary,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          Padding(
                            padding: EdgeInsets.only(top: AppTheme.spaceSm),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.school_outlined,
                                  size: 14,
                                  color: AppTheme.textSecondary,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  bot['grade_level'] ?? 'N/A',
                                  style: AppTheme.bodySmall.copyWith(
                                    color: AppTheme.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
