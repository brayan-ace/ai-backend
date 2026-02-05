import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ApiService {
  // Backend URL (Railway)
  static const String baseUrl =
      "https://ai-backend-production-65d6.up.railway.app";

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
      // Decode raw bytes to a Dart string to avoid malformed UTF-16 from
      // intermediate encodings. Allow malformed so we don't crash on odd bytes.
      final bodyString = utf8.decode(response.bodyBytes, allowMalformed: true);
      // Rune-safe preview and newline/escaped-newline diagnostics
      final runeCount = bodyString.runes.length;
      final hasRealNewlines = bodyString.contains('\n');
      final hasEscapedNewlines = bodyString.contains('\\n');
      final preview = String.fromCharCodes(bodyString.runes.take(200));
      print('📄 [Response Body] $bodyString');
      print(
        '🔍 [RAW AI RESPONSE] length=$runeCount hasNewlines=$hasRealNewlines hasEscapedNewlines=$hasEscapedNewlines',
      );
      print('🔍 [RAW AI RESPONSE PREVIEW] $preview');

      if (response.statusCode == 200 || response.statusCode == 201) {
        try {
          final decodedData = jsonDecode(bodyString);
          if (decodedData is Map) {
            // Preserve backward compatibility by returning the textual reply when present
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
              return bodyString;
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

  /// Send request and return the raw decoded JSON (Map) from the backend.
  /// Useful for server responses that include structured flags (e.g., identityOffered).
  static Future<Map<String, dynamic>> sendRaw(
    String type,
    Map<String, dynamic> data,
  ) async {
    if (type.isEmpty) throw Exception('Request type cannot be empty');
    if (data.isEmpty) throw Exception('Request data cannot be empty');

    final supportedTypes = ['chat', 'search', 'image'];
    final requestType = supportedTypes.contains(type) ? type : 'chat';
    final body = jsonEncode({'type': requestType, 'data': data});

    print('📡 [sendRaw] POST $baseUrl/api/ask');
    print('📦 [sendRaw] Request Body: $body');

    final response = await http
        .post(
          Uri.parse("$baseUrl/api/ask"),
          headers: <String, String>{'Content-Type': 'application/json'},
          body: body,
        )
        .timeout(const Duration(seconds: 60));

    print('✅ [sendRaw] Response Status: ${response.statusCode}');
    final bodyString = utf8.decode(response.bodyBytes, allowMalformed: true);
    final runeCount = bodyString.runes.length;
    final hasRealNewlines = bodyString.contains('\n');
    final hasEscapedNewlines = bodyString.contains('\\n');
    final preview = String.fromCharCodes(bodyString.runes.take(400));
    print('📄 [sendRaw] Response Body: $bodyString');
    print(
      '🔍 [RAW AI RESPONSE] length=$runeCount hasNewlines=$hasRealNewlines hasEscapedNewlines=$hasEscapedNewlines',
    );
    print('🔍 [RAW AI RESPONSE PREVIEW] $preview');

    if (response.statusCode == 200 || response.statusCode == 201) {
      try {
        final decoded = jsonDecode(bodyString);
        if (decoded is Map<String, dynamic>) return decoded;
        return {'reply': bodyString};
      } catch (e) {
        throw Exception('Failed to parse backend response: $e');
      }
    }
    throw Exception('Backend error (${response.statusCode}): ${response.body}');
  }
}
