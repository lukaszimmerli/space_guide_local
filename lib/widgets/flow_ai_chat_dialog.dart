import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:flow_manager_saas/flow_manager.dart';
import 'package:carbon_icons/carbon_icons.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../services/flow_ai_manipulation_service.dart';
import '../services/flow_ai_state_service.dart';

/// Shows the AI chat as a full-screen modal bottom sheet
void showFlowAiChat(BuildContext context, String flowId) {
  // Get the AI state service from the parent context before opening modal
  final aiStateService = Provider.of<FlowAiStateService>(
    context,
    listen: false,
  );

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder:
        (modalContext) =>
            FlowAiChatSheet(flowId: flowId, aiStateService: aiStateService),
  );
}

/// Full-screen bottom sheet for AI-powered flow manipulation
class FlowAiChatSheet extends StatefulWidget {
  final String flowId;
  final FlowAiStateService aiStateService;

  const FlowAiChatSheet({
    super.key,
    required this.flowId,
    required this.aiStateService,
  });

  @override
  State<FlowAiChatSheet> createState() => _FlowAiChatSheetState();
}

class _FlowAiChatSheetState extends State<FlowAiChatSheet> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final List<_ChatMessage> _messages = [];
  bool _isLoading = false;
  late FlowAiStateService _aiStateService;

  @override
  void initState() {
    super.initState();

    // Use the AI state service passed from parent
    _aiStateService = widget.aiStateService;

    // Restore conversation history if it exists
    if (_aiStateService.conversationHistory.isEmpty) {
      // Add welcome message only if this is a new conversation
      _messages.add(
        _ChatMessage(
          text:
              'Hi! I can help you modify this flow. Try asking me to:\n\n'
              '• Add a new section\n'
              '• Add steps to a section\n'
              '• Rename a section\n'
              '• Update step descriptions\n'
              '• Delete sections or steps\n\n'
              'What would you like to do?',
          isUser: false,
        ),
      );
    } else {
      // Restore previous messages from conversation history
      _restoreMessages();
    }
  }

  void _restoreMessages() {
    // Reconstruct UI messages from conversation history
    for (var i = 0; i < _aiStateService.conversationHistory.length; i += 2) {
      if (i < _aiStateService.conversationHistory.length) {
        // User message
        final userMsg = _aiStateService.conversationHistory[i];
        _messages.add(_ChatMessage(text: userMsg.content, isUser: true));
      }
      if (i + 1 < _aiStateService.conversationHistory.length) {
        // Assistant message
        final assistantMsg = _aiStateService.conversationHistory[i + 1];
        _messages.add(_ChatMessage(text: assistantMsg.content, isUser: false));
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Flow Assistant',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Modify your flow with natural language',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(CarbonIcons.close, size: 30),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Divider(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.1),
          ),
          // Chat messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _messages.length,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemBuilder: (context, index) {
                final message = _messages[index];
                return _buildMessageBubble(message);
              },
            ),
          ),
          // Loading indicator
          if (_isLoading)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Processing your request...',
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.6),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          // Input area
          Container(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 30 + bottomPadding),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      controller: _messageController,
                      focusNode: _focusNode,
                      decoration: InputDecoration(
                        hintText: 'Ask me to modify your flow...',
                        hintStyle: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.4),
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                      ),
                      maxLines: 4,
                      minLines: 1,
                      enabled: !_isLoading,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color:
                        _isLoading
                            ? Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.1)
                            : Colors.blueAccent,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(
                      CarbonIcons.send_alt,
                      color:
                          _isLoading
                              ? Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.3)
                              : Colors.white,
                      size: 20,
                    ),
                    onPressed: _isLoading ? null : _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(_ChatMessage message) {
    final isUser = message.isUser;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: SvgPicture.asset(
                'assets/icon/noun-ai-star-6056248.svg',
                width: 16,
                height: 16,
                colorFilter: ColorFilter.mode(
                  Theme.of(context).colorScheme.onSurface,
                  BlendMode.srcIn,
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color:
                    isUser
                        ? Colors.blueAccent
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft:
                      isUser
                          ? const Radius.circular(16)
                          : const Radius.circular(4),
                  bottomRight:
                      isUser
                          ? const Radius.circular(4)
                          : const Radius.circular(16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Use Markdown for assistant messages, plain Text for user messages
                  if (isUser)
                    Text(
                      message.text,
                      style: const TextStyle(color: Colors.white, height: 1.4),
                    )
                  else
                    MarkdownBody(
                      data: message.text,
                      styleSheet: MarkdownStyleSheet(
                        p: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          height: 1.4,
                        ),
                        h1: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        h2: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        h3: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        code: TextStyle(
                          backgroundColor:
                              Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                          color: Theme.of(context).colorScheme.onSurface,
                          fontFamily: 'monospace',
                        ),
                        codeblockDecoration: BoxDecoration(
                          color:
                              Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        listBullet: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        strong: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                        em: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  if (message.actions != null &&
                      message.actions!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surface.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Actions completed:',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                          const SizedBox(height: 6),
                          ...message.actions!.map(
                            (action) => Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Row(
                                children: [
                                  Icon(
                                    CarbonIcons.checkmark_filled,
                                    size: 14,
                                    color: Colors.green[400],
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      action,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.8),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          // if (isUser) ...[
          //   // const SizedBox(width: 10),
          //   // CircleAvatar(
          //   //   radius: 16,
          //   //   backgroundColor: Theme.of(context).colorScheme.secondary,
          //   //   child: const Icon(
          //   //     CarbonIcons.user,
          //   //     size: 16,
          //   //     color: Colors.white,
          //   //   ),
          //   // ),
          // ],
        ],
      ),
    );
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    // Add user message
    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: true));
      _isLoading = true;
    });
    _messageController.clear();
    _scrollToBottom();

    // Get flow notifier
    final flowNotifier = Provider.of<FlowNotifier>(context, listen: false);

    // Process message
    final result = await FlowAiManipulationService.processMessage(
      userMessage: text,
      flowNotifier: flowNotifier,
      conversationHistory: _aiStateService.conversationHistory,
      historyService: _aiStateService.historyService,
    );

    // Update conversation history in state service
    _aiStateService.addMessage(AiChatMessage(role: 'user', content: text));
    _aiStateService.addMessage(
      AiChatMessage(role: 'assistant', content: result.message),
    );

    // Mark pending changes if AI made modifications
    print('DEBUG: AI result - changesApplied: ${result.changesApplied}');
    if (result.changesApplied) {
      print('DEBUG: Setting pending changes to true');
      _aiStateService.setPendingChanges(true);
    } else {
      print('DEBUG: No changes applied by AI');
    }

    // Add AI response
    setState(() {
      _messages.add(
        _ChatMessage(
          text: result.message,
          isUser: false,
          actions: result.actions.isNotEmpty ? result.actions : null,
        ),
      );
      _isLoading = false;
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }
}

class _ChatMessage {
  final String text;
  final bool isUser;
  final List<String>? actions;

  _ChatMessage({required this.text, required this.isUser, this.actions});
}
