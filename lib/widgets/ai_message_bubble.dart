import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import '../utils/theme.dart';
import 'professional_message_widget.dart';
import 'tts_speaker_icon.dart';

class AiMessageBubble extends StatefulWidget {
  final String text;
  final bool fromUser;
  final List<Color> gradientColors;
  final String? imagePath; // Add image path support
  final bool detailedByDefault;
  final Color? textColor;
  final Function()? onRegenerate;
  final int? messageIndex;

  const AiMessageBubble({
    super.key,
    required this.text,
    required this.fromUser,
    required this.gradientColors,
    this.imagePath,
    this.detailedByDefault = false,
    this.textColor,
    this.onRegenerate,
    this.messageIndex,
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
        borderRadius: BorderRadius.circular(8),
        child: Builder(
          builder: (context) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return AnimatedContainer(
              duration: Duration(milliseconds: 150),
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primaryBlue.withOpacity(0.25)
                    : (isDark ? Color(0xFF1E2530) : Color(0xFFF0F1F3)),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected
                      ? AppTheme.primaryBlue.withOpacity(0.5)
                      : Colors.transparent,
                  width: 1,
                ),
              ),
              child: Icon(
                icon,
                size: 16,
                color: isSelected
                    ? AppTheme.primaryBlue
                    : (isDark
                          ? AppTheme.textSecondary.withOpacity(0.7)
                          : Color(0xFF6B7280)),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCopyButton() {
    return StatefulBuilder(
      builder: (context, setLocalState) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              _copyToClipboard(context);
            },
            onHighlightChanged: (isHighlighted) {
              setLocalState(() {});
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? Color(0xFF1E2530) : Color(0xFFF0F1F3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.content_copy_rounded,
                size: 16,
                color: isDark
                    ? AppTheme.textSecondary.withOpacity(0.7)
                    : Color(0xFF6B7280),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRegenerateButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onRegenerate,
        borderRadius: BorderRadius.circular(8),
        child: Builder(
          builder: (context) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? Color(0xFF1E2530) : Color(0xFFF0F1F3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.refresh_rounded,
                size: 16,
                color: isDark
                    ? AppTheme.textSecondary.withOpacity(0.7)
                    : Color(0xFF6B7280),
              ),
            );
          },
        ),
      ),
    );
  }

  void _showFullScreenImage(BuildContext context) {
    if (widget.imagePath == null || widget.imagePath!.isEmpty) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return Scaffold(
            backgroundColor: isDark ? Colors.black : Colors.white,
            appBar: AppBar(
              backgroundColor: isDark ? Colors.black87 : Colors.white,
              elevation: 0,
              leading: IconButton(
                icon: Icon(
                  Icons.close,
                  color: isDark ? Colors.white : Colors.black,
                ),
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
          );
        },
      ),
    );
  }

  // Only show reactions for AI messages
  @override
  Widget build(BuildContext context) {
    final formattedText = _formatAiResponse(widget.text);
    final isWelcomeMessage = widget.text.contains('Welcome');
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                  color: isDark ? AppTheme.textPrimary : Color(0xFF1F2937),
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
                            color: isDark
                                ? (widget.textColor ?? Colors.white)
                                : Colors.white,
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
                    margin: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    padding: EdgeInsets.symmetric(horizontal: 0, vertical: 8),
                    // No background, border, or shadow for AI messages - full width like ChatGPT
                    color: Colors.transparent,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // AI Avatar Icon
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [AppTheme.accentBlue, AppTheme.primaryBlue],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryBlue.withOpacity(0.3),
                                blurRadius: 8,
                                spreadRadius: 0,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.psychology_outlined,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        SizedBox(width: 12),
                        // Message content
                        Expanded(
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
                              // Use ProfessionalMessageWidget for enhanced formatting
                              ProfessionalMessageWidget(formattedText, isBot: true),
                            ],
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
            padding: EdgeInsets.only(left: 64, top: 12, bottom: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TTSSpeakerIcon(
                  messageId: widget.text.hashCode.toString(),
                  messageText: widget.text,
                  isAiMessage: true,
                ),
                SizedBox(width: 8),
                _buildCopyButton(),
                SizedBox(width: 8),
                _buildReactionButton('👍', Icons.thumb_up_rounded),
                SizedBox(width: 8),
                _buildReactionButton('👎', Icons.thumb_down_rounded),
                SizedBox(width: 8),
                _buildRegenerateButton(),
              ],
            ),
          ),
      ],
    );
  }
}
