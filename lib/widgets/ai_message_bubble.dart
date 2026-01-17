import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import '../utils/theme.dart';
import 'professional_message_widget.dart';

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
                        // Use ProfessionalMessageWidget for enhanced formatting
                        ProfessionalMessageWidget(formattedText, isBot: true),
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
