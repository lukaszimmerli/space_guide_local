import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flow_manager_saas/flow_manager.dart';
import 'package:provider/provider.dart';
import '../services/settings_service.dart';
import '../services/text_improvement_service.dart';

class EnhancedStepDetailScreen extends StatefulWidget {
  final String stepId;
  final String sectionId;
  final String flowId;

  // Pass through configurable icons for the wrapped StepDetailScreen
  final Widget? deleteIcon;
  final Widget? addIcon;
  final Widget? closeIcon;
  final Widget? cameraIcon;
  final Widget? photoGalleryIcon;
  final Widget? recordVideoIcon;
  final Widget? confirmIcon;
  final Widget? existingAssetIcon;
  final Widget? videoGalleryIcon;
  final Widget? filePickerIcon;
  final Widget? timerIcon;

  const EnhancedStepDetailScreen({
    super.key,
    required this.stepId,
    required this.sectionId,
    required this.flowId,
    this.deleteIcon,
    this.addIcon,
    this.closeIcon,
    this.cameraIcon,
    this.photoGalleryIcon,
    this.recordVideoIcon,
    this.confirmIcon,
    this.existingAssetIcon,
    this.videoGalleryIcon,
    this.filePickerIcon,
    this.timerIcon,
  });

  @override
  State<EnhancedStepDetailScreen> createState() =>
      _EnhancedStepDetailScreenState();
}

class _EnhancedStepDetailScreenState extends State<EnhancedStepDetailScreen> {
  final GlobalKey<StepDetailScreenState> _stepDetailKey =
      GlobalKey<StepDetailScreenState>();

  @override
  Widget build(BuildContext context) {
    final settingsService = Provider.of<SettingsService>(context);

    return StepDetailScreen(
      key: _stepDetailKey,
      stepId: widget.stepId,
      sectionId: widget.sectionId,
      flowId: widget.flowId,
      // Pass through all icon configurations
      deleteIcon: widget.deleteIcon,
      addIcon: widget.addIcon,
      closeIcon: widget.closeIcon,
      cameraIcon: widget.cameraIcon,
      photoGalleryIcon: widget.photoGalleryIcon,
      recordVideoIcon: widget.recordVideoIcon,
      confirmIcon: widget.confirmIcon,
      existingAssetIcon: widget.existingAssetIcon,
      videoGalleryIcon: widget.videoGalleryIcon,
      filePickerIcon: widget.filePickerIcon,
      // Add enhanced custom actions if AI features are enabled
      customActions:
          settingsService.isAiFeaturesEnabled ? _buildCustomActions() : null,
      timerIcon: widget.timerIcon,
    );
  }

  List<Widget>? _buildCustomActions() {
    return [
      Padding(
        padding: const EdgeInsets.only(right: 12.0),
        child: IconButton(
          icon: SvgPicture.asset(
            'assets/icon/write-ai.svg',
            width: 26,
            height: 26,
            colorFilter: ColorFilter.mode(
              Theme.of(context).colorScheme.onSurface,
              BlendMode.srcIn,
            ),
          ),
          onPressed: _handleAITextEnhancement,
          tooltip: 'AI Text Enhancement',
        ),
      ),
    ];
  }

  /// Handle AI text enhancement button tap
  Future<void> _handleAITextEnhancement() async {
    debugPrint('AI Text Enhancement button tapped');

    // Get access to the StepDetailScreen's state
    final stepDetailState = _stepDetailKey.currentState;
    if (stepDetailState == null) {
      debugPrint('AI Text Enhancement: StepDetailScreen state not available');
      return;
    }

    // Check if AI features are enabled
    if (!TextImprovementService.isAiFeaturesEnabled()) {
      if (mounted) {
        FlowUtils.showErrorSnackBar(
          context,
          'Please set your OpenAI API key in Settings to use AI features',
        );
      }
      return;
    }

    // Get the current description from the step detail screen
    final currentDescription = stepDetailState.getDescription();
    debugPrint('Current description: "$currentDescription"');

    if (currentDescription.trim().isEmpty) {
      if (mounted) {
        FlowUtils.showErrorSnackBar(
          context,
          'Please enter some text first to improve it',
        );
      }
      return;
    }

    // Show loading indicator
    if (!mounted) return;
    _showLoadingDialog(context);

    try {
      debugPrint('AI Text Enhancement starting...');
      debugPrint('Original text: "$currentDescription"');

      // Call the text improvement service
      final improvedText = await TextImprovementService.improveText(
        currentDescription,
        task: 'improve',
      );

      // Hide loading dialog
      if (mounted) Navigator.of(context).pop();

      // Update the text field with improved text
      stepDetailState.updateDescription(improvedText);

      debugPrint('Improved text: "$improvedText"');

      // Show success message
      if (mounted) {
        FlowUtils.showSuccessSnackBar(context, 'Text improved successfully!');
      }
    } catch (e) {
      // Hide loading dialog
      if (mounted) Navigator.of(context).pop();

      debugPrint('AI Text Enhancement error: $e');

      // Show error message
      if (mounted) {
        FlowUtils.showErrorSnackBar(
          context,
          'Failed to improve text: ${e.toString()}',
        );
      }
    }
  }

  /// Shows a loading dialog
  void _showLoadingDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Improving text...'),
            ],
          ),
        );
      },
    );
  }
}
