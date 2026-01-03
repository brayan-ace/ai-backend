import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Backend URL (Render)
  static const String baseUrl = "https://ai-backend-vf75.onrender.com";

  /// Send a request to the backend's unified /api/ask endpoint
  /// Handles: chat (Groq), search (Tavily), image (Gemini)
  ///
  /// Example calls:
  /// - Chat: send('groq', 'chat', {'message': 'Hello'})
  /// - Search: send('tavily', 'search', {'query': 'best pizza'})
  /// - Image: send('gemini', 'image', {'imageUrl': '...', 'prompt': 'analyze'})
  static Future<String> send(
    String provider,
    String action,
    dynamic input,
  ) async {
    // Map the old generic contract to the new /api/ask contract
    String requestType;
    Map<String, dynamic> requestData;

    if (provider == 'groq' && action == 'chat') {
      requestType = 'chat';
      requestData = input is Map ? input : {'message': input.toString()};
    } else if (provider == 'tavily' || action == 'search') {
      requestType = 'search';
      requestData = input is Map ? input : {'query': input.toString()};
    } else if (provider == 'google' ||
        provider == 'gemini' ||
        action == 'image') {
      requestType = 'image';
      requestData = input is Map ? input : {'imageUrl': input.toString()};
    } else {
      // Default to chat for unknown types
      requestType = 'chat';
      requestData = input is Map ? input : {'message': input.toString()};
    }

    final body = jsonEncode({'type': requestType, 'data': requestData});

    try {
      final response = await http
          .post(
            Uri.parse("$baseUrl/api/ask"),
            headers: <String, String>{'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(
            const Duration(seconds: 60),
            onTimeout: () =>
                throw Exception('Request timeout after 60 seconds'),
          );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data is Map) {
          // Extract the response content based on provider
          if (data.containsKey('reply')) {
            return data['reply'].toString(); // Groq chat response
          } else if (data.containsKey('results')) {
            return jsonEncode(data['results']); // Tavily search results
          } else if (data.containsKey('analysis')) {
            return data['analysis'].toString(); // Gemini image analysis
          } else if (data.containsKey('response')) {
            return data['response'].toString(); // Generic response
          }
        }
        return response.body;
      } else {
        String errorMessage = response.body;
        try {
          final parsed = jsonDecode(response.body);
          if (parsed is Map) {
            if (parsed.containsKey('error')) {
              errorMessage = parsed['error'].toString();
            }
            if (parsed.containsKey('message')) {
              errorMessage =
                  '${parsed['error'] ?? 'Error'}: ${parsed['message']}';
            }
          }
        } catch (_) {
          // Keep the raw response body as error message
        }
        throw Exception(
          'Backend error (${response.statusCode}): $errorMessage',
        );
      }
    } on http.ClientException catch (e) {
      throw Exception('Network error: $e');
    } catch (e) {
      rethrow;
    }
  }
}
