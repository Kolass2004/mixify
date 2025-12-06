import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixify/data/models/innertube_models.dart';
import 'package:mixify/data/providers.dart';
import 'package:mixify/main.dart';
import 'package:spotify/spotify.dart' as spotify;

class PlaylistSearchScreen extends ConsumerStatefulWidget {
  final String playlistId;

  const PlaylistSearchScreen({super.key, required this.playlistId});

  @override
  ConsumerState<PlaylistSearchScreen> createState() => _PlaylistSearchScreenState();
}

class _PlaylistSearchScreenState extends ConsumerState<PlaylistSearchScreen> {
  final _searchController = TextEditingController();
  List<Song> _searchResults = [];
  bool _isLoading = false;
  String _query = "";

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) return;
    
    setState(() {
      _isLoading = true;
      _query = query;
    });

    try {
      final results = await ref.read(musicRepositoryProvider).searchSongs(query);
      if (mounted) {
        setState(() {
          _searchResults = results;
        });
      }
    } catch (e) {
      debugPrint("Error searching songs: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.white : AppColors.black;
    final bgColor = isDark ? AppColors.black : AppColors.white;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: TextField(
          controller: _searchController,
          autofocus: true,
          style: TextStyle(color: textColor),
          decoration: InputDecoration(
            hintText: "Search songs to add...",
            hintStyle: TextStyle(color: textColor.withOpacity(0.5)),
            border: InputBorder.none,
          ),
          onSubmitted: _performSearch,
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.yellow))
          : _searchResults.isEmpty && _query.isNotEmpty
              ? Center(child: Text("No results found", style: TextStyle(color: textColor)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final song = _searchResults[index];
                    return ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.network(
                          song.thumbnailUrl,
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(color: Colors.grey, width: 50, height: 50),
                        ),
                      ),
                      title: Text(song.title, style: TextStyle(color: textColor), maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(song.artist, style: TextStyle(color: textColor.withOpacity(0.7)), maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: IconButton(
                        icon: const Icon(Icons.add_circle_outline, color: AppColors.yellow),
                        onPressed: () async {
                          await ref.read(playlistRepositoryProvider).addSongToPlaylist(widget.playlistId, song);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Added ${song.title} to playlist")),
                            );
                          }
                        },
                      ),
                    );
                  },
                ),
    );
  }
}
