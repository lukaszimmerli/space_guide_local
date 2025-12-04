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
          child: const Text('SpaceGuides', style: TextStyle(fontSize: 36)),
        ),
        actions: [
          // AI Tools Menu
          Consumer<SettingsService>(
            builder: (context, settingsService, _) {
              // Show AI tools menu if AI features are enabled
              if (settingsService.isAiFeaturesEnabled) {
                return PopupMenuButton<String>(
                  icon: SvgPicture.asset(
                    'assets/icon/noun-ai-star-6056248.svg',
                    width: 26,
                    height: 26,
                    colorFilter: ColorFilter.mode(
                      Theme.of(context).colorScheme.onSurface,
                      BlendMode.srcIn,
                    ),
                  ),
                  tooltip: 'AI Tools',
                  itemBuilder:
                      (context) => const [
                        PopupMenuItem(
                          value: 'translate',
                          child: Row(
                            children: [
                              Icon(CarbonIcons.translate),
                              SizedBox(width: 8),
                              Text('Translate Flow'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'tts',
                          child: Row(
                            children: [
                              Icon(CarbonIcons.microphone),
                              SizedBox(width: 8),
                              Text('Generate Audio'),
                            ],
                          ),
                        ),
                      ],
                  onSelected: (value) {
                    switch (value) {
                      case 'translate':
                        showDialog(
                          context: context,
                          builder: (context) => const FlowTranslationDialog(),
                        );
                        break;
                      case 'tts':
                        showDialog(
                          context: context,
                          builder: (context) => const FlowTtsGenerationDialog(),
                        );
                        break;
                    }
                  },
                );
              }
              return const SizedBox.shrink();
            },
          ),
          IconButton(
            icon: const Icon(CarbonIcons.search, size: 26),
            tooltip: 'Search',
            onPressed: () {
              setState(() {
                _showSearch = !_showSearch;
              });
            },
          ),
          IconButton(
            icon: const Icon(CarbonIcons.settings, size: 26),
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

          return SafeArea(
            child: Padding(
              padding: screenPadding.toEdgeInsets(),
              child: FlowListView(
                enableFlowCreation: true,
                enableSearch: _showSearch,
                groupByCategory: true,
                createFlowIcon: Icon(CarbonIcons.add, size: 40),
                deleteIcon: Icon(CupertinoIcons.delete, size: 24),
                editIcon: Icon(CarbonIcons.edit, size: 24),
                duplicateIcon: Icon(CarbonIcons.copy, size: 24),
                shareIcon: Icon(CarbonIcons.share, size: 24),
                searchIcon: Icon(CarbonIcons.search, size: 24),
                qrIcon: Icon(CarbonIcons.qr_code, size: 24),
                qrExportIcon: Icon(CarbonIcons.qr_code, size: 24),
                defaultThumbnailIcon: Icon(
                  CarbonIcons.carousel_horizontal,
                  size: 30,
                ),
                showLanguageFlag: settingsService.showLanguageFlag,
                // Local share functionality only
                onShare: (flow) => _shareFlow(context, flow),
                onQRExport: (flow) => _exportFlowQR(context, flow),
                onCreated:
                    (flow) => Navigator.push(
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
                    ),
                onSelected: (flowData) {
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
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => FlowScreenFactory.createFlowDetailScreen(
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
                  });
                },
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
}
