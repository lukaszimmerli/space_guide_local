import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'settings_service.dart';

/// Cache entry with timestamp for TTL support
class _CacheEntry<T> {
  final T data;
  final DateTime timestamp;

  _CacheEntry(this.data, this.timestamp);

  bool isExpired(Duration timeout) {
    return DateTime.now().difference(timestamp) > timeout;
  }
}

/// Specific error types for translation operations
class TranslationError implements Exception {
  final TranslationErrorType type;
  final String message;
  final String? details;

  TranslationError(this.type, this.message, [this.details]);

  @override
  String toString() => message;
}

enum TranslationErrorType {
  authentication,
  rateLimit,
  network,
  quota,
  invalidInput,
  serviceUnavailable,
  timeout,
  unknown,
}

class FlowTranslationService {
  static const String _openaiApiUrl = 'https://api.openai.com/v1/chat/completions';

  // Cache for translations with TTL
  static final Map<String, _CacheEntry<Map<String, dynamic>>> _translationCache = {};
  static const Duration _cacheTimeout = Duration(hours: 2);

  // Cache for preview data
  static final Map<String, _CacheEntry<Map<String, dynamic>>> _previewCache = {};
  static const Duration _previewCacheTimeout = Duration(minutes: 15);

  /// Translate a flow using OpenAI API
  static Future<Map<String, dynamic>> translateFlow(
    Map<String, dynamic> flowData, {
    required String targetLanguageCode,
    required String sourceLanguageCode,
  }) async {
    // Check if AI features are enabled
    final settingsService = SettingsService();
    if (!settingsService.isAiFeaturesEnabled) {
      throw TranslationError(
        TranslationErrorType.authentication,
        'AI features not enabled. Please set OpenAI API key in Settings.',
      );
    }

    final apiKey = settingsService.openaiApiKey;
    if (apiKey == null || apiKey.isEmpty) {
      throw TranslationError(
        TranslationErrorType.authentication,
        'OpenAI API key not configured. Please set it in Settings.',
      );
    }

    // Generate cache key based on content and target language
    final cacheKey = _generateCacheKey(
      flowData,
      sourceLanguageCode,
      targetLanguageCode,
    );

    // Check cache first
    final cachedEntry = _translationCache[cacheKey];
    if (cachedEntry != null && !cachedEntry.isExpired(_cacheTimeout)) {
      return cachedEntry.data;
    }

    final stopwatch = Stopwatch()..start();

    try {
      // Extract translatable strings from flow data
      final translatableStrings = _extractTranslatableStrings(flowData);

      if (translatableStrings.isEmpty) {
        throw TranslationError(
          TranslationErrorType.invalidInput,
          'No translatable content found in flow data',
        );
      }

      // Create the translation prompt
      final translationPrompt = _createTranslationPrompt(
        translatableStrings,
        sourceLanguageCode,
        targetLanguageCode,
      );

      // Call OpenAI API for translation
      final response = await http.post(
        Uri.parse(_openaiApiUrl),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'gpt-4o-mini',
          'messages': [
            {
              'role': 'system',
              'content':
                  'You are a professional translator. Translate the provided text while maintaining context, tone, and technical accuracy. Preserve any special formatting, placeholders, or technical terms that should not be translated.',
            },
            {
              'role': 'user',
              'content': translationPrompt,
            }
          ],
          'max_completion_tokens': 2000,
          'temperature': 0.1, // Low temperature for consistent translations
          'top_p': 1,
        }),
      );

      stopwatch.stop();

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final translatedContent = data['choices']?[0]?['message']?['content']?.trim();

        if (translatedContent == null || translatedContent.isEmpty) {
          throw TranslationError(
            TranslationErrorType.unknown,
            'No translation generated',
          );
        }

        // Parse the translated content and apply to flow data
        final translatedFlow = _applyTranslationsToFlow(
          flowData,
          translatableStrings,
          translatedContent,
          targetLanguageCode,
        );

        // Cache the result
        _translationCache[cacheKey] = _CacheEntry(
          translatedFlow,
          DateTime.now(),
        );

        // Clean up old cache entries periodically
        _cleanupExpiredEntries();

