import 'package:flutter/foundation.dart';
import 'flow_ai_manipulation_service.dart';
import 'flow_history_service.dart';

/// Manages AI chat state and history for a flow editing session
class FlowAiStateService extends ChangeNotifier {
  final String flowId;
  final List<AiChatMessage> _conversationHistory = [];
  final FlowHistoryService _historyService = FlowHistoryService();
  bool _hasPendingChanges = false;

  FlowAiStateService({required this.flowId});

  /// Get the conversation history
  List<AiChatMessage> get conversationHistory => _conversationHistory;

  /// Get the history service
  FlowHistoryService get historyService => _historyService;

  /// Check if there are pending changes to keep/revert
  bool get hasPendingChanges => _hasPendingChanges;

  /// Mark that there are pending AI changes
  void setPendingChanges(bool value) {
    _hasPendingChanges = value;
    notifyListeners();
  }

  /// Add a message to conversation history
  void addMessage(AiChatMessage message) {
    _conversationHistory.add(message);
    notifyListeners();
  }

  /// Clear conversation history and snapshots
  void clear() {
    _conversationHistory.clear();
    _historyService.clear();
    _hasPendingChanges = false;
    notifyListeners();
  }

  /// Keep the current changes
  void keepChanges() {
    _hasPendingChanges = false;
    notifyListeners();
  }

  /// Check if undo is available
  bool get canUndo => _historyService.canUndo;

  /// Get description of what would be undone
  String? get undoDescription => _historyService.previousSnapshotDescription;
}
