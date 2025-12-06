import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mixify/data/models/playlist_model.dart';
import 'package:mixify/data/models/innertube_models.dart';
import 'package:uuid/uuid.dart';

import 'package:mixify/data/services/firestore_service.dart';

class PlaylistRepository {
  static const String _boxName = 'playlists';
  late Box<LocalPlaylist> _box;
  final FirestoreService _firestoreService = FirestoreService();

  Future<void> init() async {
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(LocalPlaylistAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(HiveSongAdapter());
    }
    _box = await Hive.openBox<LocalPlaylist>(_boxName);
  }
  
  // Sync from cloud
  Future<void> syncFromCloud() async {
    try {
      final playlists = await _firestoreService.getPlaylists();
      
      // Clear existing playlists to avoid duplication/stale data
      await _box.clear();

      for (final p in playlists) {
        // Convert map to LocalPlaylist
        final songs = (p['songs'] as List).map((s) => HiveSong(
          videoId: s['videoId'],
          title: s['title'],
          artist: s['artist'],
          thumbnailUrl: s['thumbnailUrl'],
        )).toList();
        
        final playlist = LocalPlaylist(
          id: p['id'],
          name: p['name'],
          songs: songs,
          imagePath: p['imagePath'],
        );
        await _box.put(playlist.id, playlist);
      }
    } catch (e) {
      debugPrint('Error syncing playlists from cloud: $e');
    }
  }

  Future<void> clearLocalData() async {
    await _box.clear();
  }

  List<LocalPlaylist> getPlaylists() {
    return _box.values.toList();
  }

  // Expose listenable for UI updates
  ValueListenable<Box<LocalPlaylist>> get boxListenable => _box.listenable();

  Future<void> createPlaylist(String name) async {
    final id = const Uuid().v4();
    final playlist = LocalPlaylist(id: id, name: name, songs: []);
    await _box.put(id, playlist);
    _syncPlaylist(playlist);
  }

  Future<void> deletePlaylist(String id) async {
    await _box.delete(id);
    _firestoreService.deletePlaylist(id);
  }

  Future<void> addSongToPlaylist(String playlistId, Song song) async {
    final playlist = _box.get(playlistId);
    if (playlist != null) {
      final hiveSong = HiveSong.fromSong(song);
      playlist.songs.add(hiveSong);
      await playlist.save();
      _syncPlaylist(playlist);
    }
  }
  
  Future<void> removeSongFromPlaylist(String playlistId, String videoId) async {
    final playlist = _box.get(playlistId);
    if (playlist != null) {
      playlist.songs.removeWhere((s) => s.videoId == videoId);
      await playlist.save();
      _syncPlaylist(playlist);
    }
  }
  
  Future<void> updatePlaylist(LocalPlaylist playlist) async {
    await playlist.save();
    _syncPlaylist(playlist);
  }

  void _syncPlaylist(LocalPlaylist playlist) {
    _firestoreService.savePlaylist({
      'id': playlist.id,
      'name': playlist.name,
      'imagePath': playlist.imagePath,
      'songs': playlist.songs.map((s) => {
        'videoId': s.videoId,
        'title': s.title,
        'artist': s.artist,
        'thumbnailUrl': s.thumbnailUrl,
      }).toList(),
    });
  }
}


