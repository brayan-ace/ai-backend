import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
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
  late bool _expanded;
  late String _displayText;

  @override
  void initState() {
    super.initState();
    _expanded = widget.detailedByDefault;
    _displayText = widget.text;
  }

  String _formatAiResponse(String text) {
    if (widget.fromUser) return text;

    // Check if response already has overview/answer structure
    if (text.contains('---') ||
        text.contains('**Overview:**') ||
        text.contains('**Answer:**')) {
      return text;
    }

    // For short responses (< 100 chars), don't add structure
    if (text.length < 100) {
      return text;
    }

    // For longer responses, extract first sentence/paragraph as overview
    final sentences = text.split(RegExp(r'(?<=[.!?])\s+'));
    if (sentences.length < 2) {
      return text;
    }

    // Get first 1-2 sentences as overview
    final overview = sentences.take(2).join(' ');
    final answer = sentences.skip(2).join(' ');

    if (answer.trim().isEmpty) {
      return text;
    }

    return '**Overview:** $overview\n\n---\n\n**Answer:**\n\n$answer';
  }

  Future<void> _regenerateSummary({required bool concise}) async {
    try {
      final mode = concise ? 'concise' : 'detailed';
      final resp = await ApiService.send('chat', {
        'message': widget.text,
        'action': 'summarize',
        'mode': mode,
      });
      if (resp != null) {
        setState(() {
          _displayText = resp;
          // If user requested detailed, expand automatically
          if (!concise) _expanded = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Regenerated ($mode)'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Regenerate failed: $e'),
          duration: Duration(seconds: 3),
        ),
      );
    }
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
    final latexPattern = RegExp(r'\$\$(.+?)\$\$|\$(.+?)\$', dotAll: true);
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

      if (latexCode.isNotEmpty) {
        try {
          spans.add(
            WidgetSpan(
              alignment: isDisplayMath
                  ? PlaceholderAlignment.middle
                  : PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: isDisplayMath
                  ? Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Center(
                        child: Math.tex(
                          latexCode,
                          textStyle: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 18,
                          ),
                          mathStyle: MathStyle.display,
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
          // If LaTeX fails, show error
          spans.add(
            TextSpan(
              text: '[LaTeX Error: $latexCode]',
              style: TextStyle(color: Colors.red, fontStyle: FontStyle.italic),
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

  // Parse markdown formatting (bold, italic, code, etc.) and URLs
  List<InlineSpan> _parseMarkdown(String text) {
    final List<InlineSpan> spans = [];

    // Handle triple-backtick code blocks first: split by ```
    if (text.contains('```')) {
      final parts = text.split('```');
      for (var i = 0; i < parts.length; i++) {
        final part = parts[i];
        if (i.isEven) {
          // plain markdown in even parts
          spans.addAll(_parseMarkdown(part));
        } else {
          // code block
          spans.add(
            WidgetSpan(
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.all(8),
                margin: EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceElevated.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SelectableText(
                    part.trim(),
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
          );
        }
      }
      return spans;
    }

    // Pattern for URLs, **bold**, *italic*, `code`, and other markdown
    final markdownPattern = RegExp(
      r'https?://[^\s]+|\*\*(.+?)\*\*|\*(.+?)\*|`(.+?)`|#{1,6}\s+(.+?)(?:\n|$)|---|\n',
    );

    int lastIndex = 0;

    for (final match in markdownPattern.allMatches(text)) {
      // Add plain text before markdown
      if (match.start > lastIndex) {
        spans.add(
          TextSpan(
            text: text.substring(lastIndex, match.start),
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 15),
          ),
        );
      }

      // Check if this is a URL (starts with http:// or https://)
      if (match.group(0)?.startsWith('http') ?? false) {
        final url = match.group(0)!;
        spans.add(
          TextSpan(
            text: url,
            style: TextStyle(
              color: AppTheme.primaryBlue,
              fontSize: 15,
              decoration: TextDecoration.underline,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () async {
                final uri = Uri.parse(url);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
          ),
        );
      } else if (match.group(1) != null) {
        // **Bold**
        spans.add(
          TextSpan(
            text: match.group(1),
            style: TextStyle(
              color: AppTheme.primaryBlue,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      } else if (match.group(2) != null) {
        // *Italic*
        spans.add(
          TextSpan(
            text: match.group(2),
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 15,
              fontStyle: FontStyle.italic,
            ),
          ),
        );
      } else if (match.group(3) != null) {
        // `code`
        spans.add(
          TextSpan(
            text: match.group(3),
            style: TextStyle(
              color: AppTheme.accentBlueLight,
              fontSize: 14,
              fontFamily: 'monospace',
              backgroundColor: AppTheme.surfaceElevated.withOpacity(0.3),
            ),
          ),
        );
      } else if (match.group(4) != null) {
        // # Headers
        spans.add(
          TextSpan(
            text: '\n${match.group(4)}\n',
            style: TextStyle(
              color: AppTheme.primaryBlue,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      } else if (match.group(0) == '---') {
        // Horizontal rule
        spans.add(
          WidgetSpan(
            child: Container(
              margin: EdgeInsets.symmetric(vertical: 8),
              height: 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: AppTheme.primaryGradient),
              ),
            ),
          ),
        );
      } else if (match.group(0) == '\n') {
        // New line
        spans.add(TextSpan(text: '\n'));
      }

      lastIndex = match.end;
    }

    // Add remaining plain text
    if (lastIndex < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(lastIndex),
          style: TextStyle(color: AppTheme.textPrimary, fontSize: 15),
        ),
      );
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

  @override
  Widget build(BuildContext context) {
    final formattedText = _formatAiResponse(_displayText);

    return Align(
      alignment: widget.fromUser ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _copyToClipboard(context),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.8,
          ),
          margin: EdgeInsets.only(
            left: widget.fromUser ? 48 : 0,
            right: widget.fromUser ? 0 : 48,
            bottom: AppTheme.spaceSm,
          ),
          padding: EdgeInsets.all(AppTheme.spaceMd),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: widget.gradientColors,
            ),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(AppTheme.radiusLg),
              topRight: Radius.circular(AppTheme.radiusLg),
              bottomLeft: widget.fromUser
                  ? Radius.circular(AppTheme.radiusLg)
                  : Radius.circular(4),
              bottomRight: widget.fromUser
                  ? Radius.circular(4)
                  : Radius.circular(AppTheme.radiusLg),
            ),
            border: Border.all(
              color: widget.fromUser
                  ? AppTheme.primaryBlue.withOpacity(0.5)
                  : AppTheme.surfaceElevated.withOpacity(0.5),
              width: 1,
            ),
            boxShadow: widget.fromUser
                ? AppTheme.glowShadow
                : AppTheme.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Show image if available
              if (widget.imagePath != null && widget.imagePath!.isNotEmpty) ...[
                GestureDetector(
                  onTap: () => _showFullScreenImage(context),
                  child: Container(
                    margin: EdgeInsets.only(bottom: AppTheme.spaceSm),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      child: Image.file(
                        File(widget.imagePath!),
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: 200,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 200,
                            color: AppTheme.surfaceElevated,
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.image_not_supported,
                                    color: AppTheme.textTertiary,
                                    size: 48,
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Image not found',
                                    style: AppTheme.bodySmall.copyWith(
                                      color: AppTheme.textTertiary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
              // Show text with concise/detailed toggle for AI responses
              if (widget.fromUser)
                Text(
                  widget.text,
                  style: AppTheme.bodyLarge.copyWith(
                    color: Colors.black,
                    fontSize: 15,
                  ),
                )
              else ...[
                // Controls: regenerate/summarize and concise/detailed toggle
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.refresh,
                        size: 18,
                        color: AppTheme.textTertiary,
                      ),
                      tooltip: 'Regenerate (detailed)',
                      onPressed: () => _regenerateSummary(concise: false),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.short_text,
                        size: 18,
                        color: AppTheme.textTertiary,
                      ),
                      tooltip: 'Summarize (concise)',
                      onPressed: () => _regenerateSummary(concise: true),
                    ),
                    TextButton(
                      onPressed: () => setState(() => _expanded = !_expanded),
                      child: Text(_expanded ? 'Concise' : 'Details'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.primaryBlue,
                        textStyle: TextStyle(fontSize: 12),
                        minimumSize: Size(0, 0),
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                      ),
                    ),
                  ],
                ),
                SelectableText.rich(
                  TextSpan(
                    children: _parseText(
                      _expanded ? formattedText : _conciseVersion(_displayText),
                    ),
                  ),
                  style: AppTheme.bodyLarge.copyWith(
                    color: AppTheme.textPrimary,
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _conciseVersion(String text) {
    if (text.trim().isEmpty) return text;
    // Prefer first paragraph
    final parts = text.split(RegExp(r'\n\s*\n'));
    final first = parts.first.trim();
    if (first.length <= 200) return first;
    // Fallback to first sentence (up to 200 chars)
    final sentences = first.split(RegExp(r'(?<=[.!?])\s+'));
    if (sentences.isNotEmpty) {
      final candidate = sentences.first;
      return candidate.length <= 200
          ? candidate
          : candidate.substring(0, 200) + '...';
    }
    return first.substring(0, 200) + '...';
  }
}
