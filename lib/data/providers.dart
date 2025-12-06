import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:mixify/data/network/spotify_api_service.dart';
import 'package:mixify/data/network/youtube_api_service.dart';
import 'package:mixify/data/preferences/user_preferences.dart';
import 'package:mixify/data/repository/music_repository.dart';
import 'package:mixify/player/mixify_audio_handler.dart';

import 'package:mixify/data/repository/download_repository.dart';
import 'package:mixify/data/repository/playlist_repository.dart'; // Added this import based on playlistRepositoryProvider

final youtubeApiServiceProvider = Provider<YouTubeApiService>((ref) {
  return YouTubeApiService();
});

final spotifyApiServiceProvider = Provider<SpotifyApiService>((ref) {
  return SpotifyApiService();
});

final musicRepositoryProvider = Provider<MusicRepository>((ref) {
  throw UnimplementedError('MusicRepository must be overridden in main');
});

final audioHandlerProvider = Provider<MixifyAudioHandler>((ref) {
  throw UnimplementedError('AudioHandler must be overridden in main');
});

final userPreferencesProvider = Provider<UserPreferences>((ref) {
  throw UnimplementedError('UserPreferences must be overridden in main');
});

final playlistRepositoryProvider = Provider<PlaylistRepository>((ref) {
  throw UnimplementedError('PlaylistRepository must be overridden in main');
});

final downloadRepositoryProvider = Provider<DownloadRepository>((ref) {
  throw UnimplementedError('DownloadRepository must be overridden in main');
});

final connectivityProvider = StreamProvider<List<ConnectivityResult>>((ref) {
  return Connectivity().onConnectivityChanged;
});
