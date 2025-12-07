import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixify/data/providers.dart';
import 'package:mixify/data/repository/download_repository.dart';
import 'package:mixify/main.dart';
import 'package:mixify/data/models/innertube_models.dart';
import 'package:mixify/data/models/playlist_model.dart';
import 'package:mixify/player/mixify_audio_handler.dart';
import 'package:mixify/ui/screens/player_screen.dart';
import 'package:mixify/ui/screens/playlist_detail_screen.dart';

class DownloadsScreen extends ConsumerStatefulWidget {
  const DownloadsScreen({super.key});

  @override
  ConsumerState<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends ConsumerState<DownloadsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {}); // Rebuild to update tab colors
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final downloadRepo = ref.watch(downloadRepositoryProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Active Downloads Section
            StreamBuilder<List<DownloadItem>>(
              stream: downloadRepo.downloadStream,
              builder: (context, snapshot) {
                final activeDownloads = snapshot.data ?? [];
                if (activeDownloads.isEmpty) return const SizedBox.shrink();

                return Container(
                  color: isDark ? Colors.grey[900] : Colors.grey[200],
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Downloading...", style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ...activeDownloads.map((item) => _buildDownloadItem(item, theme)),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Row(
                  children: [
                    _buildTabHeader("Songs", 0, isDark, theme),
                    const SizedBox(width: 20),
                    _buildTabHeader("Albums", 1, isDark, theme),
                    const SizedBox(width: 20),
                    _buildTabHeader("Playlists", 2, isDark, theme),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                physics: const BouncingScrollPhysics(),
                children: [
                  _buildSongsTab(theme),
                  _buildAlbumsTab(theme),
                  _buildPlaceholderTab("No downloaded playlists", theme),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabHeader(String title, int index, bool isDark, ThemeData theme) {
    return GestureDetector(
      onTap: () => _tabController.animateTo(index),
      child: Text(
        title,
        style: theme.textTheme.displayMedium?.copyWith(
              color: _tabController.index == index 
                  ? (isDark ? AppColors.yellow : AppColors.black) 
                  : theme.colorScheme.onSurface.withOpacity(0.4),
              fontWeight: FontWeight.bold,
              fontSize: 40,
            ),
      ),
    );
  }

  Widget _buildDownloadItem(DownloadItem item, ThemeData theme) {
    return Card(
      color: Colors.transparent,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Image.network(
              item.metadata['thumbnailUrl'] ?? "",
              width: 50,
              height: 50,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(color: Colors.grey, width: 50, height: 50),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.metadata['title'], style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold), maxLines: 1),
                const SizedBox(height: 4),
                if (item.status == DownloadStatus.failed)
                  Text("Failed: ${item.error}", style: const TextStyle(color: Colors.red, fontSize: 12))
                else
                  Row(
                    children: [
                      Expanded(
                        child: LinearProgressIndicator(
                          value: item.progress,
                          backgroundColor: Colors.grey[700],
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.yellow),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text("${(item.progress * 100).toInt()}%", style: theme.textTheme.bodySmall),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSongsTab(ThemeData theme) {
    final downloadRepo = ref.watch(downloadRepositoryProvider);

    return ValueListenableBuilder(
      valueListenable: downloadRepo.songsBoxListenable,
      builder: (context, box, _) {
        final songsData = downloadRepo.getAllDownloadedSongs();

        if (songsData.isEmpty) {
          return Center(child: Text("No downloaded songs", style: theme.textTheme.bodyLarge));
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          itemCount: songsData.length,
          itemBuilder: (context, index) {
            final songData = songsData[index];
            ImageProvider imageProvider;
            
            if (songData['localThumbnailPath'] != null && File(songData['localThumbnailPath']).existsSync()) {
              imageProvider = FileImage(File(songData['localThumbnailPath']));
            } else {
              imageProvider = NetworkImage(songData['thumbnailUrl'] ?? "");
            }

            final song = Song(
              videoId: songData['id'],
              title: songData['title'],
              artist: songData['artist'],
              thumbnailUrl: songData['thumbnailUrl'] ?? "",
            );

            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image(
                  image: imageProvider,
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(color: Colors.grey, width: 50, height: 50),
                ),
              ),
              title: Text(
                song.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                song.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.grey),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text("Delete Song"),
                      content: Text("Are you sure you want to delete '${song.title}'?"),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text("Cancel", style: TextStyle(color: AppColors.black)),
                        ),
                        TextButton(
                          onPressed: () async {
                            await downloadRepo.deleteSong(songData['id']);
                            if (context.mounted) Navigator.pop(context);
                          },
                          child: const Text("Delete", style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );
                },
              ),
              onTap: () async {
                final audioHandler = ref.read(audioHandlerProvider);
                final songs = songsData.map((s) => Song(
                  videoId: s['id'],
                  title: s['title'],
                  artist: s['artist'],
                  thumbnailUrl: s['thumbnailUrl'] ?? "",
                )).toList();
                
                if (audioHandler is MixifyAudioHandler) {
                  await audioHandler.playList(songs, index);
                  if (mounted) {
                    Navigator.of(context, rootNavigator: true).push(
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) => const PlayerScreen(),
                        transitionsBuilder: (context, animation, secondaryAnimation, child) {
                          const begin = Offset(0.0, 1.0);
                          const end = Offset.zero;
                          const curve = Curves.easeInOut;
                          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                          return SlideTransition(position: animation.drive(tween), child: child);
                        },
                      ),
                    );
                  }
                }
              },
            );
          },
        );
      }
    );
  }

  Widget _buildAlbumsTab(ThemeData theme) {
    final downloadRepo = ref.watch(downloadRepositoryProvider);
    
    return ValueListenableBuilder(
      valueListenable: downloadRepo.songsBoxListenable,
      builder: (context, box, _) {
        final songsData = downloadRepo.getAllDownloadedSongs();
        
        // Group by Album (using 'album' field if available, or just grouping by artist/unknown)
        // Since our download model might not save album name explicitly in all cases, we check.
        // Actually, our DownloadRepository saves 'album' in metadata.
        
        final Map<String, List<Map<String, dynamic>>> albums = {};
        for (final song in songsData) {
          final albumName = song['album'] ?? "Unknown Album";
          if (!albums.containsKey(albumName)) {
            albums[albumName] = [];
          }
          albums[albumName]!.add(song);
        }
        
        final albumNames = albums.keys.toList();

        if (albumNames.isEmpty) {
          return Center(child: Text("No downloaded albums", style: theme.textTheme.bodyLarge));
        }

        return GridView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.8,
          ),
          itemCount: albumNames.length,
          itemBuilder: (context, index) {
            final albumName = albumNames[index];
            final songs = albums[albumName]!;
            final firstSong = songs.first;
            
            ImageProvider imageProvider;
            if (firstSong['localThumbnailPath'] != null && File(firstSong['localThumbnailPath']).existsSync()) {
              imageProvider = FileImage(File(firstSong['localThumbnailPath']));
            } else {
              imageProvider = NetworkImage(firstSong['thumbnailUrl'] ?? "");
            }
            
            final artist = firstSong['artist'] ?? "Unknown Artist";
    
            return GestureDetector(
              onTap: () {
                 final tempPlaylist = LocalPlaylist(
                   id: "downloaded_album_$index",
                   name: albumName,
                   songs: songs.map((s) => HiveSong(
                     videoId: s['id'],
                     title: s['title'],
                     artist: s['artist'],
                     thumbnailUrl: s['thumbnailUrl'] ?? "",
                   )).toList(),
                   imagePath: null,
                 );
                 
                 Navigator.push(
                   context,
                   MaterialPageRoute(
                     builder: (context) => PlaylistDetailScreen(playlist: tempPlaylist),
                   ),
                 );
              },
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.black.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Stack(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                            child: Image(
                              image: imageProvider,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.album, size: 50, color: Colors.grey)),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                albumName,
                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                artist,
                                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.white, size: 20),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text("Delete Album"),
                                content: Text("Are you sure you want to delete all songs in '$albumName'?"),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text("Cancel", style: TextStyle(color: AppColors.black)),
                                  ),
                                  TextButton(
                                    onPressed: () async {
                                      for (final song in songs) {
                                        await downloadRepo.deleteSong(song['id']);
                                      }
                                      if (context.mounted) Navigator.pop(context);
                                    },
                                    child: const Text("Delete", style: TextStyle(color: Colors.red)),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }
    );
  }

  Widget _buildPlaceholderTab(String message, ThemeData theme) {
    return Center(
      child: Text(message, style: theme.textTheme.bodyLarge),
    );
  }
}
