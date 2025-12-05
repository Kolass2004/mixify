import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:mixify/data/providers.dart';
import 'package:mixify/main.dart'; // For AppColors
import 'package:mixify/ui/components/mini_player.dart';
import 'package:mixify/ui/screens/home_screen.dart';
import 'package:mixify/ui/screens/library_screen.dart';
import 'package:mixify/ui/screens/profile_screen.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const LibraryScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(userPreferencesProvider);
    
    return ValueListenableBuilder(
      valueListenable: prefs.boxListenable,
      builder: (context, box, _) {
        final isDark = prefs.isDarkMode;
        final navColor = isDark ? Colors.black.withOpacity(0.6) : Colors.white.withOpacity(0.6);
        final iconColor = isDark ? Colors.white : Colors.black;
        final activeColor = isDark ? AppColors.yellow : AppColors.red;

        return Scaffold(
          extendBody: true, // Important for blur effect over body
          body: Stack(
            children: [
              IndexedStack(
                index: _selectedIndex,
                children: _screens,
              ),
              // MiniPlayer positioned above the bottom nav
              // MiniPlayer positioned above the bottom nav
              // kBottomNavigationBarHeight is usually 56.
              // We add some padding to avoid overlap
              Positioned(
                left: 0,
                right: 0,
                bottom: kBottomNavigationBarHeight + 10, // Add a bit of spacing
                child: const MiniPlayer(),
              ),
            ],
          ),
          bottomNavigationBar: ClipRRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Theme(
                data: Theme.of(context).copyWith(
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                ),
                child: SafeArea(
                  child: BottomNavigationBar(
                    backgroundColor: navColor,
                    elevation: 0,
                    type: BottomNavigationBarType.fixed, // Always show labels
                    selectedItemColor: activeColor,
                    unselectedItemColor: iconColor,
                    showUnselectedLabels: true,
                    currentIndex: _selectedIndex,
                    onTap: (index) {
                      setState(() {
                        _selectedIndex = index;
                      });
                    },
                    items: const [
                      BottomNavigationBarItem(
                        icon: Icon(Icons.home),
                        label: 'Home',
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.library_music),
                        label: 'Library',
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.person),
                        label: 'Profile',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }
    );
  }
}
