import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixify/data/providers.dart';
import 'package:mixify/main.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(userPreferencesProvider);
    
    // We listen to the box to update the UI when values change
    return ValueListenableBuilder(
      valueListenable: prefs.boxListenable,
      builder: (context, box, _) {
        final isDark = prefs.isDarkMode;
        final region = prefs.region;
        final language = prefs.language;
        final quality = prefs.audioQuality;
        
        // Determine text color based on theme
        final textColor = isDark ? AppColors.white : AppColors.black;
        final bgColor = isDark ? AppColors.black : AppColors.white;

        return Scaffold(
          backgroundColor: bgColor,
          appBar: AppBar(
            title: Text("Settings", style: TextStyle(color: textColor)),
            backgroundColor: Colors.transparent,
            iconTheme: IconThemeData(color: textColor),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildSectionHeader("Appearance", textColor),
              SwitchListTile(
                title: Text("Dark Mode", style: TextStyle(color: textColor)),
                value: isDark,
                onChanged: (val) => prefs.setDarkMode(val),
                activeColor: AppColors.yellow,
              ),
              const Divider(),
              _buildSectionHeader("Audio", textColor),
              ListTile(
                title: Text("Audio Quality", style: TextStyle(color: textColor)),
                subtitle: Text(quality, style: TextStyle(color: textColor.withOpacity(0.6))),
                trailing: DropdownButton<String>(
                  value: quality,
                  dropdownColor: bgColor,
                  style: TextStyle(color: textColor),
                  underline: Container(),
                  items: ["High", "Low"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (val) {
                    if (val != null) prefs.setAudioQuality(val);
                  },
                ),
              ),
              const Divider(),
              _buildSectionHeader("Content", textColor),
              ListTile(
                title: Text("Region", style: TextStyle(color: textColor)),
                subtitle: Text(region, style: TextStyle(color: textColor.withOpacity(0.6))),
                trailing: DropdownButton<String>(
                  value: region,
                  dropdownColor: bgColor,
                  style: TextStyle(color: textColor),
                  underline: Container(),
                  items: ["US", "IN", "GB", "JP"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (val) {
                    if (val != null) prefs.setRegion(val);
                  },
                ),
              ),
              ListTile(
                title: Text("Music Language", style: TextStyle(color: textColor)),
                subtitle: Text(language, style: TextStyle(color: textColor.withOpacity(0.6))),
                trailing: DropdownButton<String>(
                  value: language,
                  dropdownColor: bgColor,
                  style: TextStyle(color: textColor),
                  underline: Container(),
                  items: ["en", "ta", "hi", "es"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (val) {
                    if (val != null) prefs.setLanguage(val);
                  },
                ),
              ),
            ],
          ),
        );
      }
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
    );
  }
}
