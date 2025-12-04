import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

enum VideoQuality { low, medium, high, defaultQuality }

class EnvConfig {
  static bool _isInitialized = false;
  static int _imageQuality = 70;
  static int _maxImageWidth = 1920;
  static int _maxImageHeight = 1080;
  static VideoQuality _videoQuality = VideoQuality.medium;
  static int _maxVideoWidth = 1280;
  static int _maxVideoHeight = 720;
  static int _maxVideoDuration = 120;

  static bool get isInitialized => _isInitialized;
  static int get imageQuality => _imageQuality;
  static int get maxImageWidth => _maxImageWidth;
  static int get maxImageHeight => _maxImageHeight;
  static VideoQuality get videoQuality => _videoQuality;
  static int get maxVideoWidth => _maxVideoWidth;
  static int get maxVideoHeight => _maxVideoHeight;
  static int get maxVideoDuration => _maxVideoDuration;

  /// Initialize the environment configuration
  static Future<void> initialize() async {
    try {
      await dotenv.load(fileName: ".env");
      _isInitialized = true;

      // Parse IMAGE_QUALITY (1-100)
      final imageQualityStr = dotenv.env['IMAGE_QUALITY'] ?? '70';
      _imageQuality = int.tryParse(imageQualityStr) ?? 70;
      // Clamp to valid range
      if (_imageQuality < 1) _imageQuality = 1;
      if (_imageQuality > 100) _imageQuality = 100;

      // Parse MAX_IMAGE_WIDTH
      final maxWidthStr = dotenv.env['MAX_IMAGE_WIDTH'] ?? '1920';
      _maxImageWidth = int.tryParse(maxWidthStr) ?? 1920;
      if (_maxImageWidth < 0) _maxImageWidth = 0;

      // Parse MAX_IMAGE_HEIGHT
      final maxHeightStr = dotenv.env['MAX_IMAGE_HEIGHT'] ?? '1080';
      _maxImageHeight = int.tryParse(maxHeightStr) ?? 1080;
      if (_maxImageHeight < 0) _maxImageHeight = 0;

      // Parse VIDEO_QUALITY
      final videoQualityStr =
          dotenv.env['VIDEO_QUALITY']?.toLowerCase() ?? 'medium';
      switch (videoQualityStr) {
        case 'low':
          _videoQuality = VideoQuality.low;
          break;
        case 'high':
          _videoQuality = VideoQuality.high;
          break;
        case 'default':
          _videoQuality = VideoQuality.defaultQuality;
          break;
        case 'medium':
        default:
          _videoQuality = VideoQuality.medium;
          break;
      }

      // Parse MAX_VIDEO_WIDTH
      final maxVideoWidthStr = dotenv.env['MAX_VIDEO_WIDTH'] ?? '1280';
      _maxVideoWidth = int.tryParse(maxVideoWidthStr) ?? 1280;
      if (_maxVideoWidth < 0) _maxVideoWidth = 0;

      // Parse MAX_VIDEO_HEIGHT
      final maxVideoHeightStr = dotenv.env['MAX_VIDEO_HEIGHT'] ?? '720';
      _maxVideoHeight = int.tryParse(maxVideoHeightStr) ?? 720;
      if (_maxVideoHeight < 0) _maxVideoHeight = 0;

      // Parse MAX_VIDEO_DURATION
      final maxVideoDurationStr = dotenv.env['MAX_VIDEO_DURATION'] ?? '120';
      _maxVideoDuration = int.tryParse(maxVideoDurationStr) ?? 120;
      if (_maxVideoDuration < 0) _maxVideoDuration = 0;

      if (kDebugMode) {
        debugPrint(
          'Environment configuration loaded: IMAGE_QUALITY=$_imageQuality, MAX_SIZE=${_maxImageWidth}x$_maxImageHeight, VIDEO_QUALITY=$videoQualityStr, MAX_VIDEO_SIZE=${_maxVideoWidth}x$_maxVideoHeight, MAX_VIDEO_DURATION=${_maxVideoDuration}s',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to load environment configuration: $e');
      }
      // Use defaults if loading fails
      _imageQuality = 70;
      _maxImageWidth = 1920;
      _maxImageHeight = 1080;
      _videoQuality = VideoQuality.medium;
      _maxVideoWidth = 1280;
      _maxVideoHeight = 720;
      _maxVideoDuration = 120;
      _isInitialized = true;
    }
  }
}
