import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

/// Service for handling timer completion audio in the example app
class TimerAudioService {
  static final AudioPlayer _audioPlayer = AudioPlayer();

  /// Plays the timer completion sound from the app's assets
  static Future<void> playTimerCompletionSound() async {
    print('🔔 Timer completed - playing completion sound from app assets');

    try {
      // Set volume to maximum
      await _audioPlayer.setVolume(1.0);

      // Play the audio from the app's assets (not the package)
      print(
        '🎵 Playing timer completion sound from assets/audio/timer_done.mp3',
      );
      await _audioPlayer.play(AssetSource('audio/timer_done.mp3'));
      print('✅ Timer completion sound played successfully');
    } catch (e) {
      print('❌ Failed to play timer completion sound: $e');
      // Fallback to haptic feedback if audio fails
      print('🤝 Using haptic feedback as fallback');
      HapticFeedback.heavyImpact();
    }
  }

  /// Disposes the audio player - call when app is shutting down
  static void dispose() {
    _audioPlayer.dispose();
  }
}
