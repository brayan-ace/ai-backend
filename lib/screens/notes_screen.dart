import 'package:flutter/material.dart';
import '../utils/theme.dart';

class Note {
  final String title;
  final String content;
  final DateTime timestamp;

  Note({required this.title, required this.content, required this.timestamp});
}

class NotesScreen extends StatefulWidget {
  final bool accessedViaSwipe;

  const NotesScreen({super.key, this.accessedViaSwipe = false});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final List<Note> _notes = [
    Note(
      title: 'Welcome to Notes',
      content:
          'This is your personal note-taking space. Tap + to create a new note.',
      timestamp: DateTime.now().subtract(Duration(hours: 2)),
    ),
  ];

  void _createNote() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NoteEditorScreen(
          onSave: (title, content) {
            setState(() {
              _notes.insert(
                0,
                Note(title: title, content: content, timestamp: DateTime.now()),
              );
            });
          },
        ),
      ),
    );
  }

  void _editNote(int index) {
    final note = _notes[index];
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NoteEditorScreen(
          initialTitle: note.title,
          initialContent: note.content,
          onSave: (title, content) {
            setState(() {
              _notes[index] = Note(
                title: title,
                content: content,
                timestamp: DateTime.now(),
              );
            });
          },
        ),
      ),
    );
  }

  void _deleteNote(int index) {
    setState(() {
      _notes.removeAt(index);
    });
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
        body: SafeArea(
          child: Column(
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
                    if (widget.accessedViaSwipe)
                      SizedBox(width: AppTheme.spaceSm),
                    Expanded(
                      child: ShaderMask(
                        shaderCallback: (bounds) => LinearGradient(
                          colors: AppTheme.accentGradient,
                        ).createShader(bounds),
                        child: Text(
                          'Notes',
                          style: AppTheme.displayMedium.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
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
                        icon: Icon(Icons.add, color: Colors.black, size: 28),
                        onPressed: _createNote,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _notes.isEmpty
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
                              'No notes yet',
                              style: AppTheme.headlineMedium.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            SizedBox(height: AppTheme.spaceSm),
                            Text(
                              'Tap + to create your first note',
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
                        itemCount: _notes.length,
                        itemBuilder: (context, index) {
                          final note = _notes[index];
                          return Dismissible(
                            key: Key(note.timestamp.toString()),
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
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radiusLg,
                                ),
                              ),
                              alignment: Alignment.centerRight,
                              padding: EdgeInsets.only(right: AppTheme.spaceLg),
                              child: Icon(
                                Icons.delete_outline,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            onDismissed: (_) => _deleteNote(index),
                            child: GestureDetector(
                              onTap: () => _editNote(index),
                              child: Container(
                                margin: EdgeInsets.only(
                                  bottom: AppTheme.spaceMd,
                                ),
                                padding: EdgeInsets.all(AppTheme.spaceMd),
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
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            note.title,
                                            style: AppTheme.headlineMedium
                                                .copyWith(
                                                  color: AppTheme.textPrimary,
                                                ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Container(
                                          padding: EdgeInsets.all(
                                            AppTheme.spaceXs,
                                          ),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: AppTheme.accentGradient,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              AppTheme.radiusSm,
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.edit,
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: AppTheme.spaceSm),
                                    Text(
                                      note.content,
                                      style: AppTheme.bodyMedium.copyWith(
                                        color: AppTheme.textSecondary,
                                      ),
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    SizedBox(height: AppTheme.spaceSm),
                                    Text(
                                      _formatTimestamp(note.timestamp),
                                      style: AppTheme.bodySmall.copyWith(
                                        color: AppTheme.textTertiary,
                                      ),
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

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
  }
}

class NoteEditorScreen extends StatefulWidget {
  final String? initialTitle;
  final String? initialContent;
  final Function(String title, String content) onSave;

  const NoteEditorScreen({
    super.key,
    this.initialTitle,
    this.initialContent,
    required this.onSave,
  });

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;

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

  void _save() {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty && content.isEmpty) {
      Navigator.pop(context);
      return;
    }

    widget.onSave(title.isEmpty ? 'Untitled Note' : title, content);
    Navigator.pop(context);
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
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: AppTheme.glassGradient),
              border: Border(
                bottom: BorderSide(
                  color: AppTheme.surfaceElevated.withOpacity(0.3),
                  width: 0.5,
                ),
              ),
            ),
          ),
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: AppTheme.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            Container(
              margin: EdgeInsets.only(right: AppTheme.spaceSm),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: AppTheme.primaryGradient,
                ),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                boxShadow: AppTheme.glowShadow,
              ),
              child: TextButton(
                onPressed: _save,
                child: Text(
                  'Save',
                  style: AppTheme.labelLarge.copyWith(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
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
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceElevated,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  child: TextField(
                    controller: _titleController,
                    style: AppTheme.headlineLarge.copyWith(
                      color: AppTheme.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Note Title',
                      hintStyle: AppTheme.headlineLarge.copyWith(
                        color: AppTheme.textTertiary,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(AppTheme.spaceMd),
                    ),
                  ),
                ),
                SizedBox(height: AppTheme.spaceMd),
                // AI Suggestion Buttons
                Row(
                  children: [
                    Expanded(
                      child: _buildAiButton(
                        icon: Icons.auto_awesome,
                        title: 'Generate Notes',
                        gradient: AppTheme.primaryGradient,
                        onTap: () {
                          // TODO: Implement AI note generation
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'AI Note Generation - Coming Soon!',
                              ),
                              backgroundColor: AppTheme.primaryBlue,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                      ),
                    ),
                    SizedBox(width: AppTheme.spaceSm),
                    Expanded(
                      child: _buildAiButton(
                        icon: Icons.summarize,
                        title: 'Summarize Notes',
                        gradient: AppTheme.accentGradient,
                        onTap: () {
                          // TODO: Implement AI summarization
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('AI Summarization - Coming Soon!'),
                              backgroundColor: AppTheme.accentBlue,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                SizedBox(height: AppTheme.spaceMd),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceElevated,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                    child: TextField(
                      controller: _contentController,
                      style: AppTheme.bodyLarge.copyWith(
                        color: AppTheme.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Start typing...',
                        hintStyle: AppTheme.bodyLarge.copyWith(
                          color: AppTheme.textTertiary,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(AppTheme.spaceMd),
                      ),
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
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

  Widget _buildAiButton({
    required IconData icon,
    required String title,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: AppTheme.spaceSm,
          vertical: AppTheme.spaceSm,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradient,
          ),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          boxShadow: [
            BoxShadow(
              color: gradient[0].withOpacity(0.3),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: gradient == AppTheme.primaryGradient
                  ? Colors.black
                  : Colors.white,
              size: 18,
            ),
            SizedBox(width: AppTheme.spaceXs),
            Text(
              title,
              style: AppTheme.bodyMedium.copyWith(
                color: gradient == AppTheme.primaryGradient
                    ? Colors.black
                    : Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
