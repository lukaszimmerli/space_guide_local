import 'package:flow_manager_saas/flow_manager.dart';
import 'settings_service.dart';

/// Adapter to make the existing SettingsService compatible with FlowPlayerSettings
/// This allows the example app to use its existing SettingsService with the reusable FlowPlayerScreen
class SettingsServiceAdapter extends FlowPlayerSettings {
  final SettingsService _settingsService;

  SettingsServiceAdapter(this._settingsService) {
    // Listen to changes in the original settings service and forward them
    _settingsService.addListener(notifyListeners);
  }

  @override
  void dispose() {
    _settingsService.removeListener(notifyListeners);
    super.dispose();
  }

  @override
  bool get autoReadEnabled => _settingsService.autoReadEnabled;

  @override
  bool get showStatistics => _settingsService.showStatistics;

  @override
  bool get showLanguageFlag => _settingsService.showLanguageFlag;

  @override
  Future<void> loadSettings() => _settingsService.loadSettings();

  @override
  Future<void> setAutoReadEnabled(bool value) =>
      _settingsService.setAutoReadEnabled(value);

  @override
  Future<void> setShowStatistics(bool value) =>
      _settingsService.setShowStatistics(value);

  @override
  Future<void> setShowLanguageFlag(bool value) =>
      _settingsService.setShowLanguageFlag(value);
}
