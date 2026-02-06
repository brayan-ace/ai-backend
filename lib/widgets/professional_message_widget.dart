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
/// - Full text selection support
class ProfessionalMessageWidget extends StatelessWidget {
  final String text;
  final bool isBot;

  // Static regex patterns for performance - compiled once
  static final RegExp _escapedNewlinePattern = RegExp(r'\\n');
  static final RegExp _brTagPattern = RegExp(
    r'<br\s*\/?>',
    caseSensitive: false,
  );
  static final RegExp _crlfPattern = RegExp(r'\r\n');
  static final RegExp _trailingSpacesPattern = RegExp(r' {2,}\n');
  static final RegExp _lineEndSpacesPattern = RegExp(r'[ \t]+\n');
  static final RegExp _codeBlockStartPattern = RegExp(r'^```');
  static final RegExp _codeBlockEndPattern = RegExp(r'```$');
  static final RegExp _headingPattern = RegExp(r'^(#{1,3})\s+(.*)$');
  static final RegExp _numberedListPattern = RegExp(r'^(\d+)\.\s+(.*)$');
  static final RegExp _bulletListPattern = RegExp(r'^[-•*]\s+(.*)$');
  static final RegExp _displayMathPattern = RegExp(
    r'^\$\$([\s\S]*?)\$\$$',
    multiLine: true,
  );
  static final RegExp _latexBracketOpenPattern = RegExp(r'\\\[');
  static final RegExp _latexBracketClosePattern = RegExp(r'\\\]');
  static final RegExp _latexParenOpenPattern = RegExp(r'\\\(');
  static final RegExp _latexParenClosePattern = RegExp(r'\\\)');

  const ProfessionalMessageWidget(this.text, {Key? key, this.isBot = true})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Split into blocks (paragraphs, code, lists, etc.) using state machine
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

  /// Parse message into structured blocks using a state machine approach
  /// This properly handles multi-line code blocks and math blocks
  List<MessageBlock> _parseMessageBlocks(String text) {
    final blocks = <MessageBlock>[];
    final normalized = _normalizeText(text);
    final lines = normalized.split('\n');

    var currentBlock = <String>[];
    var blockType = BlockType.paragraph;
    var inCodeBlock = false;
    var inMathBlock = false;
    var codeLanguage = '';

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trim();

      // Handle code block boundaries
      if (trimmed.startsWith('```')) {
        if (!inCodeBlock && !inMathBlock) {
          // Starting a code block
          if (currentBlock.isNotEmpty) {
            blocks.add(MessageBlock(blockType, currentBlock.join('\n')));
            currentBlock = [];
          }
          inCodeBlock = true;
          blockType = BlockType.code;
          // Extract language if present
          codeLanguage = trimmed.substring(3).trim();
          if (codeLanguage.isNotEmpty) {
            currentBlock.add('```$codeLanguage');
          } else {
            currentBlock.add('```');
          }
        } else if (inCodeBlock) {
          // Ending a code block
          currentBlock.add('```');
          blocks.add(MessageBlock(BlockType.code, currentBlock.join('\n')));
          currentBlock = [];
          inCodeBlock = false;
          blockType = BlockType.paragraph;
          codeLanguage = '';
        } else {
          // Inside math block, treat as content
          currentBlock.add(line);
        }
        continue;
      }

      // Handle display math block boundaries ($$)
      if (trimmed.startsWith(r'$$') && !inCodeBlock) {
        if (!inMathBlock) {
          // Starting a math block
          if (currentBlock.isNotEmpty) {
            blocks.add(MessageBlock(blockType, currentBlock.join('\n')));
            currentBlock = [];
          }
          inMathBlock = true;
          blockType = BlockType.mathBlock;
          // Check if it's a single-line math block like $$x^2$$
          if (trimmed.length > 4 && trimmed.endsWith(r'$$')) {
            blocks.add(MessageBlock(BlockType.mathBlock, trimmed));
            inMathBlock = false;
            blockType = BlockType.paragraph;
          } else {
            currentBlock.add(line);
          }
        } else {
          // Ending a math block
          currentBlock.add(line);
          blocks.add(
            MessageBlock(BlockType.mathBlock, currentBlock.join('\n')),
          );
          currentBlock = [];
          inMathBlock = false;
          blockType = BlockType.paragraph;
        }
        continue;
      }

      // If inside code or math block, just add the line
      if (inCodeBlock || inMathBlock) {
        currentBlock.add(line);
        continue;
      }

      // Handle empty lines - they separate blocks
      if (trimmed.isEmpty) {
        if (currentBlock.isNotEmpty) {
          blocks.add(MessageBlock(blockType, currentBlock.join('\n')));
          currentBlock = [];
          blockType = BlockType.paragraph;
        }
        continue;
      }

      // Detect block type for this line
      final newBlockType = _detectBlockType(trimmed);

      // If block type changes, save current block and start new one
      if (newBlockType != blockType && currentBlock.isNotEmpty) {
        blocks.add(MessageBlock(blockType, currentBlock.join('\n')));
        currentBlock = [];
      }

      blockType = newBlockType;
      currentBlock.add(line);
    }

