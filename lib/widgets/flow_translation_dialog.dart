import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flow_manager_saas/flow_manager.dart';
import '../services/flow_translation_service.dart';
import '../services/mixpanel_service.dart';

class FlowTranslationDialog extends StatefulWidget {
  final FlowData flow;

  const FlowTranslationDialog({
    super.key,
    required this.flow,
  });

  @override
  State<FlowTranslationDialog> createState() => _FlowTranslationDialogState();
}

class _FlowTranslationDialogState extends State<FlowTranslationDialog> {
  String? _targetLanguage;
  bool _isTranslating = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.translate),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Translate "${widget.flow.title.isNotEmpty ? widget.flow.title : 'Untitled Flow'}"',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Source language (read-only)
            Text(
              'Source Language',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  if (LanguageSelector.getLanguageFlag(
                        widget.flow.language,
                      ) !=
                      null) ...[
                    Text(
                      LanguageSelector.getLanguageFlag(
                        widget.flow.language,
                      )!,
                      style: const TextStyle(fontSize: 18),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    LanguageSelector.getLanguageName(
                      widget.flow.language,
                    ),
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Target language selector
            Text(
              'Target Language',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            LanguageSelector(
              selectedLanguage: _targetLanguage ?? 'en',
              onLanguageChanged: (language) {
                setState(() {
                  _targetLanguage = language;
                });
              },
              enabled: !_isTranslating,
            ),
          ],
        ),
      ),
      actions: [
        Row(
          children: [
            TextButton(
              onPressed:
                  _isTranslating ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed:
                  _targetLanguage != null &&
                          _targetLanguage != widget.flow.language &&
                          !_isTranslating
                      ? _translateFlow
                      : null,
              child:
                  _isTranslating
                      ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : Text('Translate'),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _translateFlow() async {
    if (_targetLanguage == null) return;

    setState(() {
      _isTranslating = true;
    });

    try {
      // Convert flow to JSON format for translation
      final flowData = {
        'id': widget.flow.id,
        'title': widget.flow.title,
        'subtitle': widget.flow.subtitle,
        'description': widget.flow.description,
        'language': widget.flow.language,
        'flowSections':
            widget.flow.flowSections
                .map((section) => section.toJson())
                .toList(),
        'flowSteps':
            widget.flow.flowSteps.map((step) => step.toJson()).toList(),
      };

      // Translate the flow
      final translatedFlowData = await FlowTranslationService.translateFlow(
        flowData,
        sourceLanguageCode: widget.flow.language,
        targetLanguageCode: _targetLanguage!,
      );

      // Create new flow with translated content
      if (!mounted) return;
      final flowNotifier = Provider.of<FlowNotifier>(context, listen: false);

      // Create a translated duplicate directly
      final translatedFlow = await _createTranslatedDuplicate(
        flowNotifier,
        widget.flow,
        translatedFlowData,
        _targetLanguage!,
      );

      setState(() {
        _isTranslating = false;
      });

      if (translatedFlow != null) {
        // Track successful translation
        MixpanelService.trackTranslationUsed(
          guideId: widget.flow.id,
          fromLanguage: widget.flow.language,
          toLanguage: _targetLanguage!,
          numberOfSteps: widget.flow.flowSteps.length,
          success: true,
        );

        if (mounted) {
          Navigator.of(context).pop();
          FlowUtils.showSuccessSnackBar(
            context,
            'Flow translated to ${LanguageSelector.getLanguageName(_targetLanguage!)} and created successfully!',
          );
        }
      } else {
        // Track failed translation (null flow)
        MixpanelService.trackTranslationUsed(
          guideId: widget.flow.id,
          fromLanguage: widget.flow.language,
          toLanguage: _targetLanguage!,
          numberOfSteps: widget.flow.flowSteps.length,
          success: false,
        );
      }
    } catch (e) {
      // Track failed translation
      if (_targetLanguage != null) {
        MixpanelService.trackTranslationUsed(
          guideId: widget.flow.id,
          fromLanguage: widget.flow.language,
          toLanguage: _targetLanguage!,
          numberOfSteps: widget.flow.flowSteps.length,
          success: false,
        );
      }

      if (mounted) {
        setState(() {
          _isTranslating = false;
        });

        String errorMessage = 'Translation failed';
        if (e.toString().contains('API key not configured')) {
          errorMessage = 'Please set your OpenAI API key in Settings';
        } else if (e.toString().contains('Network error')) {
          errorMessage = 'Network error. Check your connection';
        } else if (e.toString().contains('Rate limit')) {
          errorMessage = 'Rate limit exceeded. Try again later';
        }

        FlowUtils.showErrorSnackBar(context, errorMessage);
      }
    }
  }

  /// Creates a duplicate of the original flow with translated content applied directly
  Future<FlowData?> _createTranslatedDuplicate(
    FlowNotifier flowNotifier,
    FlowData originalFlow,
    Map<String, dynamic> translatedData,
    String targetLanguageCode,
  ) async {
    try {
      // First create a regular duplicate
      final duplicatedFlow = await flowNotifier.duplicateFlow(originalFlow);
      if (duplicatedFlow == null) return null;

      duplicatedFlow.language = targetLanguageCode;
      duplicatedFlow.title = translatedData['title'] ?? duplicatedFlow.title;
      duplicatedFlow.description =
          translatedData['description'] ?? duplicatedFlow.subtitle;
      duplicatedFlow.originalFlowId = originalFlow.id;
      duplicatedFlow.originalFlowVersion = originalFlow.version;

      duplicatedFlow.flowSections =
          (translatedData['flowSections'] as List<dynamic>?)
              ?.map((sectionJson) => FlowSection.fromJson(sectionJson))
              .toList() ??
          duplicatedFlow.flowSections;
      duplicatedFlow.flowSteps =
          (translatedData['flowSteps'] as List<dynamic>?)?.map((stepJson) {
            final step = FlowStep.fromJson(stepJson);
            // Remove audio asset from translated steps since they would be in the wrong language
            step.removeAudioAsset();
            // Remove only TTS-generated assets (step_tts_*) from regular assets
            step.assets.removeWhere(
              (asset) =>
                  asset.path.contains('step_tts_') ||
                  (asset.displayName?.contains('step_tts_') ?? false),
            );
            return step;
          }).toList() ??
          duplicatedFlow.flowSteps;

      // Save the translated flow directly to storage
      await flowNotifier.saveFlowData(duplicatedFlow);

      // Clean up: Delete only TTS audio files from the translated flow directory
      // since they contain speech in the source language
      try {
        final storageService = FlowStorageService();
        final flowAssetsPath = await storageService.getAbsoluteFilePath(
          duplicatedFlow.id,
          'assets',
        );
        final assetsDirectory = Directory(flowAssetsPath);
        if (await assetsDirectory.exists()) {
          final files = await assetsDirectory.list().toList();
          for (final file in files) {
            if (file is File && file.path.contains('step_tts_')) {
              await file.delete();
              debugPrint('Deleted TTS file: ${file.path}');
            }
          }
          debugPrint(
            'Cleaned up TTS audio files from translated flow directory',
          );
        }
      } catch (e) {
        debugPrint('Warning: Could not clean up TTS audio files: $e');
        // Don't fail the translation if cleanup fails
      }

      return duplicatedFlow;
    } catch (e) {
      debugPrint('Error creating translated duplicate: $e');
      return null;
    }
  }
}
