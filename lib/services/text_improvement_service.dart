import 'dart:convert';
import 'package:http/http.dart' as http;
import 'settings_service.dart';

/// Specific error types for text improvement operations
class TextImprovementError implements Exception {
  final TextImprovementErrorType type;
  final String message;
  final String? details;

  TextImprovementError(this.type, this.message, [this.details]);

  @override
  String toString() => message;
}

enum TextImprovementErrorType {
  authentication,
  rateLimit,
  network,
  quota,
  invalidInput,
  serviceUnavailable,
  timeout,
  unknown,
}

class TextImprovementService {
  static const String _openaiApiUrl = 'https://api.openai.com/v1/chat/completions';

  /// Improve text using OpenAI GPT-4o-mini model
  ///
  /// [text] - The text to improve
  /// [task] - The type of improvement ('improve', 'formal', 'casual', 'expand', 'simplify')
  ///
  /// Returns the improved text string
  /// Throws exception if improvement fails
  static Future<String> improveText(
    String text, {
    String task = 'improve',
  }) async {
    try {
      final response = await improveTextDetailed(text, task: task);
      return response['improved'] ?? text;
    } catch (e) {
      throw Exception('Failed to improve text: $e');
    }
  }

  /// Improve text with detailed response including metadata
  ///
  /// Returns a map with 'original', 'improved', 'task', and 'model' keys
  static Future<Map<String, dynamic>> improveTextDetailed(
    String text, {
    String task = 'improve',
  }) async {
    if (text.trim().isEmpty) {
      throw TextImprovementError(
        TextImprovementErrorType.invalidInput,
        'Text cannot be empty',
      );
    }

    // Get API key from settings
    final settingsService = SettingsService();
    final apiKey = settingsService.openaiApiKey;

    if (apiKey == null || apiKey.isEmpty) {
      throw TextImprovementError(
        TextImprovementErrorType.authentication,
        'OpenAI API key not configured. Please set it in Settings.',
      );
    }

    final stopwatch = Stopwatch()..start();

    try {
      // Define different prompts based on task
      final prompts = {
        'improve': '''Improve the following text by making it more grammatically correct, complete, and natural while keeping the same meaning. Only return the improved text, nothing else.

Examples:
- "open door" → "open the door"
- "remove switch add cable" → "remove the switch and add a new cable"
- "check if work" → "check if it works"
- "send email client" → "send an email to the client"

Text to improve: "$text"

Improved text:''',

        'formal': '''Rewrite the following text in a more formal and professional tone while keeping the same meaning. Only return the rewritten text, nothing else.

Text: "$text"

Formal version:''',

        'casual': '''Rewrite the following text in a more casual and friendly tone while keeping the same meaning. Only return the rewritten text, nothing else.

Text: "$text"

Casual version:''',

        'expand': '''Expand the following short text into a more detailed and complete sentence or paragraph while keeping the same core meaning. Only return the expanded text, nothing else.

Text: "$text"

Expanded version:''',

        'simplify': '''Simplify the following text to make it clearer and easier to understand while keeping the same meaning. Only return the simplified text, nothing else.

Text: "$text"

Simplified version:''',
      };

      final systemPrompt = prompts[task] ?? prompts['improve']!;

      final response = await http.post(
        Uri.parse(_openaiApiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-4o-mini',
          'messages': [
            {
              'role': 'user',
              'content': systemPrompt,
            }
          ],
          'max_completion_tokens': 100,
          'top_p': 1,
        }),
      );

      stopwatch.stop();

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        var improvedText = data['choices']?[0]?['message']?['content']?.trim();

        if (improvedText == null || improvedText.isEmpty) {
          throw TextImprovementError(
            TextImprovementErrorType.unknown,
            'No improved text generated',
          );
        }

        // Remove surrounding quotes if present (OpenAI sometimes adds them)
        if (improvedText.startsWith('"') && improvedText.endsWith('"')) {
          improvedText = improvedText.substring(1, improvedText.length - 1);
        } else if (improvedText.startsWith("'") && improvedText.endsWith("'")) {
          improvedText = improvedText.substring(1, improvedText.length - 1);
        }

        return {
          'original': text,
          'improved': improvedText,
          'task': task,
          'model': 'gpt-4o-mini',
        };
      } else {
        final errorData = response.statusCode >= 400
            ? Map<String, dynamic>.from(jsonDecode(response.body) as Map)
            : <String, dynamic>{};

        throw _createErrorFromStatusCode(response.statusCode, errorData);
      }
    } on http.ClientException catch (e) {
      stopwatch.stop();
      throw TextImprovementError(
        TextImprovementErrorType.network,
        'Network error. Please check your internet connection.',
        e.toString(),
      );
    } catch (e) {
      stopwatch.stop();

      if (e is TextImprovementError) {
        rethrow;
      } else {
        throw TextImprovementError(
          TextImprovementErrorType.unknown,
          'Unexpected error occurred: $e',
          e.toString(),
        );
      }
    }
  }

  /// Create specific error based on HTTP status code
  static TextImprovementError _createErrorFromStatusCode(
    int statusCode,
    Map<String, dynamic> errorData,
  ) {
    final errorMessage = errorData['error']?['message']?.toString() ??
        errorData['error']?.toString() ??
        'Failed to improve text';

    switch (statusCode) {
      case 401:
        return TextImprovementError(
          TextImprovementErrorType.authentication,
          'Invalid API key. Please check your OpenAI API key in Settings.',
          errorMessage,
        );
      case 429:
        return TextImprovementError(
          TextImprovementErrorType.rateLimit,
          'Rate limit exceeded. Please try again later.',
          errorMessage,
        );
      case 400:
        return TextImprovementError(
          TextImprovementErrorType.invalidInput,
          'Invalid input provided for text improvement.',
          errorMessage,
        );
      case 503:
        return TextImprovementError(
          TextImprovementErrorType.serviceUnavailable,
          'Text improvement service is temporarily unavailable.',
          errorMessage,
        );
      case 408:
        return TextImprovementError(
          TextImprovementErrorType.timeout,
          'Request timed out. Please try again.',
          errorMessage,
        );
      default:
        return TextImprovementError(
          TextImprovementErrorType.unknown,
          errorMessage,
          'HTTP $statusCode',
        );
    }
  }

  /// Check if the AI features are enabled
  static bool isAiFeaturesEnabled() {
    final settingsService = SettingsService();
    return settingsService.isAiFeaturesEnabled;
  }

  /// Get available improvement tasks
  static List<String> getAvailableTasks() {
    return ['improve', 'formal', 'casual', 'expand', 'simplify'];
  }

  /// Get task descriptions for UI display
  static Map<String, String> getTaskDescriptions() {
    return {
      'improve': 'Basic grammar and completeness improvement',
      'formal': 'Make text more formal and professional',
      'casual': 'Make text more casual and friendly',
      'expand': 'Expand short text into more detailed content',
      'simplify': 'Simplify complex text for better understanding',
    };
  }
}
