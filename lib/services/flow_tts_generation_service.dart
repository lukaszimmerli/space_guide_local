import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flow_manager_saas/flow_manager.dart';
import 'settings_service.dart';

/// Cache entry for TTS results
class _TtsCacheEntry {
  final FlowTtsGenerationResult data;
  final DateTime timestamp;

  _TtsCacheEntry(this.data, this.timestamp);

  bool isExpired(Duration timeout) {
    return DateTime.now().difference(timestamp) > timeout;
  }
}

/// Specific error types for TTS operations
class TtsError implements Exception {
  final TtsErrorType type;
  final String message;
  final String? details;

  TtsError(this.type, this.message, [this.details]);

  @override
  String toString() => message;
}

enum TtsErrorType {
  authentication,
  rateLimit,
  network,
  quota,
  invalidInput,
  serviceUnavailable,
  timeout,
  fileSystem,
  unknown,
}

/// Service for generating TTS audio files for flow steps using OpenAI TTS API
class FlowTtsGenerationService {
  static const String _openaiTtsUrl = 'https://api.openai.com/v1/audio/speech';

  // Cache for TTS results - shorter TTL since audio files can be large
  static final Map<String, _TtsCacheEntry> _ttsCache = {};
  static const Duration _ttsCacheTimeout = Duration(hours: 1);

  /// Check if AI features are enabled
  static bool isAiFeaturesEnabled() {
    final settingsService = SettingsService();
    return settingsService.isAiFeaturesEnabled;
  }

  /// Notifies all FlowNotifier instances that a specific flow has been updated
  /// This helps ensure that any currently loaded flows are refreshed
  static void notifyFlowUpdated(String flowId) {
    // This is a simple notification mechanism
    // In a more complex app, you might use a proper event bus or state management
    debugPrint('Flow updated notification: $flowId');
  }

