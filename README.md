# Space Guide

A lightweight Flutter application for interactive flow management with **local-only storage** and offline capabilities.

## Features

This example showcases the complete Flow Manager functionality without any cloud dependencies:

- 📱 **Local Storage** - All flows stored on device
- 🎯 **Complete Offline Operation** - No internet required
- 🎥 **Rich Media Support** - Images, videos, audio, and text
- 🔄 **Import/Export** - Share flows via .flow files
- 📋 **Flow Management** - Create, edit, duplicate, and organize flows
- 🎨 **Responsive UI** - Adapts to mobile, tablet, and desktop
- 🌍 **Multi-language** - Customizable translations
- ⚙️ **Configurable Media Quality** - Optimize for device storage

## Getting Started

### 1. Environment Configuration

Copy and configure the environment file:

```bash
cp .env.example .env
```

Configure your `.env` file for local operation:

```env
# Media Quality Settings
IMAGE_QUALITY=85
MAX_IMAGE_WIDTH=1920
MAX_IMAGE_HEIGHT=1080
VIDEO_QUALITY=high
MAX_VIDEO_WIDTH=1920
MAX_VIDEO_HEIGHT=1080
MAX_VIDEO_DURATION=300
```

### 2. Install Dependencies & Run

```bash
flutter pub get
flutter run
```

## Core Capabilities

### 📋 Flow Management
- **Create Flows**: Build step-by-step instructional flows
- **Edit Flows**: Modify existing flows with intuitive editor
- **Duplicate Flows**: Copy flows to use as templates
- **Delete Flows**: Remove unwanted flows
- **Flow Organization**: Sort and filter flows

### 🎥 Media Integration
- **Image Capture**: Take photos directly in the app
- **Image Import**: Add existing photos from gallery
- **Video Recording**: Record instructional videos
- **Video Import**: Add existing videos from device
- **Audio Recording**: Add voice instructions
- **Text Content**: Rich text descriptions and notes

### 💾 Local Storage
- **Device Storage**: All data stored locally
- **No Internet Required**: Fully offline operation
- **File Management**: Organized media file structure
- **Data Persistence**: Flows saved between app sessions

### 🔄 Import/Export
- **Flow Export**: Save flows as .flow files
- **Flow Import**: Load flows from .flow files
- **Native Sharing**: Use device sharing capabilities
- **Cross-Device**: Transfer flows between devices

### ⚙️ Settings & Customization
- **Media Quality Control**: Configure image/video compression
- **Language Support**: Custom translation support
- **Theme Options**: Light and dark mode support
- **App Preferences**: Customize user interface

## Responsive Design

The app provides optimized layouts for different screen sizes:

### Mobile (Phone)
- Single-column flow list
- Touch-optimized controls
- Portrait-oriented design

### Tablet
- Grid-based flow layout (2-3 columns)
- Larger touch targets
- Optimized for both portrait/landscape

## Technical Implementation

### Flow Manager Configuration

```dart
// Configure Flow Manager with environment settings
FlowConfig.configure(
  imageQuality: EnvConfig.imageQuality,
  maxImageWidth: EnvConfig.maxImageWidth,
  maxImageHeight: EnvConfig.maxImageHeight,
  videoQuality: EnvConfig.videoQuality.name,
  maxVideoWidth: EnvConfig.maxVideoWidth,
  maxVideoHeight: EnvConfig.maxVideoHeight,
  maxVideoDuration: EnvConfig.maxVideoDuration,
);
```

### Local Storage Integration

```dart
// Direct usage of local storage service
final storageService = FlowStorageService();

// Get all flows
final flows = await storageService.getAllFlows();

// Save a flow
await storageService.saveFlow(flowData);

// Delete a flow
await storageService.deleteFlow(flowId);
```

### Custom UI Components

```dart
// Responsive flow list with local operations
FlowListView(
  enableFlowCreation: true,
  onShare: (flow) => _shareFlowLocally(context, flow),
  onCreated: (flow) => _navigateToFlowEditor(flow),
  onSelected: (flowData) => _openFlowPlayer(flowData),
  onEdit: (flowData) => _editFlow(flowData),
)
```

### Translation Support

```dart
// Load custom translations
await FlowManagerLocalizations.instance.loadCustomTranslationsFromAsset(
  'assets/translations/custom_flow_manager.json',
);
```

## Project Structure

```
example_local/
├── lib/
│   ├── main.dart                 # App entry point and configuration
│   ├── config/
│   │   └── env_config.dart       # Environment configuration
│   ├── screens/
│   │   ├── home_screen.dart      # Main flow list interface
│   │   └── settings_screen.dart  # App settings and import
│   ├── services/
│   │   └── settings_service.dart # Local settings management
│   ├── theme/
│   │   └── app_theme.dart        # Material Design theming
│   └── utils/
│       └── flow_screen_factory.dart # Screen navigation utilities
├── assets/
│   ├── icon/                     # App icons and branding
│   └── translations/             # Custom translation files
├── .env.example                  # Environment configuration template
└── README.md                     # This file
```

## Storage Structure

Local flows are stored in the following structure:

```
App Documents/
├── flows/
│   ├── flow_id_1/
│   │   ├── flow.json            # Flow metadata and structure
│   │   └── assets/              # Flow media assets
│   │       ├── image_1.jpg
│   │       ├── video_1.mp4
│   │       └── audio_1.m4a
│   └── flow_id_2/
│       └── ...
└── settings/
    └── app_settings.json        # User preferences
```

## Performance Considerations

### Media Optimization
- **Compression**: Configurable quality settings
- **Resolution Limits**: Prevent excessive file sizes  
- **Duration Limits**: Control video length
- **Format Standards**: JPEG, MP4, M4A support

### Storage Management
- **Cleanup**: Remove unused assets
- **Organization**: Structured file hierarchy
- **Backup**: Export capabilities for data safety

## Development Tips

### Debugging
- Enable debug mode for detailed logging
- Check local storage paths for file issues
- Monitor memory usage with large media files

### Testing
- Test on different screen sizes
- Verify import/export functionality
- Test with various media formats

### Customization
- Modify theme colors in `app_theme.dart`
- Add custom translations in `assets/translations/`
- Adjust media settings in `.env`

## Comparison with Supabase Example

| Feature | Local Example | Supabase Example |
|---------|---------------|------------------|
| **Storage** | Device only | Cloud + Device |
| **Authentication** | None | Email + Password |
| **User Management** | Single user | Multi-user with roles |
| **Sharing** | File export | Cloud sharing |
| **Collaboration** | None | Role-based collaboration |
| **Backup** | Manual export | Automatic cloud sync |

## Use Cases

### Personal Use
- Individual instruction creation
- Private knowledge management
- Offline environments
- Data privacy requirements

### Educational
- Classroom demonstrations
- Student projects
- Offline learning materials
- No internet classrooms

### Enterprise
- On-premise deployments
- Secure environments
- Custom integrations
- Regulated industries

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes  
4. Test on multiple platforms
5. Submit a pull request

## License

This example is part of the Flow Manager package and follows the same license terms.