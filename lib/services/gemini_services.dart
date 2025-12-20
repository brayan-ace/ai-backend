import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/ai_constants.dart';

class GeminiService {
  // API keys with fallback support
  static const String groqApiKey =
      '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';
  static const String openRouterApiKey =
      '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';
  static const String deepSeekApiKey = 'sk-8d17e5b0c355485da07af11f552e37f9';
  static const String geminiApiKey = 'AIzaSyBcUnqyaxQlomrxGFV55YSDbdDj0j0e_mE';

  /// Clean API key by removing spaces, newlines, tabs, and other unwanted characters
  String _cleanApiKey(String key) {
    return key
        .trim()
        .replaceAll(' ', '')
        .replaceAll('\n', '')
        .replaceAll('\r', '')
        .replaceAll('\t', '')
        .replaceAll('"', '')
        .replaceAll("'", '');
  }

  Future<String?> generateContent(String prompt) async {
    return _callApi(prompt);
  }

  /// Call Groq API with a custom system context (used for study plans)
  Future<String?> generateContentWithContext(
    String userMessage,
    String systemContext,
  ) async {
    return _callApi('$systemContext\n\nUser: $userMessage');
  }

  Future<String?> _callApi(String prompt) async {
    // Try Groq first
    var response = await _callGroq(prompt);
    if (response != null &&
        !response.contains('ERROR') &&
        !response.contains('⚠️')) {
      return response;
    }

    // If Groq fails, try OpenRouter
    response = await _callOpenRouter(prompt);
    if (response != null &&
        !response.contains('ERROR') &&
        !response.contains('⚠️')) {
      return response;
    }

    // If OpenRouter fails, try DeepSeek
    response = await _callDeepSeek(prompt);
    if (response != null &&
        !response.contains('ERROR') &&
        !response.contains('⚠️')) {
      return response;
    }

    // All APIs failed
    return '⚠️ All AI services are currently unavailable. Please try again later.';
  }

  Future<String?> _callGroq(String prompt) async {
    try {
      final uri = Uri.parse('https://api.groq.com/openai/v1/chat/completions');
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $groqApiKey',
        },
        body: jsonEncode({
          'model': 'llama-3.3-70b-versatile',
          'messages': [
            {'role': 'system', 'content': AiConstants.systemPrompt},
            {'role': 'user', 'content': prompt},
          ],
        }),
      );

