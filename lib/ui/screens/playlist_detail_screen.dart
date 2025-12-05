import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mixify/data/models/playlist_model.dart';
import 'package:mixify/data/providers.dart';
import 'package:mixify/data/repository/playlist_repository.dart';
import 'package:mixify/main.dart';
import 'package:mixify/ui/screens/player_screen.dart';

class PlaylistDetailScreen extends ConsumerStatefulWidget {
  final LocalPlaylist playlist;

  const PlaylistDetailScreen({super.key, required this.playlist});

  @override
  ConsumerState<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends ConsumerState<PlaylistDetailScreen> {
  late List<HiveSong> _filteredSongs;
  final _searchController = TextEditingController();

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
    });
  }

  @override
  Widget build(BuildContext context) {
    // Watch the repository to rebuild when changes occur (if we had a stream)
    // For now, we rely on the passed playlist object, but if we modify it, we might need to refresh.
    // A better approach is to fetch the playlist by ID again or use a ValueListenableBuilder.
    
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.white : AppColors.black;
    final backgroundColor = isDark ? AppColors.black : AppColors.white;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.playlist.name,
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.edit, color: textColor),
            onPressed: () => _showEditDialog(context, ref),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Search in playlist...",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: isDark ? Colors.grey[800] : Colors.grey[200],
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onChanged: _filterSongs,
            ),
          ),
          Expanded(
            child: widget.playlist.songs.isEmpty
                ? const Center(child: Text("No songs in this playlist"))
                : _searchController.text.isNotEmpty 
                  ? ListView.builder( // Use ListView when searching (no reorder)
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _filteredSongs.length,
                      itemBuilder: (context, index) => _buildSongTile(context, index, false),
                    )
                  : ReorderableListView.builder( // Use ReorderableListView when not searching
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _filteredSongs.length,
                      itemBuilder: (context, index) => _buildSongTile(context, index, true),
                      onReorder: (oldIndex, newIndex) async {
                        if (oldIndex < newIndex) {
                          newIndex -= 1;
                        }
                        final item = widget.playlist.songs.removeAt(oldIndex);
                        widget.playlist.songs.insert(newIndex, item);
                        await ref.read(playlistRepositoryProvider).updatePlaylist(widget.playlist);
                        setState(() {
                          _filteredSongs = widget.playlist.songs;
                        });
                      },
                    ),
          ),
        ],
      ),
    );
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
        final url = await ref.read(musicRepositoryProvider).getStreamUrl(song.title, song.artist);
        ref.read(audioHandlerProvider).playSong(song.toSong(), url);
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
