import 'package:audio_service/audio_service.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mixify/data/network/spotify_api_service.dart';
import 'package:mixify/data/network/youtube_api_service.dart';
import 'package:mixify/data/preferences/user_preferences.dart';
import 'package:mixify/data/providers.dart';
import 'package:mixify/data/repository/music_repository.dart';
import 'package:mixify/data/repository/playlist_repository.dart';
import 'package:mixify/player/mixify_audio_handler.dart';
import 'package:mixify/ui/screens/main_screen.dart';
import 'package:mixify/ui/screens/onboarding_screen.dart';

class AppColors {
  static const Color black = Color(0xFF040411);
  static const Color red = Color(0xFFdd1a1c);
  static const Color yellow = Color(0xFFffdf42);
  static const Color white = Color(0xFFf6f6f6);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Initialize Hive
  await Hive.initFlutter();
  await Hive.openBox('settings');
  final userPrefs = UserPreferences();
  await userPrefs.init();

  final playlistRepo = PlaylistRepository();
  await playlistRepo.init();

  final dio = Dio();
  final youtubeApiService = YouTubeApiService();
  final spotifyApiService = SpotifyApiService();
  final musicRepository = MusicRepository(youtubeApiService, spotifyApiService, userPrefs);

  final audioHandler = await AudioService.init(
    builder: () => MixifyAudioHandler(userPrefs, musicRepository),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.uvitetech.mixifymusic.channel.audio',
      androidNotificationChannelName: 'Mixify Music',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );

  runApp(
    ProviderScope(
      overrides: [
        userPreferencesProvider.overrideWithValue(userPrefs),
        playlistRepositoryProvider.overrideWithValue(playlistRepo),
        musicRepositoryProvider.overrideWithValue(musicRepository),
        audioHandlerProvider.overrideWithValue(audioHandler),
      ],
      child: MixifyApp(isFirstLaunch: userPrefs.isFirstLaunch),
    ),
  );
}

class MixifyApp extends ConsumerWidget {
  final bool isFirstLaunch;
  const MixifyApp({super.key, required this.isFirstLaunch});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(userPreferencesProvider);
    
    // Force sync on app load if user is logged in
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (FirebaseAuth.instance.currentUser != null) {
        prefs.syncFromCloud();
        ref.read(playlistRepositoryProvider).syncFromCloud();
      }
    });
    
    return ValueListenableBuilder(
      valueListenable: prefs.boxListenable,
      builder: (context, box, _) {
        final isDark = prefs.isDarkMode;
        final user = FirebaseAuth.instance.currentUser;
        
        return MaterialApp(
          title: 'Mixify',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            textTheme: GoogleFonts.readexProTextTheme(
              isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme
            ).apply(
              bodyColor: isDark ? AppColors.white : AppColors.black,
              displayColor: isDark ? AppColors.yellow : AppColors.black, // Headings yellow in dark mode
            ),
            colorScheme: isDark 
              ? const ColorScheme.dark(
                  primary: AppColors.yellow,
                  secondary: AppColors.red,
                  surface: AppColors.black,
                  onSurface: AppColors.white,
                )
              : const ColorScheme.light(
                  primary: AppColors.red,
                  secondary: AppColors.yellow,
                  surface: AppColors.white,
                  onSurface: AppColors.black,
                  onPrimary: Colors.white,
                  onSecondary: AppColors.black,
                ),
            scaffoldBackgroundColor: isDark ? AppColors.black : AppColors.yellow,
            appBarTheme: AppBarTheme(
              backgroundColor: Colors.transparent,
              elevation: 0,
              titleTextStyle: TextStyle(color: isDark ? AppColors.white : AppColors.black, fontSize: 20, fontWeight: FontWeight.bold),
              iconTheme: IconThemeData(color: isDark ? AppColors.white : AppColors.black),
            ),
            pageTransitionsTheme: const PageTransitionsTheme(
              builders: {
                TargetPlatform.android: CupertinoPageTransitionsBuilder(),
                TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
                TargetPlatform.fuchsia: CupertinoPageTransitionsBuilder(),
              },
            ),
          ),
          home: user == null ? const OnboardingScreen() : const MainScreen(),
        );
      }
    );
  }
}