      print('Groq API Status: ${response.statusCode}');
      print('Groq API Response: ${response.body}');

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        // Extract text from the response
        final choices = json['choices'] as List<dynamic>?;
        if (choices != null && choices.isNotEmpty) {
          final message = choices[0]['message'] as Map<String, dynamic>?;
          if (message != null) {
            var result = message['content'] as String?;
            if (result != null) {
              result = _cleanResponse(result);
            }
            return result;
          }
        }
        print('Groq: No text extracted from response');
        return '[[GROQ_ERROR: No text extracted from response]]';
      } else if (response.statusCode == 429) {
        print('Groq API Error: 429 - Quota exceeded');
        return '⚠️ API quota exceeded. Please wait a few minutes and try again.';
      } else {
        // Return the full response body so the app can display server errors to the user for debugging
        final body = response.body;
        final status = response.statusCode;
        print('Groq API Error: $status');
        print('Groq API Error body: $body');
        return '[[GROQ_ERROR status=$status]]\n$body';
      }
    } catch (e) {
      print('Groq Error: $e');
      return '[[GROQ_EXCEPTION]] $e';
    }
  }

  /// Clean up AI response by removing unwanted formatting and asterisks
  String _cleanResponse(String text) {
    // Remove "Final Answer:" prefix
    text = text.replaceFirst(RegExp(r'Final Answer:\s*'), '');

    // Remove \boxed{...} wrapper, keep just the content
    text = text.replaceAll(RegExp(r'\\boxed\{([^}]*)\}'), r'$1');

    // Remove extra "The final answer is" phrases
    text = text.replaceAll(RegExp(r'The final answer is\s*'), '');

    // Replace bold markdown (**text**) with plain text
    text = text.replaceAll(RegExp(r'\*\*([^*]+)\*\*'), r'$1');

    // Replace italic markdown (*text*) with plain text
    text = text.replaceAll(RegExp(r'(?<!\*)\*([^*]+)\*(?!\*)'), r'$1');

    // Unwrap display math $$...$$ and inline math $...$
    text = text.replaceAllMapped(
      RegExp(r'\$\$([\s\S]*?)\$\$'),
      (m) => m.group(1) ?? '',
    );
    text = text.replaceAllMapped(
      RegExp(r'\$([^\$]+)\$'),
      (m) => m.group(1) ?? '',
    );

    // Unescape any escaped dollar signs (\$) to literal $
    text = text.replaceAll(RegExp(r'\\\$'), r'\$');

    // Remove any remaining stray $ characters that may remain
    text = text.replaceAll('\$', '');

    // Clean up multiple spaces
    text = text.replaceAll(RegExp(r' {2,}'), ' ');

    return text.trim();
  }

  Future<String?> _callOpenRouter(String prompt) async {
    try {
      final uri = Uri.parse('https://openrouter.ai/api/v1/chat/completions');
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $openRouterApiKey',
        },
        body: jsonEncode({
          'model': 'meta-llama/llama-3.1-8b-instruct:free',
          'messages': [
            {'role': 'system', 'content': AiConstants.systemPrompt},
            {'role': 'user', 'content': prompt},
          ],
        }),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final choices = json['choices'] as List<dynamic>?;
        if (choices != null && choices.isNotEmpty) {
          final message = choices[0]['message'] as Map<String, dynamic>?;
          if (message != null) {
            var result = message['content'] as String?;
            if (result != null) {
              result = _cleanResponse(result);
            }
            return result;
          }
        }
        return '[[OPENROUTER: No text found]]';
      } else {
        return '[[OPENROUTER ERROR: ${response.statusCode}]]';
      }
    } catch (e) {
      return '[[OPENROUTER EXCEPTION]] $e';
    }
  }

  Future<String?> _callDeepSeek(String prompt) async {
    try {
      final uri = Uri.parse('https://api.deepseek.com/v1/chat/completions');
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $deepSeekApiKey',
        },
        body: jsonEncode({
          'model': 'deepseek-chat',
          'messages': [
            {'role': 'system', 'content': AiConstants.systemPrompt},
            {'role': 'user', 'content': prompt},
          ],
        }),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final choices = json['choices'] as List<dynamic>?;
        if (choices != null && choices.isNotEmpty) {
          final message = choices[0]['message'] as Map<String, dynamic>?;
          if (message != null) {
            var result = message['content'] as String?;
            if (result != null) {
              result = _cleanResponse(result);
            }
            return result;
          }
        }
        return '[[DEEPSEEK: No text found]]';
      } else {
        return '[[DEEPSEEK ERROR: ${response.statusCode}]]';
      }
    } catch (e) {
      return '[[DEEPSEEK EXCEPTION]] $e';
    }
  }

  /// Generate a quiz based on the context and topic
  /// Format: 'multiple_choice' or 'full_text'
  /// Delivery: 'block' (all at once) or 'one_by_one' (individual questions)
  Future<String?> generateQuiz({
    required String context,
    required String topic,
    required String format,
    required String delivery,
    int numberOfQuestions = 5,
    bool includeAnswers = false,
    bool answersAtOnce = false,
  }) async {
    final prompt =
        '''
$context

Generate $numberOfQuestions quiz questions about: $topic

Format: $format questions
${format == 'multiple_choice' ? 'For each question, provide 4 options (A, B, C, D) and indicate the correct answer.' : 'For each question, provide a detailed answer.'}

Output style: $delivery
${delivery == 'block' ? 'Present all questions together at once.' : 'Present one question at a time, clearly numbered.'}

Make the questions clear, educational, and at an appropriate level for learning.
''';

    // Add instructions about including answers if requested
    final buffer = StringBuffer(prompt);
    if (includeAnswers) {
      if (format == 'multiple_choice') {
        buffer.writeln(
          '\nInclude the correct option (A/B/C/D) for each question.',
        );
      } else {
        buffer.writeln('\nInclude a concise answer for each question.');
      }

      if (answersAtOnce) {
        buffer.writeln(
          '\nAt the end of the quiz, include an "Answers:" block that lists all answers together.',
        );
      } else {
        buffer.writeln(
          '\nAfter each question, include its answer immediately.',
        );
      }
    }

    return generateContentWithContext(buffer.toString(), '');
  }

  /// Generate content from text and image using Gemini Vision API
  /// This method converts images to base64 and sends them to Gemini for analysis
  ///
  /// IMPORTANT: All safety filters are disabled (BLOCK_NONE) to prevent
  /// educational content from being blocked. Temperature is set to 0.4 for
  /// precise, educational responses. Max tokens set to 4096 for detailed answers.
  Future<String?> generateContentWithImage({
    required String prompt,
    required String base64Image,
    String? mimeType,
  }) async {
    try {
      // Step 1: Clean and validate API key
      final cleanedKey = _cleanApiKey(geminiApiKey);
      if (cleanedKey.isEmpty || cleanedKey.contains('YOUR_')) {
        print('ERROR: Invalid Gemini API key');
        return '⚠️ Gemini API key not configured. Please check your settings.';
      }

      // Step 2: Determine mime type (simple check)
      final actualMimeType = mimeType ?? 'image/jpeg';

      // Step 3: Construct endpoint URL with cleaned API key
      // Using Gemini 2.0 Flash only
      final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent?key=$cleanedKey',
      );

      print('================================================');
      print('Analyzing image with Gemini 2.0 Flash...');
      print(
        'API Key (cleaned, last 10 chars): ...${cleanedKey.substring(cleanedKey.length - 10)}',
      );
      print('Image mime type: $actualMimeType');
      print('Image base64 length: ${base64Image.length} characters');
      print('Endpoint: ${uri.toString().replaceAll(cleanedKey, "***")}');
      print('================================================');

      // Step 4: Construct the payload with safety settings disabled
      final body = jsonEncode({
        'contents': [
          {
            'parts': [
              // The text prompt (e.g., "What is in this image?")
              {'text': prompt},
              // The image data in base64
              {
                'inline_data': {
                  'mime_type': actualMimeType,
                  'data': base64Image,
                },
              },
            ],
          },
        ],
        // Disable all safety filters to prevent blocking
        'safetySettings': [
          {'category': 'HARM_CATEGORY_HARASSMENT', 'threshold': 'BLOCK_NONE'},
          {'category': 'HARM_CATEGORY_HATE_SPEECH', 'threshold': 'BLOCK_NONE'},
          {
            'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT',
            'threshold': 'BLOCK_NONE',
          },
          {
            'category': 'HARM_CATEGORY_DANGEROUS_CONTENT',
            'threshold': 'BLOCK_NONE',
          },
        ],
        // Optimized generation config for educational content
        'generationConfig': {
          'temperature': 0.4, // Lower = more precise for educational content
          'maxOutputTokens': 4096, // Allow longer, detailed answers
        },
      });

      // Step 5: Call Gemini 2.0 Flash API
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      print('Gemini 2.0 Flash API Status: ${response.statusCode}');

      // Step 6: Handle Response
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        print('✓ Gemini Vision API Success!');

        // Check for safety feedback
        if (json['promptFeedback'] != null) {
          print('Safety Feedback: ${json['promptFeedback']}');
        }

        final candidates = json['candidates'] as List<dynamic>?;
        if (candidates != null && candidates.isNotEmpty) {
          final candidate = candidates[0];

          // Check finish reason to understand why generation stopped
          final finishReason = candidate['finishReason'];
          print('Finish Reason: $finishReason');

          // If blocked by safety, inform user
          if (finishReason == 'SAFETY') {
            print('⚠️ Content blocked by safety filters');
            return '⚠️ The AI saw the image but content was blocked by safety filters. This should not happen with BLOCK_NONE settings.';
          }

          final content = candidate['content'] as Map<String, dynamic>?;
          if (content != null) {
            final parts = content['parts'] as List<dynamic>?;
            if (parts != null && parts.isNotEmpty) {
              final text = parts[0]['text'] as String?;
              if (text != null && text.isNotEmpty) {
                print('✓ Successfully extracted text from Gemini 2.0 Flash');
                return text.trim();
              }
            }
          }

          // If we got here, check why no content
          return '⚠️ The AI saw the image but refused to answer (FinishReason: $finishReason)';
        }
        print('Warning: No candidates found in Gemini Vision response');
        return '⚠️ No response text from Gemini Vision API';
      } else if (response.statusCode == 404) {
        print('ERROR 404: Gemini 2.0 Flash endpoint not found');
        print('Response: ${response.body}');
        return '⚠️ Gemini 2.0 Flash not found (404). Your API key may not have access to this model.';
      } else if (response.statusCode == 403) {
        print('ERROR 403: API key invalid or permissions denied');
        print('Response body: ${response.body}');
        return '⚠️ Invalid Gemini API key or permissions denied. Check your API key.';
      } else if (response.statusCode == 429) {
        print('ERROR 429: Quota exceeded');
        return '⚠️ Gemini API quota exceeded. Please try again later.';
      } else if (response.statusCode == 400) {
        print('ERROR 400: Bad Request');
        print('Response body: ${response.body}');
        return '⚠️ Invalid image format or request. Try a smaller image or different format.';
      } else {
        final body = response.body;
        final status = response.statusCode;
        print('ERROR $status from Gemini Vision API');
        print('Full response: $body');
        return '⚠️ Gemini API error ($status). Check console for details.';
      }
    } catch (e, stackTrace) {
      print('EXCEPTION in Gemini Vision: $e');
      print('Stack trace: $stackTrace');
      return '⚠️ Error processing image: $e';
    }
  }
}
