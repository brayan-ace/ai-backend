import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Backend URL (Render)
  static const String baseUrl = "https://ai-backend-vf75.onrender.com";

  /// Send a request to the central backend using the agreed JSON contract:
  /// { provider: "groq|openrouter|deepseek|tavily|google", action: "chat|generate|search|image", input: ... }
  static Future<String> send(
    String provider,
    String action,
    dynamic input,
  ) async {
    final body = jsonEncode({
      'provider': provider,
      'action': action,
      'input': input,
    });

    final response = await http.post(
      Uri.parse("$baseUrl/proxy"),
      headers: <String, String>{'Content-Type': 'application/json'},
      body: body,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is Map && data.containsKey('response'))
        return data['response'].toString();
      return response.body;
    } else {
      String body = response.body;
      try {
        final parsed = jsonDecode(response.body);
        if (parsed is Map && parsed.containsKey('error'))
          body = parsed['error'].toString();
      } catch (_) {}
      throw Exception('Backend error (${response.statusCode}): $body');
    }
  }
}