    // Don't forget the last block
    if (currentBlock.isNotEmpty) {
      blocks.add(MessageBlock(blockType, currentBlock.join('\n')));
    }

    return blocks;
  }

  /// Normalize common newline/linebreak encodings
  String _normalizeText(String text) {
    if (text.isEmpty) return text;
    var t = text;

    // Convert escaped newline sequences (literal backslash-n) into real newlines
    t = t.replaceAll(_escapedNewlinePattern, '\n');

    // Convert HTML <br> tags to newline
    t = t.replaceAll(_brTagPattern, '\n');

    // Normalize CRLF to LF
    t = t.replaceAll(_crlfPattern, '\n');

    // Convert LaTeX display and inline bracket forms to dollar forms
    t = t.replaceAll(_latexBracketOpenPattern, r'$$');
    t = t.replaceAll(_latexBracketClosePattern, r'$$');
    t = t.replaceAll(_latexParenOpenPattern, r'$');
    t = t.replaceAll(_latexParenClosePattern, r'$');

    // Treat two or more trailing spaces before a newline as paragraph break
    t = t.replaceAll(_trailingSpacesPattern, '\n\n');

    // Trim trailing spaces at end of lines while preserving line breaks
    t = t.replaceAll(_lineEndSpacesPattern, '\n');

    return t;
  }

  /// Detect block type from content (for non-code, non-math lines)
  BlockType _detectBlockType(String line) {
    final trimmed = line.trim();

    // Headings with # prefix
    if (trimmed.startsWith('###')) return BlockType.heading3;
    if (trimmed.startsWith('##')) return BlockType.heading2;
    if (trimmed.startsWith('#')) return BlockType.heading1;

    // Check for bold-only line that could be a heading
    // Must be **text** with no other content
    if (trimmed.startsWith('**') && trimmed.endsWith('**')) {
      final inner = trimmed.substring(2, trimmed.length - 2).trim();
      // Only treat as heading if it's short and not generic
      if (inner.isNotEmpty && !inner.contains('**')) {
        final wordCount = inner
            .split(RegExp(r'\s+'))
            .where((s) => s.isNotEmpty)
            .length;
        final lower = inner.toLowerCase();
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
        if (wordCount <= 6 && !generic.contains(lower)) {
          return BlockType.heading1;
        }
      }
    }

    // Lists - be careful with * to not confuse with italic
    // Only treat as list if followed by space
    if (trimmed.startsWith('• ') || trimmed.startsWith('- ')) {
      return BlockType.bulletList;
    }
    // For *, only treat as bullet if followed by space and not **
    if (trimmed.startsWith('* ') && !trimmed.startsWith('**')) {
      return BlockType.bulletList;
    }
    if (_numberedListPattern.hasMatch(trimmed)) {
      return BlockType.bulletList;
    }

    return BlockType.paragraph;
  }

  /// Build widget for block type
  Widget _buildBlock(MessageBlock block, BuildContext context) {
    switch (block.type) {
      case BlockType.heading1:
        return _buildHeading(block.content, 1, context);
      case BlockType.heading2:
        return _buildHeading(block.content, 2, context);
      case BlockType.heading3:
        return _buildHeading(block.content, 3, context);
      case BlockType.code:
        return _buildCodeBlock(block.content, context);
      case BlockType.bulletList:
        return _buildBulletList(block.content, context);
      case BlockType.mathBlock:
        return _buildMathBlock(block.content, context);
      case BlockType.paragraph:
        return _buildParagraph(block.content, context);
    }
  }

  /// Build paragraph with inline LaTeX support and markdown
  Widget _buildParagraph(String content, BuildContext context) {
    final text = content.trim();
    if (text.isEmpty) return SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Check if this paragraph contains a markdown table
    final isTable = text.contains('|') && text.contains('\n') &&
                    RegExp(r'\|[^\n]+\|').hasMatch(text);

    final spans = _parseInlineContent(text, context);

    final textWidget = SelectableText.rich(
      TextSpan(
        children: spans,
        style: TextStyle(
          fontSize: 15,
          height: 1.85,
          fontWeight: FontWeight.w400,
          color: isDark ? AppTheme.textPrimary : Color(0xFF374151),
          letterSpacing: 0.2,
        ),
      ),
    );

    // Wrap tables in horizontal scroll
    if (isTable) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: textWidget,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: textWidget,
    );
  }

  /// Parse inline content with proper handling of all markdown formats
  /// Uses a token-based approach to avoid regex conflicts
  List<InlineSpan> _parseInlineContent(String text, BuildContext context) {
    final spans = <InlineSpan>[];
    var i = 0;
    var plainBuffer = StringBuffer();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final defaultStyle = TextStyle(
      fontSize: 15,
      height: 1.85,
      color: isDark ? AppTheme.textPrimary : Color(0xFF374151),
      fontWeight: FontWeight.w400,
      letterSpacing: 0.2,
    );

    final boldStyle = TextStyle(
      fontSize: 15,
      height: 1.85,
      color: isDark ? AppTheme.textPrimary : Color(0xFF1F2937),
      fontWeight: FontWeight.w700,
      letterSpacing: 0.2,
    );

    final italicStyle = TextStyle(
      fontSize: 15,
      height: 1.85,
      color: isDark ? AppTheme.textPrimary : Color(0xFF374151),
      fontStyle: FontStyle.italic,
      letterSpacing: 0.2,
    );

    void flushPlain() {
      if (plainBuffer.isNotEmpty) {
        spans.add(TextSpan(text: plainBuffer.toString(), style: defaultStyle));
        plainBuffer.clear();
      }
    }

    while (i < text.length) {
      // Check for escaped characters
      if (text[i] == '\\' && i + 1 < text.length) {
        final next = text[i + 1];
        if (r'*`$\'.contains(next)) {
          plainBuffer.write(next);
          i += 2;
          continue;
        }
      }

      // Check for inline code `code`
      if (text[i] == '`') {
        final endIdx = text.indexOf('`', i + 1);
        if (endIdx != -1) {
          flushPlain();
          final code = text.substring(i + 1, endIdx);
          spans.add(
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppTheme.surfaceElevated.withOpacity(0.3)
                      : Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  code,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.primaryBlue,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
          );
          i = endIdx + 1;
          continue;
        }
      }

      // Check for inline math $math$ (but not $$)
      if (text[i] == r'$' && (i + 1 >= text.length || text[i + 1] != r'$')) {
        // Find closing $ that's not escaped and not $$
        var endIdx = -1;
        for (var j = i + 1; j < text.length; j++) {
          if (text[j] == r'$' && (j == 0 || text[j - 1] != '\\')) {
            if (j + 1 >= text.length || text[j + 1] != r'$') {
              endIdx = j;
              break;
            }
          }
        }
        if (endIdx != -1 && endIdx > i + 1) {
          final mathContent = text.substring(i + 1, endIdx);
          // Only treat as math if it looks like math (contains letters/symbols)
          if (_looksLikeMath(mathContent)) {
            flushPlain();
            spans.add(
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: _buildInlineLatexWidget(mathContent, isDark),
              ),
            );
            i = endIdx + 1;
            continue;
          }
        }
      }

      // Check for bold **text** (must check before italic)
      if (i + 1 < text.length && text[i] == '*' && text[i + 1] == '*') {
        // Find closing **
        final closeIdx = text.indexOf('**', i + 2);
        if (closeIdx != -1) {
          flushPlain();
          final boldContent = text.substring(i + 2, closeIdx);
          // Recursively parse bold content for nested formatting
          if (boldContent.contains('*') ||
              boldContent.contains('`') ||
              boldContent.contains(r'$')) {
            final innerSpans = _parseInlineContent(boldContent, context);
            for (final span in innerSpans) {
              if (span is TextSpan) {
                spans.add(
                  TextSpan(
                    text: span.text,
                    style: boldStyle.merge(
                      span.style?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                );
              } else {
                spans.add(span);
              }
            }
          } else {
            spans.add(TextSpan(text: boldContent, style: boldStyle));
          }
          i = closeIdx + 2;
          continue;
        }
      }

      // Check for italic *text* (single asterisk, not followed by another)
      if (text[i] == '*' && (i + 1 >= text.length || text[i + 1] != '*')) {
        // Find closing * that's not part of **
        var endIdx = -1;
        for (var j = i + 1; j < text.length; j++) {
          if (text[j] == '*') {
            // Make sure it's not **
            if (j + 1 >= text.length || text[j + 1] != '*') {
              // Also make sure previous char wasn't *
              if (j == i + 1 || text[j - 1] != '*') {
                endIdx = j;
                break;
              }
            }
          }
        }
        if (endIdx != -1 && endIdx > i + 1) {
          flushPlain();
          final italicContent = text.substring(i + 1, endIdx);
          spans.add(TextSpan(text: italicContent, style: italicStyle));
          i = endIdx + 1;
          continue;
        }
      }

      // Regular character
      plainBuffer.write(text[i]);
      i++;
    }

    flushPlain();

    if (spans.isEmpty) {
      return [TextSpan(text: text, style: defaultStyle)];
    }

    return spans;
  }

  /// Check if content looks like math (not just a price like $5)
  bool _looksLikeMath(String content) {
    if (content.isEmpty) return false;
    // If it's just a number, it's probably a price
    if (RegExp(r'^\d+\.?\d*$').hasMatch(content.trim())) return false;
    // If it contains math operators or LaTeX commands, it's math
    if (content.contains('^') ||
        content.contains('_') ||
        content.contains('\\') ||
        content.contains('{') ||
        content.contains('frac') ||
        content.contains('sqrt') ||
        content.contains('sum') ||
        content.contains('int') ||
        content.contains('=') ||
        content.contains('+') ||
        content.contains('-') && content.length > 2) {
      return true;
    }
    // If it has letters and numbers mixed with operators, likely math
    if (RegExp(r'[a-zA-Z]').hasMatch(content) &&
        RegExp(r'[\^_{}=+\-*/]').hasMatch(content)) {
      return true;
    }
    // Single letter variables are math
    if (RegExp(r'^[a-zA-Z]$').hasMatch(content.trim())) return true;
    // Greek letters or common math expressions
    if (content.contains('alpha') ||
        content.contains('beta') ||
        content.contains('gamma') ||
        content.contains('pi') ||
        content.contains('theta') ||
        content.contains('lambda')) {
      return true;
    }
    return content.length > 1;
  }

  /// Build inline LaTeX widget with horizontal scroll support for long equations
  /// This prevents overflow errors on portrait mode and long expressions
  Widget _buildInlineLatexWidget(String mathContent, bool isDark) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 2, vertical: 0),
        child: _buildLatexWithFallback(
          mathContent,
          isDark,
          fontSize: 15,
          isInline: true,
        ),
      ),
    );
  }

  /// Build LaTeX widget with comprehensive error handling and graceful fallback
  /// Handles both inline and display math modes
  Widget _buildLatexWithFallback(
    String mathContent,
    bool isDark, {
    double fontSize = 18,
    bool isInline = false,
  }) {
    try {
      // Guard against empty math content
      if (mathContent.trim().isEmpty) {
        return Text(
          '\$\$',
          style: TextStyle(
            color: isDark ? AppTheme.textSecondary : Color(0xFF6B7280),
            fontSize: fontSize,
          ),
        );
      }

      return Math.tex(
        mathContent,
        textStyle: TextStyle(
          color: isDark ? AppTheme.textPrimary : Color(0xFF1F2937),
          fontSize: fontSize,
          fontWeight: isInline ? FontWeight.w400 : FontWeight.w500,
        ),
        onErrorFallback: (error) {
          // Graceful fallback: render as code box when LaTeX parsing fails
          // This prevents crashes on malformed LaTeX while showing formatted content
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: isInline ? 6 : 14,
                vertical: isInline ? 3 : 10,
              ),
              decoration: BoxDecoration(
                color: isDark
                    ? AppTheme.surfaceElevated.withOpacity(0.2)
                    : Color(0xFFF0F9FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark
                      ? AppTheme.primaryBlue.withOpacity(0.2)
                      : Color(0xFF93C5FD),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calculate_outlined,
                    size: isInline ? 14 : 16,
                    color: AppTheme.primaryBlue,
                  ),
                  SizedBox(width: isInline ? 4 : 8),
                  Text(
                    '[Math: Formula too complex to display]',
                    style: TextStyle(
                      fontSize: isInline ? 12 : 14,
                      color: isDark
                          ? AppTheme.textSecondary
                          : Color(0xFF1E40AF),
                      fontFamily: 'monospace',
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } catch (e) {
      // Emergency fallback if Math.tex throws an exception
      // Prevents app crash on unexpected LaTeX errors
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isInline ? 6 : 14,
            vertical: isInline ? 3 : 10,
          ),
          decoration: BoxDecoration(
            color: isDark
                ? Color(0xFF7F1D1D).withOpacity(0.2)
                : Color(0xFFFEF2F2),
            border: Border.all(
              color: isDark
                  ? Color(0xFFDC2626).withOpacity(0.3)
                  : Color(0xFFFECACA),
              width: 1,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.warning_outlined,
                size: isInline ? 14 : 16,
                color: isDark ? Color(0xFFFCA5A5) : Color(0xFFDC2626),
              ),
              SizedBox(width: isInline ? 4 : 8),
              Text(
                '[Math rendering error]',
                style: TextStyle(
                  fontSize: isInline ? 12 : 14,
                  color: isDark ? Color(0xFFFCA5A5) : Color(0xFFDC2626),
                  fontFamily: 'monospace',
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  /// Build heading with enhanced visual hierarchy
  Widget _buildHeading(String content, int level, BuildContext context) {
    // Remove leading hashes if present, and also remove surrounding bold markers
    var text = content.replaceFirst(RegExp(r'^#+\s*'), '').trim();
    text = text.replaceAll(RegExp(r'^\*{2}\s*|\s*\*{2}$'), '').trim();
    if (text.isEmpty) return SizedBox.shrink();
    final topPadding = {1: 24.0, 2: 20.0, 3: 16.0};
    final bottomPadding = {1: 14.0, 2: 12.0, 3: 10.0};
    final isDark = Theme.of(context).brightness == Brightness.dark;

    TextStyle style;
    if (level == 1) {
      style = AppTheme.displayLarge.copyWith(
        fontSize: 22,
        color: isDark ? AppTheme.textPrimary : Color(0xFF1F2937),
      );
    } else if (level == 2) {
      style = AppTheme.displayMedium.copyWith(
        fontSize: 19,
        color: isDark ? AppTheme.textPrimary : Color(0xFF1F2937),
      );
    } else {
      style = AppTheme.displaySmall.copyWith(
        fontSize: 17,
        color: isDark ? AppTheme.textPrimary : Color(0xFF1F2937),
      );
    }

    return Padding(
      padding: EdgeInsets.only(
        top: topPadding[level] ?? 16,
        bottom: bottomPadding[level] ?? 10,
      ),
      child: SelectableText(text, style: style, textAlign: TextAlign.left),
    );
  }

  /// Build code block with enhanced styling
  Widget _buildCodeBlock(String content, BuildContext context) {
    final code = content
        .replaceFirst('```', '')
        .replaceAll(RegExp(r'```$'), '')
        .trim();

    if (code.isEmpty) return SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
        color: isDark ? Color(0xFF1A1A1A) : Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppTheme.primaryBlue.withOpacity(0.2),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.3)
                : Colors.black.withOpacity(0.05),
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
                color: isDark ? Colors.grey[300] : Color(0xFF1F2937),
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build bullet/numbered list with enhanced styling
  Widget _buildBulletList(String content, BuildContext context) {
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
            _buildListItem(items[i].trim(), context),
            if (i < items.length - 1) SizedBox(height: 6.0),
          ],
        ],
      ),
    );
  }

  /// Build single list item with enhanced styling and inline markdown support
  Widget _buildListItem(String item, BuildContext context) {
    String bullet = '•';
    String text = item;
    Color bulletColor = AppTheme.primaryBlue;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Extract bullet/number - be careful with * to not confuse with bold
    if (item.startsWith('• ')) {
      text = item.substring(2).trim();
      bullet = '•';
      bulletColor = isDark ? AppTheme.textPrimary : Color(0xFF1F2937);
    } else if (item.startsWith('- ')) {
      text = item.substring(2).trim();
      bullet = '•';
      bulletColor = isDark ? AppTheme.textPrimary : Color(0xFF1F2937);
    } else if (item.startsWith('* ') && !item.startsWith('**')) {
      text = item.substring(2).trim();
      bullet = '◦';
      bulletColor = isDark
          ? AppTheme.textPrimary.withOpacity(0.9)
          : Color(0xFF374151);
    } else {
      final match = RegExp(r'^(\d+)\.\s+').firstMatch(item);
      if (match != null) {
        bullet = '${match.group(1)}.';
        text = item.substring(match.end).trim();
        bulletColor = isDark ? AppTheme.textPrimary : Color(0xFF1F2937);
      }
    }

    // Parse inline markdown within list item text
    final spans = _parseInlineContent(text, context);

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
          child: SelectableText.rich(
            TextSpan(
              children: spans,
              style: TextStyle(
                fontSize: 15,
                height: 1.85,
                color: isDark ? AppTheme.textPrimary : Color(0xFF374151),
                fontWeight: FontWeight.w400,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Build math block (display mode) with enhanced styling and horizontal scroll support
  /// Prevents overflow errors on long equations in portrait mode
  Widget _buildMathBlock(String content, BuildContext context) {
    final math = content
        .replaceAll(RegExp(r'^\$\$'), '')
        .replaceAll(RegExp(r'\$\$$'), '')
        .trim();

    if (math.isEmpty) return SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: EdgeInsets.symmetric(vertical: 16.0),
      padding: EdgeInsets.all(18.0),
      decoration: BoxDecoration(
        color: isDark
            ? AppTheme.surfaceElevated.withOpacity(0.08)
            : Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primaryBlue.withOpacity(0.15),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? AppTheme.primaryBlue.withOpacity(0.05)
                : Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      // Wrap in SingleChildScrollView with horizontal scroll capability
      // This allows long equations to scroll horizontally on small screens
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Center(
          child: _buildLatexWithFallback(
            math,
            isDark,
            fontSize: 18,
            isInline: false,
          ),
        ),
      ),
    );
  }

  /// Get dynamic spacing between blocks (invisible line breaks)
  double _getBlockSpacing(MessageBlock current, MessageBlock next) {
    // Extra spacing after headings
    if (current.type == BlockType.heading1) {
      return 20.0;
    }
    if (current.type == BlockType.heading2 ||
        current.type == BlockType.heading3) {
      return 18.0;
    }

    // Extra spacing around code blocks
    if (current.type == BlockType.code || next.type == BlockType.code) {
      return 18.0;
    }

    // Extra spacing around math blocks
    if (current.type == BlockType.mathBlock ||
        next.type == BlockType.mathBlock) {
      return 18.0;
    }

    // Extra spacing before lists
    if (next.type == BlockType.bulletList) {
      return 14.0;
    }

    // Standard spacing between paragraphs
    return 14.0;
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
