import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mixify/data/models/playlist_model.dart';
import 'package:mixify/data/providers.dart';
import 'package:mixify/data/repository/playlist_repository.dart';
import 'package:mixify/main.dart';
import 'package:mixify/ui/screens/player_screen.dart';
import 'package:mixify/player/mixify_audio_handler.dart';
import 'package:mixify/ui/screens/playlist_search_screen.dart';
import 'package:permission_handler/permission_handler.dart';

class PlaylistDetailScreen extends ConsumerStatefulWidget {
  final LocalPlaylist playlist;

  const PlaylistDetailScreen({super.key, required this.playlist});

  @override
  ConsumerState<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends ConsumerState<PlaylistDetailScreen> {
  late List<HiveSong> _filteredSongs;
  final _searchController = TextEditingController();
  String _sortOption = 'Custom'; // Custom, A-Z, Artist, Newest

  @override
  void initState() {
    super.initState();
    _filteredSongs = widget.playlist.songs;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterSongs(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredSongs = widget.playlist.songs;
      } else {
        _filteredSongs = widget.playlist.songs.where((song) => 
          song.title.toLowerCase().contains(query.toLowerCase()) ||
          song.artist.toLowerCase().contains(query.toLowerCase())
        ).toList();
      }
      _applySort();
    });
  }

  void _applySort() {
    switch (_sortOption) {
      case 'A-Z':
        _filteredSongs.sort((a, b) => a.title.compareTo(b.title));
        break;
      case 'Artist':
        _filteredSongs.sort((a, b) => a.artist.compareTo(b.artist));
        break;
      case 'Newest':
        // Assuming the list order is insertion order, reverse it
        _filteredSongs = _filteredSongs.reversed.toList();
        break;
      case 'Custom':
      default:
        // Default order (insertion order usually)
        break;
    }
  }

  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: const Text("Custom Order"), onTap: () => _setSort('Custom')),
            ListTile(title: const Text("Title (A-Z)"), onTap: () => _setSort('A-Z')),
            ListTile(title: const Text("Artist"), onTap: () => _setSort('Artist')),
            ListTile(title: const Text("Newest Added"), onTap: () => _setSort('Newest')),
          ],
        );
      },
    );
  }

  void _setSort(String option) {
    setState(() {
      _sortOption = option;
      _applySort();
    });
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.white : AppColors.black;
    final backgroundColor = isDark ? AppColors.black : AppColors.white;
    final primaryColor = isDark ? AppColors.yellow : AppColors.black;
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 350,
            pinned: true,
            backgroundColor: backgroundColor,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: textColor),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      primaryColor.withOpacity(0.3),
                      backgroundColor,
                    ],
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 60),
                    GestureDetector(
                      onTap: () => _showEditDialog(context, ref),
                      child: Container(
                        width: 180,
                        height: 180,
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: widget.playlist.imagePath != null
                            ? Image.file(File(widget.playlist.imagePath!), fit: BoxFit.cover)
                            : widget.playlist.songs.isEmpty
                                ? Container(color: Colors.grey[800], child: const Icon(Icons.music_note, size: 80, color: Colors.white))
                                : _buildHeaderCollage(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        widget.playlist.name,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Creator Info
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (user?.photoURL != null)
                          CircleAvatar(
                            radius: 10,
                            backgroundImage: NetworkImage(user!.photoURL!),
                          )
                        else
                          CircleAvatar(
                            radius: 10,
                            backgroundColor: Colors.grey[800],
                            child: const Icon(Icons.person, size: 12, color: Colors.white),
                          ),
                        const SizedBox(width: 8),
                        Text(
                          user?.displayName ?? "Mixify User", 
                          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Column(
                children: [
                  // Controls Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(Icons.download_for_offline_outlined, color: textColor.withOpacity(0.7), size: 30),
                            onPressed: _downloadPlaylist,
                          ),
                          // Removed Add Person and More Options
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(Icons.shuffle, color: primaryColor, size: 30),
                            onPressed: () {
                              // Shuffle Play Logic
                            },
                          ),
                          const SizedBox(width: 16),
                          FloatingActionButton(
                            onPressed: () {
                              if (widget.playlist.songs.isNotEmpty) {
                                final songs = widget.playlist.songs.map((s) => s.toSong()).toList();
                                final audioHandler = ref.read(audioHandlerProvider);
                                if (audioHandler is MixifyAudioHandler) {
                                   audioHandler.playList(songs, 0);
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
                            backgroundColor: AppColors.yellow, // Always yellow for play button
                            child: const Icon(Icons.play_arrow, color: Colors.black, size: 32),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Action Chips
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => PlaylistSearchScreen(playlistId: widget.playlist.id)),
                          ).then((_) => setState(() {})); // Refresh on return
                        },
                        child: _buildActionChip(Icons.add, "Add", textColor, backgroundColor),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => _showEditDialog(context, ref),
                        child: _buildActionChip(Icons.edit, "Edit", textColor, backgroundColor),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _showSortOptions,
                        child: _buildActionChip(Icons.sort, "Sort", textColor, backgroundColor),
                      ),
                      // Removed Details chip
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: "Find in playlist",
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: isDark ? Colors.grey[900] : Colors.grey[200],
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                    ),
                    onChanged: _filterSongs,
                  ),
                ],
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildSongTile(context, index, _searchController.text.isEmpty),
              childCount: _filteredSongs.length,
            ),
          ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
        ],
      ),
    );
  }

  Widget _buildActionChip(IconData icon, String label, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: textColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: textColor),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildHeaderCollage() {
    final images = widget.playlist.songs.take(4).map((s) => s.thumbnailUrl).toList();
    if (images.isEmpty) return Container(color: Colors.grey);
    
    if (images.length < 4) {
      return Image.network(images.first, fit: BoxFit.cover);
    }
    
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(child: Image.network(images[0], fit: BoxFit.cover)),
              Expanded(child: Image.network(images[1], fit: BoxFit.cover)),
            ],
          ),
        ),
        Expanded(
          child: Row(
            children: [
              Expanded(child: Image.network(images[2], fit: BoxFit.cover)),
              Expanded(child: Image.network(images[3], fit: BoxFit.cover)),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _downloadPlaylist() async {
    // Check permission first
    PermissionStatus status;
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt >= 33) {
        status = await Permission.audio.request();
      } else {
        status = await Permission.storage.request();
      }
    } else {
      status = await Permission.storage.request();
    }

    if (status.isPermanentlyDenied) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Permission Required"),
            content: const Text("Storage permission is required to download songs. Please enable it in settings."),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  openAppSettings();
                },
                child: const Text("Open Settings"),
              ),
            ],
          ),
        );
      }
      return;
    }

    if (!status.isGranted) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Storage permission required for downloads.")),
        );
      }
      return;
    }

    // Show progress dialog or snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Downloading playlist... This might take a while.")),
    );
    
    final downloadRepo = ref.read(downloadRepositoryProvider);
    final musicRepo = ref.read(musicRepositoryProvider);
    
    int successCount = 0;
    
    for (final song in widget.playlist.songs) {
      try {
        // 1. Get URL
        final url = await musicRepo.getStreamUrl(song.title, song.artist, videoId: song.videoId);
        
        // 2. Download
        await downloadRepo.downloadSongWithUrl(
          {
            'id': song.videoId,
            'title': song.title,
            'artist': song.artist,
            'thumbnailUrl': song.thumbnailUrl,
            'album': widget.playlist.name,
          },
          url
        );
        successCount++;
      } catch (e) {
        print("Failed to download ${song.title}: $e");
      }
    }
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Downloaded $successCount / ${widget.playlist.songs.length} songs.")),
      );
    }
  }

  Widget _buildSongTile(BuildContext context, int index, bool reorderable) {
    final song = _filteredSongs[index];
    return ListTile(
      key: ValueKey(song.videoId),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          song.thumbnailUrl,
          width: 50,
          height: 50,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(color: Colors.grey, width: 50, height: 50),
        ),
      ),
      title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove_circle_outline, color: AppColors.red),
            onPressed: () async {
              await ref.read(playlistRepositoryProvider).removeSongFromPlaylist(widget.playlist.id, song.videoId);
              setState(() {
                // Refresh filtered list
                if (_searchController.text.isEmpty) {
                  _filteredSongs = widget.playlist.songs;
                } else {
                  _filterSongs(_searchController.text);
                }
              });
            },
          ),
          if (reorderable) const Icon(Icons.drag_handle, color: Colors.grey),
        ],
      ),
      onTap: () async {
        final songs = _filteredSongs.map((s) => s.toSong()).toList();
        final audioHandler = ref.read(audioHandlerProvider);
        if (audioHandler is MixifyAudioHandler) {
           await audioHandler.playList(songs, index);
           if (context.mounted) {
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
  }

  void _showEditDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController(text: widget.playlist.name);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Edit Playlist"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: "Name"),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                final ImagePicker picker = ImagePicker();
                final XFile? image = await picker.pickImage(source: ImageSource.gallery);
                if (image != null) {
                  widget.playlist.imagePath = image.path;
                  await ref.read(playlistRepositoryProvider).updatePlaylist(widget.playlist);
                  setState(() {}); // Refresh UI
                }
              },
              child: const Text("Change Image"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                widget.playlist.name = nameController.text;
                await ref.read(playlistRepositoryProvider).updatePlaylist(widget.playlist);
                setState(() {}); // Refresh UI
                Navigator.pop(context);
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }
}
