import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixify/data/providers.dart';
import 'package:mixify/data/repository/playlist_repository.dart';
import 'package:mixify/ui/screens/main_screen.dart';

import 'package:mixify/data/services/auth_service.dart';
import 'package:mixify/data/services/firestore_service.dart';

import 'package:mixify/data/constants.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  final AuthService _authService = AuthService();
  int _currentPage = 0;
  bool _isSigningIn = false;
  
  // Default selections
  String _selectedRegion = 'US';
  String _selectedLanguage = 'en';

  final List<Map<String, String>> _regions = AppConstants.countries;
  final List<Map<String, String>> _languages = AppConstants.languages;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) => setState(() => _currentPage = index),
                children: [
                  _buildWelcomeSlide(),
                  _buildPreferencesSlide(),
                ],
              ),
            ),
            _buildBottomControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeSlide() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.music_note_rounded, size: 100, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 24),
          Text(
            "Welcome to Mixify",
            style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            "Sign in to start streaming your favorite music.",
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          if (_isSigningIn)
            const CircularProgressIndicator()
          else if (FirebaseAuth.instance.currentUser == null)
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _signInWithGoogle,
                  borderRadius: BorderRadius.circular(30),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.network(
                          'https://developers.google.com/identity/images/g-logo.png',
                          height: 24,
                          width: 24,
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          "Sign in with Google",
                          style: TextStyle(
                            color: Colors.black87,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          else
            const Text("Signed in successfully! Swipe to continue.", style: TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildPreferencesSlide() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Personalize Experience",
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 32),
          Text("Select Region", style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedRegion,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            items: _regions.map((region) {
              return DropdownMenuItem(value: region['code'], child: Text(region['name']!));
            }).toList(),
            onChanged: (value) => setState(() => _selectedRegion = value!),
          ),
          const SizedBox(height: 24),
          Text("Select Language", style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedLanguage,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            items: _languages.map((lang) {
              return DropdownMenuItem(value: lang['code'], child: Text(lang['name']!));
            }).toList(),
            onChanged: (value) => setState(() => _selectedLanguage = value!),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Page Indicators
          Row(
            children: List.generate(2, (index) {
              return Container(
                margin: const EdgeInsets.only(right: 8),
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _currentPage == index
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
              );
            }),
          ),
          // Next/Sign In Button
          if (_isSigningIn)
            const CircularProgressIndicator()
          else if (_currentPage == 1)
            FilledButton(
              onPressed: _onGetStartedPressed,
              child: const Text("Get Started"),
            )
          else if (FirebaseAuth.instance.currentUser != null)
             FilledButton(
              onPressed: () => _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
              child: const Text("Next"),
            )
          else
             // Show Sign In button here too if needed, or just hide "Next" until signed in. 
             // The design says "Sign in with Google" is on the slide itself. 
             // But if we want it in the bottom bar too:
             Container() // Hide bottom button on first page, force user to use the main button
             
        ],
      ),
    );
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isSigningIn = true);
    final user = await _authService.signInWithGoogle();
    
    if (user != null) {
      if (mounted) {
        // Check if user has existing settings
        final firestoreService = FirestoreService();
        final settings = await firestoreService.getSettings();

        if (settings != null && settings.isNotEmpty) {
          // Old user: Sync and go to Main
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Welcome back, ${user.user?.displayName}! Syncing your data...")),
          );

          try {
            // Capture providers before async gaps
            final prefs = ref.read(userPreferencesProvider);
            final playlistRepo = ref.read(playlistRepositoryProvider);
            
            await prefs.syncFromCloud();
            await playlistRepo.syncFromCloud();
            await prefs.setFirstLaunchComplete(); // Ensure this is set

            if (mounted) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const MainScreen()),
              );
            }
          } catch (e) {
            debugPrint("Error syncing data: $e");
             // If sync fails, maybe still go to main or let them try again? 
             // For now, let's fall through to preferences if sync fails drastically, 
             // or just go to main. Going to main is safer for "Old User".
             if (mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const MainScreen()),
                );
             }
          }
        } else {
          // New user: Go to preferences
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Welcome, ${user.user?.displayName}! Please select your preferences.")),
          );
          // Auto advance to preferences
          _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
        }
      }
    }
    
    if (mounted) setState(() => _isSigningIn = false);
  }

  Future<void> _onGetStartedPressed() async {
    if (!mounted) return;
    setState(() => _isSigningIn = true);

    // Capture providers before async gaps
    final prefs = ref.read(userPreferencesProvider);
    final playlistRepo = ref.read(playlistRepositoryProvider);

    // 1. Save local preferences
    await prefs.setRegion(_selectedRegion);
    await prefs.setLanguage(_selectedLanguage);
    await prefs.setFirstLaunchComplete();

    // 2. Sync to Cloud (Initial Data)
    // Ensure we catch errors here so navigation still happens
    try {
      await prefs.syncFromCloud();
      await playlistRepo.syncFromCloud();
    } catch (e) {
      debugPrint("Error syncing data: $e");
    }

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainScreen()),
      );
    }
  }
}
