import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mixify/data/models/innertube_models.dart';
import 'package:mixify/data/preferences/user_preferences.dart';
import 'package:mixify/data/repository/download_repository.dart';
import 'package:mixify/data/repository/music_repository.dart';
import 'package:uuid/uuid.dart';

class MixifyAudioHandler extends BaseAudioHandler {
  final _player = AudioPlayer();
  final _playlist = ConcatenatingAudioSource(children: []);
  final UserPreferences _prefs;
  final MusicRepository _musicRepository;
  final DownloadRepository _downloadRepository;

  MixifyAudioHandler(this._prefs, this._musicRepository, this._downloadRepository) {
    _loadEmptyPlaylist();
    _notifyAudioHandlerAboutPlaybackEvents();
    _listenToPlaybackState();
    _listenToBufferedPosition();
    _listenToTotalDuration();
    _listenToChangesInSong();
    _listenToProcessingState();
    _restoreLastState();
  }

  Future<void> _restoreLastState() async {
    try {
      final lastQueue = _prefs.getLastQueue();
      final lastMediaItemMap = _prefs.getLastMediaItem();
      final lastPosition = _prefs.getLastPosition();

      if (lastQueue.isNotEmpty) {
        final items = lastQueue.map((e) => _mediaItemFromJson(e)).toList();
        
        // Check for invalid IDs (legacy data fix)
        final hasInvalidIds = items.any((item) => item.id.isEmpty);
        
        if (hasInvalidIds) {
          print("Detected legacy queue with missing IDs. Clearing player state.");
          await _prefs.saveLastState(null, [], 0); // Clear storage
          return; // Do not restore
        }

        queue.add(items);
        
        if (lastMediaItemMap != null) {
          final item = _mediaItemFromJson(lastMediaItemMap);
          // Ensure current item also has a valid ID
          if (item.id.isNotEmpty) {
             mediaItem.add(item);
             
             if (item.extras?['url'] != null) {
                await _player.setAudioSource(AudioSource.uri(Uri.parse(item.extras!['url']!), tag: item));
                if (lastPosition > 0) {
                  await _player.seek(Duration(milliseconds: lastPosition));
                }
             }
          }
        }
      }
    } catch (e) {
      print("Error restoring state: $e");
    }
  }

  void _saveState() {
    final currentItem = mediaItem.value;
    final currentQueue = queue.value;
    final position = _player.position.inMilliseconds;
    
    _prefs.saveLastState(
      currentItem != null ? _mediaItemToJson(currentItem) : null, 
      currentQueue.map((e) => _mediaItemToJson(e)).toList(), 
      position
    );
  }

  Map<String, dynamic> _mediaItemToJson(MediaItem item) {
    return {
      'id': item.id,
      'album': item.album,
      'title': item.title,
      'artist': item.artist,
      'artUri': item.artUri?.toString(),
      'extras': item.extras,
    };
  }

  MediaItem _mediaItemFromJson(Map<String, dynamic> json) {
    return MediaItem(
      id: json['id'] ?? "",
      album: json['album'],
      title: json['title'],
      artist: json['artist'],
      artUri: json['artUri'] != null ? Uri.parse(json['artUri']) : null,
      extras: json['extras'] != null ? Map<String, dynamic>.from(json['extras']) : null,
    );
  }

  Future<void> _loadEmptyPlaylist() async {
    try {
      await _player.setAudioSource(_playlist);
    } catch (e) {
      print("Error loading playlist: $e");
    }
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> stop() async {
    await _player.stop();
    return super.stop();
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index >= 0 && index < queue.value.length) {
      await _player.seek(Duration.zero, index: index);
    }
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    switch (repeatMode) {
      case AudioServiceRepeatMode.none:
        await _player.setLoopMode(LoopMode.off);
        break;
      case AudioServiceRepeatMode.one:
        await _player.setLoopMode(LoopMode.one);
        break;
      case AudioServiceRepeatMode.group:
      case AudioServiceRepeatMode.all:
        await _player.setLoopMode(LoopMode.all);
        break;
    }
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    if (shuffleMode == AudioServiceShuffleMode.none) {
      await _player.setShuffleModeEnabled(false);
    } else {
      await _player.setShuffleModeEnabled(true);
    }
  }

  Future<void> setVolume(double volume) async {
    await _player.setVolume(volume);
  }

  @override
  Future<void> addQueueItem(MediaItem mediaItem) async {
    final newQueue = queue.value..add(mediaItem);
    queue.add(newQueue);
  }

  // Play a single song (legacy support, clears queue)
  Future<void> playSong(Song song, String url) async {
    // Check if already playing this song
    if (mediaItem.value != null) {
      final current = mediaItem.value!;
      if ((song.videoId.isNotEmpty && song.videoId == current.id) || 
          (song.title == current.title && song.artist == current.artist)) {
        return;
      }
    }

    final item = MediaItem(
      id: song.videoId.isNotEmpty ? song.videoId : const Uuid().v4(),
      album: "YouTube Music",
      title: song.title,
      artist: song.artist,
      artUri: Uri.parse(song.thumbnailUrl),
      extras: {'url': url},
    );

    queue.add([item]);
    mediaItem.add(item);
    
    final currentSkipId = ++_skipId;

    try {
      await _player.setAudioSource(AudioSource.uri(Uri.parse(url), tag: item));
      await _player.play();
      
      _addToHistoryAfterDelay(item, currentSkipId);
    } catch (e) {
      print("Error playing song: $e");
    }
  }