  /// Generate TTS audio for all steps in a flow that don't have audio assets
  /// Set [forceRegenerate] to true to regenerate audio even if steps already have audio
  static Future<FlowTtsGenerationResult> generateTtsForFlow({
    required String flowId,
    required FlowData flowData,
    String voice = 'nova',
    String? instructions,
    bool forceRegenerate = false,
  }) async {
    if (!isAiFeaturesEnabled()) {
      throw TtsError(
        TtsErrorType.authentication,
        'AI features not enabled. Please set OpenAI API key in Settings.',
      );
    }

    // Get API key from settings
    final settingsService = SettingsService();
    final apiKey = settingsService.openaiApiKey;

    if (apiKey == null || apiKey.isEmpty) {
      throw TtsError(
        TtsErrorType.authentication,
        'OpenAI API key not configured. Please set it in Settings.',
      );
    }

    // Generate cache key based on flow content and TTS settings
    final cacheKey = _generateTtsCacheKey(flowData, voice);

    // Check if we have a recent cached result for the same content
    final cachedEntry = _ttsCache[cacheKey];
    if (cachedEntry != null && !cachedEntry.isExpired(_ttsCacheTimeout)) {
      // Verify that the cached audio files still exist locally
      if (await _verifyLocalAudioFiles(flowId, cachedEntry.data.audioFiles)) {
        debugPrint('TTS generation cache hit for flow $flowId');
        return cachedEntry.data;
      } else {
        // Remove invalid cache entry
        _ttsCache.remove(cacheKey);
      }
    }

    final stopwatch = Stopwatch()..start();

    try {
      // Find steps without audio assets (or all steps if forceRegenerate is true)
      final stepsNeedingAudio =
          flowData.flowSteps.where((step) {
            if (step.description.isEmpty) return false;
            if (forceRegenerate) return true; // Regenerate all steps with text
            return !step.hasAudioAsset || step.audioAsset == null;
          }).toList();

      if (stepsNeedingAudio.isEmpty) {
        return FlowTtsGenerationResult(
          message: 'All steps already have audio or no text content',
          processedSteps: 0,
          totalStepsNeedingAudio: 0,
          audioFiles: [],
        );
      }

      // If force regenerating, delete existing TTS audio first
      if (forceRegenerate) {
        final storageService = FlowStorageService();
        for (final step in stepsNeedingAudio) {
          if (step.hasAudioAsset) {
            final audioAsset = step.audioAsset!;
            final isTtsAudio =
                audioAsset.path.contains('step_tts_') ||
                (audioAsset.displayName?.contains('step_tts_') ?? false);

            if (isTtsAudio) {
              try {
                await storageService.deleteAsset(flowId, audioAsset.path);
                step.removeAudioAsset();
                if (kDebugMode) {
                  print(
                    'Deleted existing TTS audio for regeneration: ${audioAsset.path}',
                  );
                }
              } catch (e) {
                if (kDebugMode) {
                  print('Warning: Failed to delete existing TTS audio: $e');
                }
              }
            }
          }
        }
      }

      debugPrint(
        'Processing ${stepsNeedingAudio.length} steps for TTS generation',
      );

      // Process TTS generation with controlled concurrency
      const maxConcurrentRequests = 3;
      final processedSteps = <TtsAudioFile>[];
      final errors = <Map<String, dynamic>>[];

      // Process steps in batches
      for (
        var i = 0;
        i < stepsNeedingAudio.length;
        i += maxConcurrentRequests
      ) {
        final batch =
            stepsNeedingAudio.skip(i).take(maxConcurrentRequests).toList();
        final batchPromises = batch.map(
          (step) => _processTtsStep(step, voice, apiKey),
        );

        try {
          final batchResults = await Future.wait(batchPromises);

          // Add successful results to processedSteps
          for (final result in batchResults) {
            if (result != null) {
              processedSteps.add(result);
            }
          }

          debugPrint(
            'Completed batch ${(i / maxConcurrentRequests).floor() + 1} of ${(stepsNeedingAudio.length / maxConcurrentRequests).ceil()}',
          );
        } catch (error) {
          debugPrint('Batch processing error: $error');
          errors.add({'batch': i, 'error': error.toString()});
        }
      }

      stopwatch.stop();

      // Download and save audio files locally if any were generated
      if (processedSteps.isNotEmpty) {
        await _downloadAndSaveAudioFiles(flowId, processedSteps);

        // Update the flow steps with audio assets
        await _updateFlowStepsWithAudioAssets(flowData, processedSteps);

        // Notify that this flow has been updated
        notifyFlowUpdated(flowId);

        // Create result
        final result = FlowTtsGenerationResult(
          message:
              'Successfully generated TTS audio for ${processedSteps.length} steps',
          processedSteps: processedSteps.length,
          totalStepsNeedingAudio: stepsNeedingAudio.length,
          audioFiles: processedSteps,
        );

        // Cache the result
        _ttsCache[cacheKey] = _TtsCacheEntry(result, DateTime.now());

        // Clean up expired entries
        _cleanupExpiredTtsEntries();

        return result;
      } else {
        throw TtsError(
          TtsErrorType.unknown,
          'Failed to generate TTS audio for any steps',
        );
      }
    } catch (e) {
      stopwatch.stop();

      if (e is TtsError) {
        rethrow;
      } else {
        throw _categorizeError(e);
      }
    }
  }

  /// Process a single TTS step
  static Future<TtsAudioFile?> _processTtsStep(
    FlowStep step,
    String voice,
    String apiKey,
  ) async {
    try {
      debugPrint('Processing step ${step.id}: "${step.description}"');

      // Call OpenAI TTS API
      final response = await http.post(
        Uri.parse(_openaiTtsUrl),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'tts-1',
          'voice': voice,
          'input': step.description,
          'response_format': 'mp3',
        }),
      );

      if (response.statusCode != 200) {
        debugPrint('TTS API error for step ${step.id}: ${response.body}');
        return null;
      }

      // Get the audio data
      final audioData = response.bodyBytes;

      // Generate filename with timestamp to avoid collisions
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'step_tts_${step.id.substring(0, 8)}_$timestamp.mp3';
      final filePath = 'assets/$fileName';

      // Convert to base64 for storage
      final base64Audio = base64Encode(audioData);

      debugPrint('Generated TTS audio for step ${step.id}: $fileName');

