import 'package:flow_manager_saas/flow_manager.dart';

/// Represents a snapshot of a flow at a specific point in time
class FlowSnapshot {
  final FlowData flow;
  final DateTime timestamp;
  final String description;

  FlowSnapshot({
    required this.flow,
    required this.timestamp,
    required this.description,
  });

  /// Create a deep copy of the flow for this snapshot
  factory FlowSnapshot.fromFlow(FlowData flow, String description) {
    return FlowSnapshot(
      flow: flow.copy(),
      timestamp: DateTime.now(),
      description: description,
    );
  }
}

/// Service for managing flow history and undo/redo functionality
class FlowHistoryService {
  final List<FlowSnapshot> _history = [];
  int _currentIndex = -1;
  static const int _maxHistorySize = 50;

  /// Add a new snapshot to the history
  void addSnapshot(FlowData flow, String description) {
    // Remove any redo history if we're not at the end
    if (_currentIndex < _history.length - 1) {
      _history.removeRange(_currentIndex + 1, _history.length);
    }

    // Add new snapshot
    _history.add(FlowSnapshot.fromFlow(flow, description));
    _currentIndex = _history.length - 1;

    // Limit history size
    if (_history.length > _maxHistorySize) {
      _history.removeAt(0);
      _currentIndex--;
    }
  }

  /// Check if undo is available
  bool get canUndo => _currentIndex > 0;

  /// Check if redo is available
  bool get canRedo => _currentIndex < _history.length - 1;

  /// Undo to the previous state
  FlowSnapshot? undo() {
    if (!canUndo) return null;
    _currentIndex--;
    return _history[_currentIndex];
  }

  /// Redo to the next state
  FlowSnapshot? redo() {
    if (!canRedo) return null;
    _currentIndex++;
    return _history[_currentIndex];
  }

  /// Get the current snapshot
  FlowSnapshot? get currentSnapshot {
    if (_currentIndex < 0 || _currentIndex >= _history.length) return null;
    return _history[_currentIndex];
  }

  /// Get the most recent snapshot description
  String? get lastSnapshotDescription {
    if (_currentIndex < 0 || _currentIndex >= _history.length) return null;
    return _history[_currentIndex].description;
  }

  /// Get the previous snapshot description (for undo preview)
  String? get previousSnapshotDescription {
    if (!canUndo) return null;
    return _history[_currentIndex - 1].description;
  }

  /// Get the next snapshot description (for redo preview)
  String? get nextSnapshotDescription {
    if (!canRedo) return null;
    return _history[_currentIndex + 1].description;
  }

  /// Clear all history
  void clear() {
    _history.clear();
    _currentIndex = -1;
  }

  /// Get history size
  int get historySize => _history.length;

  /// Get current position in history
  int get currentPosition => _currentIndex;
}
