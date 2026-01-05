import 'package:flutter/material.dart';
import '../services/chat_storage_service.dart';
import '../utils/theme.dart';

class ChatHistoryScreen extends StatefulWidget {
  const ChatHistoryScreen({super.key});

  @override
  State<ChatHistoryScreen> createState() => _ChatHistoryScreenState();
}

class _ChatHistoryScreenState extends State<ChatHistoryScreen> {
  final ChatStorageService _chatStorage = ChatStorageService();
  List<Map<String, dynamic>> _chats = [];
  List<Map<String, dynamic>> _filteredChats = [];
  String _searchQuery = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadChats();
  }

  Future<void> _loadChats() async {
    setState(() => _isLoading = true);
    try {
      final chats = await _chatStorage.getChats().first;
      setState(() {
        _chats = chats;
        _filteredChats = chats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _filterChats(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredChats = _chats;
      } else {
        _filteredChats = _chats
            .where(
              (chat) =>
                  (chat['title'] ?? '').toLowerCase().contains(
                    query.toLowerCase(),
                  ) ||
                  (chat['lastMessage'] ?? '').toLowerCase().contains(
                    query.toLowerCase(),
                  ),
            )
            .toList();
      }
    });
  }

  void _openChat(String chatId) {
    Navigator.pop(context, chatId);
  }

  String _formatTimestamp(dynamic timestamp) {
    try {
      DateTime date;
      if (timestamp is DateTime) {
        date = timestamp;
      } else {
        date = DateTime.parse(timestamp.toString());
      }

      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'Recently';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.backgroundGradientStart,
            AppTheme.backgroundGradientEnd,
          ],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: AppTheme.glassGradient),
              border: Border(
                bottom: BorderSide(
                  color: AppTheme.surfaceElevated.withOpacity(0.15),
                  width: 0.5,
                ),
              ),
            ),
          ),
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: AppTheme.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          title: ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: AppTheme.primaryGradient,
            ).createShader(bounds),
            child: Text(
              'Chat History',
              style: AppTheme.headlineMedium.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Search Bar
              Padding(
                padding: EdgeInsets.all(AppTheme.spaceMd),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceCard,
                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                    border: Border.all(
                      color: AppTheme.surfaceElevated.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: TextField(
                    onChanged: _filterChats,
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search chats...',
                      hintStyle: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.textTertiary,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: AppTheme.textSecondary,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: AppTheme.spaceMd,
                        vertical: AppTheme.spaceMd,
                      ),
                    ),
                  ),
                ),
              ),

              // Chat List
              Expanded(
                child: _isLoading
                    ? Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppTheme.primaryBlue,
                          ),
                        ),
                      )
                    : _filteredChats.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: EdgeInsets.all(AppTheme.spaceLg),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: AppTheme.surfaceGradient,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _searchQuery.isEmpty
                                    ? Icons.chat_bubble_outline
                                    : Icons.search_off,
                                size: 64,
                                color: AppTheme.textTertiary,
                              ),
                            ),
                            SizedBox(height: AppTheme.spaceLg),
                            Text(
                              _searchQuery.isEmpty
                                  ? 'No chats yet'
                                  : 'No results found',
                              style: AppTheme.headlineMedium.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            SizedBox(height: AppTheme.spaceSm),
                            Text(
                              _searchQuery.isEmpty
                                  ? 'Start a conversation to see it here'
                                  : 'Try a different search term',
                              style: AppTheme.bodyMedium.copyWith(
                                color: AppTheme.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppTheme.spaceMd,
                        ),
                        itemCount: _filteredChats.length,
                        itemBuilder: (context, index) {
                          final chat = _filteredChats[index];
                          final isStarred = chat['isStarred'] ?? false;

                          return Container(
                            margin: EdgeInsets.only(bottom: AppTheme.spaceMd),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: AppTheme.surfaceGradient,
                              ),
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusLg,
                              ),
                              border: Border.all(
                                color: AppTheme.surfaceElevated.withOpacity(
                                  0.5,
                                ),
                                width: 1,
                              ),
                              boxShadow: AppTheme.cardShadow,
                            ),
                            child: InkWell(
                              onTap: () => _openChat(chat['id']),
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusLg,
                              ),
                              child: Padding(
                                padding: EdgeInsets.all(AppTheme.spaceMd),
                                child: Row(
                                  children: [
                                    // Chat Icon
                                    Container(
                                      padding: EdgeInsets.all(AppTheme.spaceSm),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: isStarred
                                              ? [Colors.amber, Colors.orange]
                                              : AppTheme.primaryGradient,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          AppTheme.radiusSm,
                                        ),
                                      ),
                                      child: Icon(
                                        isStarred
                                            ? Icons.star
                                            : Icons.chat_bubble,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                    SizedBox(width: AppTheme.spaceMd),

                                    // Chat Info
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            chat['title'] ?? 'Untitled Chat',
                                            style: AppTheme.headlineSmall
                                                .copyWith(
                                                  color: AppTheme.textPrimary,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            chat['lastMessage'] ??
                                                'No messages yet',
                                            style: AppTheme.bodySmall.copyWith(
                                              color: AppTheme.textSecondary,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Timestamp & Arrow
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          _formatTimestamp(chat['timestamp']),
                                          style: AppTheme.bodySmall.copyWith(
                                            color: AppTheme.textTertiary,
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Icon(
                                          Icons.chevron_right,
                                          color: AppTheme.textTertiary,
                                          size: 20,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
