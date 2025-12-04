import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flow_manager_saas/flow_manager.dart';
import 'package:carbon_icons/carbon_icons.dart';
import '../services/flow_tts_generation_service.dart';

class FlowTtsGenerationDialog extends StatefulWidget {
  final String? initialFlowId;

  const FlowTtsGenerationDialog({super.key, this.initialFlowId});

  @override
  State<FlowTtsGenerationDialog> createState() =>
      _FlowTtsGenerationDialogState();
}

class _FlowTtsGenerationDialogState extends State<FlowTtsGenerationDialog> {
  FlowData? _selectedFlow;
  bool _isGenerating = false;
  bool _forceRegenerate = false;

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
              Icon(CarbonIcons.microphone),
              SizedBox(width: 8),
              Text('Generate Audio'),
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
                const Text('Select Flow for Audio Generation'),
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
                            // Count steps that need audio
                            final stepsNeedingAudio =
                                flow.flowSteps
                                    .where(
                                      (step) =>
                                          step.description.isNotEmpty &&
                                          !step.hasAudioAsset,
                                    )
                                    .length;

                            return DropdownMenuItem<FlowData>(
                              value: flow,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    flow.title.isNotEmpty
                                        ? flow.title
                                        : 'Untitled Flow',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  if (stepsNeedingAudio > 0)
                                    Text(
                                      '$stepsNeedingAudio steps need audio',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.orange[600],
                                      ),
                                    )
                                  else
                                    Text(
                                      'All steps have audio',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.green[600],
                                      ),
                                    ),
                                ],
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
                // Force regenerate checkbox - only show if selected flow has all steps with audio
                if (_selectedFlow != null &&
                    _selectedFlow!.flowSteps.isNotEmpty &&
                    _selectedFlow!.flowSteps
                        .where((s) => s.description.isNotEmpty)
                        .every((s) => s.hasAudioAsset)) ...[
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    value: _forceRegenerate,
                    onChanged:
                        _isGenerating
                            ? null
                            : (value) {
                              setState(() {
                                _forceRegenerate = value ?? false;
                              });
                            },
                    title: const Text('Regenerate existing audio'),
                    subtitle: const Text(
                      'Generate new audio for all steps',
                      style: TextStyle(fontSize: 12),
                    ),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
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
                      _isGenerating ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed:
                      _selectedFlow != null && !_isGenerating
                          ? _generateTts
                          : null,
                  child:
                      _isGenerating
                          ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Text('Generate Audio'),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _generateTts() async {
    if (_selectedFlow == null) return;

    setState(() {
      _isGenerating = true;
    });

    try {
      final result = await FlowTtsGenerationService.generateTtsForFlow(
        flowId: _selectedFlow!.id,
        flowData: _selectedFlow!,
        forceRegenerate: _forceRegenerate,
      );

      if (!mounted) return;

      // Close the TTS dialog
      Navigator.of(context).pop();

      // Refresh flows to show updated audio assets
      if (mounted) {
        debugPrint('TTS Dialog: Refreshing flows after TTS generation...');
        final flowNotifier = Provider.of<FlowNotifier>(context, listen: false);

        // First refresh the flows list
        await flowNotifier.refreshFlows();

        // If the updated flow is currently loaded, reload it specifically
        if (flowNotifier.flow?.id == _selectedFlow!.id) {
          debugPrint('TTS Dialog: Reloading currently active flow...');
          await flowNotifier.loadFlow(_selectedFlow!.id);
        }

        debugPrint('TTS Dialog: Flows refreshed successfully');

        // Show a snackbar with success message
        if (mounted) {
          FlowUtils.showSuccessSnackBar(
            context,
            'Audio generation completed! Generated ${result.processedSteps} audio files.',
          );
        }
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isGenerating = false;
      });

      // Show error message
      String errorMessage = 'Audio generation failed';
      if (e.toString().contains('API key not configured')) {
        errorMessage = 'Please set your OpenAI API key in Settings';
      } else if (e.toString().contains('Network error')) {
        errorMessage = 'Network error. Check your connection';
      } else if (e.toString().contains('Rate limit')) {
        errorMessage = 'Rate limit exceeded. Try again later';
      }

      FlowUtils.showErrorSnackBar(context, errorMessage);
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }
}
