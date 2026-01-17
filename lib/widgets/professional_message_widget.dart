import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import '../utils/theme.dart';

/// Professional message formatter matching ChatGPT style
/// Features:
/// - Enhanced LaTeX math rendering with better display modes
/// - Smart heading hierarchy with varied sizing and colors
/// - Generous spacing between paragraphs and sections
/// - Invisible line breaks between major sections
/// - Code blocks with language badges and syntax highlighting
/// - Styled bullet points with custom colors
/// - Numbered lists with proper indentation
/// - Dynamic block spacing based on content type
/// - Professional typography and line heights (1.6-1.8 for text)
class ProfessionalMessageWidget extends StatelessWidget {
  final String text;
  final bool isBot;

  const ProfessionalMessageWidget(this.text, {Key? key, this.isBot = true})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Split into blocks (paragraphs, code, lists, etc.)
    final blocks = _parseMessageBlocks(text);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < blocks.length; i++) ...[
            _buildBlock(blocks[i], context),
            // Dynamic spacing between blocks
            if (i < blocks.length - 1)
              SizedBox(height: _getBlockSpacing(blocks[i], blocks[i + 1])),
          ],
        ],
      ),
    );
  }

  /// Parse message into structured blocks
  List<MessageBlock> _parseMessageBlocks(String text) {
    final blocks = <MessageBlock>[];
    final lines = text.split('\n');
    var currentBlock = <String>[];
    var blockType = BlockType.paragraph;

    for (final line in lines) {
      final trimmed = line.trim();

      if (trimmed.isEmpty) {
        if (currentBlock.isNotEmpty) {
          blocks.add(MessageBlock(blockType, currentBlock.join('\n')));
          currentBlock = [];
        }
        continue;
      }

      final newBlockType = _detectBlockType(trimmed);

      if (newBlockType != blockType && currentBlock.isNotEmpty) {
        blocks.add(MessageBlock(blockType, currentBlock.join('\n')));
        currentBlock = [];
      }

      blockType = newBlockType;
      currentBlock.add(line);
    }

    if (currentBlock.isNotEmpty) {
      blocks.add(MessageBlock(blockType, currentBlock.join('\n')));
    }

    return blocks;
  }

  /// Detect block type from content
  BlockType _detectBlockType(String line) {
    final trimmed = line.trim();

    // Headings
    if (trimmed.startsWith('###')) return BlockType.heading3;
    if (trimmed.startsWith('##')) return BlockType.heading2;
    if (trimmed.startsWith('#')) return BlockType.heading1;

    // Code block
    if (trimmed.startsWith('```')) return BlockType.code;

    // Lists
    if (trimmed.startsWith('•') ||
        trimmed.startsWith('-') ||
        trimmed.startsWith('*') ||
        RegExp(r'^\d+\.').hasMatch(trimmed)) {
      return BlockType.bulletList;
    }

    // Math (LaTeX)
    if (trimmed.startsWith('\$\$') || trimmed.startsWith(r'$$')) {
      return BlockType.mathBlock;
    }

    return BlockType.paragraph;
  }

  /// Build widget for block type
  Widget _buildBlock(MessageBlock block, BuildContext context) {
    switch (block.type) {
      case BlockType.heading1:
        return _buildHeading(block.content, 1);
      case BlockType.heading2:
        return _buildHeading(block.content, 2);
      case BlockType.heading3:
        return _buildHeading(block.content, 3);
      case BlockType.code:
        return _buildCodeBlock(block.content);
      case BlockType.bulletList:
        return _buildBulletList(block.content);
      case BlockType.mathBlock:
        return _buildMathBlock(block.content);
      case BlockType.paragraph:
      default:
        return _buildParagraph(block.content);
    }
  }

  /// Build paragraph with inline LaTeX support
  Widget _buildParagraph(String content) {
    final text = content.trim();
    if (text.isEmpty) return SizedBox.shrink();

    // Check if paragraph contains inline math
    if (text.contains(r'$') && !text.startsWith(r'$$')) {
      return _buildMixedContentParagraph(text);
    }

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.0),
      child: SelectableText(
        text,
        style: TextStyle(
          fontSize: 15,
          height: 1.75,
          color: AppTheme.textPrimary,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  /// Build paragraph with mixed text and LaTeX
  Widget _buildMixedContentParagraph(String text) {
    final spans = <InlineSpan>[];
    var lastIndex = 0;

    // Regex to find $...$ patterns (inline math)
    final mathRegex = RegExp(r'\$([^\$]+)\$');

    for (final match in mathRegex.allMatches(text)) {
      // Add text before math
      if (match.start > lastIndex) {
        spans.add(
          TextSpan(
            text: text.substring(lastIndex, match.start),
            style: TextStyle(
              fontSize: 15,
              height: 1.75,
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w400,
              letterSpacing: 0.2,
            ),
          ),
        );
      }

      // Add math with proper styling
      final mathContent = match.group(1) ?? '';
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
            child: Math.tex(
              mathContent,
              textStyle: TextStyle(color: AppTheme.primaryBlue, fontSize: 15),
              onErrorFallback: (error) {
                return Text(
                  '\$${mathContent}\$',
                  style: TextStyle(
                    color: AppTheme.primaryBlue,
                    fontFamily: 'monospace',
                  ),
                );
              },
            ),
          ),
        ),
      );

      lastIndex = match.end;
    }

    // Add remaining text
    if (lastIndex < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(lastIndex),
          style: TextStyle(
            fontSize: 15,
            height: 1.75,
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w400,
            letterSpacing: 0.2,
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.0),
      child: RichText(text: TextSpan(children: spans)),
    );
  }

  /// Build heading with enhanced visual hierarchy
  Widget _buildHeading(String content, int level) {
    final text = content.replaceFirst(RegExp(r'^#+\s*'), '').trim();
    if (text.isEmpty) return SizedBox.shrink();

    final fontSizes = {1: 28.0, 2: 22.0, 3: 18.0};
    final topPadding = {1: 20.0, 2: 16.0, 3: 12.0};
    final bottomPadding = {1: 12.0, 2: 10.0, 3: 8.0};
    final fontWeights = {
      1: FontWeight.w800,
      2: FontWeight.w700,
      3: FontWeight.w700,
    };

    return Padding(
      padding: EdgeInsets.only(
        top: topPadding[level] ?? 12,
        bottom: bottomPadding[level] ?? 8,
      ),
      child: SelectableText(
        text,
        style: TextStyle(
          fontSize: fontSizes[level] ?? 16,
          fontWeight: fontWeights[level] ?? FontWeight.w700,
          color: level == 1 ? AppTheme.primaryBlue : AppTheme.textPrimary,
          height: 1.3,
          letterSpacing: level == 1 ? 0.2 : 0.1,
        ),
      ),
    );
  }

  /// Build code block with enhanced styling
  Widget _buildCodeBlock(String content) {
    final code = content
        .replaceFirst('```', '')
        .replaceAll(RegExp(r'```$'), '')
        .trim();

    if (code.isEmpty) return SizedBox.shrink();

    // Extract language if specified
    final lines = code.split('\n');
    var language = '';
    var codeContent = code;

    if (lines.isNotEmpty && !lines[0].contains(RegExp(r'[{}();]'))) {
      language = lines[0];
      codeContent = lines.skip(1).join('\n');
    }

    return Container(
      margin: EdgeInsets.symmetric(vertical: 12.0),
      decoration: BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppTheme.primaryBlue.withOpacity(0.2),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (language.isNotEmpty)
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withOpacity(0.15),
                border: Border(
                  bottom: BorderSide(
                    color: AppTheme.primaryBlue.withOpacity(0.2),
                    width: 1,
                  ),
                ),
              ),
              child: Text(
                language.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.primaryBlue,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          Padding(
            padding: EdgeInsets.all(14),
            child: SelectableText(
              codeContent,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                height: 1.7,
                color: Colors.grey[300],
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build bullet/numbered list with enhanced styling
  Widget _buildBulletList(String content) {
    final items = content
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .toList();

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < items.length; i++) ...[
            _buildListItem(items[i].trim()),
            if (i < items.length - 1) SizedBox(height: 6.0),
          ],
        ],
      ),
    );
  }

  /// Build single list item with enhanced styling
  Widget _buildListItem(String item) {
    String bullet = '•';
    String text = item;
    Color bulletColor = AppTheme.primaryBlue;

    // Extract bullet/number
    if (item.startsWith('•')) {
      text = item.replaceFirst('•', '').trim();
      bullet = '•';
      bulletColor = AppTheme.primaryBlue;
    } else if (item.startsWith('-')) {
      text = item.replaceFirst('-', '').trim();
      bullet = '•';
      bulletColor = AppTheme.primaryBlue;
    } else if (item.startsWith('*')) {
      text = item.replaceFirst('*', '').trim();
      bullet = '◦';
      bulletColor = AppTheme.primaryBlue.withOpacity(0.7);
    } else {
      final match = RegExp(r'^(\d+)\.').firstMatch(item);
      if (match != null) {
        bullet = '${match.group(1)}.';
        text = item.substring(match.end).trim();
        bulletColor = AppTheme.primaryBlue;
      }
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(right: 12, top: 3),
          child: Text(
            bullet,
            style: TextStyle(
              fontSize: 16,
              height: 1.4,
              color: bulletColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: SelectableText(
            text,
            style: TextStyle(
              fontSize: 15,
              height: 1.75,
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w400,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ],
    );
  }

  /// Build math block (display mode) with enhanced styling
  Widget _buildMathBlock(String content) {
    final math = content
        .replaceAll(RegExp(r'^\$\$'), '')
        .replaceAll(RegExp(r'\$\$$'), '')
        .trim();

    if (math.isEmpty) return SizedBox.shrink();

    return Container(
      margin: EdgeInsets.symmetric(vertical: 16.0),
      padding: EdgeInsets.all(18.0),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primaryBlue.withOpacity(0.15),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryBlue.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Math.tex(
          math,
          textStyle: TextStyle(
            fontSize: 18,
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w500,
          ),
          onErrorFallback: (error) {
            return SelectableText(
              '\$\$\n$math\n\$\$',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
                fontFamily: 'monospace',
              ),
              textAlign: TextAlign.center,
            );
          },
        ),
      ),
    );
  }

  /// Get dynamic spacing between blocks (invisible line breaks)
  double _getBlockSpacing(MessageBlock current, MessageBlock next) {
    // Extra spacing after headings
    if (current.type == BlockType.heading1) {
      return 14.0;
    }
    if (current.type == BlockType.heading2 ||
        current.type == BlockType.heading3) {
      return 12.0;
    }

    // Extra spacing around code blocks
    if (current.type == BlockType.code || next.type == BlockType.code) {
      return 14.0;
    }

    // Extra spacing around math blocks
    if (current.type == BlockType.mathBlock ||
        next.type == BlockType.mathBlock) {
      return 14.0;
    }

    // Extra spacing before lists
    if (next.type == BlockType.bulletList) {
      return 10.0;
    }

    // Standard spacing between paragraphs
    return 10.0;
  }
}

/// Message block structure
class MessageBlock {
  final BlockType type;
  final String content;

  MessageBlock(this.type, this.content);
}

/// Block types
enum BlockType {
  paragraph,
  heading1,
  heading2,
  heading3,
  code,
  bulletList,
  mathBlock,
}
