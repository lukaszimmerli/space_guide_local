import 'dart:io';
import 'dart:convert';
import 'package:carbon_icons/carbon_icons.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flow_manager_saas/flow_manager.dart';
import 'package:archive/archive.dart';
import '../services/settings_service.dart';
import '../utils/flow_screen_factory.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _apiKeyController = TextEditingController();
  bool _obscureApiKey = true;

  @override
  void initState() {
    super.initState();
    _loadApiKey();
  }

  Future<void> _loadApiKey() async {
    final settingsService = Provider.of<SettingsService>(
      context,
      listen: false,
    );
    final apiKey = settingsService.openaiApiKey;
    if (apiKey != null && apiKey.isNotEmpty) {
      setState(() {
        _apiKeyController.text = apiKey;
      });
    }
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  /// Handles the flow import process
  Future<void> _importFlow(BuildContext context) async {
    try {
      // Show file picker to select flow file
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        dialogTitle: 'Select Flow File (.flow)',
        withData: false,
        withReadStream: false,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final fileName = result.files.single.name;

        // Validate file extension
        if (!fileName.toLowerCase().endsWith('.flow') &&
            !fileName.toLowerCase().endsWith('.zip')) {
          if (context.mounted) {
            _showErrorDialog(
              context,
              'Invalid File Type',
              'Please select a .flow file.',
            );
          }
          return;
        }

        // Show loading indicator for validation
        if (!context.mounted) return;
        _showLoadingDialog(context, 'Validating flow file...');

        try {
          // First, try to peek at the flow data to check for duplicates
          final storageService = FlowStorageService();
          final flowData = await _parseFlowFromFile(file);

          // Hide validation loading dialog
          if (!context.mounted) return;
          Navigator.of(context).pop();

          // Check if a flow with this ID already exists
          final existingFlows = await storageService.getAllFlows();
          FlowData? existingFlow;

          if (existingFlows.isNotEmpty) {
            try {
              existingFlow = existingFlows.firstWhere(
                (f) => f.id == flowData['id'],
              );
            } catch (e) {
              // No flow found with this ID, existingFlow remains null
              existingFlow = null;
            }
          }

          if (existingFlow != null) {
            // Show confirmation dialog for duplicate flow
            if (!context.mounted) return;
            final shouldReplace = await _showDuplicateConfirmationDialog(
              context,
              existingFlow.title,
              flowData['title'] ?? 'Untitled Flow',
            );

            if (!shouldReplace) {
              return; // User cancelled
            }
          }

          // Show import loading indicator
          if (!context.mounted) return;
          _showLoadingDialog(context, 'Importing flow...');

          // Import the flow using FlowStorageService
          final flowId = await storageService.importFlow(file);

          // Load the imported flow to get its details
          final importedFlow = await storageService.loadFlow(flowId);

          // Hide loading dialog
          if (!context.mounted) return;
          Navigator.of(context).pop();

          // Show success message
          FlowUtils.showSuccessSnackBar(
            context,
            'Flow "${importedFlow.title}" imported successfully!',
          );

          // Navigate to the flow overview screen and replace the current stack
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder:
                  (context) => FlowScreenFactory.createFlowDetailScreen(
                    flowId: importedFlow.id,
                    flowTitle:
                        importedFlow.title.isNotEmpty
                            ? importedFlow.title
                            : 'Untitled Flow',
                  ),
            ),
            (route) => route.isFirst, // Keep only the first route (main screen)
          );
        } catch (e) {
          // Hide loading dialog if still showing
          if (context.mounted) Navigator.of(context).pop();

          // Show error message
          if (context.mounted) {
            _showErrorDialog(
              context,
              'Import Failed',
              'Failed to import flow: ${e.toString()}',
            );
          }
        }
      }
    } catch (e) {
      // Show error message for file picker failure
      if (context.mounted) {
        _showErrorDialog(
          context,
          'File Selection Failed',
          'Failed to select file: ${e.toString()}',
        );
      }
    }
  }

  /// Parses basic flow data from a file without importing it
  Future<Map<String, dynamic>> _parseFlowFromFile(File file) async {
    try {
      final extension = file.path.toLowerCase().split('.').last;

      if (extension == 'flow' || extension == 'zip') {
        // Parse ZIP file
        final bytes = await file.readAsBytes();
        final archive = ZipDecoder().decodeBytes(bytes);

        // First get the flow data
        Map<String, dynamic>? flowJson;
        for (final file in archive) {
          if (file.isFile && file.name == 'flow.json') {
            final jsonString = utf8.decode(file.content as List<int>);
            flowJson = jsonDecode(jsonString) as Map<String, dynamic>;
            break;
          }
        }

        if (flowJson == null) {
          throw Exception('No valid flow.json found in archive');
        }

        // Try to get title from flow.json first
        String? title = flowJson['title'] as String?;

        // If no title in flow.json or it's empty, try language files
        if (title == null || title.isEmpty) {
          // Get the flow's language to find the correct language file
          final flowLanguage = flowJson['language'] as String? ?? 'en';

          for (final langFile in archive) {
            if (langFile.isFile && langFile.name == '$flowLanguage.json') {
              try {
                final langJsonString = utf8.decode(
                  langFile.content as List<int>,
                );
                final langJson =
                    jsonDecode(langJsonString) as Map<String, dynamic>;
                title = langJson['title'] as String?;
                if (title != null && title.isNotEmpty) break;
              } catch (e) {
                // Continue to next language file
              }
            }
          }

          // If still no title, try any language file
          if (title == null || title.isEmpty) {
            for (final langFile in archive) {
              if (langFile.isFile &&
                  langFile.name.endsWith('.json') &&
                  langFile.name != 'flow.json') {
                try {
                  final langJsonString = utf8.decode(
                    langFile.content as List<int>,
                  );
                  final langJson =
                      jsonDecode(langJsonString) as Map<String, dynamic>;
                  title = langJson['title'] as String?;
                  if (title != null && title.isNotEmpty) break;
                } catch (e) {
                  // Continue to next language file
                }
              }
            }
          }
        }

        return {
          'id': flowJson['id'],
          'title': title?.isNotEmpty == true ? title! : 'Untitled Flow',
        };
      } else {
        // Parse JSON file (legacy format)
        final jsonString = await file.readAsString();
        final importData = jsonDecode(jsonString) as Map<String, dynamic>;
        final flowJson = importData['flow'] as Map<String, dynamic>;
        final languageJson = importData['language'] as Map<String, dynamic>?;

        // Try flow title first, then language title
        String? title = flowJson['title'] as String?;
        if (title == null || title.isEmpty) {
          title = languageJson?['title'] as String?;
        }

        return {
          'id': flowJson['id'],
          'title': title?.isNotEmpty == true ? title! : 'Untitled Flow',
        };
      }
    } catch (e) {
      // If parsing fails, return a placeholder to allow the import to continue
      // The actual import will handle the error properly
      return {'id': 'unknown', 'title': 'Unknown Flow'};
    }
  }

  /// Shows a confirmation dialog for duplicate flows
  Future<bool> _showDuplicateConfirmationDialog(
    BuildContext context,
    String existingTitle,
    String newTitle,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return StyledAlertDialog(
          title: 'Flow Already Exists',
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('A flow with this ID already exists:'),
              const SizedBox(height: 8),
              Text(
                'Existing: "$existingTitle"',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Importing: "$newTitle"',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Text('Do you want to replace the existing flow?'),
            ],
          ),
          leftAction: TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          rightAction: ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Replace'),
          ),
        );
      },
    );

    return result ?? false;
  }

  /// Shows a loading dialog
  void _showLoadingDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 16),
              Text(message),
            ],
          ),
        );
      },
    );
  }

  /// Shows an error dialog
  void _showErrorDialog(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StyledAlertDialog(
          title: title,
          content: Text(message),
          leftAction: const SizedBox.shrink(), // Empty left action
          rightAction: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        );
      },
    );
  }

  /// Saves the OpenAI API key
  Future<void> _saveApiKey(BuildContext context) async {
    final apiKey = _apiKeyController.text.trim();

    if (apiKey.isEmpty) {
      FlowUtils.showErrorSnackBar(context, 'Please enter an API key');
      return;
    }

    // Basic validation - OpenAI API keys start with 'sk-'
    if (!apiKey.startsWith('sk-')) {
      FlowUtils.showErrorSnackBar(
        context,
        'Invalid API key format. OpenAI API keys start with "sk-"',
      );
      return;
    }

    try {
      final settingsService = Provider.of<SettingsService>(
        context,
        listen: false,
      );
      await settingsService.setOpenAiApiKey(apiKey);

      if (context.mounted) {
        FlowUtils.showSuccessSnackBar(
          context,
          'API key saved successfully! AI features are now enabled.',
        );
      }
    } catch (e) {
      if (context.mounted) {
        FlowUtils.showErrorSnackBar(context, 'Failed to save API key: $e');
      }
    }
  }

  /// Clears the OpenAI API key
  Future<void> _clearApiKey(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return StyledAlertDialog(
          title: 'Clear API Key',
          content: const Text(
            'Are you sure you want to clear your OpenAI API key? AI features will be disabled.',
          ),
          leftAction: TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          rightAction: ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Clear'),
          ),
        );
      },
    );

    if (confirmed == true && mounted) {
      try {
        final settingsService = Provider.of<SettingsService>(
          context,
          listen: false,
        );
        await settingsService.clearOpenAiApiKey();

        setState(() {
          _apiKeyController.clear();
        });

        if (context.mounted) {
          FlowUtils.showSuccessSnackBar(
            context,
            'API key cleared successfully',
          );
        }
      } catch (e) {
        if (context.mounted) {
          FlowUtils.showErrorSnackBar(context, 'Failed to clear API key: $e');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get standard screen padding
    final screenPadding = DeviceUtils.getStandardScreenPadding(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        scrolledUnderElevation: 0,
      ),
      body: CustomPaint(
        painter: DottedBackgroundPainter(
          brightness: Theme.of(context).brightness,
        ),
        child: Consumer<SettingsService>(
          builder: (context, settingsService, _) {
            return SafeArea(
              child: ListView(
                padding: screenPadding.toEdgeInsets(bottom: 16.0),
                children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12.0, left: 14.0),
                      child: Text(
                        'Flow Management',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    // Import Flow Button
                    Card(
                      margin: EdgeInsets.zero,
                      child: ListTile(
                        title: const Text('Import Flow'),
                        subtitle: const Padding(
                          padding: EdgeInsets.only(bottom: 4.0),
                          child: Text('Import a flow from a .flow file'),
                        ),
                        onTap: () => _importFlow(context),
                        leading: const Icon(
                          CarbonIcons.document_import,
                          size: 34,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),

                // Reading Settings Section
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0, left: 14.0),
                  child: Text(
                    'Player',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                // Auto-Read Toggle
                Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    title: const Text('Auto Read Text'),
                    subtitle: const Padding(
                      padding: EdgeInsets.only(bottom: 4.0),
                      child: Text('Read step aloud when navigating.'),
                    ),
                    trailing: Switch(
                      value: settingsService.autoReadEnabled,
                      onChanged: (value) {
                        settingsService.setAutoReadEnabled(value);
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Statistics Display Toggle
                Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    title: const Text('Show Statistics'),
                    subtitle: const Padding(
                      padding: EdgeInsets.only(bottom: 4.0),
                      child: Text(
                        'Show time spent and other metrics at the end of a flow.',
                      ),
                    ),
                    trailing: Switch(
                      value: settingsService.showStatistics,
                      onChanged: (value) {
                        settingsService.setShowStatistics(value);
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 12.0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'App Appearance',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          'Select the app theme mode.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: SegmentedButton<String>(
                            style: ButtonStyle(
                              backgroundColor: WidgetStateProperty.resolveWith(
                                (states) {
                                  if (states.contains(WidgetState.selected)) {
                                    return Theme.of(context).colorScheme.primary;
                                  }
                                  return null;
                                },
                              ),
                              foregroundColor: WidgetStateProperty.resolveWith(
                                (states) {
                                  if (states.contains(WidgetState.selected)) {
                                    return Theme.of(context).colorScheme.onPrimary;
                                  }
                                  return null;
                                },
                              ),
                            ),
                            segments: const [
                              ButtonSegment(
                                value: 'light',
                                label: Text('Light'),
                                icon: Icon(CarbonIcons.sun, size: 18),
                              ),
                              ButtonSegment(
                                value: 'dark',
                                label: Text('Dark'),
                                icon: Icon(CarbonIcons.moon, size: 18),
                              ),
                              ButtonSegment(
                                value: 'system',
                                label: Text('System'),
                                icon: Icon(CarbonIcons.settings, size: 18),
                              ),
                            ],
                            selected: {settingsService.themeMode},
                            onSelectionChanged: (Set<String> newSelection) {
                              settingsService.setThemeMode(newSelection.first);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // AI Features Section
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0, left: 14.0),
                  child: Text(
                    'AI Features',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.only(
                      left: 16.0,
                      right: 16.0,
                      top: 22.0,
                      bottom: 16.0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            SvgPicture.asset(
                              'assets/icon/noun-ai-star-6056248.svg',
                              width: 26,
                              height: 26,
                              colorFilter: ColorFilter.mode(
                                Theme.of(context).colorScheme.onSurface,
                                BlendMode.srcIn,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'OpenAI API Key',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Enable AI features by providing an API key.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _apiKeyController,
                          obscureText: _obscureApiKey,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Theme.of(context).colorScheme.surfaceContainer,
                            labelText: 'API Key',
                            hintText: 'sk-...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureApiKey
                                    ? CarbonIcons.view_off
                                    : CarbonIcons.view,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscureApiKey = !_obscureApiKey;
                                });
                              },
                            ),
                          ),
                          onChanged: (value) {},
                        ),
                        if (settingsService.isAiFeaturesEnabled)
                          Padding(
                            padding: const EdgeInsets.only(top: 12.0),
                            child: Row(
                              children: [
                                Icon(
                                  CarbonIcons.checkmark_filled,
                                  color: Theme.of(context).colorScheme.primary,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'AI features enabled',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 20),

                        settingsService.isAiFeaturesEnabled
                            ? ElevatedButton(
                              onPressed: () => _clearApiKey(context),
                              style: ElevatedButton.styleFrom(
                                foregroundColor:
                                    Theme.of(context).colorScheme.error,
                                backgroundColor:
                                    Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.grey.shade900
                                        : Theme.of(
                                          context,
                                        ).colorScheme.errorContainer,
                                minimumSize: const Size(120, 40),
                              ),
                              child: const Text('Clear'),
                            )
                            : ElevatedButton(
                              onPressed: () => _saveApiKey(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.grey.shade900
                                        : Theme.of(
                                          context,
                                        ).colorScheme.primaryContainer,
                                foregroundColor:
                                    Theme.of(
                                      context,
                                    ).colorScheme.onPrimaryContainer,
                                minimumSize: const Size(120, 40),
                              ),
                              child: const Text('Save'),
                            ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Add more settings sections here as needed
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
