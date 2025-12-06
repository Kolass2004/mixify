import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixify/data/providers.dart';
import 'package:mixify/main.dart'; // For AppColors
import 'package:mixify/ui/components/mini_player.dart';
import 'package:mixify/ui/screens/downloads_screen.dart';
import 'package:mixify/ui/screens/home_screen.dart';
import 'package:mixify/ui/screens/library_screen.dart';
import 'package:mixify/ui/screens/profile_screen.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => MainScreenState();
}

class MainScreenState extends ConsumerState<MainScreen> {
  int _selectedIndex = 0;

  final List<GlobalKey<NavigatorState>> _navigatorKeys = [
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
  ];

  Future<bool> _onWillPop() async {
    final NavigatorState? currentNavigator = _navigatorKeys[_selectedIndex].currentState;
    if (currentNavigator != null && currentNavigator.canPop()) {
      currentNavigator.pop();
      return false;
    }
    if (_selectedIndex != 0) {
      setState(() {
        _selectedIndex = 0;
      });
      return false;
    }
    return true;
  }

  Widget _buildTabNavigator(int index, Widget child) {
    return Navigator(
      key: _navigatorKeys[index],
      onGenerateRoute: (settings) {
        return MaterialPageRoute(
          builder: (_) => child,
          settings: settings,
        );
      },
    );
  }

  void switchToDownloads() {
    setState(() {
      _selectedIndex = 2; // Downloads is at index 2
    });
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(userPreferencesProvider);
    
    return WillPopScope(
      onWillPop: _onWillPop,
      child: ValueListenableBuilder(
        valueListenable: prefs.boxListenable,
        builder: (context, box, _) {
          final isDark = prefs.isDarkMode;
          final navColor = isDark ? Colors.black.withOpacity(0.9) : Colors.white.withOpacity(0.9);
          final iconColor = isDark ? Colors.white : Colors.black;
          final activeColor = isDark ? AppColors.yellow : AppColors.red;

          return Scaffold(
            extendBody: true,
            body: Stack(
              children: [
                IndexedStack(
                  index: _selectedIndex,
                  children: [
                    _buildTabNavigator(0, const HomeScreen()),
                    _buildTabNavigator(1, const LibraryScreen()),
                    _buildTabNavigator(2, const DownloadsScreen()),
                    _buildTabNavigator(3, const ProfileScreen()),
                  ],
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: kBottomNavigationBarHeight + MediaQuery.of(context).padding.bottom, 
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
                  child: BottomNavigationBar(
                    backgroundColor: navColor,
                    elevation: 0,
                    type: BottomNavigationBarType.fixed,
                    selectedItemColor: activeColor,
                    unselectedItemColor: iconColor,
                    showUnselectedLabels: true,
                    currentIndex: _selectedIndex,
                    onTap: (index) {
                      if (_selectedIndex == index) {
                        _navigatorKeys[index].currentState?.popUntil((route) => route.isFirst);
                      } else {
                        setState(() {
                          _selectedIndex = index;
                        });
                      }
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
                        icon: Icon(Icons.download_rounded),
                        label: 'Downloads',
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
          );
        }
      ),
    );
  }
}
