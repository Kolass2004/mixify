import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixify/data/providers.dart';
import 'package:mixify/data/models/innertube_models.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:mixify/ui/screens/spotify_playlist_detail_screen.dart';
class CategoryScreen extends ConsumerStatefulWidget {
  final String categoryId;
  final String categoryName;

  const CategoryScreen({
    super.key,
    required this.categoryId,
    required this.categoryName,
  });

  @override
  ConsumerState<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends ConsumerState<CategoryScreen> {
  late Future<List<MusicItem>> _playlistsFuture;

  @override
  void initState() {
    super.initState();
    _playlistsFuture = _fetchPlaylists();
  }

  Future<List<MusicItem>> _fetchPlaylists() async {
    final spotify = ref.read(spotifyApiServiceProvider);
    final playlists = await spotify.getCategoryPlaylists(widget.categoryId, categoryName: widget.categoryName);
    
    return playlists.map((p) {
      String imageUrl = "";
      if (p.images != null && p.images!.isNotEmpty) {
        imageUrl = p.images!.first.url ?? "";
      }
      return MusicItem(
        videoId: p.id ?? "",
        title: p.name ?? "Unknown",
        subtitle: p.description ?? "Playlist",
        thumbnailUrl: imageUrl,
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.categoryName),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: FutureBuilder<List<MusicItem>>(
        future: _playlistsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No playlists found'));
          }

          final playlists = snapshot.data!;
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.75,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: playlists.length,
            itemBuilder: (context, index) {
              final playlist = playlists[index];
              return GestureDetector(
                onTap: () {
                  // Navigate to Playlist Detail (Assuming it exists or handling generic playlist tap)
                  // Since we don't have a direct route to generic Spotify playlist detail yet, 
                  // we might need to implement one or use an existing one.
                  // For now, let's show a snackbar or try to use a generic playlist screen if available.
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SpotifyPlaylistDetailScreen(
                        playlistId: playlist.videoId,
                        playlistName: playlist.title,
                        imageUrl: playlist.thumbnailUrl,
                        ownerName: playlist.subtitle,
                      ),
                    ),
                  );
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          image: playlist.thumbnailUrl.isNotEmpty
                              ? DecorationImage(
                                  image: CachedNetworkImageProvider(playlist.thumbnailUrl),
                                  fit: BoxFit.cover,
                                )
                              : null,
                          color: Colors.grey[800],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      playlist.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      playlist.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
