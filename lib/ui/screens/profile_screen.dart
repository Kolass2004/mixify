import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixify/data/providers.dart';
import 'package:mixify/data/repository/playlist_repository.dart';
import 'package:mixify/main.dart';
import 'package:mixify/ui/screens/settings_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mixify/data/services/auth_service.dart';
import 'package:mixify/ui/screens/onboarding_screen.dart';
import 'package:android_intent_plus/android_intent.dart';
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(userPreferencesProvider);
    final user = FirebaseAuth.instance.currentUser;
    
    return ValueListenableBuilder(
      valueListenable: prefs.boxListenable,
      builder: (context, box, _) {
        final isDark = prefs.isDarkMode;
        final textColor = isDark ? AppColors.white : AppColors.black;
        final bgColor = isDark ? AppColors.black : AppColors.yellow;
        final accentColor = isDark ? AppColors.yellow : AppColors.red;

          return Scaffold(
          backgroundColor: bgColor,
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                const SizedBox(height: 40),
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: textColor, width: 2),
                          image: DecorationImage(
                            image: NetworkImage(user?.photoURL ?? "https://i.pravatar.cc/300"),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        user?.displayName ?? "Mixify User",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        user?.email ?? "",
                        style: TextStyle(
                          fontSize: 14,
                          color: textColor.withOpacity(0.7),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: accentColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          "PREMIUM",
                          style: TextStyle(
                            color: isDark ? Colors.black : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                ListTile(
                  leading: Icon(Icons.settings, color: textColor),
                  title: Text("Settings", style: TextStyle(color: textColor, fontSize: 18)),
                  trailing: Icon(Icons.arrow_forward_ios, color: textColor, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const SettingsScreen()),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(Icons.equalizer, color: textColor),
                  title: Text("Equalizer", style: TextStyle(color: textColor, fontSize: 18)),
                  trailing: Icon(Icons.arrow_forward_ios, color: textColor, size: 16),
                  onTap: () async {
                    try {
                      final audioHandler = ref.read(audioHandlerProvider);
                      final sessionId = audioHandler.androidAudioSessionId;
                      
                      debugPrint("Equalizer: Session ID: $sessionId");

                      if (sessionId != null) {
                        final intent = AndroidIntent(
                          action: 'android.media.action.DISPLAY_AUDIO_EFFECT_CONTROL_PANEL',
                          flags: const [0x10000000], // FLAG_ACTIVITY_NEW_TASK
                          arguments: <String, dynamic>{
                            'android.media.extra.AUDIO_SESSION': sessionId,
                            'android.media.extra.PACKAGE_NAME': context.packageName,
                            'android.media.extra.CONTENT_TYPE': 0, // CONTENT_TYPE_MUSIC
                          },
                        );
                        await intent.launch();
                      } else {
                         ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Please play a song first to initialize the equalizer.")),
                        );
                      }
                    } catch (e) {
                      debugPrint("Equalizer Error: $e");
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("No equalizer found on this device.")),
                        );
                      }
                    }
                  },
                ),
                SwitchListTile(
                  secondary: Icon(isDark ? Icons.dark_mode : Icons.light_mode, color: textColor),
                  title: Text("Dark Mode", style: TextStyle(color: textColor, fontSize: 18)),
                  value: isDark,
                  activeColor: accentColor,
                  onChanged: (value) {
                    prefs.setDarkMode(value);
                  },
                ),
                const SizedBox(height: 40),
                Padding(
                  padding: const EdgeInsets.only(bottom: 120.0), // Extra padding for mini player
                  child: TextButton.icon(
                    onPressed: () async {
                      // Stop audio playback
                      await ref.read(audioHandlerProvider).stop();

                      // Clear local data
                      await prefs.clearUserData();
                      await ref.read(playlistRepositoryProvider).clearLocalData();
                      
                      await AuthService().signOut();
                      if (context.mounted) {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const OnboardingScreen()),
                          (route) => false,
                        );
                      }
                    },
                    icon: Icon(Icons.logout, color: accentColor),
                    label: Text(
                      "Logout",
                      style: TextStyle(color: accentColor, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
            ),
          );

      },
    );
  }
}

extension ContextExtensions on BuildContext {
  String get packageName {
    return "com.uvitetech.mixifymusic";
  }
}