  // Play a list of songs, starting at index
  Future<void> playList(List<Song> songs, int index) async {
    // Check if already playing this song
    if (mediaItem.value != null && index >= 0 && index < songs.length) {
      final song = songs[index];
      final current = mediaItem.value!;
      if ((song.videoId.isNotEmpty && song.videoId == current.id) || 
          (song.title == current.title && song.artist == current.artist)) {
        return;
      }
    }

    // Convert Songs to MediaItems
    final items = songs.map((s) => MediaItem(
      id: s.videoId.isNotEmpty ? s.videoId : const Uuid().v4(),
      album: "YouTube Music",
      title: s.title,
      artist: s.artist,
      artUri: Uri.parse(s.thumbnailUrl),
      extras: {'url': null}, // URL not known yet
    )).toList();

    // Update Queue
    queue.add(items);
    
    // Set Loop Mode to all by default for playlists (as requested)
    await _player.setLoopMode(LoopMode.all);
    
    // Play the selected item
    await _skipToindex(index);
  }

  Future<void> _skipToindex(int index) async {
    if (index < 0 || index >= queue.value.length) return;
    
    final currentSkipId = ++_skipId;
    
    final item = queue.value[index];
    mediaItem.add(item); // Notify UI immediately

    try {
      // Check if we already have the URL
      String? url = item.extras?['url'];
      
      // Check for offline file first
      if (url == null) {
        final downloadedSong = _downloadRepository.getDownloadedSong(item.id);
        if (downloadedSong != null && downloadedSong['localPath'] != null) {
           final file = File(downloadedSong['localPath']);
           if (await file.exists()) {
             url = file.path;
             print("Playing from offline file: $url");
           }
        }
      }
      
      if (url == null) {
        // Fetch URL using MusicRepository
        try {
           // Use item.id as videoId if it looks like a YouTube ID (usually 11 chars)
           // But our getStreamUrl handles fallback, so just pass it.
           // Note: item.id might be a UUID for local files or Spotify IDs.
           // If it's a Spotify ID (22 chars), direct YouTube playback will fail and it will fallback to search, which is correct.
           // If it's a YouTube ID (11 chars), it will play directly.
           
           String? videoId = item.id;
           // Simple check to avoid passing UUIDs (which are 36 chars) as video IDs to YouTube API
           if (videoId.length > 20 && videoId.contains('-')) {
             videoId = null; 
           }
           
           url = await _musicRepository.getStreamUrl(item.title, item.artist ?? "", videoId: videoId);
           
           // Check if skipped again during fetch
           if (_skipId != currentSkipId) return;

           // Update item with URL to avoid re-fetching
           final updatedItem = item.copyWith(extras: {'url': url});
           
           // Create a new list to ensure stream updates
           final currentQueue = List<MediaItem>.from(queue.value);
           if (index < currentQueue.length) {
             currentQueue[index] = updatedItem;
             queue.add(currentQueue);
           }
           mediaItem.add(updatedItem);
        } catch (e) {
          print("Failed to fetch URL for ${item.title}: $e");
          return;
        }
      }

      // Check if skipped again
      if (_skipId != currentSkipId) return;

      if (url != null) {
        try {
          await _player.setAudioSource(AudioSource.uri(Uri.parse(url), tag: item));
          await _player.play();
          
          // Add to history after delay to ensure it's actually played
          _addToHistoryAfterDelay(item, currentSkipId);
        } catch (e) {
           if (e.toString().contains("Connection aborted") || e.toString().contains("abort")) {
             // Ignore aborts as they are likely due to rapid skipping
             print("Playback aborted for ${item.title}, likely skipped.");
           } else {
             print("Error setting audio source: $e");
             // rethrow; // Don't rethrow to avoid crashing
           }
        }
      }
    } catch (e) {
      print("Error playing item at index $index: $e");
    }
  }

  int _skipId = 0;

  Future<void> _addToHistoryAfterDelay(MediaItem item, int skipId) async {
    await Future.delayed(const Duration(seconds: 10));
    if (_skipId == skipId && _player.playing) {
       _prefs.addSongToHistory(_mediaItemToJson(item));
    }
  }

