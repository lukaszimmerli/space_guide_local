# Space Guide App Icons

## Required Files:

1. **space_guide_icon.png** - Your main app icon (1024x1024px minimum)
2. **space_guide_icon_foreground.png** - Foreground layer for Android adaptive icons (1024x1024px)

## Instructions:

1. Place your Space Guide app icon as `space_guide_icon.png` in this folder
2. For Android adaptive icons, create a foreground version as `flowxr_icon_foreground.png`
3. Update the background and theme colors in `pubspec.yaml` under `flutter_icons`
4. Run the icon generation command: `dart run flutter_launcher_icons`

## Icon Requirements:
- Main icon should be 1024x1024px minimum
- Use PNG format with transparency if needed
- For adaptive icons, ensure the important content is in the center 66% of the image
- Consider how the icon will look on different backgrounds

## Colors to Update in pubspec.yaml:
- `background_color`: Background color for web manifest and adaptive icons
- `theme_color`: Theme color for web manifest
- `adaptive_icon_background`: Background color for Android adaptive icons
