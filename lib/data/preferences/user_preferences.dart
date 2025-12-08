import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mixify/data/services/firestore_service.dart';

class UserPreferences {
  static const _boxName = 'user_preferences';
  static const _keyIsFirstLaunch = 'is_first_launch';
  static const _keyRegion = 'region';
  static const _keyLanguage = 'language';

  static const _keyThemeMode = 'theme_mode';
  static const _keyAudioQuality = 'audio_quality';

  late Box _box;
  final FirestoreService _firestoreService = FirestoreService();

  Future<void> init() async {
    _box = await Hive.openBox(_boxName);
  }
  
  // Sync data from Firestore on login
  Future<void> syncFromCloud() async {
    final settings = await _firestoreService.getSettings();
    if (settings != null) {
      if (settings.containsKey('region')) await setRegion(settings['region']);
      if (settings.containsKey('language')) await setLanguage(settings['language']);
      if (settings.containsKey('isDarkMode')) await setDarkMode(settings['isDarkMode']);
      if (settings.containsKey('audioQuality')) await setAudioQuality(settings['audioQuality']);
    }

    final history = await _firestoreService.getHistory();
    if (history != null) {
      await _box.put(_keyHistory, history);
    }
  }

  // Expose listenable
  ValueListenable<Box> get boxListenable => _box.listenable();

  bool get isFirstLaunch => _box.get(_keyIsFirstLaunch, defaultValue: true);

  Future<void> setFirstLaunchComplete() async {
    await _box.put(_keyIsFirstLaunch, false);
  }

  String get region => _box.get(_keyRegion, defaultValue: 'US');

  Future<void> setRegion(String region) async {
    await _box.put(_keyRegion, region);
    _syncSettings();
  }

  String get language => _box.get(_keyLanguage, defaultValue: 'en');

  Future<void> setLanguage(String language) async {
    await _box.put(_keyLanguage, language);
    _syncSettings();
  }
  
  bool get isDarkMode => _box.get(_keyThemeMode, defaultValue: true);
  
  Future<void> setDarkMode(bool isDark) async {
    await _box.put(_keyThemeMode, isDark);
    _syncSettings();
  }
  
  String get audioQuality => _box.get(_keyAudioQuality, defaultValue: 'High');
  
  Future<void> setAudioQuality(String quality) async {
    await _box.put(_keyAudioQuality, quality);
    _syncSettings();
  }

  void _syncSettings() {
    _firestoreService.saveSettings({
      'region': region,
      'language': language,
      'isDarkMode': isDarkMode,
      'audioQuality': audioQuality,
    });
  }

  // Persistence
  static const _keyLastMediaItem = 'last_media_item';
  static const _keyLastQueue = 'last_queue';
  static const _keyLastPosition = 'last_position';

  Future<void> saveLastState(Map<String, dynamic>? mediaItem, List<Map<String, dynamic>> queue, int position) async {
    if (mediaItem != null) await _box.put(_keyLastMediaItem, mediaItem);
    await _box.put(_keyLastQueue, queue);
    await _box.put(_keyLastPosition, position);
  }

  Map<String, dynamic>? getLastMediaItem() {
    final map = _box.get(_keyLastMediaItem);
    if (map is Map) return Map<String, dynamic>.from(map);
    return null;
  }

  List<Map<String, dynamic>> getLastQueue() {
    final list = _box.get(_keyLastQueue);
    if (list is List) {
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  int getLastPosition() => _box.get(_keyLastPosition, defaultValue: 0);

  // History
  static const _keyHistory = 'song_history';
  static const _maxHistorySize = 20; // Increased for better list view

  Future<void> addSongToHistory(Map<String, dynamic> song) async {
    final history = getSongHistory();
    // Remove if exists to move to top
    history.removeWhere((s) => s['id'] == song['id']);
    // Add to start
    history.insert(0, song);
    // Limit size
    if (history.length > _maxHistorySize) {
      history.removeRange(_maxHistorySize, history.length);
    }
    await _box.put(_keyHistory, history);
    _firestoreService.saveHistory(history);
  }

  List<Map<String, dynamic>> getSongHistory() {
    final list = _box.get(_keyHistory);
    if (list is List) {
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  Stream<BoxEvent> get historyStream => _box.watch(key: _keyHistory);

  Future<void> clearUserData() async {
    await _box.delete(_keyRegion);
    await _box.delete(_keyLanguage);
    await _box.delete(_keyThemeMode);
    await _box.delete(_keyAudioQuality);
    await _box.delete(_keyHistory);
    await _box.delete(_keyLastMediaItem);
    await _box.delete(_keyLastQueue);
    await _box.delete(_keyLastPosition);
    // We don't clear isFirstLaunch so they don't see onboarding again if we don't want them to,
    // BUT since we redirect to Onboarding on logout, maybe we should?
    // Actually, Onboarding logic checks auth state now. 
    // If we clear isFirstLaunch, they might see the welcome screen again.
    // Let's keep isFirstLaunch as is, or maybe set it to true if we want full reset.
    // For now, let's just clear user specific data.
  }
}