  void _listenToProcessingState() {
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        // Song finished, play next
        _playNextInQueue();
      }
    });
  }

  Future<void> _playNextInQueue() async {
    final currentItem = mediaItem.value;
    final currentQueue = queue.value;
    if (currentItem == null || currentQueue.isEmpty) return;

    // Robust index finding: Match by ID first, then Title+Artist
    int currentIndex = currentQueue.indexWhere((item) => item.id == currentItem.id);

    if (currentIndex == -1) {
       currentIndex = currentQueue.indexWhere((item) => item.title == currentItem.title && item.artist == currentItem.artist);
    }
    
    print("PlayNext: Current Index: $currentIndex, Queue Length: ${currentQueue.length}");

    // Handle Repeat Modes
    if (_player.loopMode == LoopMode.one) {
       await _player.seek(Duration.zero);
       await _player.play();
       return;
    }

    if (currentIndex >= 0 && currentIndex + 1 < currentQueue.length) {
      await _skipToindex(currentIndex + 1);
    } else if (_player.loopMode == LoopMode.all) {
      await _skipToindex(0); // Loop back to start
    } else {
      // Auto-play / Radio Feature - DISABLED as per user request (prefer looping)
      // print("End of queue, fetching recommendations...");
      
      // If we are here, it means LoopMode is OFF or ONE (but ONE is handled above).
      // So LoopMode is OFF.
      // Standard behavior is to STOP.
      // But user complained about "random songs", so we definitely stop auto-play.
      // If they want to "start over", they should use LoopMode.all (which we set by default).
      // If they manually turned off loop, we should probably just stop.
      
      await stop();
      
      /* 
      try {
        final song = Song(
          videoId: currentItem.id,
          title: currentItem.title,
          artist: currentItem.artist ?? "Unknown",
          thumbnailUrl: currentItem.artUri.toString(),
        );
        
        final recommendations = await _musicRepository.getRecommendations(song);
        if (recommendations.isNotEmpty) {
          // Add to queue
          final newItems = recommendations.map((s) => MediaItem(
            id: s.videoId,
            album: "Radio",
            title: s.title,
            artist: s.artist,
            artUri: Uri.parse(s.thumbnailUrl),
            extras: {'url': null},
          )).toList();
          
          final List<MediaItem> newQueue = [...currentQueue, ...newItems];
          queue.add(newQueue);
          
          // Play next (which is the first of new items)
          await _skipToindex(currentIndex + 1);
        }
      } catch (e) {
        print("Error fetching recommendations for auto-play: $e");
      }
      */
    }
  }
  
  @override
  Future<void> skipToNext() async {
     await _playNextInQueue();
  }
  
  @override
  Future<void> skipToPrevious() async {
    final currentItem = mediaItem.value;
    final currentQueue = queue.value;
    if (currentItem == null || currentQueue.isEmpty) return;
    
    // If we are more than 3 seconds in, restart song
    if (_player.position.inSeconds > 3) {
      await _player.seek(Duration.zero);
      return;
    }
    
    int currentIndex = currentQueue.indexWhere((item) => item.id == currentItem.id);
    if (currentIndex == -1) {
       currentIndex = currentQueue.indexWhere((item) => item.title == currentItem.title && item.artist == currentItem.artist);
    }

    if (currentIndex > 0) {
      await _skipToindex(currentIndex - 1);
    } else {
      await _player.seek(Duration.zero);
    }
  }

  void _notifyAudioHandlerAboutPlaybackEvents() {
    _player.playbackEventStream.listen((PlaybackEvent event) {
      final playing = _player.playing;
      playbackState.add(playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.stop,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
        },
        androidCompactActionIndices: const [0, 1, 3],
        processingState: const {
          ProcessingState.idle: AudioProcessingState.idle,
          ProcessingState.loading: AudioProcessingState.loading,
          ProcessingState.buffering: AudioProcessingState.buffering,
          ProcessingState.ready: AudioProcessingState.ready,
          ProcessingState.completed: AudioProcessingState.completed,
        }[_player.processingState]!,
        repeatMode: const {
          LoopMode.off: AudioServiceRepeatMode.none,
          LoopMode.one: AudioServiceRepeatMode.one,
          LoopMode.all: AudioServiceRepeatMode.all,
        }[_player.loopMode]!,
        shuffleMode: (_player.shuffleModeEnabled)
            ? AudioServiceShuffleMode.all
            : AudioServiceShuffleMode.none,
        playing: playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: event.currentIndex,
      ));
      _saveState();
    });
  }

  void _listenToPlaybackState() {
    _player.playerStateStream.listen((state) {
        // Handled in _notifyAudioHandlerAboutPlaybackEvents
    });
  }

  void _listenToBufferedPosition() {
    _player.bufferedPositionStream.listen((bufferedPosition) {
      playbackState.add(playbackState.value.copyWith(bufferedPosition: bufferedPosition));
    });
  }

  void _listenToTotalDuration() {
    _player.durationStream.listen((totalDuration) {
       final currentItem = mediaItem.value;
       if (currentItem != null && totalDuration != null) {
         mediaItem.add(currentItem.copyWith(duration: totalDuration));
       }
    });
  }

  void _listenToChangesInSong() {
    // Not needed as we manually update mediaItem in _skipToindex
  }

  @override
  Future<void> onTaskRemoved() async {
    await stop();
  }

  int? get androidAudioSessionId => _player.androidAudioSessionId;
}