      return TtsAudioFile(
        stepId: step.id,
        fileName: fileName,
        filePath: filePath,
        audioData: base64Audio,
      );
    } catch (error) {
      debugPrint('Error processing step ${step.id}: $error');
      return null;
    }
  }

  /// Generate a cache key for TTS generation based on content
  static String _generateTtsCacheKey(FlowData flowData, String voice) {
    // Create a hash based on the steps that need TTS
    final stepsNeedingAudio =
        flowData.flowSteps
            .where((step) => step.description.isNotEmpty && !step.hasAudioAsset)
            .map((step) => step.description)
            .toList();

    final contentForHashing = {'steps': stepsNeedingAudio, 'voice': voice};

    final contentJson = jsonEncode(contentForHashing);
    final bytes = utf8.encode(contentJson);
    final digest = sha256.convert(bytes);

    return 'tts_${digest.toString().substring(0, 16)}';
  }

  /// Verify that cached audio files still exist locally
  static Future<bool> _verifyLocalAudioFiles(
    String flowId,
    List<TtsAudioFile> audioFiles,
  ) async {
    try {
      final storageService = FlowStorageService();

      for (final audioFile in audioFiles) {
        final audioFilePath = await storageService.getAbsoluteFilePath(
          flowId,
          'assets/${audioFile.fileName}',
        );

        final file = File(audioFilePath);
        if (!await file.exists()) {
          return false;
        }
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Clean up expired TTS cache entries
  static void _cleanupExpiredTtsEntries() {
    _ttsCache.removeWhere((key, entry) => entry.isExpired(_ttsCacheTimeout));
  }

  /// Clear TTS cache
  static void clearTtsCache() {
    _ttsCache.clear();
  }

  /// Categorize errors into specific types for better error handling
  static TtsError _categorizeError(dynamic error) {
    final errorString = error.toString().toLowerCase();

    if (errorString.contains('401') || errorString.contains('unauthorized')) {
      return TtsError(
        TtsErrorType.authentication,
        'Invalid API key. Please check your OpenAI API key in Settings.',
        error.toString(),
      );
    } else if (errorString.contains('429') ||
        errorString.contains('rate limit')) {
      return TtsError(
        TtsErrorType.rateLimit,
        'Rate limit exceeded. Please try again later.',
        error.toString(),
      );
    } else if (errorString.contains('network') ||
        errorString.contains('connection')) {
      return TtsError(
        TtsErrorType.network,
        'Network error. Please check your connection and try again.',
        error.toString(),
      );
    } else if (errorString.contains('quota') ||
        errorString.contains('insufficient')) {
      return TtsError(
        TtsErrorType.quota,
        'TTS quota exceeded. Please check your OpenAI account.',
        error.toString(),
      );
    } else if (errorString.contains('timeout')) {
      return TtsError(
        TtsErrorType.timeout,
        'TTS request timed out. Please try again.',
        error.toString(),
      );
    } else if (errorString.contains('503') ||
        errorString.contains('service unavailable')) {
      return TtsError(
        TtsErrorType.serviceUnavailable,
        'TTS service is temporarily unavailable. Please try again later.',
        error.toString(),
      );
    } else if (errorString.contains('file') ||
        errorString.contains('directory')) {
      return TtsError(
        TtsErrorType.fileSystem,
        'Error saving audio files. Please check disk space and permissions.',
        error.toString(),
      );
    } else if (errorString.contains('invalid') || errorString.contains('400')) {
      return TtsError(
        TtsErrorType.invalidInput,
        'Invalid input provided for TTS generation.',
        error.toString(),
      );
    } else {
      return TtsError(
        TtsErrorType.unknown,
        'TTS generation failed: ${error.toString()}',
        error.toString(),
      );
    }
  }

  /// Download and save audio files to the local flow directory
  static Future<void> _downloadAndSaveAudioFiles(
    String flowId,
    List<TtsAudioFile> audioFiles,
  ) async {
    try {
      // Use FlowStorageService to get the assets directory
      final storageService = FlowStorageService();

      for (final audioFile in audioFiles) {
        // Decode base64 audio data
        final audioBytes = base64Decode(audioFile.audioData);

        // Get the absolute path to save the audio file
        final audioFilePath = await storageService.getAbsoluteFilePath(
          flowId,
          'assets/${audioFile.fileName}',
        );

        // Create the file and ensure the directory exists
        final file = File(audioFilePath);
        await file.parent.create(recursive: true);
        await file.writeAsBytes(audioBytes);

        debugPrint('Saved TTS audio file: ${file.path}');
      }
    } catch (e) {
      debugPrint('Error saving audio files: $e');
      throw TtsError(TtsErrorType.fileSystem, 'Failed to save audio files: $e');
    }
  }

  /// Update flow steps with their corresponding audio assets
  static Future<void> _updateFlowStepsWithAudioAssets(
    FlowData flowData,
    List<TtsAudioFile> audioFiles,
  ) async {
    try {
      debugPrint(
        'Starting to update ${flowData.flowSteps.length} flow steps with ${audioFiles.length} audio files',
      );

      // Create a map of stepId to audioFile for quick lookup
      final audioFileMap = <String, TtsAudioFile>{};
      for (final audioFile in audioFiles) {
        audioFileMap[audioFile.stepId] = audioFile;
        debugPrint(
          'Mapping audio file ${audioFile.fileName} to step ${audioFile.stepId}',
        );
      }

      int updatedSteps = 0;
      // Update each flow step that has a corresponding audio file
      for (final step in flowData.flowSteps) {
        final audioFile = audioFileMap[step.id];
        if (audioFile != null) {
          debugPrint(
            'Before update - Step ${step.id} hasAudioAsset: ${step.hasAudioAsset}',
          );

          // Create a FlowStepAsset for the audio file
          final audioAsset = FlowStepAsset(
            type: AssetType.audio,
            path: 'assets/${audioFile.fileName}',
            displayName: audioFile.fileName,
          );

          // Set the audio asset on the step
          step.setAudioAsset(audioAsset);
          updatedSteps++;

          debugPrint(
            'After update - Step ${step.id} hasAudioAsset: ${step.hasAudioAsset}, audioAsset.path: ${step.audioAsset?.path}',
          );
        } else {
          debugPrint('No audio file found for step ${step.id}');
        }
      }

      debugPrint(
        'Updated $updatedSteps steps with audio assets. Saving flow...',
      );

      // Save the updated flow data
      final storageService = FlowStorageService();
      await storageService.saveFlow(flowData);

      debugPrint(
        'Successfully saved flow with audio assets. Flow ID: ${flowData.id}',
      );

      // Verify that the flow was saved correctly by reloading it
      try {
        final reloadedFlow = await storageService.loadFlow(flowData.id);
        final stepsWithAudio =
            reloadedFlow.flowSteps.where((step) => step.hasAudioAsset).length;
        debugPrint(
          'Verification: Reloaded flow has $stepsWithAudio steps with audio assets',
        );
      } catch (e) {
        debugPrint('Warning: Could not verify saved flow: $e');
      }
    } catch (e) {
      debugPrint('Error updating flow steps with audio assets: $e');
      rethrow;
    }
  }
}

/// Result of TTS generation process
class FlowTtsGenerationResult {
  final String message;
  final int processedSteps;
  final int totalStepsNeedingAudio;
  final List<TtsAudioFile> audioFiles;

  FlowTtsGenerationResult({
    required this.message,
    required this.processedSteps,
    required this.totalStepsNeedingAudio,
    required this.audioFiles,
  });

  bool get hasAudioFiles => audioFiles.isNotEmpty;
  bool get allStepsProcessed => processedSteps == totalStepsNeedingAudio;
}

/// Represents a generated TTS audio file
class TtsAudioFile {
  final String stepId;
  final String fileName;
  final String filePath;
  final String audioData; // Base64 encoded audio

  TtsAudioFile({
    required this.stepId,
    required this.fileName,
    required this.filePath,
    required this.audioData,
  });

  factory TtsAudioFile.fromJson(Map<String, dynamic> json) {
    return TtsAudioFile(
      stepId: json['stepId'] as String,
      fileName: json['fileName'] as String,
      filePath: json['filePath'] as String,
      audioData: json['audioData'] as String,
    );
  }
}