        return translatedFlow;
      } else {
        final errorData = response.statusCode >= 400
            ? Map<String, dynamic>.from(jsonDecode(response.body) as Map)
            : <String, dynamic>{};

        throw _categorizeError(response.statusCode, errorData);
      }
    } on http.ClientException catch (e) {
      stopwatch.stop();
      throw TranslationError(
        TranslationErrorType.network,
        'Network error. Please check your connection and try again.',
        e.toString(),
      );
    } catch (e) {
      stopwatch.stop();

      if (e is TranslationError) {
        rethrow;
      } else {
        throw TranslationError(
          TranslationErrorType.unknown,
          'Translation failed: ${e.toString()}',
          e.toString(),
        );
      }
    }
  }

  /// Extract translatable strings from flow JSON
  static List<Map<String, String>> _extractTranslatableStrings(
    Map<String, dynamic> flowData,
  ) {
    final strings = <Map<String, String>>[];

    void traverse(dynamic obj, String path) {
      if (obj is String && obj.trim().isNotEmpty) {
        // Skip technical fields that shouldn't be translated
        final skipFields = [
          'id',
          'type',
          'asset_type',
          'file_path',
          'url',
          'mime_type',
          'created_at',
          'updated_at'
        ];
        final currentKey = path.split('.').last;

        if (!skipFields.contains(currentKey) &&
            !obj.startsWith('http') &&
            !obj.contains('://')) {
          strings.add({
            'key': 'string_${strings.length}',
            'value': obj,
            'path': path,
          });
        }
      } else if (obj is Map) {
        obj.forEach((key, value) {
          final newPath = path.isEmpty ? key : '$path.$key';
          traverse(value, newPath);
        });
      } else if (obj is List) {
        for (var i = 0; i < obj.length; i++) {
          traverse(obj[i], '$path[$i]');
        }
      }
    }

    traverse(flowData, '');
    return strings;
  }

  /// Create translation prompt
  static String _createTranslationPrompt(
    List<Map<String, String>> strings,
    String sourceLanguage,
    String targetLanguage,
  ) {
    final stringsList = strings.map((s) => '${s['key']}: "${s['value']}"').join('\n');

    return '''Translate the following text strings from $sourceLanguage to $targetLanguage.
Maintain the same format with the key followed by the translated text in quotes.
Preserve any technical terms, proper nouns, and formatting.
Context: These are strings from a workflow/process management application.

$stringsList

Translated versions:''';
  }

  /// Apply translations back to the flow data
  static Map<String, dynamic> _applyTranslationsToFlow(
    Map<String, dynamic> flowData,
    List<Map<String, String>> originalStrings,
    String translatedContent,
    String targetLanguageCode,
  ) {
    // Parse translated content back into key-value pairs
    final translations = <String, String>{};
    final lines = translatedContent.split('\n');

    for (final line in lines) {
      final match = RegExp(r'^(string_\d+):\s*"(.+)"$').firstMatch(line);
      if (match != null) {
        translations[match.group(1)!] = match.group(2)!;
      }
    }

    // Deep clone the flow data
    final translatedFlow = jsonDecode(jsonEncode(flowData)) as Map<String, dynamic>;

    // Apply translations
    for (final stringInfo in originalStrings) {
      final translation = translations[stringInfo['key']];
      if (translation != null) {
        _setValueAtPath(translatedFlow, stringInfo['path']!, translation);
      }
    }

    // Update the language field to the target language code
    if (translatedFlow.containsKey('language')) {
      translatedFlow['language'] = targetLanguageCode;
    }

    return translatedFlow;
  }

  /// Set value at a specific path in an object
  static void _setValueAtPath(Map<String, dynamic> obj, String path, String value) {
    final parts = path.split(RegExp(r'[.\[\]]')).where((part) => part.isNotEmpty).toList();
    dynamic current = obj;

    for (var i = 0; i < parts.length - 1; i++) {
      final part = parts[i];
      final isArrayIndex = RegExp(r'^\d+$').hasMatch(part);

      if (isArrayIndex) {
        final index = int.parse(part);
        if (current is List) {
          if (index >= current.length) {
            current.add(<String, dynamic>{});
          }
          current = current[index];
        }
      } else {
        if (current is Map) {
          if (!current.containsKey(part)) {
            current[part] = <String, dynamic>{};
          }
          current = current[part];
        }
      }
    }

    final lastPart = parts.last;
    if (RegExp(r'^\d+$').hasMatch(lastPart)) {
      if (current is List) {
        current[int.parse(lastPart)] = value;
      }
    } else {
      if (current is Map) {
        current[lastPart] = value;
      }
    }
  }

  /// Generate a unique cache key for the translation request
  static String _generateCacheKey(
    Map<String, dynamic> flowData,
    String sourceLanguage,
    String targetLanguage,
  ) {
    // Create a content hash based on translatable content
    final contentForHashing = {
      'title': flowData['title'],
      'description': flowData['description'],
      'flowSteps': (flowData['flowSteps'] as List?)
          ?.map((step) => step['description'])
          .where((desc) => desc != null && desc.toString().isNotEmpty)
          .toList(),
      'sourceLanguage': sourceLanguage,
      'targetLanguage': targetLanguage,
    };

    final contentJson = jsonEncode(contentForHashing);
    final bytes = utf8.encode(contentJson);
    final digest = sha256.convert(bytes);

    return 'translation_${digest.toString().substring(0, 16)}';
  }

  /// Clean up expired cache entries
  static void _cleanupExpiredEntries() {
    // Clean translation cache
    _translationCache.removeWhere(
      (key, entry) => entry.isExpired(_cacheTimeout),
    );

    // Clean preview cache
    _previewCache.removeWhere(
      (key, entry) => entry.isExpired(_previewCacheTimeout),
    );
  }

  /// Clear all cached translations (useful for testing or manual refresh)
  static void clearCache() {
    _translationCache.clear();
    _previewCache.clear();
  }

  /// Categorize errors into specific types for better error handling
  static TranslationError _categorizeError(
    int statusCode,
    Map<String, dynamic> errorData,
  ) {
    final errorMessage = errorData['error']?['message']?.toString() ??
        errorData['error']?.toString() ??
        'Translation failed';

    switch (statusCode) {
      case 401:
        return TranslationError(
          TranslationErrorType.authentication,
          'Invalid API key. Please check your OpenAI API key in Settings.',
          errorMessage,
        );
      case 429:
        return TranslationError(
          TranslationErrorType.rateLimit,
          'Rate limit exceeded. Please try again later.',
          errorMessage,
        );
      case 400:
        return TranslationError(
          TranslationErrorType.invalidInput,
          'Invalid input provided for translation.',
          errorMessage,
        );
      case 503:
        return TranslationError(
          TranslationErrorType.serviceUnavailable,
          'Translation service is temporarily unavailable. Please try again later.',
          errorMessage,
        );
      case 408:
        return TranslationError(
          TranslationErrorType.timeout,
          'Translation request timed out. Please try again.',
          errorMessage,
        );
      default:
        return TranslationError(
          TranslationErrorType.unknown,
          errorMessage,
          'HTTP $statusCode',
        );
    }
  }

  /// Estimate translation complexity based on content size
  static String estimateComplexity(Map<String, dynamic> flowData) {
    int contentSize = 0;

    if (flowData['title'] != null) {
      contentSize += (flowData['title'] as String).length;
    }
    if (flowData['description'] != null) {
      contentSize += (flowData['description'] as String).length;
    }
    if (flowData['flowSteps'] != null) {
      final steps = flowData['flowSteps'] as List;
      for (final step in steps) {
        if (step['description'] != null) {
          contentSize += (step['description'] as String).length;
        }
      }
    }

    if (contentSize < 500) {
      return 'Simple';
    } else if (contentSize < 2000) {
      return 'Medium';
    } else {
      return 'Complex';
    }
  }

  /// Get preview of content that will be translated
  static Map<String, dynamic> getTranslationPreview(
    Map<String, dynamic> flowData,
  ) {
    // Generate cache key for preview
    final previewKey = _generatePreviewCacheKey(flowData);

    // Check preview cache first
    final cachedPreview = _previewCache[previewKey];
    if (cachedPreview != null && !cachedPreview.isExpired(_previewCacheTimeout)) {
      return cachedPreview.data;
    }

    final preview = <String, dynamic>{};

    if (flowData['title'] != null && (flowData['title'] as String).isNotEmpty) {
      preview['title'] = flowData['title'];
    }

    if (flowData['description'] != null &&
        (flowData['description'] as String).isNotEmpty) {
      preview['description'] = flowData['description'];
    }

    if (flowData['flowSteps'] != null) {
      final steps = flowData['flowSteps'] as List;
      final stepPreviews = <String>[];

      for (int i = 0; i < steps.length && i < 3; i++) {
        final step = steps[i];
        if (step['description'] != null &&
            (step['description'] as String).isNotEmpty) {
          stepPreviews.add(step['description'] as String);
        }
      }

      if (stepPreviews.isNotEmpty) {
        preview['steps'] = stepPreviews;
        if (steps.length > 3) {
          preview['moreSteps'] = steps.length - 3;
        }
      }
    }

    // Cache the preview
    _previewCache[previewKey] = _CacheEntry(preview, DateTime.now());

    return preview;
  }

  /// Generate cache key for preview data
  static String _generatePreviewCacheKey(Map<String, dynamic> flowData) {
    final contentForHashing = {
      'title': flowData['title'],
      'description': flowData['description'],
      'flowSteps': (flowData['flowSteps'] as List?)
          ?.take(3)
          .map((step) => step['description'])
          .where((desc) => desc != null && desc.toString().isNotEmpty)
          .toList(),
    };

    final contentJson = jsonEncode(contentForHashing);
    final bytes = utf8.encode(contentJson);
    final digest = sha256.convert(bytes);

    return 'preview_${digest.toString().substring(0, 16)}';
  }
}
