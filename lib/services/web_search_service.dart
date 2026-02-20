import 'api_service.dart';

/// Service for handling web searches — routed through backend.
class WebSearchService {
  /// Performs a web search by delegating to the backend. The backend
  /// can call Tavily or other search providers securely.
  ///
  /// [conversationHistory] - Optional list of conversation messages to provide
  /// context for the search. This helps the AI understand what the user was
  /// discussing and return more relevant search results.
  Future<String> search({
    required String query,
    int maxResults = 5,
    String searchDepth = 'basic',
    List<Map<String, String>>? conversationHistory,
  }) async {
    try {
      final input = {
        'query': query,
        'maxResults': maxResults,
        'searchDepth': searchDepth,
        'includeAnswer': true,
        // Include conversation history for context-aware searches
        if (conversationHistory != null && conversationHistory.isNotEmpty)
          'messages': conversationHistory,
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
  /// The model's intelligence comes first - web results are supplementary
  String createEnhancedPrompt(String originalQuery, String searchResults) {
    return '''
$originalQuery

Use your knowledge and understanding to answer this question. The following information from web search is provided to supplement and improve your answer - use it if relevant to provide the most current and accurate information:

---
Web Search Results:
$searchResults
---

Respond naturally and conversationally. Base your answer primarily on your knowledge and reasoning, and incorporate the web results only where they add value or provide current information. Do not simply repeat the search results - synthesize them with your understanding.
''';
  }
}
