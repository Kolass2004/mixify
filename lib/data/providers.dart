import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixify/data/network/spotify_api_service.dart';
import 'package:mixify/data/network/youtube_api_service.dart';
import 'package:mixify/data/preferences/user_preferences.dart';
import 'package:mixify/data/repository/music_repository.dart';
import 'package:mixify/player/mixify_audio_handler.dart';

final youtubeApiServiceProvider = Provider<YouTubeApiService>((ref) {
  return YouTubeApiService();
});

final spotifyApiServiceProvider = Provider<SpotifyApiService>((ref) {
  return SpotifyApiService();
});

final musicRepositoryProvider = Provider<MusicRepository>((ref) {
  final youtubeApiService = ref.watch(youtubeApiServiceProvider);
  final spotifyApiService = ref.watch(spotifyApiServiceProvider);
  final userPreferences = ref.watch(userPreferencesProvider);
  return MusicRepository(youtubeApiService, spotifyApiService, userPreferences);
});

final audioHandlerProvider = Provider<MixifyAudioHandler>((ref) {
  throw UnimplementedError('AudioHandler must be overridden in main');
});

final userPreferencesProvider = Provider<UserPreferences>((ref) {
  throw UnimplementedError('UserPreferences must be overridden in main');
});
