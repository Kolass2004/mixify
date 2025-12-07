import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixify/data/models/innertube_models.dart';
import 'package:mixify/data/providers.dart';
import 'package:mixify/player/mixify_audio_handler.dart';
import 'package:mixify/ui/screens/player_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:spotify/spotify.dart' as spotify;

class SpotifyPlaylistDetailScreen extends ConsumerStatefulWidget {
  final String playlistId;
  final String playlistName;
  final String imageUrl;
  final String ownerName;

  const SpotifyPlaylistDetailScreen({
    super.key,
    required this.playlistId,
    required this.playlistName,
    required this.imageUrl,
    this.ownerName = "Spotify",
  });

  @override
  ConsumerState<SpotifyPlaylistDetailScreen> createState() => _SpotifyPlaylistDetailScreenState();
}

class _SpotifyPlaylistDetailScreenState extends ConsumerState<SpotifyPlaylistDetailScreen> {
  late Future<List<spotify.Track>> _tracksFuture;
  List<Song> _songs = [];

  @override
  void initState() {
    super.initState();
    _tracksFuture = _fetchTracks();
  }

  Future<List<spotify.Track>> _fetchTracks() async {
    final spotifyApi = ref.read(spotifyApiServiceProvider);
    final tracks = await spotifyApi.getPlaylistTracks(widget.playlistId);
    
    // Map to internal Song model for playback
    _songs = tracks.map((t) {
      String? trackImage;
      if (t.album != null && t.album!.images != null && t.album!.images!.isNotEmpty) {
        trackImage = t.album!.images!.first.url;
      }
      
      return Song(
        videoId: t.id ?? "", // Use Spotify ID
        title: t.name ?? "Unknown",
        artist: t.artists?.map((a) => a.name).join(", ") ?? "Unknown Artist",
        thumbnailUrl: trackImage ?? widget.imageUrl,
      );
    }).toList();
    
    return tracks;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final backgroundColor = isDark ? Colors.black : Colors.white;
    final primaryColor = isDark ? const Color(0xFFEDB33C) : Colors.black; // AppColors.yellow

    return Scaffold(
      backgroundColor: backgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
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
                    Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: widget.imageUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: widget.imageUrl,
                                fit: BoxFit.cover,
                                errorWidget: (context, url, error) => Container(color: Colors.grey[800], child: const Icon(Icons.music_note, size: 80, color: Colors.white)),
                              )
                            : Container(color: Colors.grey[800], child: const Icon(Icons.music_note, size: 80, color: Colors.white)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        widget.playlistName,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "By ${widget.ownerName}",
                      style: TextStyle(color: textColor.withOpacity(0.7), fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  FloatingActionButton(
                    onPressed: () {
                      if (_songs.isNotEmpty) {
                        _playPlaylist(0);
                      }
                    },
                    backgroundColor: primaryColor,
                    child: const Icon(Icons.play_arrow, color: Colors.black, size: 32),
                  ),
                ],
              ),
            ),
          ),
          FutureBuilder<List<spotify.Track>>(
            future: _tracksFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                );
              } else if (snapshot.hasError) {
                return SliverFillRemaining(
                  child: Center(child: Text('Error: ${snapshot.error}')),
                );
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const SliverFillRemaining(
                  child: Center(child: Text('No songs found')),
                );
              }

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final song = _songs[index];
                    return ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: CachedNetworkImage(
                          imageUrl: song.thumbnailUrl,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          errorWidget: (context, url, error) => Container(color: Colors.grey, width: 48, height: 48),
                        ),
                      ),
                      title: Text(
                        song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: textColor),
                      ),
                      subtitle: Text(
                        song.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: textColor.withOpacity(0.6)),
                      ),
                      trailing: IconButton(
                        icon: Icon(Icons.more_vert, color: textColor.withOpacity(0.6)),
                        onPressed: () {
                          // Show options (Add to library, etc.) - Future implementation
                        },
                      ),
                      onTap: () => _playPlaylist(index),
                    );
                  },
                  childCount: _songs.length,
                ),
              );
            },
          ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
        ],
      ),
    );
  }

  void _playPlaylist(int index) {
    final audioHandler = ref.read(audioHandlerProvider);
    if (audioHandler is MixifyAudioHandler) {
      audioHandler.playList(_songs, index);
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
}
