import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'mixpanel_service.dart';

/// Service to manage user settings and preferences
class SettingsService extends ChangeNotifier {
  static const String _autoReadEnabledKey = 'autoReadEnabled';
  static const String _showStatisticsKey = 'showStatistics';
  static const String _showLanguageFlagKey = 'showLanguageFlag';
  static const String _openaiApiKeyKey = 'openai_api_key';
  static const String _themeModeKey = 'themeMode';

  // Secure storage for API key
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  // Default values
  bool _autoReadEnabled = true;
  bool _showStatistics = true;
  bool _showLanguageFlag = false; // Default is hidden as requested
  String? _openaiApiKey;
  String _themeMode = 'dark'; // 'light', 'dark', or 'system'

  // Singleton instance
  static final SettingsService _instance = SettingsService._internal();

  // Private constructor
  SettingsService._internal();

  // Factory constructor to return the same instance
  factory SettingsService() {
    return _instance;
  }

  // Getters
  bool get autoReadEnabled => _autoReadEnabled;
  bool get showStatistics => _showStatistics;
  bool get showLanguageFlag => _showLanguageFlag;
  String? get openaiApiKey => _openaiApiKey;
  bool get isAiFeaturesEnabled =>
      _openaiApiKey != null && _openaiApiKey!.isNotEmpty;
  String get themeMode => _themeMode;

  // Load settings from SharedPreferences
  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _autoReadEnabled = prefs.getBool(_autoReadEnabledKey) ?? true;
    _showStatistics = prefs.getBool(_showStatisticsKey) ?? true;
    _showLanguageFlag = prefs.getBool(_showLanguageFlagKey) ?? false;
    _themeMode = prefs.getString(_themeModeKey) ?? 'dark';

    // Load OpenAI API key from secure storage
    _openaiApiKey = await _secureStorage.read(key: _openaiApiKeyKey);

    notifyListeners();
  }

  // Toggle auto-read setting
  Future<void> toggleAutoReadEnabled() async {
    _autoReadEnabled = !_autoReadEnabled;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoReadEnabledKey, _autoReadEnabled);

    notifyListeners();
  }

  // Toggle show statistics setting
  Future<void> toggleShowStatistics() async {
    _showStatistics = !_showStatistics;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showStatisticsKey, _showStatistics);

    notifyListeners();
  }

  // Toggle show language flag setting
  Future<void> toggleShowLanguageFlag() async {
    _showLanguageFlag = !_showLanguageFlag;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showLanguageFlagKey, _showLanguageFlag);

    notifyListeners();
  }

  // Set auto-read setting directly
  Future<void> setAutoReadEnabled(bool value) async {
    if (_autoReadEnabled == value) return;

    _autoReadEnabled = value;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoReadEnabledKey, _autoReadEnabled);

    notifyListeners();
  }

  // Set show statistics setting directly
  Future<void> setShowStatistics(bool value) async {
    if (_showStatistics == value) return;

    _showStatistics = value;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showStatisticsKey, _showStatistics);

    notifyListeners();
  }

  // Set OpenAI API key
  Future<void> setOpenAiApiKey(String apiKey) async {
    final wasEnabled = isAiFeaturesEnabled;
    _openaiApiKey = apiKey.trim();

    if (_openaiApiKey!.isEmpty) {
      await clearOpenAiApiKey();
      return;
    }

    await _secureStorage.write(key: _openaiApiKeyKey, value: _openaiApiKey);

    // Track AI features toggle if state changed
    final isNowEnabled = isAiFeaturesEnabled;
    if (wasEnabled != isNowEnabled) {
      MixpanelService.trackAiFeaturesToggled(enabled: isNowEnabled);
      MixpanelService.setUserProperty('ai_features_enabled', isNowEnabled);
    }

    notifyListeners();
  }

  // Clear OpenAI API key
  Future<void> clearOpenAiApiKey() async {
    _openaiApiKey = null;
    await _secureStorage.delete(key: _openaiApiKeyKey);

    // Track AI features disabled
    MixpanelService.trackAiFeaturesToggled(enabled: false);
    MixpanelService.setUserProperty('ai_features_enabled', false);

    notifyListeners();
  }

  // Set theme mode
  Future<void> setThemeMode(String mode) async {
    if (_themeMode == mode) return;
    if (!['light', 'dark', 'system'].contains(mode)) return;

    _themeMode = mode;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, _themeMode);

    notifyListeners();
  }
}
