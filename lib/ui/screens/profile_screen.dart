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
import 'package:mixify/ui/screens/home_screen.dart';
import 'package:mixify/player/mixify_audio_handler.dart';

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
        final theme = Theme.of(context);
        final textColor = theme.colorScheme.onBackground;
        final backgroundColor = theme.scaffoldBackgroundColor;
        final primaryColor = theme.colorScheme.primary;

        return Scaffold(
          backgroundColor: backgroundColor,
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                // Profile Avatar with Glow
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.grey[800],
                    backgroundImage: NetworkImage(user?.photoURL ?? "https://i.pravatar.cc/300"),
                  ),
                ),
                const SizedBox(height: 24),
                
                // User Info
                Text(
                  user?.displayName ?? "Mixify User",
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  user?.email ?? "",
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: textColor.withOpacity(0.6),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Premium Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFD700), Color(0xFFFFA500)], // Gold Gradient
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Text(
                    "PREMIUM MEMBER",
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                      fontSize: 12,
                    ),
                  ),
                ),

                const SizedBox(height: 40),
                
                // Menu Options
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[900] : Colors.grey[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      _buildProfileTile(
                        icon: Icons.settings_rounded,
                        title: "Settings",
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const SettingsScreen()),
                          );
                        },
                        isDark: isDark,
                      ),
                      Divider(height: 1, color: Colors.grey.withOpacity(0.2)),
                      _buildProfileTile(
                         icon: isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                         title: "Dark Mode",
                         trailing: Switch(
                           value: isDark,
                           activeColor: primaryColor,
                           onChanged: (value) => prefs.setDarkMode(value),
                         ),
                         isDark: isDark,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // Logout Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () async {
                      // 1. CLEAR PLAYER (Memory)
                      final audioHandler = ref.read(audioHandlerProvider);
                      if (audioHandler is MixifyAudioHandler) {
                        await audioHandler.clear();
                      } else {
                        await audioHandler.stop();
                      }

                      // 2. CLEAR DATA (Storage)
                      await prefs.clearUserData();
                      await ref.read(playlistRepositoryProvider).clearLocalData();
                      await ref.read(musicRepositoryProvider).clearHomeCache();

                      // 3. INVALIDATE PROVIDERS (Memory)
                      ref.invalidate(homeSectionsProvider);
                      ref.invalidate(historyStreamProvider);

                      // 4. SIGN OUT
                      await AuthService().signOut();
                      
                      if (context.mounted) {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const OnboardingScreen()),
                          (route) => false,
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent.withOpacity(0.1),
                      foregroundColor: Colors.redAccent,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.redAccent.withOpacity(0.5)),
                      ),
                    ),
                    child: const Text(
                      "Log Out",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 80), // Bottom padding
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileTile({
    required IconData icon,
    required String title,
    VoidCallback? onTap,
    Widget? trailing,
    required bool isDark,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[800] : Colors.grey[200],
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: isDark ? Colors.white : Colors.black, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black,
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
      trailing: trailing ?? Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey[500]),
      onTap: onTap,
    );
  }
}

extension ContextExtensions on BuildContext {
  String get packageName {
    return "com.uvitetech.mixifymusic";
  }
}
