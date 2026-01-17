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
    final normalized = _normalizeText(text);
    final lines = normalized.split('\n');
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

  /// Normalize common newline/linebreak encodings so markdown-like
  /// formatting is preserved when the backend returns escaped sequences
  /// or HTML `<br>` tags. This converts literal `\\n` into real
  /// newlines, normalizes `<br>` to newline, and treats trailing two
  /// spaces + newline as a paragraph break.
  String _normalizeText(String text) {
    if (text.isEmpty) return text;
    var t = text;

    // Convert escaped newline sequences (literal backslash-n) into real newlines
    t = t.replaceAll('\\n', '\n');

    // Normalize bold markers that have stray spaces/newlines inside them
    // e.g. "** Hello **" -> "**Hello**" so our inline parser catches them
    t = t.replaceAllMapped(
      RegExp(r'\*{2}\s*(.+?)\s*\*{2}', dotAll: true),
      (m) => '**${m.group(1)!.trim()}**',
    );

    // Collapse accidental long runs of asterisks into a valid bold marker
    // e.g., "*****" or "****" -> "**" to avoid literal **** showing.
    t = t.replaceAllMapped(RegExp(r'\*{3,}'), (_) => '**');

    // Convert HTML <br> tags to newline (case-insensitive)
    t = t.replaceAll(RegExp(r'<br\s*\/?>', caseSensitive: false), '\n');

    // Normalize CRLF to LF
    t = t.replaceAll('\r\n', '\n');

    // Convert LaTeX display and inline bracket forms to dollar forms
    // so the existing parser can handle them. Convert \[ ... \] -> $$...$$
    // and \( ... \) -> $...$ (handles backslash-escaped bracket forms).
    t = t.replaceAll(RegExp(r'\\\[', caseSensitive: false), '\$\$');
    t = t.replaceAll(RegExp(r'\\\]', caseSensitive: false), '\$\$');
    t = t.replaceAll(RegExp(r'\\\(', caseSensitive: false), '\$');
    t = t.replaceAll(RegExp(r'\\\)', caseSensitive: false), '\$');

    // Treat two or more trailing spaces before a newline as an explicit
    // markdown line break — convert to an extra blank line (paragraph break)
    t = t.replaceAllMapped(RegExp(r' {2,}\n'), (m) => '\n\n');

    // Trim trailing spaces at end of lines while preserving line breaks
    t = t.replaceAll(RegExp(r'[ \t]+\n'), '\n');

    return t;
  }

  /// Detect block type from content
  BlockType _detectBlockType(String line) {
    final trimmed = line.trim();

    // Treat a single-line bold-only paragraph as a top-level heading only
    // when it's likely meaningful (not generic words like 'answer' or 'response').
    final boldOnlyMatch = RegExp(r'^\*\*(.+)\*\*$').firstMatch(trimmed);
    if (boldOnlyMatch != null) {
      final content = boldOnlyMatch.group(1)?.trim() ?? '';
      final lower = content.toLowerCase();
      // Reject generic labels that are not useful as headings
      final generic = {
        'answer',
        'answers',
        'response',
        'reply',
        'greeting',
        'greetings',
        'hello',
        'hi',
        'note',
        'summary',
        'definition',
      };
      // Heuristics: must contain letters, be reasonably short (<=6 words),
      // and not be a generic label.
      final wordCount = content
          .split(RegExp(r'\s+'))
          .where((s) => s.isNotEmpty)
          .length;
      final hasLetter = RegExp(r'[A-Za-z]').hasMatch(content);
      if (hasLetter && wordCount <= 6 && !generic.contains(lower)) {
        return BlockType.heading1;
      }
    }

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

    // Also accept LaTeX bracket forms and begin/end environments
    if (trimmed.startsWith('\\[') ||
        trimmed.startsWith('\\(') ||
        trimmed.contains('\\begin{')) {
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
        return _buildParagraph(block.content);
    }
  }

  /// Build paragraph with inline LaTeX support and markdown
  Widget _buildParagraph(String content) {
    final text = content.trim();
    if (text.isEmpty) return SizedBox.shrink();

    // Use RichText with a merged DefaultTextStyle so WidgetSpan (math/code)
    // can be rendered inline. SelectableText.rich does not reliably support
    // WidgetSpan in all Flutter versions, so RichText is safer here.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: DefaultTextStyle.merge(
        style: TextStyle(
          fontSize: 15,
          height: 1.75,
          fontWeight: FontWeight.w400,
          color: AppTheme.textPrimary,
          letterSpacing: 0.2,
        ),
        child: RichText(text: _parseInlineMarkdown(text)),
      ),
    );
  }

  /// Parse inline markdown formatting (**bold**, *italic*, `code`, $math$)
  InlineSpan _parseInlineMarkdown(String text) {
    final spans = <InlineSpan>[];
    var lastIndex = 0;

    // Pattern for **bold**, *italic*, `code`, and $math$
    final pattern = RegExp(
      r'\*\*(.+?)\*\*|\*(.+?)\*|`(.+?)`|\$([^\$]+)\$',
      multiLine: true,
      dotAll: true,
    );

    for (final match in pattern.allMatches(text)) {
      // Add plain text before match; pass it through the bold-fallback
      // splitter so any literal **bold** is rendered even if the main
      // pattern misses an edge case.
      if (match.start > lastIndex) {
        final plainSegment = text.substring(lastIndex, match.start);
        spans.addAll(_splitBoldFallback(plainSegment));
      }

      if (match.group(1) != null) {
        // **Bold**
        spans.add(
          TextSpan(
            text: match.group(1),
            style: TextStyle(
              fontSize: 15,
              height: 1.75,
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        );
      } else if (match.group(2) != null) {
        // *Italic*
        spans.add(
          TextSpan(
            text: match.group(2),
            style: TextStyle(
              fontSize: 15,
              height: 1.75,
              color: AppTheme.textPrimary,
              fontStyle: FontStyle.italic,
              letterSpacing: 0.2,
            ),
          ),
        );
      } else if (match.group(3) != null) {
        // `code`
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Color(0xFF2D333B),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                match.group(3) ?? '',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFFE06C75),
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
        );
      } else if (match.group(4) != null) {
        // $math$
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Math.tex(
              match.group(4) ?? '',
              textStyle: TextStyle(color: AppTheme.primaryBlue, fontSize: 15),
              onErrorFallback: (_) => Text(
                '\$${match.group(4)}\$',
                style: TextStyle(
                  color: AppTheme.primaryBlue,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
        );
      }

      lastIndex = match.end;
    }

    // Add remaining text and ensure leftover bold markers are handled
    if (lastIndex < text.length) {
      final remaining = text.substring(lastIndex);
      spans.addAll(_splitBoldFallback(remaining));
    }

    return TextSpan(children: spans.isEmpty ? [TextSpan(text: text)] : spans);
  }

  /// Fallback splitter: converts any literal `**bold**` occurrences in `s`
  /// into TextSpans, leaving other text as normal TextSpans. This is a
  /// safety net when the primary regex misses some edge cases.
  List<InlineSpan> _splitBoldFallback(String s) {
    final out = <InlineSpan>[];
    var last = 0;
    // Accept two-or-more asterisks as delimiters and allow inner whitespace.
    // This catches ****bold****, ******bold******, and ** bold ** variants.
    final pat = RegExp(r'\*{2,}\s*(.+?)\s*\*{2,}', dotAll: true);
    for (final m in pat.allMatches(s)) {
      if (m.start > last) {
        out.add(
          TextSpan(
            text: s.substring(last, m.start),
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
      final boldText = m.group(1) ?? '';
      out.add(
        TextSpan(
          text: boldText,
          style: TextStyle(
            fontSize: 15,
            height: 1.75,
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      );
      last = m.end;
    }
    if (last < s.length) {
      out.add(
        TextSpan(
          text: s.substring(last),
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
    return out;
  }

  /// Build heading with enhanced visual hierarchy
  Widget _buildHeading(String content, int level) {
    // Remove leading hashes if present, and also remove surrounding bold markers
    var text = content.replaceFirst(RegExp(r'^#+\s*'), '').trim();
    text = text.replaceAll(RegExp(r'^\*{2}\s*|\s*\*{2}$'), '').trim();
    if (text.isEmpty) return SizedBox.shrink();
    final topPadding = {1: 20.0, 2: 16.0, 3: 12.0};
    final bottomPadding = {1: 12.0, 2: 10.0, 3: 8.0};

    TextStyle style;
    if (level == 1) {
      style = AppTheme.displayLarge.copyWith(
        fontSize: 28,
        color: AppTheme.textPrimary,
      );
    } else if (level == 2) {
      style = AppTheme.displayMedium.copyWith(
        fontSize: 24,
        color: AppTheme.textPrimary,
      );
    } else {
      style = AppTheme.displaySmall.copyWith(
        fontSize: 20,
        color: AppTheme.textPrimary,
      );
    }

    return Padding(
      padding: EdgeInsets.only(
        top: topPadding[level] ?? 14,
        bottom: bottomPadding[level] ?? 10,
      ),
      child: SelectableText(text, style: style, textAlign: TextAlign.left),
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
      bulletColor = AppTheme.textPrimary;
    } else if (item.startsWith('-')) {
      text = item.replaceFirst('-', '').trim();
      bullet = '•';
      bulletColor = AppTheme.textPrimary;
    } else if (item.startsWith('*')) {
      text = item.replaceFirst('*', '').trim();
      bullet = '◦';
      bulletColor = AppTheme.textPrimary.withOpacity(0.9);
    } else {
      final match = RegExp(r'^(\d+)\.').firstMatch(item);
      if (match != null) {
        bullet = '${match.group(1)}.';
        text = item.substring(match.end).trim();
        bulletColor = AppTheme.textPrimary;
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
              fontSize: 18,
              height: 1.4,
              color: bulletColor,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Expanded(
          child: SelectableText(
            text,
            style: TextStyle(
              fontSize: 16,
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
