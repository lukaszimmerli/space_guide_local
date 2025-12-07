import 'package:carbon_icons/carbon_icons.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:flow_manager_saas/flow_manager.dart';
import 'package:flutter/services.dart';
import 'settings_screen.dart';
import '../services/settings_service.dart';
import '../services/timer_audio_service.dart';
import '../services/mixpanel_service.dart';
import '../utils/flow_screen_factory.dart';
import '../widgets/flow_translation_dialog.dart';
import '../widgets/flow_tts_generation_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _showSearch = false;
  Key _flowListKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    debugPrint('========================================');
    debugPrint('🏠 HOME SCREEN INIT');
    debugPrint('🔍 Mixpanel initialized: ${MixpanelService.isInitialized}');
    debugPrint('========================================');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Set orientation constraints once MediaQuery is available
    _setOrientationConstraints();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 6.0),
                child: Image.asset(
                  'assets/icon/spaceguide_icon_transparent_nobounds.png',
                  height: 32,
                  width: 32,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'spaceguide',
                style: TextStyle(fontSize: 36, fontFamily: 'NovaSquare'),
              ),
            ],
          ),
        ),
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            icon: const Icon(CupertinoIcons.search, size: 26),
            tooltip: 'Search',
            onPressed: () {
              setState(() {
                _showSearch = !_showSearch;
              });
            },
          ),
          IconButton(
            icon: const Icon(CarbonIcons.user, size: 26),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Consumer<SettingsService>(
        builder: (context, settingsService, _) {
          // Get standard screen padding with custom phone horizontal padding
          final screenPadding = DeviceUtils.getStandardScreenPadding(
            context,
            phoneHorizontal:
                4.0, // Custom reduced padding for phone on home screen
          );

          return CustomPaint(
            painter: DottedBackgroundPainter(
              brightness: Theme.of(context).brightness,
            ),
            child: SafeArea(
              child: Padding(
                padding: screenPadding.toEdgeInsets(),
                child: FlowListView(
                  key: _flowListKey,
                  enableFlowCreation: true,
                  enableSearch: _showSearch,
                  groupByCategory: true,
                  searchIcon: Icon(CarbonIcons.search, size: 24),
                  qrIcon: Icon(CupertinoIcons.qrcode_viewfinder, size: 24),
                  createFlowIcon: Icon(
                    CarbonIcons.add,
                    size: 40,
                    color: Colors.white,
                  ),
                  deleteIcon: Icon(CupertinoIcons.delete, size: 24),
                  editIcon: Icon(CarbonIcons.edit, size: 24),
                  duplicateIcon: Icon(CupertinoIcons.doc_on_doc, size: 24),
                  shareIcon: Icon(CarbonIcons.share, size: 24),
                  createFlowButtonColor: Theme.of(context).colorScheme.primary,
                  qrFlashIcon: CupertinoIcons.lightbulb,
                  qrCameraSwitchIcon: CupertinoIcons.camera_rotate,
                  qrExportIcon: Icon(CarbonIcons.qr_code, size: 24),
                  defaultThumbnailIcon: Icon(
                    CarbonIcons.carousel_horizontal,
                    size: 30,
                  ),
                  showLanguageFlag: settingsService.showLanguageFlag,
                  // Local share functionality only
                  onShare: (flow) => _shareFlow(context, flow),
                  onQRExport: (flow) => _exportFlowQR(context, flow),
                  onDeleted: (flow) {
                    // Track guide deleted
                    MixpanelService.trackGuideDeleted(
                      guideId: flow.id,
                      category: flow.category,
                      language: flow.language,
                      numberOfSteps: flow.flowSteps.length,
                    );
                  },
                  onDuplicated: (originalFlow, newFlow) {
                    // Track guide duplicated
                    MixpanelService.trackGuideDuplicated(
                      originalGuideId: originalFlow.id,
                      newGuideId: newFlow.id,
                      category: newFlow.category,
                      language: newFlow.language,
                    );
                  },
                  onCreated: (flow) {
                    // Track guide creation
                    MixpanelService.trackGuideCreated(
                      guideId: flow.id,
                      category: flow.category,
                      language: flow.language,
                      numberOfSections: flow.flowSections.length,
                      numberOfSteps: flow.flowSteps.length,
                    );
                    MixpanelService.incrementGuideCount();

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) =>
                                FlowScreenFactory.createFlowDetailScreen(
                                  flowId: flow.id,
                                  flowTitle:
                                      flow.title.isNotEmpty
                                          ? flow.title
                                          : 'Untitled Flow',
                                ),
                      ),
                    ).then((_) {
                      // Reload the flow list when returning from flow creation
                      setState(() {
                        _flowListKey = UniqueKey();
                      });
                    });
                  },
                  onSelected: (flowData) {
                    // Track guide viewed
                    MixpanelService.trackGuideViewed(
                      guideId: flowData.id,
                      category: flowData.category,
                      language: flowData.language,
                      numberOfSteps: flowData.flowSteps.length,
                      numberOfSections: flowData.flowSections.length,
                    );
                    MixpanelService.incrementGuidePlayCount();

                    // Calculate average step length for detailed metrics
                    final avgStepLength =
                        flowData.flowSteps.isEmpty
                            ? 0.0
                            : flowData.flowSteps
                                    .map((s) => s.description.length)
                                    .reduce((a, b) => a + b) /
                                flowData.flowSteps.length;

                    // Track guide played with detailed metrics
                    MixpanelService.trackGuidePlayed(
                      guideId: flowData.id,
                      category: flowData.category,
                      language: flowData.language,
                      totalSteps: flowData.flowSteps.length,
                      averageStepLength: avgStepLength,
                      numberOfSections: flowData.flowSections.length,
                    );

                    // Track comprehensive guide metrics
                    MixpanelService.trackGuideMetrics(flowData);

                    // Force flush events to Mixpanel immediately (for testing)
                    MixpanelService.flush();
                    debugPrint('🔄 Mixpanel: Events flushed to server');

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => FlowPlayerScreen(
                              flow: flowData,
                              // Configure Carbon Icons for FlowStatisticsScreen
                              pdfExportIcon: Icon(
                                CarbonIcons.document_pdf,
                                size: 24,
                              ),
                              printIcon: Icon(CarbonIcons.printer, size: 24),
                              shareIcon: Icon(CarbonIcons.share, size: 24),
                              previewIcon: Icon(CarbonIcons.view, size: 24),
                              playIcon: Icon(
                                CarbonIcons.play_filled_alt,
                                size: 80,
                              ),
                              pdfIcon: const Icon(
                                CarbonIcons.document_pdf,
                                size: 80,
                              ),
                              timerIcon: CarbonIcons.timer,
                              timePlotIcon: CarbonIcons.time_plot,
                              listIcon: CarbonIcons.list,
                              calendarIcon: CarbonIcons.calendar,
                              // Timer completion callback
                              onTimerCompleted:
                                  TimerAudioService.playTimerCompletionSound,
                            ),
                      ),
                    ).then((_) {
                      // Called when returning from FlowPlayerScreen
                      _setOrientationConstraints();
                    });
                  },
                  onEdit: (flowData) {
                    // Track guide edited
                    MixpanelService.trackGuideEdited(
                      guideId: flowData.id,
                      category: flowData.category,
                      language: flowData.language,
                      numberOfSections: flowData.flowSections.length,
                      numberOfSteps: flowData.flowSteps.length,
                    );
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) =>
                                FlowScreenFactory.createFlowDetailScreen(
                                  flowId: flowData.id,
                                  flowTitle:
                                      flowData.title.isNotEmpty
                                          ? flowData.title
                                          : 'Untitled Flow',
                                ),
                      ),
                    ).then((_) {
                      // Called when returning from FlowDetailScreen
                      _setOrientationConstraints();
                      // Reload the flow list to reflect any changes
                      setState(() {
                        _flowListKey = UniqueKey();
                      });
                    });
                  },
                  // Custom AI menu items for flow dropdown
                  customMenuItems:
                      settingsService.isAiFeaturesEnabled
                          ? (flow) {
                            final menuItems = <PopupMenuEntry<String>>[];

                            // Add Translate option
                            menuItems.add(
                              PopupMenuItem<String>(
                                value: 'translate',
                                child: Row(
                                  children: [
                                    SvgPicture.asset(
                                      'assets/icon/translate-ai.svg',
                                      width: 24,
                                      height: 24,
                                      colorFilter: ColorFilter.mode(
                                        Theme.of(context).colorScheme.onSurface,
                                        BlendMode.srcIn,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Text('Translate Flow'),
                                  ],
                                ),
                              ),
                            );

                            // Add TTS Generation option
                            menuItems.add(
                              PopupMenuItem<String>(
                                value: 'tts',
                                child: Row(
                                  children: [
                                    SvgPicture.asset(
                                      'assets/icon/mic-ai.svg',
                                      width: 24,
                                      height: 24,
                                      colorFilter: ColorFilter.mode(
                                        Theme.of(context).colorScheme.onSurface,
                                        BlendMode.srcIn,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Text('Generate Audio'),
                                  ],
                                ),
                              ),
                            );

                            return menuItems;
                          }
                          : null,
                  // Handle custom AI actions
                  onCustomAction: (flow, action) {
                    switch (action) {
                      case 'translate':
                        _showTranslationDialog(context, flow);
                        break;
                      case 'tts':
                        _showTtsDialog(context, flow);
                        break;
                    }
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // Helper method to set orientation constraints
  void _setOrientationConstraints() {
    // Allow both portrait and landscape orientations for all devices
    // since we now have proper layouts for both orientations
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  /// Share a flow locally using the device share functionality
  Future<void> _shareFlow(BuildContext context, FlowData flow) async {
    try {
      // Track guide shared
      MixpanelService.trackGuideShared(
        guideId: flow.id,
        category: flow.category,
        language: flow.language,
        numberOfSteps: flow.flowSteps.length,
      );
      await exportAndShareFlow(context, flow);
    } catch (e) {
      if (mounted) {
        FlowUtils.showErrorSnackBar(context, 'Error sharing flow: $e');
      }
    }
  }

  /// Export a flow as QR code
  Future<void> _exportFlowQR(BuildContext context, FlowData flow) async {
    try {
      await QRExportUtils.exportFlowQR(
        context,
        flow.id,
        flow.title.isNotEmpty ? flow.title : 'Untitled Flow',
      );
    } catch (e) {
      if (mounted) {
        FlowUtils.showErrorSnackBar(context, 'Error exporting QR code: $e');
      }
    }
  }

  /// Show the translation dialog for a flow
  void _showTranslationDialog(BuildContext context, FlowData flow) {
    showDialog(
      context: context,
      builder: (context) => FlowTranslationDialog(flow: flow),
    );
  }

  /// Show the TTS generation dialog for a flow
  void _showTtsDialog(BuildContext context, FlowData flow) {
    showDialog(
      context: context,
      builder: (context) => FlowTtsGenerationDialog(flow: flow),
    );
  }
}
