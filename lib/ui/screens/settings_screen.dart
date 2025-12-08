import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixify/data/providers.dart';
import 'package:mixify/main.dart'; // For AppColors (fallback if needed)
import 'package:mixify/data/constants.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(userPreferencesProvider);
    
    return ValueListenableBuilder(
      valueListenable: prefs.boxListenable,
      builder: (context, box, _) {
        final isDark = prefs.isDarkMode;
        final region = prefs.region;
        final language = prefs.language;
        final quality = prefs.audioQuality;
        
        final theme = Theme.of(context);
        final textColor = theme.colorScheme.onBackground;
        final backgroundColor = theme.scaffoldBackgroundColor;
        final cardColor = isDark ? Colors.grey[900] : Colors.grey[100];
        final primaryColor = theme.colorScheme.primary;

        return Scaffold(
          backgroundColor: backgroundColor,
          appBar: AppBar(
            title: Text(
              "Settings",
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            centerTitle: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: IconThemeData(color: textColor),
          ),
          body: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              _buildSectionHeader(context, "Appearance"),
              _buildSettingsGroup(
                context,
                cardColor,
                children: [
                  _buildSwitchTile(
                    context,
                    title: "Dark Mode",
                    icon: isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                    value: isDark,
                    onChanged: (val) => prefs.setDarkMode(val),
                    activeColor: primaryColor,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              _buildSectionHeader(context, "Audio"),
              _buildSettingsGroup(
                context,
                cardColor,
                children: [
                   _buildDropdownTile(
                    context,
                    title: "Audio Quality",
                    icon: Icons.high_quality_rounded,
                    value: quality,
                    items: ["High", "Low"],
                    onChanged: (val) {
                      if (val != null) prefs.setAudioQuality(val);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),

              _buildSectionHeader(context, "Content"),
              _buildSettingsGroup(
                context,
                cardColor,
                children: [
                  _buildDropdownTile(
                    context,
                    title: "Region",
                    icon: Icons.public_rounded,
                    value: region,
                    itemsMap: {for (var e in AppConstants.countries) e['code']!: e['name']!},
                    onChanged: (val) {
                      if (val != null) prefs.setRegion(val);
                    },
                  ),
                  Divider(height: 1, color: Colors.grey.withOpacity(0.2)),
                  _buildDropdownTile(
                    context,
                    title: "Music Language",
                    icon: Icons.language_rounded,
                    value: language,
                    itemsMap: {for (var e in AppConstants.languages) e['code']!: e['name']!},
                    onChanged: (val) {
                      if (val != null) prefs.setLanguage(val);
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      }
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildSettingsGroup(BuildContext context, Color? color, {required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildSwitchTile(
    BuildContext context, {
    required String title,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
    required Color activeColor,
  }) {
    final textColor = Theme.of(context).colorScheme.onBackground;
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      secondary: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.grey[200],
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: textColor, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
      value: value,
      onChanged: onChanged,
      activeColor: activeColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  Widget _buildDropdownTile(
    BuildContext context, {
    required String title,
    required IconData icon,
    required String value,
    List<String>? items,
    Map<String, String>? itemsMap,
    required ValueChanged<String?> onChanged,
  }) {
    final textColor = Theme.of(context).colorScheme.onBackground;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Determine display text for the current value
    String displayValue = value;
    if (itemsMap != null && itemsMap.containsKey(value)) {
      displayValue = itemsMap[value]!;
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[800] : Colors.grey[200],
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: textColor, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
      trailing: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: (items != null && items.contains(value)) || (itemsMap != null && itemsMap.containsKey(value)) ? value : null,
          icon: Icon(Icons.arrow_drop_down_rounded, color: textColor.withOpacity(0.5)),
          dropdownColor: isDark ? Colors.grey[850] : Colors.white,
          style: TextStyle(color: textColor, fontWeight: FontWeight.normal),
          alignment: Alignment.centerRight,
          items: items != null
              ? items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList()
              : itemsMap!.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
