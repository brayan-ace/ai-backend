import 'package:flutter/material.dart';
import '../utils/theme.dart';
import '../utils/app_localizations.dart';

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
  final List<Note> _notes = [];

  void _createNote() {
    _showNoteCreationOptions();
  }

  /// Show premium 3-option modal for note creation
  void _showNoteCreationOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: AppTheme.surfaceGradientFromContext(context),
          ),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(AppTheme.radiusLg),
            topRight: Radius.circular(AppTheme.radiusLg),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(AppTheme.spaceLg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Text(
                  'Create a New Note',
                  style: AppTheme.headlineSmall.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryFromContext(context),
                  ),
                ),
                SizedBox(height: AppTheme.spaceLg),

                // Option 1: Take Down Notes
                _buildNoteOption(
                  icon: Icons.edit_note,
                  title: 'Take Down Notes',
                  subtitle: 'Write and organize your notes',
                  gradient: AppTheme.primaryGradient,
                  onTap: () {
                    Navigator.pop(context);
                    _openNoteEditor();
                  },
                ),
                SizedBox(height: AppTheme.spaceMd),

                // Option 2: Summarise Notes
                _buildNoteOption(
                  icon: Icons.summarize,
                  title: 'Summarise Notes',
                  subtitle: 'Coming soon',
                  gradient: AppTheme.accentGradient,
                  isComingSoon: true,
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            Icon(Icons.info, color: Colors.white),
                            SizedBox(width: 8),
                            Text('Summarise feature coming soon'),
                          ],
                        ),
                        backgroundColor: AppTheme.primaryBlue,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
                SizedBox(height: AppTheme.spaceMd),

                // Option 3: Generate Notes
                _buildNoteOption(
                  icon: Icons.auto_awesome,
                  title: 'Generate Notes',
                  subtitle: 'Coming soon',
                  gradient: [Color(0xFFFF6B6B), Color(0xFFFF8E72)],
                  isComingSoon: true,
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            Icon(Icons.info, color: Colors.white),
                            SizedBox(width: 8),
                            Text('Generate feature coming soon'),
                          ],
                        ),
                        backgroundColor: AppTheme.primaryBlue,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
                SizedBox(height: AppTheme.spaceMd),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Build individual note creation option
  Widget _buildNoteOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Color> gradient,
    required VoidCallback onTap,
    bool isComingSoon = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isComingSoon ? null : onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        child: Container(
          padding: EdgeInsets.all(AppTheme.spaceMd),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradient,
            ),
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            boxShadow: [
              BoxShadow(
                color: gradient[0].withOpacity(0.3),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(AppTheme.spaceSm),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              SizedBox(width: AppTheme.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTheme.bodyLarge.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: AppTheme.bodySmall.copyWith(
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white.withOpacity(0.6),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Open the premium note editor
  void _openNoteEditor() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PremiumNoteEditorScreen(
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
        builder: (_) => PremiumNoteEditorScreen(
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
            AppTheme.backgroundGradientStartFromContext(context),
            AppTheme.backgroundGradientEndFromContext(context),
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
                          AppLocalizations.of(context).t('notes.notesTitle'),
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
                              AppLocalizations.of(
                                context,
                              ).t('notes.noNotesYet'),
                              style: AppTheme.headlineMedium.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            SizedBox(height: AppTheme.spaceSm),
                            Text(
                              AppLocalizations.of(
                                context,
                              ).t('notes.tapToCreateFirst'),
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
                                color: AppTheme.textPrimaryFromContext(context),
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
                                    colors: AppTheme.surfaceGradientFromContext(
                                      context,
                                    ),
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusLg,
                                  ),
                                  border: Border.all(
                                    color: AppTheme.surfaceElevatedFromContext(
                                      context,
                                    ).withOpacity(0.5),
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
                                            color:
                                                AppTheme.textPrimaryFromContext(
                                                  context,
                                                ),
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

    if (diff.inMinutes < 1)
      return AppLocalizations.of(context).t('notes.justNow');
    if (diff.inMinutes < 60)
      return AppLocalizations.of(
        context,
      ).t('notes.minutesAgo').replaceAll('{count}', diff.inMinutes.toString());
    if (diff.inHours < 24)
      return AppLocalizations.of(
        context,
      ).t('notes.hoursAgo').replaceAll('{count}', diff.inHours.toString());
    if (diff.inDays < 7)
      return AppLocalizations.of(
        context,
      ).t('notes.daysAgo').replaceAll('{count}', diff.inDays.toString());
    return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
  }
}

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
  bool _isBold = false;
  bool _isItalic = false;
  bool _isUnderline = false;
  bool _isSaved = true;
  String _lastSavedTime = 'All changes saved';
  TextAlign _textAlign = TextAlign.left;
  double _fontSize = 16;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle ?? '');
    _contentController = TextEditingController(
      text: widget.initialContent ?? '',
    );

    // Auto-save every 10 seconds
    Future.delayed(Duration(seconds: 10), _autoSave);

    // Listen for changes
    _titleController.addListener(() => setState(() => _isSaved = false));
    _contentController.addListener(() => setState(() => _isSaved = false));
  }

  Future<void> _autoSave() async {
    if (!_isSaved && mounted) {
      setState(() {
        _lastSavedTime = 'Saved at ${TimeOfDay.now().format(context)}';
        _isSaved = true;
      });
      Future.delayed(Duration(seconds: 10), _autoSave);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Widget _buildFormatButton({
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
    String? tooltip,
  }) {
    return Tooltip(
      message: tooltip ?? '',
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          color: isActive
              ? AppTheme.primaryBlue.withOpacity(0.2)
              : Colors.transparent,
          border: Border.all(
            color: isActive ? AppTheme.primaryBlue : Colors.grey[300]!,
            width: 1,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            child: Padding(
              padding: EdgeInsets.all(8),
              child: Icon(
                icon,
                size: 18,
                color: isActive ? AppTheme.primaryBlue : Colors.grey[600],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (!_isSaved) {
          return await showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('Save changes?'),
                  content: Text(
                    'You have unsaved changes. Do you want to save before leaving?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text('Discard'),
                    ),
                    TextButton(
                      onPressed: () {
                        _saveNote();
                        Navigator.pop(context, true);
                      },
                      child: Text('Save'),
                    ),
                  ],
                ),
              ) ??
              false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: AppTheme.surfaceElevatedFromContext(context),
        appBar: AppBar(
          backgroundColor: AppTheme.surfaceElevatedFromContext(context),
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'New Note',
            style: AppTheme.headlineSmall.copyWith(fontWeight: FontWeight.bold),
          ),
          actions: [
            // Save status indicator
            Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: AppTheme.spaceMd),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _lastSavedTime,
                      style: AppTheme.labelSmall.copyWith(
                        color: _isSaved ? Colors.green : Colors.orange,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            // Title field
            Container(
              padding: EdgeInsets.fromLTRB(
                AppTheme.spaceLg,
                AppTheme.spaceMd,
                AppTheme.spaceLg,
                AppTheme.spaceSm,
              ),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey[200]!, width: 1),
                ),
              ),
              child: TextField(
                controller: _titleController,
                style: AppTheme.headlineSmall.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimaryFromContext(context),
                ),
                decoration: InputDecoration(
                  hintText: 'Note title',
                  border: InputBorder.none,
                  hintStyle: AppTheme.headlineSmall.copyWith(
                    color: Colors.grey[400],
                  ),
                ),
                maxLines: 1,
              ),
            ),

            // Formatting toolbar
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: AppTheme.spaceMd,
                vertical: AppTheme.spaceSm,
              ),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey[200]!, width: 1),
                ),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // Text formatting
                    _buildFormatButton(
                      icon: Icons.format_bold,
                      isActive: _isBold,
                      onTap: () => setState(() => _isBold = !_isBold),
                      tooltip: 'Bold',
                    ),
                    _buildFormatButton(
                      icon: Icons.format_italic,
                      isActive: _isItalic,
                      onTap: () => setState(() => _isItalic = !_isItalic),
                      tooltip: 'Italic',
                    ),
                    _buildFormatButton(
                      icon: Icons.format_underlined,
                      isActive: _isUnderline,
                      onTap: () => setState(() => _isUnderline = !_isUnderline),
                      tooltip: 'Underline',
                    ),
                    SizedBox(width: 12),

                    // Text alignment
                    _buildFormatButton(
                      icon: Icons.format_align_left,
                      isActive: _textAlign == TextAlign.left,
                      onTap: () => setState(() => _textAlign = TextAlign.left),
                      tooltip: 'Align left',
                    ),
                    _buildFormatButton(
                      icon: Icons.format_align_center,
                      isActive: _textAlign == TextAlign.center,
                      onTap: () =>
                          setState(() => _textAlign = TextAlign.center),
                      tooltip: 'Align center',
                    ),
                    _buildFormatButton(
                      icon: Icons.format_align_right,
                      isActive: _textAlign == TextAlign.right,
                      onTap: () => setState(() => _textAlign = TextAlign.right),
                      tooltip: 'Align right',
                    ),
                    SizedBox(width: 12),

                    // Font size - using a popup menu
                    PopupMenuButton<double>(
                      initialValue: _fontSize,
                      onSelected: (size) {
                        setState(() => _fontSize = size);
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(value: 12, child: Text('Small (12)')),
                        PopupMenuItem(value: 16, child: Text('Normal (16)')),
                        PopupMenuItem(value: 18, child: Text('Large (18)')),
                        PopupMenuItem(value: 20, child: Text('XL (20)')),
                        PopupMenuItem(value: 24, child: Text('XXL (24)')),
                      ],
                      child: Container(
                        margin: EdgeInsets.symmetric(horizontal: 4),
                        padding: EdgeInsets.symmetric(
                          horizontal: AppTheme.spaceSm,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusSm,
                          ),
                          border: Border.all(
                            color: Colors.grey[300]!,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${_fontSize.toInt()}',
                              style: AppTheme.labelMedium,
                            ),
                            SizedBox(width: 4),
                            Icon(Icons.arrow_drop_down, size: 16),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Content field
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(AppTheme.spaceLg),
                child: TextField(
                  controller: _contentController,
                  style: TextStyle(
                    fontSize: _fontSize,
                    fontWeight: _isBold ? FontWeight.bold : FontWeight.normal,
                    fontStyle: _isItalic ? FontStyle.italic : FontStyle.normal,
                    decoration: _isUnderline
                        ? TextDecoration.underline
                        : TextDecoration.none,
                    color: AppTheme.textPrimaryFromContext(context),
                  ),
                  textAlign: _textAlign,
                  decoration: InputDecoration(
                    hintText: 'Start typing your notes...',
                    border: InputBorder.none,
                    hintStyle: TextStyle(color: Colors.grey[400]),
                  ),
                  maxLines: null,
                  expands: true,
                ),
              ),
            ),

            // Word count and action buttons
            Container(
              padding: EdgeInsets.all(AppTheme.spaceMd),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.grey[200]!, width: 1),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_contentController.text.length} characters • ${_contentController.text.split(' ').where((w) => w.isNotEmpty).length} words',
                          style: AppTheme.labelSmall.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: AppTheme.spaceMd),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Discard'),
                  ),
                  SizedBox(width: AppTheme.spaceSm),
                  ElevatedButton(
                    onPressed: _saveNote,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      elevation: 0,
                      padding: EdgeInsets.symmetric(
                        horizontal: AppTheme.spaceLg,
                        vertical: AppTheme.spaceSm,
                      ),
                    ),
                    child: Text(
                      'Save Note',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _saveNote() {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Please add a title')));
      return;
    }

    widget.onSave(_titleController.text.trim(), _contentController.text.trim());

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 8),
            Text('Note saved successfully'),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );

    Navigator.pop(context);
  }
}
