import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl =
      "http://localhost:3000"; // Replace with your backend URL

  static Future<String> chat(String message) async {
    final response = await http.post(
      Uri.parse("$baseUrl/chat"),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(<String, String>{'message': message}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data["response"];
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData["error"] ?? "Failed to get AI response");
    }
  }
}
