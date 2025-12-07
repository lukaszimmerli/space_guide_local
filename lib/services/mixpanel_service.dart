import 'package:flutter/foundation.dart';
import 'package:mixpanel_flutter/mixpanel_flutter.dart';
import 'package:flow_manager_saas/flow_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../config/env_config.dart';

class MixpanelService {
  static Mixpanel? _mixpanel;
  static bool _isInitialized = false;

  static bool get isInitialized => _isInitialized;

  static Future<void> initialize() async {
    final token = EnvConfig.mixpanelToken;

    print(
      '🔍 Mixpanel token from env: ${token.isEmpty ? "EMPTY" : token.substring(0, 8)}...',
    );

    if (token.isEmpty || token == 'YOUR_MIXPANEL_TOKEN_HERE') {
      print(
        '🔴 Mixpanel: Token not configured in .env file. Analytics disabled.',
      );
      return;
    }

    print('🔵 Mixpanel: Initializing with token: ${token.substring(0, 8)}...');

    try {
      _mixpanel = await Mixpanel.init(
        token,
        trackAutomaticEvents: true,
        optOutTrackingDefault: false,
      );

      // Set to EU server if your project uses EU data residency
      _mixpanel?.setServerURL('https://api-eu.mixpanel.com');

      _isInitialized = true;
      print('✅ Mixpanel: Successfully initialized!');
      print('✅ Mixpanel instance: ${_mixpanel != null}');

      // Get or create a persistent user ID
      final prefs = await SharedPreferences.getInstance();
      String? distinctId = prefs.getString('mixpanel_distinct_id');

      if (distinctId == null) {
        // First time user - generate a new UUID and persist it
        const uuid = Uuid();
        distinctId = uuid.v4();
        await prefs.setString('mixpanel_distinct_id', distinctId);
        print('👤 Mixpanel: Created new Distinct ID: $distinctId');
      } else {
        print('👤 Mixpanel: Using existing Distinct ID: $distinctId');
      }

      // Create a short readable name from the first 4 chars of the UUID
      final shortId = distinctId.substring(0, 4).toUpperCase();
      final userName = 'User #$shortId';

      // Identify the user with our persisted ID
      await _mixpanel?.identify(distinctId);
      print('👤 Mixpanel: User identified as: $userName');

      // Set initial user properties
      _mixpanel?.getPeople().set('\$name', userName);
      _mixpanel?.getPeople().set('app_version', '1.0.0');
      _mixpanel?.getPeople().set('platform', 'flutter');
      _mixpanel?.getPeople().setOnce(
        'first_seen',
        DateTime.now().toIso8601String(),
      );
      _mixpanel?.getPeople().set('last_seen', DateTime.now().toIso8601String());
      print('👤 Mixpanel: User properties set');

      // Send a test event to verify connection
      _mixpanel?.track(
        'App Launched',
        properties: {
          'timestamp': DateTime.now().toIso8601String(),
          'platform': 'flutter',
        },
      );
      print('📊 Mixpanel: Test event "App Launched" sent');

      // Flush immediately to ensure events are sent
      _mixpanel?.flush();
      print('🔄 Mixpanel: Initial flush completed');
    } catch (e, stackTrace) {
      print('🔴 Mixpanel: Failed to initialize: $e');
      print('🔴 Stack trace: $stackTrace');
      _isInitialized = false;
    }
  }

  // Guide Creation Events
  static void trackGuideCreated({
    required String guideId,
    required String category,
    required String language,
    required int numberOfSections,
    required int numberOfSteps,
  }) {
    if (!_isInitialized || _mixpanel == null) {
      debugPrint('⚠️ Mixpanel: Cannot track "Guide Created" - not initialized');
      return;
    }

    final properties = {
      'guide_id': guideId,
      'category': category,
      'language': language,
      'number_of_sections': numberOfSections,
      'number_of_steps': numberOfSteps,
      'timestamp': DateTime.now().toIso8601String(),
    };

    debugPrint('📊 Mixpanel: Tracking "Guide Created" - $properties');
    _mixpanel?.track('Guide Created', properties: properties);
  }

  // Guide Viewing/Playback Events
  static void trackGuideViewed({
    required String guideId,
    required String category,
    required String language,
    required int numberOfSteps,
    required int numberOfSections,
  }) {
    print(
      '🔍 trackGuideViewed called - initialized: $_isInitialized, mixpanel: ${_mixpanel != null}',
    );

    if (!_isInitialized || _mixpanel == null) {
      print('⚠️ Mixpanel: Cannot track "Guide Viewed" - not initialized');
      return;
    }

    final properties = {
      'guide_id': guideId,
      'category': category,
      'language': language,
      'number_of_steps': numberOfSteps,
      'number_of_sections': numberOfSections,
      'timestamp': DateTime.now().toIso8601String(),
    };

    print('📊 Mixpanel: Tracking "Guide Viewed" - $properties');
    _mixpanel?.track('Guide Viewed', properties: properties);
  }

