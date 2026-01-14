import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/theme.dart';

class AiMessageBubble extends StatefulWidget {
  final String text;
  final bool fromUser;
  final List<Color> gradientColors;
  final String? imagePath; // Add image path support
  final bool detailedByDefault;

  const AiMessageBubble({
    super.key,
    required this.text,
    required this.fromUser,
    required this.gradientColors,
    this.imagePath,
    this.detailedByDefault = false,
  });

  @override
  _AiMessageBubbleState createState() => _AiMessageBubbleState();
}

class _AiMessageBubbleState extends State<AiMessageBubble> {
  late Set<String> _reactions; // Track which reactions are selected

  @override
  void initState() {
    super.initState();
    _reactions = {};
  }

  String _formatAiResponse(String text) {
    if (widget.fromUser) return text;

    // If AI response looks like a short numbered definition (e.g., "1. The study of ..."),
    // remove the leading numbering to render naturally in-flow.
    String out = text;
    final preview = out.trim().split('\n').take(3).join(' ');
    final numbered = RegExp(r'^\s*\d+[.)]\s*').hasMatch(preview);
    if (numbered && preview.length < 200) {
      out = out.replaceAll(RegExp(r'^\s*\d+[.)]\s*', multiLine: true), '');
    }

    return out;
  }

  void _copyToClipboard(BuildContext context) {
    Clipboard.setData(ClipboardData(text: widget.text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text('Message copied to clipboard'),
          ],
        ),
        backgroundColor: AppTheme.primaryBlue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        ),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _toggleReaction(String emoji) {
    setState(() {
      if (_reactions.contains(emoji)) {
        _reactions.remove(emoji);
      } else {
        _reactions.add(emoji);
      }
    });
  }

