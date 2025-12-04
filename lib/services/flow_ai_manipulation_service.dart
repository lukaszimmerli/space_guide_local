import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flow_manager_saas/flow_manager.dart';
import 'settings_service.dart';
import 'flow_history_service.dart';

/// Message in the AI chat conversation
class AiChatMessage {
  final String role; // 'user', 'assistant', 'system'
  final String content;
  final List<Map<String, dynamic>>? toolCalls;
  final String? toolCallId;
  final String? name;

  AiChatMessage({
    required this.role,
    required this.content,
    this.toolCalls,
    this.toolCallId,
    this.name,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{'role': role, 'content': content};
    if (toolCalls != null) {
      json['tool_calls'] = toolCalls;
    }
    if (toolCallId != null) {
      json['tool_call_id'] = toolCallId;
    }
    if (name != null) {
      json['name'] = name;
    }
    return json;
  }
}

/// Result of an AI manipulation operation
class AiManipulationResult {
  final bool success;
  final String message;
  final List<String> actions;
  final bool changesApplied;

  AiManipulationResult({
    required this.success,
    required this.message,
    this.actions = const [],
    this.changesApplied = false,
  });
}

/// Service for AI-powered flow manipulation using OpenAI function calling
class FlowAiManipulationService {
  static const String _openaiApiUrl =
      'https://api.openai.com/v1/chat/completions';

