import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flow_manager_saas/flow_manager.dart';
import 'package:carbon_icons/carbon_icons.dart';
import '../services/flow_translation_service.dart';

class FlowTranslationDialog extends StatefulWidget {
  final String? initialFlowId;

  const FlowTranslationDialog({super.key, this.initialFlowId});

  @override
  State<FlowTranslationDialog> createState() => _FlowTranslationDialogState();
}

class _FlowTranslationDialogState extends State<FlowTranslationDialog> {
  FlowData? _selectedFlow;
  String? _targetLanguage;
  bool _isTranslating = false;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<FlowData>>(
      future: Provider.of<FlowNotifier>(context, listen: false).refreshFlows(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.0),
            ),
            content: const SizedBox(
              height: 100,
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        if (snapshot.hasError) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.0),
            ),
            title: const Text('Error'),
            content: Text('Failed to load flows: ${snapshot.error}'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          );
        }

        final flows = snapshot.data ?? [];

        // Pre-select flow if initialFlowId is provided
        if (widget.initialFlowId != null && _selectedFlow == null) {
          final matchingFlow =
              flows.where((f) => f.id == widget.initialFlowId).firstOrNull;
          if (matchingFlow != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _selectedFlow = matchingFlow;
                });
              }
            });
          }
        }

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          title: const Row(
            children: [
              Icon(CarbonIcons.translate),
              SizedBox(width: 8),
              Text('Translate Flow'),
            ],
          ),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Flow selection
                const SizedBox(height: 12),
                const Text('Select Flow to Translate'),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<FlowData>(
                      focusColor: Colors.transparent,
                      value: _selectedFlow,
                      hint: const Text('Choose a flow...'),
                      isExpanded: true,
                      items:
                          flows.map((flow) {
                            return DropdownMenuItem<FlowData>(
                              value: flow,
                              child: Text(
                                flow.title.isNotEmpty
                                    ? flow.title
                                    : 'Untitled Flow',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            );
                          }).toList(),
                      onChanged: (flow) {
                        setState(() {
                          _selectedFlow = flow;
                        });
                      },
                    ),
                  ),
                ),

                if (_selectedFlow != null) ...[
                  const SizedBox(height: 24),

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
                              _selectedFlow!.language,
                            ) !=
                            null) ...[
                          Text(
                            LanguageSelector.getLanguageFlag(
                              _selectedFlow!.language,
                            )!,
                            style: const TextStyle(fontSize: 18),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          LanguageSelector.getLanguageName(
                            _selectedFlow!.language,
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
                      _selectedFlow != null &&
                              _targetLanguage != null &&
                              _targetLanguage != _selectedFlow!.language &&
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
                          : const Text('Translate'),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _translateFlow() async {
    if (_selectedFlow == null || _targetLanguage == null) return;

    setState(() {
      _isTranslating = true;
    });

    try {
      // Convert flow to JSON format for translation
      final flowData = {
        'id': _selectedFlow!.id,
        'title': _selectedFlow!.title,
        'subtitle': _selectedFlow!.subtitle,
        'description': _selectedFlow!.description,
        'language': _selectedFlow!.language,
        'flowSections':
            _selectedFlow!.flowSections
                .map((section) => section.toJson())
                .toList(),
        'flowSteps':
            _selectedFlow!.flowSteps.map((step) => step.toJson()).toList(),
      };

      // Translate the flow
      final translatedFlowData = await FlowTranslationService.translateFlow(
        flowData,
        sourceLanguageCode: _selectedFlow!.language,
        targetLanguageCode: _targetLanguage!,
      );

      // Create new flow with translated content
      if (!mounted) return;
      final flowNotifier = Provider.of<FlowNotifier>(context, listen: false);

      // Create a translated duplicate directly
      final translatedFlow = await _createTranslatedDuplicate(
        flowNotifier,
        _selectedFlow!,
        translatedFlowData,
        _targetLanguage!,
      );

      setState(() {
        _isTranslating = false;
      });

      if (translatedFlow != null) {
        if (mounted) {
          Navigator.of(context).pop();
          FlowUtils.showSuccessSnackBar(
            context,
            'Flow translated to ${LanguageSelector.getLanguageName(_targetLanguage!)} and created successfully!',
          );
        }
      }
    } catch (e) {
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
