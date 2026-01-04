import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ApiService {
  // Backend URL (Render)
  static const String baseUrl = "https://ai-backend-vf75.onrender.com";

  /// Send a request to the backend's unified /api/ask endpoint
  /// Handles: chat (Groq), search (Tavily), image (Gemini)
  ///
  /// Example calls:
  /// - Chat: send('chat', {'message': 'Hello'})
  /// - Search: send('search', {'query': 'best pizza'})
  /// - Image: send('image', {'imageUrl': '...', 'prompt': 'analyze'})
  static Future<String> send(String type, Map<String, dynamic> data) async {
    // Validate inputs
    if (type.isEmpty) {
      throw Exception('Request type cannot be empty');
    }
    if (data.isEmpty) {
      throw Exception('Request data cannot be empty');
    }

    // Ensure the type is one of the supported types
    final supportedTypes = ['chat', 'search', 'image'];
    final requestType = supportedTypes.contains(type) ? type : 'chat';

    if (requestType != type) {
      print('⚠️ Warning: Unknown type "$type", defaulting to "chat"');
    }

    final body = jsonEncode({'type': requestType, 'data': data});

    try {
      print('📡 [API Request] Calling $baseUrl/api/ask');
      print('📦 [Request Body] type: $requestType, data: $data');

      final response = await http
          .post(
            Uri.parse("$baseUrl/api/ask"),
            headers: <String, String>{'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(
            const Duration(seconds: 60),
            onTimeout: () {
              throw Exception(
                'Request timeout: No response from backend after 60 seconds',
              );
            },
          );

      print('✅ [Response Received] Status: ${response.statusCode}');
      print('📄 [Response Body] ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        try {
          final decodedData = jsonDecode(response.body);
          if (decodedData is Map) {
            // Extract the response content based on type
            if (decodedData.containsKey('reply')) {
              print('💬 [Chat Response] ${decodedData['reply']}');
              return decodedData['reply'].toString(); // Groq chat response
            } else if (decodedData.containsKey('results')) {
              print('🔍 [Search Results] Found results');
              return jsonEncode(
                decodedData['results'],
              ); // Tavily search results
            } else if (decodedData.containsKey('analysis')) {
              print('🖼️ [Image Analysis] ${decodedData['analysis']}');
              return decodedData['analysis']
                  .toString(); // Gemini image analysis
            } else if (decodedData.containsKey('response')) {
              print('📝 [Generic Response] ${decodedData['response']}');
              return decodedData['response'].toString(); // Generic response
            } else {
              print('⚠️ [Warning] Unexpected response format: $decodedData');
              return response.body;
            }
          }
          return response.body;
        } catch (jsonError) {
          print('❌ [JSON Parse Error] Failed to decode response: $jsonError');
          throw Exception('Failed to parse backend response: $jsonError');
        }
      } else {
        // Handle error responses
        String errorMessage = response.body;
        try {
          final parsed = jsonDecode(response.body);
          if (parsed is Map) {
            if (parsed.containsKey('message')) {
              errorMessage = parsed['message'].toString();
            }
            if (parsed.containsKey('error')) {
              errorMessage = '${parsed['error']}: $errorMessage';
            }
          }
        } catch (_) {
          // Keep the raw response body as error message
        }
        print(
          '❌ [Backend Error] Status: ${response.statusCode}, Message: $errorMessage',
        );
        throw Exception(
          'Backend error (${response.statusCode}): $errorMessage',
        );
      }
    } on http.ClientException catch (e) {
      print('❌ [HTTP Client Error] $e');
      throw Exception('HTTP client error: $e');
    } on SocketException catch (e) {
      print('❌ [Network Error] Failed to connect to backend: $e');
      throw Exception(
        'Network error: Unable to reach backend. Check your connection and ensure backend is running at $baseUrl',
      );
    } catch (e) {
      print('❌ [Unknown Error] $e');
      rethrow;
    }
  }
}
