/// Premium Message Bubble Widget
/// Beautiful animated chat bubbles with glassmorphism effects

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'professional_message_widget.dart';

class PremiumColors {
  static const Color darkBg = Color(0xFF0a0a0a);
  static const Color darkBg2 = Color(0xFF1a1a2e);
  static const Color accentGradient1 = Color(0xFF6366f1);
  static const Color accentGradient2 = Color(0xFF8b5cf6);
  static const Color accentGradient3 = Color(0xFF3b82f6);
  static const Color cardBg = Color(0xFF111827);
  static const Color successGreen = Color(0xFF10b981);
}

class PremiumMessageBubble extends StatefulWidget {
  final String message;
  final bool isBot;
  final DateTime? timestamp;
  final String? botName;
  final bool showAvatar;
  final bool animate;
  final VoidCallback? onLongPress;
  final VoidCallback? onDoubleTap;

  const PremiumMessageBubble({
    Key? key,
    required this.message,
    required this.isBot,
    this.timestamp,
    this.botName,
    this.showAvatar = true,
    this.animate = true,
    this.onLongPress,
    this.onDoubleTap,
  }) : super(key: key);

  @override
  State<PremiumMessageBubble> createState() => _PremiumMessageBubbleState();
}

class _PremiumMessageBubbleState extends State<PremiumMessageBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: Offset(widget.isBot ? -0.3 : 0.3, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    if (widget.animate) {
      _controller.forward();
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Padding(
            padding: EdgeInsets.only(
              left: widget.isBot ? 12 : 48,
              right: widget.isBot ? 48 : 12,
              bottom: 12,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment:
                  widget.isBot ? MainAxisAlignment.start : MainAxisAlignment.end,
              children: [
                if (widget.isBot && widget.showAvatar) ...[
                  _buildBotAvatar(),
                  SizedBox(width: 10),
                ],
                Flexible(child: _buildMessageContent()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBotAvatar() {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            PremiumColors.accentGradient2,
            PremiumColors.accentGradient1,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: PremiumColors.accentGradient2.withOpacity(0.4),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Center(
        child: Icon(
          Icons.psychology,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildMessageContent() {
    return GestureDetector(
      onLongPress: () {
        HapticFeedback.mediumImpact();
        widget.onLongPress?.call();
        _showMessageOptions();
      },
      onDoubleTap: () {
        HapticFeedback.lightImpact();
        widget.onDoubleTap?.call();
      },
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.98 : 1.0,
        duration: Duration(milliseconds: 100),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: widget.isBot
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      PremiumColors.cardBg.withOpacity(0.9),
                      PremiumColors.darkBg2.withOpacity(0.7),
                    ],
                  )
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      PremiumColors.accentGradient2,
                      PremiumColors.accentGradient1,
                    ],
                  ),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(widget.isBot ? 4 : 20),
              topRight: Radius.circular(widget.isBot ? 20 : 4),
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
            border: widget.isBot
                ? Border.all(
                    color: PremiumColors.accentGradient1.withOpacity(0.2),
                    width: 1,
                  )
                : null,
            boxShadow: [
              BoxShadow(
                color: widget.isBot
                    ? Colors.black.withOpacity(0.2)
                    : PremiumColors.accentGradient2.withOpacity(0.3),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              widget.isBot
                  ? ProfessionalMessageWidget(widget.message, isBot: true)
                  : Text(
                      widget.message,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        height: 1.5,
                      ),
                    ),
              if (widget.timestamp != null) ...[
                SizedBox(height: 6),
                Text(
                  _formatTime(widget.timestamp!),
                  style: TextStyle(
                    color: widget.isBot
                        ? Colors.white38
                        : Colors.white.withOpacity(0.7),
                    fontSize: 10,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  void _showMessageOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              PremiumColors.cardBg,
              PremiumColors.darkBg2,
            ],
          ),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(
            color: PremiumColors.accentGradient1.withOpacity(0.2),
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: 20),
              _buildOptionTile(
                icon: Icons.copy,
                label: 'Copy message',
                onTap: () {
                  Clipboard.setData(ClipboardData(text: widget.message));
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Message copied'),
                      backgroundColor: PremiumColors.successGreen,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                },
              ),
              if (widget.isBot) ...[
                _buildOptionTile(
                  icon: Icons.refresh,
                  label: 'Regenerate response',
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
                _buildOptionTile(
                  icon: Icons.bookmark_outline,
                  label: 'Save to notes',
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
              ],
              _buildOptionTile(
                icon: Icons.share,
                label: 'Share',
                onTap: () {
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: PremiumColors.accentGradient1.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: PremiumColors.accentGradient1,
                  size: 20,
                ),
              ),
              SizedBox(width: 14),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Quick action chips for common responses
class QuickActionChips extends StatelessWidget {
  final List<String> suggestions;
  final Function(String) onTap;

  const QuickActionChips({
    Key? key,
    required this.suggestions,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16),
        itemCount: suggestions.length,
        separatorBuilder: (_, __) => SizedBox(width: 10),
        itemBuilder: (context, index) {
          return _buildChip(suggestions[index]);
        },
      ),
    );
  }

  Widget _buildChip(String text) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap(text);
        },
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                PremiumColors.accentGradient1.withOpacity(0.15),
                PremiumColors.accentGradient2.withOpacity(0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: PremiumColors.accentGradient1.withOpacity(0.3),
            ),
          ),
          child: Text(
            text,
            style: TextStyle(
              color: PremiumColors.accentGradient1,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
