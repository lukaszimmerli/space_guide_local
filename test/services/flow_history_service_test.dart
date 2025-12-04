import 'package:flutter_test/flutter_test.dart';
import 'package:flow_manager_saas/flow_manager.dart';

void main() {
  group('FlowHistoryService', () {
    late FlowHistoryService historyService;
    late FlowData testFlow;

    setUp(() {
      historyService = FlowHistoryService();
      testFlow = FlowData(
        title: 'Test Flow',
        description: 'Test Description',
        language: 'en',
      );
    });

    test('should add snapshot to history', () {
      historyService.addSnapshot(testFlow, 'Initial state');
      expect(historyService.historySize, 1);
      expect(historyService.currentPosition, 0);
    });

    test('should support undo', () {
      // Add first snapshot
      historyService.addSnapshot(testFlow, 'State 1');

      // Modify and add second snapshot
      final modifiedFlow = testFlow.copy(title: 'Modified Flow');
      historyService.addSnapshot(modifiedFlow, 'State 2');

      expect(historyService.canUndo, true);
      expect(historyService.historySize, 2);

      final previousSnapshot = historyService.undo();
      expect(previousSnapshot, isNotNull);
      expect(previousSnapshot!.flow.title, 'Test Flow');
      expect(historyService.currentPosition, 0);
    });

    test('should support redo', () {
      historyService.addSnapshot(testFlow, 'State 1');
      final modifiedFlow = testFlow.copy(title: 'Modified Flow');
      historyService.addSnapshot(modifiedFlow, 'State 2');

      historyService.undo();
      expect(historyService.canRedo, true);

      final nextSnapshot = historyService.redo();
      expect(nextSnapshot, isNotNull);
      expect(nextSnapshot!.flow.title, 'Modified Flow');
      expect(historyService.currentPosition, 1);
    });

    test('should clear redo history when adding new snapshot', () {
      historyService.addSnapshot(testFlow, 'State 1');
      historyService.addSnapshot(testFlow.copy(title: 'State 2'), 'State 2');
      historyService.addSnapshot(testFlow.copy(title: 'State 3'), 'State 3');

      // Undo twice
      historyService.undo();
      historyService.undo();
      expect(historyService.canRedo, true);

      // Add new snapshot - should clear redo history
      historyService.addSnapshot(
        testFlow.copy(title: 'New State'),
        'New State',
      );
      expect(historyService.canRedo, false);
      expect(historyService.historySize, 2);
    });

    test('should limit history size', () {
      // Add more than max history size
      for (int i = 0; i < 60; i++) {
        historyService.addSnapshot(testFlow.copy(title: 'Flow $i'), 'State $i');
      }

      expect(historyService.historySize, 50); // Max size
    });

    test('should provide snapshot descriptions', () {
      historyService.addSnapshot(testFlow, 'Initial state');
      historyService.addSnapshot(
        testFlow.copy(title: 'Modified'),
        'After modification',
      );

      expect(historyService.lastSnapshotDescription, 'After modification');
      expect(historyService.previousSnapshotDescription, 'Initial state');
      expect(historyService.nextSnapshotDescription, null);
    });

    test('should clear all history', () {
      historyService.addSnapshot(testFlow, 'State 1');
      historyService.addSnapshot(testFlow, 'State 2');

      historyService.clear();

      expect(historyService.historySize, 0);
      expect(historyService.currentPosition, -1);
      expect(historyService.canUndo, false);
      expect(historyService.canRedo, false);
    });
  });
}
