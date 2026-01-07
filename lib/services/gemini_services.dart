import '../utils/ai_constants.dart';
import 'api_service.dart';

class GeminiService {
  Future<String?> generateContent(
    String prompt, {
    String? responseMode,
    Map<String, dynamic>? instructions,
    List<Map<String, String>>? messages,
  }) async {
    // Route all LLM chat requests through the backend
    try {
      // Normalize client-side mode values to backend-expected values
      String? normalizedMode;
      if (responseMode != null) {
        final rm = responseMode.toLowerCase();
        if (rm == 'straight' || rm == 'quick') normalizedMode = 'quick';
        if (rm == 'detailed' || rm == 'long' || rm == 'verbose')
          normalizedMode = 'detailed';
      }

      // If a pre-built messages array is provided, send that (preferred).
      // Otherwise fall back to the legacy single-message contract.
      final input = {
        if (messages != null) 'messages': messages,
        if (messages == null) 'message': prompt,
        if (normalizedMode != null) 'mode': normalizedMode,
        if (instructions != null) 'instructions': instructions,
      };
      final resp = await ApiService.send('chat', input);
      return _cleanResponse(resp);
    } catch (e) {
      return '[[GEMINI SERVICE ERROR]] $e';
    }
  }

  /// Call Groq API with a custom system context (used for study plans)
  Future<String?> generateContentWithContext(
    String userMessage,
    String systemContext,
  ) async {
    final input = {'message': userMessage};
    try {
      final resp = await ApiService.send('chat', input);
      return _cleanResponse(resp);
    } catch (e) {
      return '[[GEMINI SERVICE ERROR]] $e';
    }
  }

  /// Clean up AI response by removing only unwanted formatting (math, prefixes)
  /// PRESERVE Markdown bold (**), italic (*), and other formatting for UI rendering
  String _cleanResponse(String text) {
    // Remove "Final Answer:" prefix
    text = text.replaceFirst(RegExp(r'Final Answer:\s*'), '');

    // Remove \boxed{...} wrapper, keep just the content
    text = text.replaceAll(RegExp(r'\\boxed\{([^}]*)\}'), r'$1');

    // Remove extra "The final answer is" phrases
    text = text.replaceAll(RegExp(r'The final answer is\s*'), '');

    // DO NOT remove markdown bold (**text**) - UI needs it for rendering!
    // DO NOT remove markdown italic (*text*) - UI needs it for rendering!
    // These are now handled by ai_message_bubble.dart markdown parser

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

  // _callOpenRouter was removed as it's not used; routing goes via generateContent
  // Fallback methods removed; all calls are routed via generateContent()/generateContentWithContext

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
    final actualMimeType = mimeType ?? 'image/jpeg';
    final payload = {
      'prompt': prompt,
      'imageBase64': base64Image,
      'mimeType': actualMimeType,
      'system': AiConstants.systemPrompt,
    };

    try {
      final resp = await ApiService.send('image', payload);
      return _cleanResponse(resp);
    } catch (e) {
      return '⚠️ Gemini image analysis failed: $e';
    }
  }
}