  Widget _buildReactionButton(String emoji, IconData icon) {
    final isSelected = _reactions.contains(emoji);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _toggleReaction(emoji),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.primaryBlue.withOpacity(0.15)
                : AppTheme.backgroundGradientEnd.withOpacity(0.5),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            icon,
            size: 14,
            color: isSelected
                ? AppTheme.primaryBlue
                : AppTheme.textTertiary.withOpacity(0.6),
          ),
        ),
      ),
    );
  }

  Widget _buildCopyButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _copyToClipboard(context),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppTheme.backgroundGradientEnd.withOpacity(0.5),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            Icons.content_copy_rounded,
            size: 14,
            color: AppTheme.textTertiary.withOpacity(0.6),
          ),
        ),
      ),
    );
  }

  Widget _buildRegenerateButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          // TODO: Implement regenerate functionality
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Regenerate coming soon'),
              duration: Duration(seconds: 1),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppTheme.backgroundGradientEnd.withOpacity(0.5),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            Icons.refresh_rounded,
            size: 14,
            color: AppTheme.textTertiary.withOpacity(0.6),
          ),
        ),
      ),
    );
  }

  void _showFullScreenImage(BuildContext context) {
    if (widget.imagePath == null || widget.imagePath!.isEmpty) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.file(File(widget.imagePath!), fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }

  // Parse text with LaTeX and markdown formatting
  List<InlineSpan> _parseText(String text) {
    final List<InlineSpan> spans = [];

    // Pattern to match $$...$$ (display math) and $...$ (inline math)
    // Using non-greedy matching and handling newlines properly
    final latexPattern = RegExp(
      r'\$\$(.+?)\$\$|\$([^\$]+?)\$',
      dotAll: true,
      multiLine: true,
    );
    int lastIndex = 0;

    for (final match in latexPattern.allMatches(text)) {
      // Add text before LaTeX
      if (match.start > lastIndex) {
        final beforeText = text.substring(lastIndex, match.start);
        spans.addAll(_parseMarkdown(beforeText));
      }

      // Determine if display or inline math
      final isDisplayMath = match.group(1) != null;
      final latexCode = (match.group(1) ?? match.group(2) ?? '').trim();

      if (latexCode.isNotEmpty && !latexCode.contains('\$')) {
        try {
          spans.add(
            WidgetSpan(
              alignment: isDisplayMath
                  ? PlaceholderAlignment.middle
                  : PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: isDisplayMath
                  ? Container(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width - 60,
                      ),
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Center(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Math.tex(
                            latexCode,
                            textStyle: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 18,
                            ),
                            mathStyle: MathStyle.display,
                          ),
                        ),
                      ),
                    )
                  : Padding(
                      padding: EdgeInsets.symmetric(horizontal: 2),
                      child: Math.tex(
                        latexCode,
                        textStyle: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 15,
                        ),
                        mathStyle: MathStyle.text,
                      ),
                    ),
            ),
          );
        } catch (e) {
          // If LaTeX fails, show fallback text instead of error
          spans.add(
            TextSpan(
              text: isDisplayMath ? '\$\$$latexCode\$\$' : '\$$latexCode\$',
              style: TextStyle(
                color: AppTheme.primaryBlue,
                fontFamily: 'monospace',
                fontSize: 13,
              ),
            ),
          );
        }
      }

      lastIndex = match.end;
    }

    // Add remaining text
    if (lastIndex < text.length) {
      final remainingText = text.substring(lastIndex);
      spans.addAll(_parseMarkdown(remainingText));
    }

    return spans.isEmpty
        ? [
            TextSpan(
              text: text,
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 15),
            ),
          ]
        : spans;
  }

  // Parse markdown formatting (bold, italic, code, lists, headings) and URLs
  List<InlineSpan> _parseMarkdown(String text) {
    final List<InlineSpan> spans = [];

    // Handle tables first: |header|header| format (only in detailed mode)
    if (widget.detailedByDefault && text.contains('|')) {
      final tableRegex = RegExp(
        r'(\|.+\|(?:\n\|[-:\s|]+\|)?\n(?:\|.+\|\n)*)',
        multiLine: true,
      );

      if (tableRegex.hasMatch(text)) {
        int lastIndex = 0;

        for (final match in tableRegex.allMatches(text)) {
          // Add text before table
          if (match.start > lastIndex) {
            spans.addAll(
              _parseMarkdownContent(text.substring(lastIndex, match.start)),
            );
          }

          // Parse table
          final tableText = match.group(0)!;
          final tableWidget = _buildTableFromMarkdown(tableText);
          spans.add(tableWidget);

          lastIndex = match.end;
        }

        // Add remaining text
        if (lastIndex < text.length) {
          spans.addAll(_parseMarkdownContent(text.substring(lastIndex)));
        }

        return spans.isEmpty
            ? [
                TextSpan(
                  text: text,
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 15),
                ),
              ]
            : spans;
      }
    }

    // Handle triple-backtick code blocks first: split by ```
    if (text.contains('```')) {
      final parts = text.split('```');
      for (var i = 0; i < parts.length; i++) {
        final part = parts[i];
        if (i.isEven) {
          // plain markdown in even parts
          spans.addAll(_parseMarkdownContent(part));
        } else {
          // code block
          final lines = part.trim().split('\n');
          final language = lines.isNotEmpty ? lines[0] : '';
          final code = lines.length > 1
              ? lines.skip(1).join('\n')
              : part.trim();

          spans.add(
            WidgetSpan(
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.all(12),
                margin: EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceElevated.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  border: Border.all(
                    color: AppTheme.primaryBlue.withOpacity(0.2),
                    width: 0.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header with language and copy button
                    Row(
                      children: [
                        if (language.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.only(right: 8),
                            child: Text(
                              language,
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 11,
                                color: AppTheme.primaryBlue,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        Spacer(),
                        Material(
                          color: Colors.transparent,
                          child: Tooltip(
                            message: 'Copy code',
                            child: InkWell(
                              onTap: () {
                                Clipboard.setData(
                                  ClipboardData(text: code.trim()),
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Row(
                                      children: [
                                        Icon(
                                          Icons.check_circle,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                        SizedBox(width: 8),
                                        Text('Code copied to clipboard'),
                                      ],
                                    ),
                                    backgroundColor: AppTheme.primaryBlue,
                                    duration: Duration(seconds: 2),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(4),
                              child: Padding(
                                padding: EdgeInsets.all(4),
                                child: Icon(
                                  Icons.content_copy,
                                  size: 16,
                                  color: AppTheme.primaryBlue.withOpacity(0.6),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (language.isNotEmpty) SizedBox(height: 8),
                    // Code content
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SelectableText(
                        code.trim(),
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                          color: AppTheme.textPrimary,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
      }
      return spans;
    }

    return _parseMarkdownContent(text);
  }

  List<InlineSpan> _parseMarkdownContent(String text) {
    final List<InlineSpan> spans = [];

    // Enhanced pattern for bullet points, numbered lists, **bold**, *italic*, `code`, headings, URLs, and emojis
    final markdownPattern = RegExp(
      r'\*\*([\s\S]+?)\*\*|\*([\s\S]+?)\*|`([\s\S]+?)`|^#{1,6}\s+(.+?)$|https?://[^\s]+|^[\s]*[-•*]\s+(.+?)$|^\s*\d+[\.)]\s+(.+?)$|---|\n|(?::[a-zA-Z0-9_]+:)|(?::[a-zA-Z0-9_]+:)',
      multiLine: true,
    );

    int lastIndex = 0;

    for (final match in markdownPattern.allMatches(text)) {
      // Add plain text before match
      if (match.start > lastIndex) {
        final plainText = text.substring(lastIndex, match.start);
        if (plainText.trim().isNotEmpty) {
          spans.add(
            TextSpan(
              text: plainText,
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                height: 1.7,
                letterSpacing: 0.1,
              ),
            ),
          );
        }
      }

      final matched = match.group(0) ?? '';

      // Bullet point or list item (group 5)
      if (match.group(5) != null) {
        final item = match.group(5)!.trim();
        spans.add(
          WidgetSpan(
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.only(left: 8, top: 12, bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: EdgeInsets.only(top: 10, right: 12),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        height: 1.7,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      } else if (match.group(6) != null) {
        // Numbered list (group 6) - preserve the number from original match
        final fullMatch = match.group(0) ?? '';
        final item = match.group(6)!.trim();
        final numberMatch = RegExp(r'^\s*(\d+)[\.)]').firstMatch(fullMatch);
        final number = numberMatch?.group(1) ?? '1';

        spans.add(
          WidgetSpan(
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.only(left: 8, top: 12, bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 28,
                    margin: EdgeInsets.only(right: 8),
                    child: Text(
                      '$number.',
                      style: TextStyle(
                        color: AppTheme.primaryBlue,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        height: 1.7,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        height: 1.7,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      } else if (matched.startsWith('http')) {
        // URL
        spans.add(
          TextSpan(
            text: matched,
            style: TextStyle(
              color: AppTheme.primaryBlue,
              fontSize: 16,
              decoration: TextDecoration.underline,
              height: 1.7,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () async {
                final uri = Uri.parse(matched);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
          ),
        );
      } else if (match.group(1) != null) {
        // **Bold** with newlines (group 1)
        spans.add(
          TextSpan(
            text: match.group(1),
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              height: 1.7,
            ),
          ),
        );
      } else if (match.group(2) != null) {
        // *Italic* with newlines (group 2)
        spans.add(
          TextSpan(
            text: match.group(2),
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontStyle: FontStyle.italic,
              height: 1.7,
            ),
          ),
        );
      } else if (match.group(3) != null) {
        // `code` with newlines (group 3)
        spans.add(
          WidgetSpan(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              margin: EdgeInsets.symmetric(horizontal: 2, vertical: 2),
              decoration: BoxDecoration(
                color: Color(0xFF2D333B),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                match.group(3)!,
                style: TextStyle(
                  color: Color(0xFFE06C75),
                  fontSize: 15,
                  fontFamily: 'monospace',
                  height: 1.5,
                ),
              ),
            ),
          ),
        );
      } else if (match.group(4) != null) {
        // # Headers (group 4)
        final headerText = match.group(4)!;
        final headerMatch = match.group(0)!;
        int level = 0;
        for (int i = 0; i < headerMatch.length; i++) {
          if (headerMatch[i] == '#')
            level++;
          else
            break;
        }

        // Enhanced ChatGPT-like heading sizes with better spacing
        double fontSize;
        FontWeight fontWeight;
        double topPadding;
        double bottomPadding;

        switch (level) {
          case 1:
            fontSize = 28;
            fontWeight = FontWeight.w800;
            topPadding = 32;
            bottomPadding = 20;
            break;
          case 2:
            fontSize = 24;
            fontWeight = FontWeight.w700;
            topPadding = 28;
            bottomPadding = 16;
            break;
          case 3:
            fontSize = 20;
            fontWeight = FontWeight.w700;
            topPadding = 24;
            bottomPadding = 12;
            break;
          case 4:
            fontSize = 18;
            fontWeight = FontWeight.w600;
            topPadding = 20;
            bottomPadding = 10;
            break;
          case 5:
            fontSize = 17;
            fontWeight = FontWeight.w600;
            topPadding = 18;
            bottomPadding = 8;
            break;
          default:
            fontSize = 16;
            fontWeight = FontWeight.w600;
            topPadding = 16;
            bottomPadding = 6;
        }

        spans.add(
          WidgetSpan(
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.only(top: topPadding, bottom: bottomPadding),
              child: Text(
                headerText,
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: fontSize,
                  fontWeight: fontWeight,
                  height: 1.3,
                  letterSpacing: -0.4,
                ),
              ),
            ),
          ),
        );
      } else if (matched == '---') {
        // Horizontal rule
        spans.add(
          WidgetSpan(
            child: Container(
              width: double.infinity,
              margin: EdgeInsets.symmetric(vertical: 20),
              height: 1,
              color: AppTheme.surfaceElevated.withOpacity(0.5),
            ),
          ),
        );
      } else if (matched == '\n') {
        // Preserve newlines with proper spacing
        spans.add(
          WidgetSpan(child: SizedBox(height: 12, width: double.infinity)),
        );
      } else if (matched.startsWith(':') && matched.endsWith(':')) {
        // Emoji pattern
        final emojiCode = matched.substring(1, matched.length - 1);
        spans.add(
          WidgetSpan(
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 2),
              child: Text(matched, style: TextStyle(fontSize: 20, height: 1.5)),
            ),
          ),
        );
      }

      lastIndex = match.end;
    }

    // Add remaining text
    if (lastIndex < text.length) {
      final remaining = text.substring(lastIndex);
      if (remaining.trim().isNotEmpty) {
        spans.add(
          TextSpan(
            text: remaining,
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              height: 1.7,
              letterSpacing: 0.1,
            ),
          ),
        );
      }
    }

    return spans.isEmpty
        ? [
            TextSpan(
              text: text,
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                height: 1.7,
                letterSpacing: 0.1,
              ),
            ),
          ]
        : spans;
  }

  WidgetSpan _buildTableFromMarkdown(String tableText) {
    final lines = tableText.trim().split('\n');
    final rows = <List<String>>[];

    for (final line in lines) {
      if (line.trim().isEmpty || line.contains('---')) continue;
      final cells = line
          .split('|')
          .where((c) => c.trim().isNotEmpty)
          .map((c) => c.trim())
          .toList();
      if (cells.isNotEmpty) {
        rows.add(cells);
      }
    }

    if (rows.isEmpty) {
      return WidgetSpan(child: SizedBox.shrink());
    }

    return WidgetSpan(
      child: Container(
        width: double.infinity,
        margin: EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(
            color: AppTheme.primaryBlue.withOpacity(0.2),
            width: 0.5,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 16,
            dataRowHeight: 40,
            headingRowHeight: 45,
            decoration: BoxDecoration(
              color: AppTheme.surfaceElevated.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            columns: rows.isNotEmpty
                ? rows[0]
                      .map(
                        (header) => DataColumn(
                          label: Expanded(
                            child: Text(
                              header,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryBlue,
                                fontSize: 13,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      )
                      .toList()
                : [],
            rows: rows.length > 1
                ? rows.skip(1).map((row) {
                    return DataRow(
                      cells: row
                          .map(
                            (cell) => DataCell(
                              Text(
                                cell,
                                style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 12,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                    );
                  }).toList()
                : [],
          ),
        ),
      ),
    );
  }

  // Only show reactions for AI messages
  @override
  Widget build(BuildContext context) {
    final formattedText = _formatAiResponse(widget.text);
    final isWelcomeMessage = widget.text.contains('Welcome');

    // Welcome message: centered and large
    if (isWelcomeMessage) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                widget.text,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.w300,
                  height: 1.6,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: widget.fromUser
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Align(
          alignment: widget.fromUser
              ? Alignment.centerRight
              : Alignment.centerLeft,
          child: widget.fromUser
              ? GestureDetector(
                  onLongPress: () => _copyToClipboard(context),
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.85,
                    ),
                    margin: EdgeInsets.only(left: 56, right: 0, bottom: 16),
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withOpacity(0.9),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                        bottomLeft: Radius.circular(16),
                        bottomRight: Radius.circular(6),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.imagePath != null &&
                            widget.imagePath!.isNotEmpty) ...[
                          GestureDetector(
                            onTap: () => _showFullScreenImage(context),
                            child: Container(
                              margin: EdgeInsets.only(bottom: AppTheme.spaceSm),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radiusMd,
                                ),
                                child: Image.file(
                                  File(widget.imagePath!),
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: 200,
                                ),
                              ),
                            ),
                          ),
                        ],
                        Text(
                          widget.text,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : GestureDetector(
                  onLongPress: () => _copyToClipboard(context),
                  child: Container(
                    width: double.infinity,
                    margin: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    padding: EdgeInsets.symmetric(horizontal: 0, vertical: 6),
                    // No background, border, or shadow for AI messages - full width like ChatGPT
                    color: Colors.transparent,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.imagePath != null &&
                            widget.imagePath!.isNotEmpty) ...[
                          GestureDetector(
                            onTap: () => _showFullScreenImage(context),
                            child: Container(
                              margin: EdgeInsets.only(bottom: AppTheme.spaceSm),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radiusSm,
                                ),
                                child: Image.file(
                                  File(widget.imagePath!),
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: 200,
                                ),
                              ),
                            ),
                          ),
                        ],
                        // Use RichText with proper text wrapping - no horizontal scroll
                        SelectableText.rich(
                          TextSpan(children: _parseText(formattedText)),
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 16,
                            height: 1.7,
                            letterSpacing: 0.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
        // Action buttons attached directly to AI message bubble
        if (!widget.fromUser && !widget.text.contains('Welcome —'))
          Padding(
            padding: EdgeInsets.only(left: 16, top: 6, bottom: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildCopyButton(),
                SizedBox(width: 6),
                _buildReactionButton('👍', Icons.thumb_up_rounded),
                SizedBox(width: 6),
                _buildReactionButton('👎', Icons.thumb_down_rounded),
                SizedBox(width: 6),
                _buildRegenerateButton(),
              ],
            ),
          ),
      ],
    );
  }
}
