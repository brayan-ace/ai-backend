import 'package:flutter/material.dart';
import 'dart:async';
import '../utils/theme.dart';
import '../services/notes_service.dart';

class NotesScreen extends StatefulWidget {
  final bool accessedViaSwipe;

  const NotesScreen({super.key, this.accessedViaSwipe = false});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> with WidgetsBindingObserver {
  final NotesService _notesService = NotesService();
  List<SavedNote> _allNotes = [];
  bool _isLoading = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Initial load
    _loadNotes();
    // Start periodic refresh every 2 seconds
    _startAutoRefresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(Duration(seconds: 2), (_) {
      if (mounted) {
        _loadNotes();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Reload notes when app comes back into focus
      _loadNotes();
    }
  }

  Future<void> _loadNotes() async {
    print('[NotesScreen] DEBUG: _loadNotes() called');
    if (!mounted) return;

    if (!_isLoading) {
      setState(() => _isLoading = true);
    }
    try {
      print('[NotesScreen] DEBUG: Calling NotesService.getAllNotes()');
      final notes = await _notesService.getAllNotes();
      print('[NotesScreen] DEBUG: Received ${notes.length} notes from service');
      for (final note in notes) {
        print('[NotesScreen] DEBUG: - Note: "${note.title}" (id: ${note.id})');
      }
      if (mounted) {
        setState(() {
          _allNotes = notes;
          _isLoading = false;
        });
        print(
          '[NotesScreen] DEBUG: State updated, _allNotes.length = ${_allNotes.length}',
        );
      }
    } catch (e) {
      print('[NotesScreen] ❌ Error loading notes: $e');
      print('[NotesScreen] ❌ Stack trace: ${StackTrace.current}');
    }
  }

  @override
  void didUpdateWidget(NotesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload when widget is updated
    _loadNotes();
  }

  void _createNote() {
    _showNoteEditor();
  }

  /// Open the premium note editor for manual notes
  void _showNoteEditor() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PremiumNoteEditorScreen(
          onSave: (title, content) async {
            try {
              await _notesService.saveManualNote(
                title: title,
                content: content,
              );
              _loadNotes();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Note saved! 📝'),
                    backgroundColor: AppTheme.success,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error saving note: $e'),
                    backgroundColor: AppTheme.error,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            }
          },
        ),
      ),
    );
  }

  void _editNote(SavedNote note) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PremiumNoteEditorScreen(
          initialTitle: note.title,
          initialContent: note.content,
          onSave: (title, content) async {
            try {
              await _notesService.updateNote(
                note.copyWith(title: title, content: content),
              );
              _loadNotes();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Note updated! 📝'),
                    backgroundColor: AppTheme.success,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error updating note: $e'),
                    backgroundColor: AppTheme.error,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            }
          },
        ),
      ),
    );
  }

  Future<void> _deleteNote(SavedNote note) async {
    try {
      await _notesService.deleteNote(note.id);
      _loadNotes();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Note deleted'),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting note: $e'),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.backgroundGradientStartFromContext(context),
            AppTheme.backgroundGradientEndFromContext(context),
          ],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: isLandscape
              ? _buildLandscapeLayout(context)
              : _buildPortraitLayout(context),
        ),
      ),
    );
  }

  Widget _buildPortraitLayout(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.all(AppTheme.spaceMd),
          child: Row(
            children: [
              // Back button only appears when accessed via swipe gesture
              if (widget.accessedViaSwipe)
                IconButton(
                  icon: Icon(
                    Icons.arrow_back,
                    color: AppTheme.textPrimary,
                    size: 24,
                  ),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(),
                ),
              if (widget.accessedViaSwipe) SizedBox(width: AppTheme.spaceSm),
              Expanded(
                child: ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: AppTheme.accentGradient,
                  ).createShader(bounds),
                  child: Text(
                    'Notes',
                    style: AppTheme.displayMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimaryFromContext(context),
                    ),
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: AppTheme.primaryGradient,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: AppTheme.glowShadow,
                ),
                child: IconButton(
                  icon: Icon(
                    Icons.add,
                    color: AppTheme.textPrimaryFromContext(context),
                    size: 28,
                  ),
                  onPressed: _createNote,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppTheme.primaryBlue,
                    ),
                  ),
                )
              : _allNotes.isEmpty
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
                          Icons.note_add_outlined,
                          size: 64,
                          color: AppTheme.textTertiary,
                        ),
                      ),
                      SizedBox(height: AppTheme.spaceLg),
                      Text(
                        'No Notes Yet',
                        style: AppTheme.headlineMedium.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      SizedBox(height: AppTheme.spaceSm),
                      Text(
                        'Save messages from chats or create manual notes',
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.textTertiary,
                        ),
                      ),
                    ],
                  ),
                )
              : _buildNotesList(),
        ),
      ],
    );
  }

  Widget _buildLandscapeLayout(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Compact header for landscape
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppTheme.spaceMd,
            vertical: AppTheme.spaceSm,
          ),
          child: Row(
            children: [
              // Back button only appears when accessed via swipe gesture
              if (widget.accessedViaSwipe)
                IconButton(
                  icon: Icon(
                    Icons.arrow_back,
                    color: AppTheme.textPrimary,
                    size: 20,
                  ),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(),
                ),
              if (widget.accessedViaSwipe) SizedBox(width: AppTheme.spaceSm),
              Expanded(
                child: ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: AppTheme.accentGradient,
                  ).createShader(bounds),
                  child: Text(
                    'Notes',
                    style: AppTheme.headlineSmall.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimaryFromContext(context),
                    ),
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: AppTheme.primaryGradient,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: AppTheme.glowShadow,
                ),
                child: IconButton(
                  icon: Icon(
                    Icons.add,
                    color: AppTheme.textPrimaryFromContext(context),
                    size: 24,
                  ),
                  onPressed: _createNote,
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(minWidth: 40, minHeight: 40),
                ),
              ),
            ],
          ),
        ),
        // Scrollable content area for landscape
        Expanded(
          child: _isLoading
              ? Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppTheme.primaryBlue,
                    ),
                  ),
                )
              : _allNotes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: EdgeInsets.all(AppTheme.spaceMd),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: AppTheme.surfaceGradient,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.note_add_outlined,
                          size: 48,
                          color: AppTheme.textTertiary,
                        ),
                      ),
                      SizedBox(height: AppTheme.spaceMd),
                      Text(
                        'No Notes Yet',
                        style: AppTheme.bodyLarge.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                )
              : _buildNotesListLandscape(),
        ),
      ],
    );
  }

  Widget _buildNotesListLandscape() {
    return GridView.builder(
      padding: EdgeInsets.symmetric(horizontal: AppTheme.spaceMd),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.5,
        mainAxisSpacing: AppTheme.spaceMd,
        crossAxisSpacing: AppTheme.spaceMd,
      ),
      itemCount: _allNotes.length,
      itemBuilder: (context, index) {
        final note = _allNotes[index];
        return Dismissible(
          key: Key(note.id),
          direction: DismissDirection.endToStart,
          background: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryBlue.withOpacity(0.1),
                  AppTheme.primaryBlue.withOpacity(0.8),
                ],
              ),
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            ),
            alignment: Alignment.centerRight,
            padding: EdgeInsets.only(right: AppTheme.spaceLg),
            child: Icon(
              Icons.delete_outline,
              color: AppTheme.textPrimaryFromContext(context),
              size: 24,
            ),
          ),
          onDismissed: (_) => _deleteNote(note),
          child: GestureDetector(
            onTap: () => _editNote(note),
            child: _buildNoteCardCompact(note),
          ),
        );
      },
    );
  }

  Widget _buildNotesList() {
    return ListView.builder(
      padding: EdgeInsets.symmetric(
        horizontal: AppTheme.spaceMd,
        vertical: AppTheme.spaceMd,
      ),
      itemCount: _allNotes.length,
      itemBuilder: (context, index) {
        final note = _allNotes[index];
        return Dismissible(
          key: Key(note.id),
          direction: DismissDirection.endToStart,
          background: Container(
            margin: EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryBlue.withOpacity(0.1),
                  AppTheme.primaryBlue.withOpacity(0.8),
                ],
              ),
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            ),
            alignment: Alignment.centerRight,
            padding: EdgeInsets.only(right: AppTheme.spaceLg),
            child: Icon(
              Icons.delete_outline,
              color: AppTheme.textPrimaryFromContext(context),
              size: 28,
            ),
          ),
          onDismissed: (_) => _deleteNote(note),
          child: GestureDetector(
            onTap: () => _editNote(note),
            child: _buildNoteCardCompact(note),
          ),
        );
      },
    );
  }

  Widget _buildNoteCardCompact(SavedNote note) {
    final sourceInfo = _getSourceInfo(note.source);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  AppTheme.surfaceCard.withOpacity(0.8),
                  AppTheme.surfaceCard.withOpacity(0.5),
                ]
              : [Colors.white.withOpacity(0.9), Colors.white.withOpacity(0.7)],
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: isDark
              ? AppTheme.primaryBlue.withOpacity(0.1)
              : Colors.grey.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.2)
                : Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(AppTheme.spaceSm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Source badge
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: sourceInfo['color'].withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: sourceInfo['color'].withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        sourceInfo['icon'],
                        size: 10,
                        color: sourceInfo['color'],
                      ),
                      SizedBox(width: 3),
                      Text(
                        sourceInfo['label'],
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w600,
                          color: sourceInfo['color'],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 6),

            // Title
            Text(
              note.title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? AppTheme.textPrimary : Colors.black,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 4),

            // Preview
            Text(
              note.content,
              style: TextStyle(
                fontSize: 10,
                color: isDark ? AppTheme.textSecondary : Colors.black87,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _getSourceInfo(String source) {
    switch (source) {
      case 'chat_message':
        return {
          'label': 'From Chat',
          'icon': Icons.message_outlined,
          'color': AppTheme.success,
        };
      case 'chat_history':
        return {
          'label': 'Full Chat',
          'icon': Icons.chat_outlined,
          'color': AppTheme.accentBlue,
        };
      case 'manual':
      default:
        return {
          'label': 'Manual',
          'icon': Icons.edit_outlined,
          'color': AppTheme.primaryBlue,
        };
    }
  }
}

/// Premium note editor screen
class PremiumNoteEditorScreen extends StatefulWidget {
  final String? initialTitle;
  final String? initialContent;
  final Function(String title, String content) onSave;

  const PremiumNoteEditorScreen({
    Key? key,
    this.initialTitle,
    this.initialContent,
    required this.onSave,
  }) : super(key: key);

  @override
  State<PremiumNoteEditorScreen> createState() =>
      _PremiumNoteEditorScreenState();
}

class _PremiumNoteEditorScreenState extends State<PremiumNoteEditorScreen> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle ?? '');
    _contentController = TextEditingController(
      text: widget.initialContent ?? '',
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter a title'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      widget.onSave(_titleController.text, _contentController.text);
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
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
            AppTheme.backgroundGradientStartFromContext(context),
            AppTheme.backgroundGradientEndFromContext(context),
          ],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: AppTheme.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Create Note',
            style: TextStyle(color: AppTheme.textPrimary),
          ),
          actions: [
            Padding(
              padding: EdgeInsets.only(right: AppTheme.spaceMd),
              child: Center(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _isSaving ? null : _handleSave,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: _isSaving
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppTheme.success,
                                ),
                              ),
                            )
                          : Text(
                              'Save',
                              style: TextStyle(
                                color: AppTheme.success,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(AppTheme.spaceMd),
            child: Column(
              children: [
                // Title field
                TextField(
                  controller: _titleController,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Note title',
                    hintStyle: TextStyle(
                      color: AppTheme.textTertiary,
                      fontSize: 20,
                    ),
                    border: InputBorder.none,
                  ),
                ),
                SizedBox(height: AppTheme.spaceLg),

                // Content field
                Expanded(
                  child: TextField(
                    controller: _contentController,
                    maxLines: null,
                    expands: true,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textPrimary,
                      height: 1.6,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Start typing...',
                      hintStyle: TextStyle(color: AppTheme.textTertiary),
                      border: InputBorder.none,
                    ),
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