  static void trackGuidePlayed({
    required String guideId,
    required String category,
    required String language,
    required int totalSteps,
    required double averageStepLength,
    required int numberOfSections,
  }) {
    print(
      '🔍 trackGuidePlayed called - initialized: $_isInitialized, mixpanel: ${_mixpanel != null}',
    );

    if (!_isInitialized || _mixpanel == null) {
      print('⚠️ Mixpanel: Cannot track "Guide Played" - not initialized');
      return;
    }

    final properties = {
      'guide_id': guideId,
      'category': category,
      'language': language,
      'total_steps': totalSteps,
      'average_step_length': averageStepLength,
      'number_of_sections': numberOfSections,
      'timestamp': DateTime.now().toIso8601String(),
    };

    print('📊 Mixpanel: Tracking "Guide Played" - $properties');
    _mixpanel?.track('Guide Played', properties: properties);
  }

  // AI Feature Events
  static void trackAiFeaturesToggled({required bool enabled}) {
    _mixpanel?.track(
      'AI Features Toggled',
      properties: {
        'enabled': enabled,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  static void trackAiChatUsed({
    required String guideId,
    required String messageType,
    required int conversationLength,
  }) {
    _mixpanel?.track(
      'AI Chat Used',
      properties: {
        'guide_id': guideId,
        'message_type': messageType,
        'conversation_length': conversationLength,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  static void trackAiChatAction({
    required String guideId,
    required String action,
    required bool accepted,
  }) {
    _mixpanel?.track(
      'AI Chat Action',
      properties: {
        'guide_id': guideId,
        'action': action,
        'accepted': accepted,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  static void trackTranslationUsed({
    required String guideId,
    required String fromLanguage,
    required String toLanguage,
    required int numberOfSteps,
    required bool success,
  }) {
    _mixpanel?.track(
      'Translation Used',
      properties: {
        'guide_id': guideId,
        'from_language': fromLanguage,
        'to_language': toLanguage,
        'number_of_steps': numberOfSteps,
        'success': success,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  static void trackTtsGenerated({
    required String guideId,
    required int numberOfSteps,
    required String voice,
    required bool success,
  }) {
    _mixpanel?.track(
      'TTS Generated',
      properties: {
        'guide_id': guideId,
        'number_of_steps': numberOfSteps,
        'voice': voice,
        'success': success,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  static void trackTextImprovement({
    required String guideId,
    required String improvementType,
    required int textLength,
  }) {
    _mixpanel?.track(
      'Text Improvement Used',
      properties: {
        'guide_id': guideId,
        'improvement_type': improvementType,
        'text_length': textLength,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  // Guide Metadata Analytics
  static void trackGuideMetrics(FlowData flow) {
    print(
      '🔍 trackGuideMetrics called - initialized: $_isInitialized, mixpanel: ${_mixpanel != null}',
    );

    if (!_isInitialized || _mixpanel == null) {
      print('⚠️ Mixpanel: Cannot track "Guide Metrics" - not initialized');
      return;
    }

    final averageStepLength = _calculateAverageStepLength(flow);
    final averageSectionSize = _calculateAverageSectionSize(flow);

    final properties = {
      'guide_id': flow.id,
      'category': flow.category,
      'language': flow.language,
      'state': flow.state.toString(),
      'number_of_sections': flow.flowSections.length,
      'number_of_steps': flow.flowSteps.length,
      'average_step_length': averageStepLength,
      'average_section_size': averageSectionSize,
      'has_audio': flow.flowSteps.any((step) => step.audioAsset != null),
      'has_timer': flow.flowSteps.any((step) => step.timerDurationMinutes > 0),
      'has_media': flow.flowSteps.any((step) => step.assets.isNotEmpty),
      'timestamp': DateTime.now().toIso8601String(),
    };

    print('📊 Mixpanel: Tracking "Guide Metrics" - $properties');
    _mixpanel?.track('Guide Metrics', properties: properties);
  }

  // Helper Methods
  static double _calculateAverageStepLength(FlowData flow) {
    if (flow.flowSteps.isEmpty) return 0.0;

    final totalLength = flow.flowSteps.fold<int>(
      0,
      (sum, step) => sum + step.description.length,
    );

    return totalLength / flow.flowSteps.length;
  }

  static double _calculateAverageSectionSize(FlowData flow) {
    if (flow.flowSections.isEmpty) return 0.0;
    return flow.flowSteps.length / flow.flowSections.length;
  }

  // User Properties
  static void setUserProperty(String property, dynamic value) {
    _mixpanel?.getPeople().set(property, value);
  }

  // Increment counters
  static void incrementGuideCount() {
    _mixpanel?.getPeople().increment('total_guides_created', 1);
  }

  static void incrementGuidePlayCount() {
    _mixpanel?.getPeople().increment('total_guides_played', 1);
  }

  // Guide Lifecycle Events
  static void trackGuideEdited({
    required String guideId,
    required String category,
    required String language,
    required int numberOfSections,
    required int numberOfSteps,
  }) {
    _mixpanel?.track(
      'Guide Edited',
      properties: {
        'guide_id': guideId,
        'category': category,
        'language': language,
        'number_of_sections': numberOfSections,
        'number_of_steps': numberOfSteps,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  static void trackGuideDuplicated({
    required String originalGuideId,
    required String newGuideId,
    required String category,
    required String language,
  }) {
    _mixpanel?.track(
      'Guide Duplicated',
      properties: {
        'original_guide_id': originalGuideId,
        'new_guide_id': newGuideId,
        'category': category,
        'language': language,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
    _mixpanel?.getPeople().increment('total_guides_duplicated', 1);
  }

  static void trackGuideDeleted({
    required String guideId,
    required String category,
    required String language,
    required int numberOfSteps,
  }) {
    _mixpanel?.track(
      'Guide Deleted',
      properties: {
        'guide_id': guideId,
        'category': category,
        'language': language,
        'number_of_steps': numberOfSteps,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
    _mixpanel?.getPeople().increment('total_guides_deleted', 1);
  }

  static void trackGuideExported({
    required String guideId,
    required String exportType, // 'file', 'share'
    required String category,
    required String language,
  }) {
    _mixpanel?.track(
      'Guide Exported',
      properties: {
        'guide_id': guideId,
        'export_type': exportType,
        'category': category,
        'language': language,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
    _mixpanel?.getPeople().increment('total_guides_exported', 1);
  }

  static void trackGuideImported({
    required String guideId,
    required String importSource, // 'qr_code', 'file'
    required String category,
    required String language,
    required int numberOfSteps,
  }) {
    _mixpanel?.track(
      'Guide Imported',
      properties: {
        'guide_id': guideId,
        'import_source': importSource,
        'category': category,
        'language': language,
        'number_of_steps': numberOfSteps,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
    _mixpanel?.getPeople().increment('total_guides_imported', 1);
  }

  static void trackGuideShared({
    required String guideId,
    required String category,
    required String language,
    required int numberOfSteps,
  }) {
    _mixpanel?.track(
      'Guide Shared',
      properties: {
        'guide_id': guideId,
        'category': category,
        'language': language,
        'number_of_steps': numberOfSteps,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
    _mixpanel?.getPeople().increment('total_guides_shared', 1);
  }

  // Section Events
  static void trackSectionAdded({
    required String guideId,
    required String sectionId,
    required String sectionTitle,
    required int sectionOrder,
  }) {
    _mixpanel?.track(
      'Section Added',
      properties: {
        'guide_id': guideId,
        'section_id': sectionId,
        'section_title': sectionTitle,
        'section_order': sectionOrder,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  static void trackSectionDeleted({
    required String guideId,
    required String sectionId,
    required int stepsInSection,
  }) {
    _mixpanel?.track(
      'Section Deleted',
      properties: {
        'guide_id': guideId,
        'section_id': sectionId,
        'steps_in_section': stepsInSection,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  // Step Events
  static void trackStepAdded({
    required String guideId,
    required String sectionId,
    required String stepId,
    required int stepOrder,
    required bool hasMedia,
  }) {
    _mixpanel?.track(
      'Step Added',
      properties: {
        'guide_id': guideId,
        'section_id': sectionId,
        'step_id': stepId,
        'step_order': stepOrder,
        'has_media': hasMedia,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
    _mixpanel?.getPeople().increment('total_steps_created', 1);
  }

  static void trackStepEdited({
    required String guideId,
    required String stepId,
    required bool hasMedia,
    required bool hasAudio,
    required bool hasTimer,
  }) {
    _mixpanel?.track(
      'Step Edited',
      properties: {
        'guide_id': guideId,
        'step_id': stepId,
        'has_media': hasMedia,
        'has_audio': hasAudio,
        'has_timer': hasTimer,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  static void trackStepDeleted({
    required String guideId,
    required String sectionId,
    required String stepId,
  }) {
    _mixpanel?.track(
      'Step Deleted',
      properties: {
        'guide_id': guideId,
        'section_id': sectionId,
        'step_id': stepId,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  // Media Events
  static void trackMediaAdded({
    required String guideId,
    required String stepId,
    required String mediaType, // 'image', 'video', 'audio', 'file'
    required String source, // 'camera', 'gallery', 'file_picker', 'recorded'
  }) {
    _mixpanel?.track(
      'Media Added',
      properties: {
        'guide_id': guideId,
        'step_id': stepId,
        'media_type': mediaType,
        'source': source,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
    _mixpanel?.getPeople().increment('total_media_added', 1);
  }

  // Flush events (useful before app termination)
  static void flush() {
    _mixpanel?.flush();
  }
}
