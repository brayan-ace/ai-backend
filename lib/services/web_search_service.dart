import 'api_service.dart';

/// Service for handling web searches — routed through backend.
class WebSearchService {
  /// Performs a web search by delegating to the backend. The backend
  /// can call Tavily or other search providers securely.
  Future<String> search({
    required String query,
    int maxResults = 5,
    String searchDepth = 'basic',
  }) async {
    try {
      final input = {
        'query': query,
        'maxResults': maxResults,
        'searchDepth': searchDepth,
        'includeAnswer': true,
      };
      final resp = await ApiService.send('search', input);
      return resp;
    } catch (e) {
      return 'Error during web search: $e. Please try again.';
    }
  }

  // Formatting moved to backend; keep method removed to avoid unused declaration.

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
