import 'dart:convert';
import 'package:http/http.dart' as http;

/// Service for handling web searches using Tavily API
class WebSearchService {
  static const String _apiKey = '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';
  static const String _baseUrl = 'https://api.tavily.com/search';

  /// Performs a web search using Tavily API
  ///
  /// Returns a formatted string containing search results
  /// that can be used to enhance AI responses
  Future<String> search({required String query, int maxResults = 5}) async {
    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'api_key': _apiKey,
          'query': query,
          'max_results': maxResults,
          'search_depth': 'basic',
          'include_answer': true,
          'include_raw_content': false,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return _formatSearchResults(data);
      } else {
        throw Exception('Search failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Web search error: $e');
    }
  }

  /// Formats search results into a readable string
  String _formatSearchResults(Map<String, dynamic> data) {
    final buffer = StringBuffer();

    // Add the answer if available
    if (data['answer'] != null && data['answer'].toString().isNotEmpty) {
      buffer.writeln('📋 Quick Answer:\n${data['answer']}\n');
      buffer.writeln('---\n');
    }

    // Add search results
    final results = data['results'] as List<dynamic>?;
    if (results != null && results.isNotEmpty) {
      buffer.writeln('🔍 Web Search Results:\n');

      for (var i = 0; i < results.length; i++) {
        final result = results[i];
        final title = result['title'] ?? 'No title';
        final url = result['url'] ?? '';
        final content = result['content'] ?? 'No content';

        buffer.writeln('${i + 1}. **$title**');
        buffer.writeln('   Source: $url');
        buffer.writeln('   $content\n');
      }
    }

    return buffer.toString();
  }

  /// Checks if the query requires web search based on keywords
  bool shouldSuggestWebSearch(String query) {
    final lowercaseQuery = query.toLowerCase();

    // Keywords that suggest recent/current information needs
    final webSearchKeywords = [
      'latest',
      'recent',
      'current',
      'today',
      'now',
      'update',
      '2024',
      '2025',
      'this year',
      'this month',
      'news',
      'price',
      'stock',
      'weather',
      'score',
      'election',
    ];

    return webSearchKeywords.any((keyword) => lowercaseQuery.contains(keyword));
  }

  /// Creates an enhanced prompt combining AI knowledge with web search results
  String createEnhancedPrompt(String originalQuery, String searchResults) {
    return '''
Web search results for: "$originalQuery"

$searchResults

Provide a clear, accurate answer based on these results. Be natural and conversational - only use special formatting (markdown, LaTeX) when it genuinely improves clarity. Focus on answering the question directly.
''';
  }
}
