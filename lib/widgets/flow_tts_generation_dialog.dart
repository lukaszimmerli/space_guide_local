import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flow_manager_saas/flow_manager.dart';
import '../services/flow_tts_generation_service.dart';

class FlowTtsGenerationDialog extends StatefulWidget {
  final FlowData flow;

  const FlowTtsGenerationDialog({super.key, required this.flow});

  @override
  State<FlowTtsGenerationDialog> createState() =>
      _FlowTtsGenerationDialogState();
}

class _FlowTtsGenerationDialogState extends State<FlowTtsGenerationDialog> {
  bool _isGenerating = false;

  @override
  Widget build(BuildContext context) {
    // Count steps that need audio
    final stepsNeedingAudio =
        widget.flow.flowSteps
            .where((step) => step.description.isNotEmpty && !step.hasAudioAsset)
            .length;

    final totalSteps = widget.flow.flowSteps.length;

    return AlertDialog(
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: SvgPicture.asset(
              'assets/icon/mic-ai.svg',
              width: 26,
              height: 26,
              colorFilter: ColorFilter.mode(
                Theme.of(context).colorScheme.onSurface,
                BlendMode.srcIn,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Generate Audio', overflow: TextOverflow.ellipsis),
                Text(
                  widget.flow.title.isNotEmpty ? widget.flow.title : 'Untitled Flow',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
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
            if (stepsNeedingAudio > 0) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange[700]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '$stepsNeedingAudio of $totalSteps steps need audio generation',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.orange[900],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.green.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline, color: Colors.green[700]),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'All steps already have audio',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              'This will generate audio for all steps that don\'t have audio yet.',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
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
              onPressed: !_isGenerating ? _generateTts : null,
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
  }

  Future<void> _generateTts() async {
    setState(() {
      _isGenerating = true;
    });

    try {
      final result = await FlowTtsGenerationService.generateTtsForFlow(
        flowId: widget.flow.id,
        flowData: widget.flow,
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
        if (flowNotifier.flow?.id == widget.flow.id) {
          debugPrint('TTS Dialog: Reloading currently active flow...');
          await flowNotifier.loadFlow(widget.flow.id);
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
