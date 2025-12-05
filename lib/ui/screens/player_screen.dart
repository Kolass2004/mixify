import 'dart:math';
import 'dart:ui';

import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixify/data/models/innertube_models.dart';
import 'package:mixify/data/providers.dart';
import 'package:mixify/data/repository/playlist_repository.dart';
import 'package:mixify/main.dart'; // For AppColors

class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final audioHandler = ref.watch(audioHandlerProvider);

    return StreamBuilder<MediaItem?>(
      stream: audioHandler.mediaItem,
      builder: (context, snapshot) {
        final mediaItem = snapshot.data;
        if (mediaItem == null) {
          return const Scaffold(
            backgroundColor: AppColors.black,
            body: Center(child: Text("No music playing", style: TextStyle(color: Colors.white))),
          );
        }

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              // 1. Blurred Background
              Positioned.fill(
                child: CachedNetworkImage(
                  imageUrl: mediaItem.artUri.toString(),
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(color: AppColors.black),
                ),
              ),
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                  child: Container(
                    color: Colors.black.withOpacity(0.5), // Dark overlay for readability
                  ),
                ),
              ),

              // 2. Content
              SafeArea(
                child: Column(
                  children: [
                    // AppBar
                    AppBar(
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      leading: IconButton(
                        icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 30),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      actions: [
                        IconButton(
                          icon: const Icon(Icons.playlist_play, color: Colors.white, size: 30),
                          onPressed: () {
                             showModalBottomSheet(
                              context: context,
                              backgroundColor: Colors.transparent,
                              builder: (context) => const QueueBottomSheet(),
                            );
                          },
                        ),
                      ],
                    ),
                    
                    const Spacer(),

                    // Vinyl Record
                    StreamBuilder<PlaybackState>(
                      stream: audioHandler.playbackState,
                      builder: (context, stateSnapshot) {
                        final playing = stateSnapshot.data?.playing ?? false;
                        if (playing) {
                          _rotationController.repeat();
                        } else {
                          _rotationController.stop();
                        }

                        return AnimatedBuilder(
                          animation: _rotationController,
                          builder: (context, child) {
                            return Transform.rotate(
                              angle: _rotationController.value * 2 * pi,
                              child: Container(
                                width: 300,
                                height: 300,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.black,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black45,
                                      blurRadius: 20,
                                      offset: Offset(0, 10),
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.all(40), // Vinyl rim
                                child: ClipOval(
                                  child: CachedNetworkImage(
                                    imageUrl: mediaItem.artUri.toString(),
                                    fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) => const Icon(Icons.music_note, color: Colors.white),
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      }
                    ),

                    const Spacer(),
                    
                    // Song Info & Add to Playlist
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  mediaItem.title,
                                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  mediaItem.artist ?? "Unknown Artist",
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.playlist_add, color: Colors.white, size: 30),
                            onPressed: () => _showAddToPlaylistDialog(context, mediaItem),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Progress Bar
                    StreamBuilder<Duration>(
                      stream: AudioService.position,
                      builder: (context, positionSnapshot) {
                        final position = positionSnapshot.data ?? Duration.zero;
                        final duration = mediaItem.duration ?? Duration.zero;
                        
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: Column(
                            children: [
                              SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 4,
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                                  activeTrackColor: Colors.white,
                                  inactiveTrackColor: Colors.white24,
                                  thumbColor: Colors.white,
                                  overlayColor: Colors.white.withOpacity(0.2),
                                ),
                                child: Slider(
                                  value: min(position.inMilliseconds.toDouble(), duration.inMilliseconds.toDouble()),
                                  max: duration.inMilliseconds.toDouble(),
                                  onChanged: (value) {
                                    audioHandler.seek(Duration(milliseconds: value.toInt()));
                                  },
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(_formatDuration(position), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                    Text(_formatDuration(duration), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    
                    const SizedBox(height: 10),

                    // Controls
                    StreamBuilder<PlaybackState>(
                      stream: audioHandler.playbackState,
                      builder: (context, stateSnapshot) {
                        final state = stateSnapshot.data;
                        final playing = state?.playing ?? false;
                        final repeatMode = state?.repeatMode ?? AudioServiceRepeatMode.none;
                        final shuffleMode = state?.shuffleMode ?? AudioServiceShuffleMode.none;

                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // Shuffle
                            IconButton(
                              icon: Icon(Icons.shuffle, color: shuffleMode == AudioServiceShuffleMode.all ? AppColors.yellow : Colors.white),
                              onPressed: () {
                                final newMode = shuffleMode == AudioServiceShuffleMode.none
                                    ? AudioServiceShuffleMode.all
                                    : AudioServiceShuffleMode.none;
                                audioHandler.setShuffleMode(newMode);
                              },
                            ),
                            
                            // Previous
                            IconButton(
                              icon: const Icon(Icons.skip_previous_rounded, size: 45, color: Colors.white),
                              onPressed: () => audioHandler.skipToPrevious(),
                            ),
                            
                            // Play/Pause
                            Container(
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                              ),
                              child: IconButton(
                                icon: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 50, color: Colors.black),
                                onPressed: () => playing ? audioHandler.pause() : audioHandler.play(),
                              ),
                            ),
                            
                            // Next
                            IconButton(
                              icon: const Icon(Icons.skip_next_rounded, size: 45, color: Colors.white),
                              onPressed: () => audioHandler.skipToNext(),
                            ),
                            
                            // Repeat
                            IconButton(
                              icon: Icon(
                                repeatMode == AudioServiceRepeatMode.one ? Icons.repeat_one : Icons.repeat,
                                color: repeatMode == AudioServiceRepeatMode.none ? Colors.white : AppColors.yellow,
                              ),
                              onPressed: () {
                                AudioServiceRepeatMode newMode;
                                if (repeatMode == AudioServiceRepeatMode.none) {
                                  newMode = AudioServiceRepeatMode.all;
                                } else if (repeatMode == AudioServiceRepeatMode.all) {
                                  newMode = AudioServiceRepeatMode.one;
                                } else {
                                  newMode = AudioServiceRepeatMode.none;
                                }
                                audioHandler.setRepeatMode(newMode);
                              },
                            ),
                          ],
                        );
                      }
                    ),
                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAddToPlaylistDialog(BuildContext context, MediaItem mediaItem) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        final playlistRepo = ref.watch(playlistRepositoryProvider);
        final playlists = playlistRepo.getPlaylists();
        
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Add to Playlist", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () {
                      Navigator.pop(context);
                      _showCreatePlaylistDialog(context, mediaItem);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (playlists.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: Text("No playlists found. Create one!")),
                )
              else
                Expanded(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: playlists.length,
                    itemBuilder: (context, index) {
                      final playlist = playlists[index];
                      return ListTile(
                        leading: const Icon(Icons.music_note),
                        title: Text(playlist.name),
                        subtitle: Text("${playlist.songs.length} songs"),
                        onTap: () async {
                          final song = Song(
                            videoId: mediaItem.id,
                            title: mediaItem.title,
                            artist: mediaItem.artist ?? "Unknown",
                            thumbnailUrl: mediaItem.artUri.toString(),
                          );
                          await playlistRepo.addSongToPlaylist(playlist.id, song);
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Added to ${playlist.name}")),
                            );
                          }
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showCreatePlaylistDialog(BuildContext context, MediaItem mediaItem) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("New Playlist"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: "Playlist Name"),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                final playlistRepo = ref.read(playlistRepositoryProvider);
                await playlistRepo.createPlaylist(controller.text);
                
                // Get the newly created playlist (it will be the last one or we can search by name)
                // For simplicity, we just created it. Now let's add the song to it.
                // But we need the ID. Let's just refresh the list and let user pick it, 
                // or better, modify createPlaylist to return ID.
                // For now, let's just close and show the list again.
                
                if (context.mounted) {
                  Navigator.pop(context); // Close dialog
                  _showAddToPlaylistDialog(context, mediaItem); // Re-open list
                }
              }
            },
            child: const Text("Create"),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }
}

class QueueBottomSheet extends ConsumerWidget {
  const QueueBottomSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioHandler = ref.watch(audioHandlerProvider);
    
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: StreamBuilder<List<MediaItem>>(
        stream: audioHandler.queue,
        builder: (context, snapshot) {
          final queue = snapshot.data ?? [];
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text("Up Next", style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppColors.black, fontWeight: FontWeight.bold)),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: queue.length,
                  itemBuilder: (context, index) {
                    final item = queue[index];
                    return ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: CachedNetworkImage(
                          imageUrl: item.artUri.toString(),
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(color: Colors.grey),
                        ),
                      ),
                      title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.black, fontWeight: FontWeight.bold)),
                      subtitle: Text(item.artist ?? "", maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey)),
                      onTap: () {
                        audioHandler.skipToQueueItem(index);
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
