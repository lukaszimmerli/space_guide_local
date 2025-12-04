import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flow_manager_saas/flow_manager.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';
import 'services/settings_service.dart';
import 'services/settings_service_adapter.dart';
import 'config/env_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize environment configuration
  await EnvConfig.initialize();

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

  // Set preferred orientations to portrait up only
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]).then((
    _,
  ) async {
    // Initialize device detection
    await DeviceUtils.initialize();

    // Load custom translations for Flow Manager
    // This demonstrates how to override the default text strings
    await FlowManagerLocalizations.instance.loadCustomTranslationsFromAsset(
      'assets/translations/custom_flow_manager.json',
    );

    runApp(const FlowManagerApp());
  });
}

class FlowManagerApp extends StatelessWidget {
  const FlowManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => FlowNotifier()),
        ChangeNotifierProvider(
          create: (_) {
            final settingsService = SettingsService();
            // Load settings when app starts
            settingsService.loadSettings();
            return settingsService;
          },
        ),
        ChangeNotifierProvider<FlowPlayerSettings>(
          create: (context) {
            final settingsService = Provider.of<SettingsService>(
              context,
              listen: false,
            );
            return SettingsServiceAdapter(settingsService);
          },
        ),
      ],
      child: Consumer<SettingsService>(
        builder: (context, settingsService, _) {
          // Convert string theme mode to ThemeMode enum
          ThemeMode themeMode;
          switch (settingsService.themeMode) {
            case 'light':
              themeMode = ThemeMode.light;
              break;
            case 'dark':
              themeMode = ThemeMode.dark;
              break;
            case 'system':
              themeMode = ThemeMode.system;
              break;
            default:
              themeMode = ThemeMode.dark;
          }

          return MaterialApp(
            title: 'Space Guide',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeMode,
            home: const HomeScreen(),
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}
