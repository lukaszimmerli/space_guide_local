import 'package:carbon_icons/carbon_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flow_manager_saas/flow_manager.dart';
import 'package:provider/provider.dart';
import '../services/settings_service.dart';
import '../services/flow_ai_state_service.dart';
import '../widgets/enhanced_step_detail_screen.dart';
import '../widgets/flow_ai_chat_dialog.dart';

class FlowScreenFactory {
  static Widget createFlowDetailScreen({
    required String flowId,
    required String flowTitle,
  }) {
    return _FlowDetailScreenWrapper(flowId: flowId, flowTitle: flowTitle);
  }
}

class _FlowDetailScreenWrapper extends StatefulWidget {
  final String flowId;
  final String flowTitle;

  const _FlowDetailScreenWrapper({
    required this.flowId,
    required this.flowTitle,
  });

  @override
  State<_FlowDetailScreenWrapper> createState() =>
      _FlowDetailScreenWrapperState();
}

class _FlowDetailScreenWrapperState extends State<_FlowDetailScreenWrapper> {
  late FlowAiStateService _aiStateService;

  @override
  void initState() {
    super.initState();
    _aiStateService = FlowAiStateService(flowId: widget.flowId);

    // Create initial snapshot after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _createInitialSnapshot();
    });
  }

  void _createInitialSnapshot() {
    final flowNotifier = Provider.of<FlowNotifier>(context, listen: false);
    print('DEBUG: Attempting to create initial snapshot');
    print('DEBUG: Flow is null: ${flowNotifier.flow == null}');

    if (flowNotifier.flow != null) {
      _aiStateService.historyService.addSnapshot(
        flowNotifier.flow!,
        'Initial flow state',
      );
      print('DEBUG: Initial snapshot created');
      print(
        'DEBUG: History size: ${_aiStateService.historyService.historySize}',
      );
      print(
        'DEBUG: Current index: ${_aiStateService.historyService.currentPosition}',
      );
    } else {
      print('DEBUG: Flow not loaded yet, will retry');
      // Flow not loaded yet, try again after a delay
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          _createInitialSnapshot();
        }
      });
    }
  }

  @override
  void dispose() {
    // Clear AI state when leaving flow editor
    _aiStateService.clear();
    _aiStateService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<FlowAiStateService>.value(
      value: _aiStateService,
      child: Consumer2<SettingsService, FlowAiStateService>(
        builder: (context, settingsService, aiState, _) {
          return Stack(
            children: [
              // Flow detail screen (full screen)
              _createFlowDetailScreen(
                context,
                widget.flowId,
                widget.flowTitle,
                settingsService.isAiFeaturesEnabled,
              ),
              // Keep/Revert banner at bottom
              if (aiState.hasPendingChanges &&
                  settingsService.isAiFeaturesEnabled)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _buildKeepRevertBanner(context, aiState),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildKeepRevertBanner(
    BuildContext context,
    FlowAiStateService aiState,
  ) {
    return Material(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'AI changes applied',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  fontSize: 14,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            OutlinedButton.icon(
              onPressed: () => _revertChanges(context, aiState),
              icon: const Icon(CarbonIcons.undo, size: 16),
              label: const Text('Revert'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
                side: BorderSide(color: Theme.of(context).colorScheme.error),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: () => aiState.keepChanges(),
              icon: const Icon(CarbonIcons.checkmark, size: 16),
              label: const Text('Keep'),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _revertChanges(
    BuildContext context,
    FlowAiStateService aiState,
  ) async {
    print('DEBUG: Revert button pressed');
    print('DEBUG: Can undo: ${aiState.historyService.canUndo}');
    print('DEBUG: History size: ${aiState.historyService.historySize}');

    final flowNotifier = Provider.of<FlowNotifier>(context, listen: false);
    final snapshot = aiState.historyService.undo();

    print('DEBUG: Snapshot is null: ${snapshot == null}');

    if (snapshot != null) {
      // Restore the previous flow state
      final currentFlow = flowNotifier.flow;
      if (currentFlow != null) {
        currentFlow.flowSections.clear();
        currentFlow.flowSections.addAll(snapshot.flow.flowSections);
        currentFlow.flowSteps.clear();
        currentFlow.flowSteps.addAll(snapshot.flow.flowSteps);

        // Update metadata
        await flowNotifier.updateFlowMetadata(
          title: snapshot.flow.title,
          description: snapshot.flow.description,
          language: snapshot.flow.language,
        );

        await flowNotifier.saveFlow();

        // Clear pending changes
        aiState.keepChanges();

        // Show snackbar
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Changes reverted successfully'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } else {
      // No history to revert to
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No changes to revert'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  static FlowDetailScreen _createFlowDetailScreen(
    BuildContext context,
    String flowId,
    String flowTitle,
    bool isAiFeaturesEnabled,
  ) {
    return FlowDetailScreen(
      flowId: flowId,
      flowTitle: flowTitle,
      // Configure Carbon Icons for FlowDetailScreen
      deleteIcon: const Icon(CupertinoIcons.delete, size: 24),
      editIcon: const Icon(CarbonIcons.edit, size: 24),
      addStepIcon: const Icon(CarbonIcons.add_alt, size: 24),
      duplicateIcon: const Icon(CupertinoIcons.doc_on_doc, size: 24),
      sectionMoreOptionsIcon: const Icon(
        CarbonIcons.overflow_menu_vertical,
        size: 26,
      ),
      stepMoreOptionsIcon: const Icon(
        CarbonIcons.overflow_menu_vertical,
        size: 18,
      ),
      addIcon: const Icon(CarbonIcons.add, size: 34),
      submitIcon: const Icon(
        CarbonIcons.arrow_up,
        size: 26,
        color: Colors.white,
      ),
      stepModeIcon: const Icon(
        CarbonIcons.text_align_justify,
        size: 24,
        color: Colors.white,
      ),
      sectionModeIcon: const Icon(
        CarbonIcons.license,
        size: 24,
        color: Colors.white,
      ),
      micIcon: const Icon(
        CarbonIcons.microphone,
        size: 26,
        color: Colors.white,
      ),
      micOnIcon: const Icon(
        CarbonIcons.microphone_filled,
        size: 26,
        color: Colors.white,
      ),
      cameraIcon: const Icon(CarbonIcons.camera, size: 24),
      photoGalleryIcon: const Icon(CarbonIcons.image, size: 24),
      recordVideoIcon: const Icon(CarbonIcons.video, size: 24),
      videoGalleryIcon: const Icon(CarbonIcons.document_video, size: 24),
      existingAssetIcon: const Icon(CarbonIcons.copy, size: 24),
      settingsIcon: const Icon(CupertinoIcons.gear, size: 28),
      // Add AI button when AI features are enabled
      customActions:
          isAiFeaturesEnabled
              ? [
                IconButton(
                  icon: SvgPicture.asset(
                    'assets/icon/chat-ai-round.svg',
                    width: 28,
                    height: 28,
                    colorFilter: ColorFilter.mode(
                      Theme.of(context).colorScheme.onSurface,
                      BlendMode.srcIn,
                    ),
                  ),
                  onPressed: () {
                    // Show AI chat sheet for flow manipulation
                    showFlowAiChat(context, flowId);
                  },
                  tooltip: 'AI Assistant',
                ),
              ]
              : null,
      // Additional icons for FlowSettingsScreen
      confirmIcon: const Icon(CarbonIcons.checkmark, size: 24),
      draftIcon: const Icon(CarbonIcons.document, size: 24),
      inReviewIcon: const Icon(CarbonIcons.view, size: 24),
      approvedIcon: const Icon(CarbonIcons.checkmark, size: 24),
      archivedIcon: const Icon(CarbonIcons.archive, size: 24),
      rejectedIcon: const Icon(CarbonIcons.close, size: 24),
      // Additional icons for StepDetailScreen
      closeIcon: const Icon(CarbonIcons.close, size: 36),
      filePickerIcon: const Icon(CarbonIcons.folder, size: 24),
      timerIcon: const Icon(CarbonIcons.timer, size: 20),
      // Use the enhanced step detail screen wrapper for AI features
      stepDetailBuilder: (stepId, sectionId, flowId) {
        return EnhancedStepDetailScreen(
          stepId: stepId,
          sectionId: sectionId,
          flowId: flowId,
          deleteIcon: const Icon(CupertinoIcons.delete, size: 24),
          addIcon: const Icon(CarbonIcons.add, size: 34),
          closeIcon: const Icon(CarbonIcons.close, size: 36),
          cameraIcon: const Icon(CarbonIcons.camera, size: 24),
          photoGalleryIcon: const Icon(CarbonIcons.image, size: 24),
          recordVideoIcon: const Icon(CarbonIcons.video, size: 24),
          confirmIcon: const Icon(CarbonIcons.checkmark, size: 24),
          existingAssetIcon: const Icon(CarbonIcons.copy, size: 24),
          videoGalleryIcon: const Icon(CarbonIcons.document_video, size: 24),
          filePickerIcon: const Icon(CarbonIcons.folder, size: 24),
          timerIcon: const Icon(CarbonIcons.timer, size: 20),
        );
      },
    );
  }
}