  /// Tool definitions for OpenAI function calling
  static List<Map<String, dynamic>> get _tools => [
    {
      'type': 'function',
      'function': {
        'name': 'add_section',
        'description': 'Add a new section to the flow',
        'parameters': {
          'type': 'object',
          'properties': {
            'title': {
              'type': 'string',
              'description': 'The title of the new section',
            },
          },
          'required': ['title'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'add_step',
        'description':
            'Add a new step to a section. If section_name is provided, the step will be added to that section. If section_name is not provided, the step will be added to the first section.',
        'parameters': {
          'type': 'object',
          'properties': {
            'description': {
              'type': 'string',
              'description': 'The description/content of the step',
            },
            'section_name': {
              'type': 'string',
              'description':
                  'The name of the section to add the step to. If not provided, adds to the first section.',
            },
          },
          'required': ['description'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'add_section_with_steps',
        'description': 'Add a new section with multiple steps at once',
        'parameters': {
          'type': 'object',
          'properties': {
            'section_title': {
              'type': 'string',
              'description': 'The title of the new section',
            },
            'steps': {
              'type': 'array',
              'items': {'type': 'string'},
              'description': 'List of step descriptions to add to the section',
            },
          },
          'required': ['section_title', 'steps'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'update_section_title',
        'description': 'Update the title of an existing section',
        'parameters': {
          'type': 'object',
          'properties': {
            'old_title': {
              'type': 'string',
              'description': 'The current title of the section to update',
            },
            'new_title': {
              'type': 'string',
              'description': 'The new title for the section',
            },
          },
          'required': ['old_title', 'new_title'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'delete_section',
        'description': 'Delete a section and all its steps',
        'parameters': {
          'type': 'object',
          'properties': {
            'section_name': {
              'type': 'string',
              'description': 'The name of the section to delete',
            },
          },
          'required': ['section_name'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'delete_step',
        'description': 'Delete a step from a section',
        'parameters': {
          'type': 'object',
          'properties': {
            'step_description': {
              'type': 'string',
              'description':
                  'The description of the step to delete (partial match supported)',
            },
            'section_name': {
              'type': 'string',
              'description':
                  'The name of the section containing the step (optional)',
            },
          },
          'required': ['step_description'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'update_flow_title',
        'description': 'Update the title of the flow',
        'parameters': {
          'type': 'object',
          'properties': {
            'title': {
              'type': 'string',
              'description': 'The new title for the flow',
            },
          },
          'required': ['title'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'update_flow_description',
        'description': 'Update the description of the flow',
        'parameters': {
          'type': 'object',
          'properties': {
            'description': {
              'type': 'string',
              'description': 'The new description for the flow',
            },
          },
          'required': ['description'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'update_flow_language',
        'description':
            'Update the language code of the flow (e.g., "en", "es", "fr", "de")',
        'parameters': {
          'type': 'object',
          'properties': {
            'language': {
              'type': 'string',
              'description':
                  'The new language code for the flow (ISO 639-1 format)',
            },
          },
          'required': ['language'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'update_flow_category',
        'description':
            'Update the category of the flow (e.g., "Cooking", "Tutorial", "Handicraft")',
        'parameters': {
          'type': 'object',
          'properties': {
            'category': {
              'type': 'string',
              'description': 'The new category for the flow',
            },
          },
          'required': ['category'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'update_step_description',
        'description':
            'Update the description of an existing step. Can match by partial description or by section and step position.',
        'parameters': {
          'type': 'object',
          'properties': {
            'step_identifier': {
              'type': 'string',
              'description':
                  'The current description or partial description of the step to update',
            },
            'new_description': {
              'type': 'string',
              'description': 'The new description for the step',
            },
            'section_name': {
              'type': 'string',
              'description':
                  'Optional: The name of the section containing the step for more precise matching',
            },
          },
          'required': ['step_identifier', 'new_description'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'update_section_steps',
        'description':
            'Update multiple step descriptions in a section at once. Useful when updating all steps in a section.',
        'parameters': {
          'type': 'object',
          'properties': {
            'section_name': {
              'type': 'string',
              'description': 'The name of the section containing the steps',
            },
            'step_updates': {
              'type': 'array',
              'items': {
                'type': 'object',
                'properties': {
                  'old_description': {
                    'type': 'string',
                    'description':
                        'Current description (partial match supported)',
                  },
                  'new_description': {
                    'type': 'string',
                    'description': 'New description for the step',
                  },
                },
                'required': ['old_description', 'new_description'],
              },
              'description':
                  'List of step updates with old and new descriptions',
            },
          },
          'required': ['section_name', 'step_updates'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'set_step_timer',
        'description':
            'Set or update the timer duration for a step. Timer is displayed in minutes.',
        'parameters': {
          'type': 'object',
          'properties': {
            'step_description': {
              'type': 'string',
              'description': 'The description of the step to set the timer on',
            },
            'timer_minutes': {
              'type': 'integer',
              'description':
                  'Timer duration in minutes (0 to remove timer, positive integer to set)',
            },
          },
          'required': ['step_description', 'timer_minutes'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'set_step_type_to_check',
        'description':
            'Change a step type to "check" which displays OK/NOK buttons for quality control or verification steps',
        'parameters': {
          'type': 'object',
          'properties': {
            'step_description': {
              'type': 'string',
              'description':
                  'The description of the step to change to check type',
            },
          },
          'required': ['step_description'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'set_check_branching',
        'description':
            'Set branching behavior for a check-type step. Specify which step to go to when user clicks OK or NOK.',
        'parameters': {
          'type': 'object',
          'properties': {
            'step_description': {
              'type': 'string',
              'description':
                  'The description of the check step to configure branching for',
            },
            'ok_target_description': {
              'type': 'string',
              'description':
                  'Description of the step to go to when user clicks OK (leave empty to go to next step)',
            },
            'nok_target_description': {
              'type': 'string',
              'description':
                  'Description of the step to go to when user clicks NOK (leave empty to go to next step)',
            },
          },
          'required': ['step_description'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'get_flow_structure',
        'description':
            'Get the current structure of the flow including all sections and steps',
        'parameters': {'type': 'object', 'properties': {}},
      },
    },
  ];

  /// System prompt for the AI assistant
  static String _getSystemPrompt(FlowData flow) {
    return '''You are an AI assistant that helps users modify their flows. A flow consists of sections, and each section contains steps.

Current flow information:
- Title: ${flow.title}
- Description: ${flow.description}
- Number of sections: ${flow.flowSections.length}
- Total steps: ${flow.flowSteps.length}

Current structure:
${_getFlowStructureText(flow)}

You can help users:
- Add new sections
- Add steps to sections
- Update section titles and step descriptions
- Delete sections or steps
- Update flow title, description, or language
- Set timers on steps (in minutes)
- Change step types to "check" for quality control (adds OK/NOK buttons)
- Configure branching for check steps (what happens when user clicks OK or NOK)

IMPORTANT: When updating step descriptions, ALWAYS use the update_step_description or update_section_steps tools. NEVER delete and recreate steps just to change their descriptions.

When the user asks you to do something, use the appropriate tools to make the changes. Always confirm what you've done after making changes.

If the user's request is unclear, ask for clarification before making changes.''';
  }

  /// Get flow structure as text
  static String _getFlowStructureText(FlowData flow) {
    final buffer = StringBuffer();
    final sortedSections = List<FlowSection>.from(flow.flowSections)
      ..sort((a, b) => a.order.compareTo(b.order));

    for (final section in sortedSections) {
      buffer.writeln('Section: ${section.title}');
      final sectionSteps =
          flow.flowSteps.where((s) => s.flowSectionId == section.id).toList()
            ..sort((a, b) => a.order.compareTo(b.order));

      for (final step in sectionSteps) {
        final preview =
            step.description.length > 50
                ? '${step.description.substring(0, 50)}...'
                : step.description;
        buffer.writeln('  - $preview');
      }
    }
    return buffer.toString();
  }

  /// Process a user message and execute any tool calls
  static Future<AiManipulationResult> processMessage({
    required String userMessage,
    required FlowNotifier flowNotifier,
    required List<AiChatMessage> conversationHistory,
    FlowHistoryService? historyService,
  }) async {
    final flow = flowNotifier.flow;
    if (flow == null) {
      return AiManipulationResult(
        success: false,
        message: 'No flow is currently loaded.',
      );
    }

    // Create a snapshot before making changes
    if (historyService != null) {
      print('DEBUG: Adding snapshot before AI changes');
      print('DEBUG: Flow sections count: ${flow.flowSections.length}');
      print('DEBUG: Flow steps count: ${flow.flowSteps.length}');

      // If this is the first snapshot, add a dummy "current state" snapshot first
      // so that we can undo to the "before changes" state
      if (historyService.historySize == 0) {
        print('DEBUG: First AI change - creating initial snapshot');
        historyService.addSnapshot(flow, 'Before AI changes: $userMessage');
        // Add a second snapshot that represents "after changes will go here"
        // This will be overwritten by the actual changes
        historyService.addSnapshot(flow, 'Current state (temp)');
        print('DEBUG: Created 2 snapshots for first AI change');
      } else {
        historyService.addSnapshot(flow, 'Before AI changes: $userMessage');
      }

      print(
        'DEBUG: History size after snapshot: ${historyService.historySize}',
      );
      print('DEBUG: Can undo: ${historyService.canUndo}');
    }

    // Get API key
    final settingsService = SettingsService();
    final apiKey = settingsService.openaiApiKey;

    if (apiKey == null || apiKey.isEmpty) {
      return AiManipulationResult(
        success: false,
        message: 'OpenAI API key not configured. Please set it in Settings.',
      );
    }

    try {
      // Build messages for API call
      final messages = <Map<String, dynamic>>[
        {'role': 'system', 'content': _getSystemPrompt(flow)},
        ...conversationHistory.map((m) => m.toJson()),
        {'role': 'user', 'content': userMessage},
      ];

      // Make API call
      final response = await http.post(
        Uri.parse(_openaiApiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-4o-mini',
          'messages': messages,
          'tools': _tools,
          'tool_choice': 'auto',
        }),
      );

      if (response.statusCode != 200) {
        final errorData = jsonDecode(response.body);
        return AiManipulationResult(
          success: false,
          message:
              'API error: ${errorData['error']?['message'] ?? response.statusCode}',
        );
      }

      final data = jsonDecode(response.body);
      final choice = data['choices']?[0];
      final message = choice?['message'];

      if (message == null) {
        return AiManipulationResult(
          success: false,
          message: 'Invalid response from AI.',
        );
      }

      // Check if there are tool calls
      final toolCalls = message['tool_calls'] as List<dynamic>?;

      if (toolCalls != null && toolCalls.isNotEmpty) {
        print('DEBUG: Tool calls found: ${toolCalls.length}');
        // Execute tool calls
        final actions = <String>[];
        final toolResults = <Map<String, dynamic>>[];

        for (final toolCall in toolCalls) {
          final functionName = toolCall['function']['name'];
          print('DEBUG: Executing tool call: $functionName');
          final arguments = jsonDecode(toolCall['function']['arguments']);

          final result = await _executeToolCall(
            functionName,
            arguments,
            flowNotifier,
          );

          actions.add(result['action'] as String);
          toolResults.add({
            'tool_call_id': toolCall['id'],
            'role': 'tool',
            'content': result['result'] as String,
          });
        }

        // Get final response after tool execution
        final finalMessages = <Map<String, dynamic>>[
          {'role': 'system', 'content': _getSystemPrompt(flowNotifier.flow!)},
          ...conversationHistory.map((m) => m.toJson()),
          {'role': 'user', 'content': userMessage},
          message,
          ...toolResults,
        ];

        final finalResponse = await http.post(
          Uri.parse(_openaiApiUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $apiKey',
          },
          body: jsonEncode({'model': 'gpt-4o-mini', 'messages': finalMessages}),
        );

        if (finalResponse.statusCode == 200) {
          final finalData = jsonDecode(finalResponse.body);
          final finalContent =
              finalData['choices']?[0]?['message']?['content'] ??
              'Changes applied successfully.';

          // Save the flow after changes
          await flowNotifier.saveFlow();

          print(
            'DEBUG: Changes applied successfully, returning changesApplied: true',
          );
          return AiManipulationResult(
            success: true,
            message: finalContent,
            actions: actions,
            changesApplied: true,
          );
        }
      }

      // No tool calls, just return the message
      print('DEBUG: No tool calls found, returning changesApplied: false');
      final content =
          message['content'] ??
          'I understand. How can I help you modify this flow?';
      return AiManipulationResult(
        success: true,
        message: content,
        changesApplied: false,
      );
    } catch (e) {
      if (kDebugMode) {
        print('AI Manipulation error: $e');
      }
      return AiManipulationResult(
        success: false,
        message: 'Error: ${e.toString()}',
      );
    }
  }

  /// Execute a tool call and return the result
  static Future<Map<String, String>> _executeToolCall(
    String functionName,
    Map<String, dynamic> arguments,
    FlowNotifier flowNotifier,
  ) async {
    final flow = flowNotifier.flow!;

    switch (functionName) {
      case 'add_section':
        final title = arguments['title'] as String;
        final section = await flowNotifier.addFlowSection(title: title);
        if (section != null) {
          return {
            'action': 'Added section "$title"',
            'result': 'Successfully added section "$title"',
          };
        }
        return {
          'action': 'Failed to add section',
          'result': 'Failed to add section "$title"',
        };

      case 'add_step':
        final description = arguments['description'] as String;
        final sectionName = arguments['section_name'] as String?;

        String? sectionId;
        if (sectionName != null) {
          // Find section by name
          final section = flow.flowSections.firstWhere(
            (s) => s.title.toLowerCase() == sectionName.toLowerCase(),
            orElse: () => flow.flowSections.first,
          );
          sectionId = section.id;
        } else {
          // Use first section
          sectionId = flow.flowSections.first.id;
        }

        final step = await flowNotifier.addFlowStep(
          flowSectionId: sectionId,
          description: description,
        );

        if (step != null) {
          return {
            'action': 'Added step "$description"',
            'result': 'Successfully added step "$description"',
          };
        }
        return {
          'action': 'Failed to add step',
          'result': 'Failed to add step "$description"',
        };

      case 'add_section_with_steps':
        final sectionTitle = arguments['section_title'] as String;
        final steps = (arguments['steps'] as List).cast<String>();

        final section = await flowNotifier.addFlowSection(title: sectionTitle);
        if (section == null) {
          return {
            'action': 'Failed to add section',
            'result': 'Failed to add section "$sectionTitle"',
          };
        }

        final addedSteps = <String>[];
        for (final stepDesc in steps) {
          final step = await flowNotifier.addFlowStep(
            flowSectionId: section.id,
            description: stepDesc,
          );
          if (step != null) {
            addedSteps.add(stepDesc);
          }
        }

        return {
          'action':
              'Added section "$sectionTitle" with ${addedSteps.length} steps',
          'result':
              'Successfully added section "$sectionTitle" with steps: ${addedSteps.join(", ")}',
        };

      case 'update_section_title':
        final oldTitle = arguments['old_title'] as String;
        final newTitle = arguments['new_title'] as String;

        final section = flow.flowSections.firstWhere(
          (s) => s.title.toLowerCase() == oldTitle.toLowerCase(),
          orElse: () => FlowSection(title: ''),
        );

        if (section.title.isEmpty) {
          return {
            'action': 'Section not found',
            'result': 'Could not find section "$oldTitle"',
          };
        }

        final success = await flowNotifier.updateFlowSection(
          section.id,
          title: newTitle,
        );

        if (success) {
          return {
            'action': 'Renamed section "$oldTitle" to "$newTitle"',
            'result':
                'Successfully renamed section from "$oldTitle" to "$newTitle"',
          };
        }
        return {
          'action': 'Failed to update section',
          'result': 'Failed to update section title',
        };

      case 'delete_section':
        final sectionName = arguments['section_name'] as String;

        final section = flow.flowSections.firstWhere(
          (s) => s.title.toLowerCase() == sectionName.toLowerCase(),
          orElse: () => FlowSection(title: ''),
        );

        if (section.title.isEmpty) {
          return {
            'action': 'Section not found',
            'result': 'Could not find section "$sectionName"',
          };
        }

        final success = await flowNotifier.deleteFlowSection(section.id);

        if (success) {
          return {
            'action': 'Deleted section "$sectionName"',
            'result':
                'Successfully deleted section "$sectionName" and all its steps',
          };
        }
        return {
          'action': 'Failed to delete section',
          'result': 'Failed to delete section "$sectionName"',
        };

      case 'delete_step':
        final stepDescription = arguments['step_description'] as String;
        final sectionName = arguments['section_name'] as String?;

        FlowStep? stepToDelete;

        if (sectionName != null) {
          final section = flow.flowSections.firstWhere(
            (s) => s.title.toLowerCase() == sectionName.toLowerCase(),
            orElse: () => FlowSection(title: ''),
          );

          if (section.title.isNotEmpty) {
            stepToDelete = flow.flowSteps.firstWhere(
              (s) =>
                  s.flowSectionId == section.id &&
                  s.description.toLowerCase().contains(
                    stepDescription.toLowerCase(),
                  ),
              orElse: () => FlowStep(flowSectionId: ''),
            );
          }
        } else {
          stepToDelete = flow.flowSteps.firstWhere(
            (s) => s.description.toLowerCase().contains(
              stepDescription.toLowerCase(),
            ),
            orElse: () => FlowStep(flowSectionId: ''),
          );
        }

        if (stepToDelete == null || stepToDelete.flowSectionId.isEmpty) {
          return {
            'action': 'Step not found',
            'result': 'Could not find step matching "$stepDescription"',
          };
        }

        final success = await flowNotifier.deleteFlowStep(stepToDelete.id);

        if (success) {
          return {
            'action': 'Deleted step "$stepDescription"',
            'result': 'Successfully deleted step',
          };
        }
        return {
          'action': 'Failed to delete step',
          'result': 'Failed to delete step',
        };

      case 'update_flow_title':
        final title = arguments['title'] as String;
        await flowNotifier.updateFlowMetadata(title: title);
        return {
          'action': 'Updated flow title to "$title"',
          'result': 'Successfully updated flow title to "$title"',
        };

      case 'update_flow_description':
        final description = arguments['description'] as String;
        await flowNotifier.updateFlowMetadata(description: description);
        return {
          'action': 'Updated flow description',
          'result': 'Successfully updated flow description',
        };

      case 'update_flow_language':
        final language = arguments['language'] as String;
        await flowNotifier.updateFlowMetadata(language: language);
        return {
          'action': 'Updated flow language to "$language"',
          'result': 'Successfully updated flow language to "$language"',
        };

      case 'update_flow_category':
        final category = arguments['category'] as String;
        await flowNotifier.updateFlowMetadata(category: category);
        return {
          'action': 'Updated flow category to "$category"',
          'result': 'Successfully updated flow category to "$category"',
        };

      case 'update_step_description':
        final stepIdentifier = arguments['step_identifier'] as String;
        final newDescription = arguments['new_description'] as String;
        final sectionName = arguments['section_name'] as String?;

        FlowStep? stepToUpdate;

        if (sectionName != null) {
          // Find section by name
          final section = flow.flowSections.firstWhere(
            (s) => s.title.toLowerCase() == sectionName.toLowerCase(),
            orElse: () => FlowSection(title: ''),
          );

          if (section.title.isNotEmpty) {
            // Find step in that section
            stepToUpdate = flow.flowSteps.firstWhere(
              (s) =>
                  s.flowSectionId == section.id &&
                  s.description.toLowerCase().contains(
                    stepIdentifier.toLowerCase(),
                  ),
              orElse: () => FlowStep(flowSectionId: ''),
            );
          }
        } else {
          // Search all steps
          stepToUpdate = flow.flowSteps.firstWhere(
            (s) => s.description.toLowerCase().contains(
              stepIdentifier.toLowerCase(),
            ),
            orElse: () => FlowStep(flowSectionId: ''),
          );
        }

        if (stepToUpdate == null || stepToUpdate.flowSectionId.isEmpty) {
          return {
            'action': 'Step not found',
            'result':
                'Could not find step matching "$stepIdentifier"${sectionName != null ? ' in section "$sectionName"' : ''}',
          };
        }

        // Delete TTS audio if description is changing and audio exists
        if (stepToUpdate.hasAudioAsset) {
          final audioAsset = stepToUpdate.audioAsset!;
          final isTtsAudio =
              audioAsset.path.contains('step_tts_') ||
              (audioAsset.displayName?.contains('step_tts_') ?? false);

          if (isTtsAudio) {
            try {
              final storageService = FlowStorageService();
              await storageService.deleteAsset(flow.id, audioAsset.path);
              stepToUpdate.removeAudioAsset();
              if (kDebugMode) {
                print(
                  'Deleted TTS audio due to AI description change: ${audioAsset.path}',
                );
              }
            } catch (e) {
              if (kDebugMode) {
                print('Warning: Failed to delete TTS audio: $e');
              }
            }
          }
        }

        final success = await flowNotifier.updateFlowStep(
          flowStepId: stepToUpdate.id,
          description: newDescription,
        );

        if (success) {
          return {
            'action': 'Updated step description',
            'result':
                'Successfully updated step from "${stepToUpdate.description}" to "$newDescription"',
          };
        }
        return {
          'action': 'Failed to update step',
          'result': 'Failed to update step description',
        };

      case 'update_section_steps':
        final sectionName = arguments['section_name'] as String;
        final stepUpdates = arguments['step_updates'] as List;

        // Find section
        final section = flow.flowSections.firstWhere(
          (s) => s.title.toLowerCase() == sectionName.toLowerCase(),
          orElse: () => FlowSection(title: ''),
        );

        if (section.title.isEmpty) {
          return {
            'action': 'Section not found',
            'result': 'Could not find section "$sectionName"',
          };
        }

        final updatedSteps = <String>[];
        final failedSteps = <String>[];

        for (final update in stepUpdates) {
          final oldDesc = update['old_description'] as String;
          final newDesc = update['new_description'] as String;

          // Find step in section
          final stepToUpdate = flow.flowSteps.firstWhere(
            (s) =>
                s.flowSectionId == section.id &&
                s.description.toLowerCase().contains(oldDesc.toLowerCase()),
            orElse: () => FlowStep(flowSectionId: ''),
          );

          if (stepToUpdate.flowSectionId.isEmpty) {
            failedSteps.add(oldDesc);
            continue;
          }

          // Delete TTS audio if description is changing and audio exists
          if (stepToUpdate.hasAudioAsset) {
            final audioAsset = stepToUpdate.audioAsset!;
            final isTtsAudio =
                audioAsset.path.contains('step_tts_') ||
                (audioAsset.displayName?.contains('step_tts_') ?? false);

            if (isTtsAudio) {
              try {
                final storageService = FlowStorageService();
                await storageService.deleteAsset(flow.id, audioAsset.path);
                stepToUpdate.removeAudioAsset();
                if (kDebugMode) {
                  print(
                    'Deleted TTS audio due to AI batch update: ${audioAsset.path}',
                  );
                }
              } catch (e) {
                if (kDebugMode) {
                  print('Warning: Failed to delete TTS audio: $e');
                }
              }
            }
          }

          final success = await flowNotifier.updateFlowStep(
            flowStepId: stepToUpdate.id,
            description: newDesc,
          );

          if (success) {
            updatedSteps.add(oldDesc);
          } else {
            failedSteps.add(oldDesc);
          }
        }

        if (updatedSteps.isEmpty) {
          return {
            'action': 'Failed to update steps',
            'result': 'Failed to update any steps in section "$sectionName"',
          };
        }

        return {
          'action':
              'Updated ${updatedSteps.length} step(s) in section "$sectionName"',
          'result':
              'Successfully updated ${updatedSteps.length} step(s)${failedSteps.isNotEmpty ? '. Failed: ${failedSteps.length}' : ''}',
        };

      case 'set_step_timer':
        final stepDescription = arguments['step_description'] as String;
        final timerMinutes = arguments['timer_minutes'] as int;

        // Find step by description
        final step = flow.flowSteps.firstWhere(
          (s) => s.description.toLowerCase() == stepDescription.toLowerCase(),
          orElse: () => FlowStep(flowSectionId: ''),
        );

        if (step.flowSectionId.isEmpty) {
          return {
            'action': 'Step not found',
            'result': 'Could not find step with description "$stepDescription"',
          };
        }

        final success = await flowNotifier.updateFlowStep(
          flowStepId: step.id,
          timerDurationMinutes: timerMinutes,
        );

        if (success) {
          if (timerMinutes == 0) {
            return {
              'action': 'Removed timer from step "$stepDescription"',
              'result':
                  'Successfully removed timer from step "$stepDescription"',
            };
          } else {
            return {
              'action':
                  'Set timer on step "$stepDescription" to $timerMinutes minutes',
              'result':
                  'Successfully set timer on step "$stepDescription" to $timerMinutes minutes',
            };
          }
        }
        return {
          'action': 'Failed to set timer',
          'result': 'Failed to set timer on step "$stepDescription"',
        };

      case 'set_step_type_to_check':
        final stepDescription = arguments['step_description'] as String;

        // Find step by description
        final step = flow.flowSteps.firstWhere(
          (s) => s.description.toLowerCase() == stepDescription.toLowerCase(),
          orElse: () => FlowStep(flowSectionId: ''),
        );

        if (step.flowSectionId.isEmpty) {
          return {
            'action': 'Step not found',
            'result': 'Could not find step with description "$stepDescription"',
          };
        }

        final success = await flowNotifier.updateFlowStep(
          flowStepId: step.id,
          type: 'check',
        );

        if (success) {
          return {
            'action': 'Changed step "$stepDescription" to check type',
            'result':
                'Successfully changed step "$stepDescription" to check type with OK/NOK buttons',
          };
        }
        return {
          'action': 'Failed to change step type',
          'result': 'Failed to change step "$stepDescription" to check type',
        };

      case 'set_check_branching':
        final stepDescription = arguments['step_description'] as String;
        final okTargetDescription =
            arguments['ok_target_description'] as String?;
        final nokTargetDescription =
            arguments['nok_target_description'] as String?;

        // Find the check step
        final step = flow.flowSteps.firstWhere(
          (s) => s.description.toLowerCase() == stepDescription.toLowerCase(),
          orElse: () => FlowStep(flowSectionId: ''),
        );

        if (step.flowSectionId.isEmpty) {
          return {
            'action': 'Step not found',
            'result': 'Could not find step with description "$stepDescription"',
          };
        }

        // Find OK target step if provided
        String? okBranchStepId;
        if (okTargetDescription != null && okTargetDescription.isNotEmpty) {
          final okTargetStep = flow.flowSteps.firstWhere(
            (s) =>
                s.description.toLowerCase() ==
                okTargetDescription.toLowerCase(),
            orElse: () => FlowStep(flowSectionId: ''),
          );
          if (okTargetStep.flowSectionId.isNotEmpty) {
            okBranchStepId = okTargetStep.id;
          }
        }

        // Find NOK target step if provided
        String? nokBranchStepId;
        if (nokTargetDescription != null && nokTargetDescription.isNotEmpty) {
          final nokTargetStep = flow.flowSteps.firstWhere(
            (s) =>
                s.description.toLowerCase() ==
                nokTargetDescription.toLowerCase(),
            orElse: () => FlowStep(flowSectionId: ''),
          );
          if (nokTargetStep.flowSectionId.isNotEmpty) {
            nokBranchStepId = nokTargetStep.id;
          }
        }

        final success = await flowNotifier.updateFlowStep(
          flowStepId: step.id,
          okBranchStepId: okBranchStepId ?? '',
          nokBranchStepId: nokBranchStepId ?? '',
        );

        if (success) {
          final okInfo =
              okTargetDescription != null && okTargetDescription.isNotEmpty
                  ? 'OK -> "$okTargetDescription"'
                  : 'OK -> next step';
          final nokInfo =
              nokTargetDescription != null && nokTargetDescription.isNotEmpty
                  ? 'NOK -> "$nokTargetDescription"'
                  : 'NOK -> next step';
          return {
            'action': 'Set branching for step "$stepDescription"',
            'result':
                'Successfully set branching for step "$stepDescription": $okInfo, $nokInfo',
          };
        }
        return {
          'action': 'Failed to set branching',
          'result': 'Failed to set branching for step "$stepDescription"',
        };

      case 'get_flow_structure':
        return {
          'action': 'Retrieved flow structure',
          'result': _getFlowStructureText(flow),
        };

      default:
        return {
          'action': 'Unknown function',
          'result': 'Unknown function: $functionName',
        };
    }
  }
}
