import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixify/data/models/innertube_models.dart';
import 'package:mixify/data/models/playlist_model.dart';
import 'package:mixify/data/providers.dart';
import 'package:mixify/ui/components/mini_player.dart';
import 'package:mixify/ui/screens/player_screen.dart';
import 'package:mixify/ui/screens/playlist_detail_screen.dart';
import 'package:spotify/spotify.dart' as spotify;

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  List<Song> _songs = [];
  List<spotify.AlbumSimple> _albums = [];
  bool _isLoading = false;
  Timer? _debounce;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (query.isNotEmpty) {
        _search();
      }
    });
  }

  Future<void> _search() async {
    if (_searchController.text.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(musicRepositoryProvider);
      
      // Parallel fetch
      final results = await Future.wait([
        repo.searchSongs(_searchController.text),
        repo.searchAlbums(_searchController.text),
      ]);
      
      if (mounted) {
        setState(() {
          _songs = results[0] as List<Song>;
          _albums = results[1] as List<spotify.AlbumSimple>;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _playSong(Song song) async {
    try {
      final url = await ref.read(musicRepositoryProvider).getStreamUrl(song.title, song.artist, videoId: song.videoId);
      await ref.read(audioHandlerProvider).playSong(song, url);
      
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error playing song: $e')));
      }
    }
  }

  Future<void> _openAlbum(spotify.AlbumSimple album) async {
    try {
      // Fetch tracks for the album
      final tracks = await ref.read(musicRepositoryProvider).getAlbumTracks(album.id!);
      
      // Convert to HiveSongs (LocalPlaylist format)
      String? imageUrl;
      if (album.images != null && album.images!.isNotEmpty) {
        imageUrl = album.images!.first.url;
      }

      final songs = tracks.map((t) => HiveSong(
        videoId: t.id ?? "", // Use Spotify ID
        title: t.name ?? "Unknown",
        artist: t.artists?.map((a) => a.name).join(", ") ?? "Unknown Artist",
        thumbnailUrl: imageUrl ?? "",
      )).toList();

      final tempPlaylist = LocalPlaylist(
        id: "temp_album_${album.id}",
        name: album.name ?? "Unknown Album",
        songs: songs,
        imagePath: null, // We handle network image in detail screen if needed, or pass it differently
      );
      
      // Hack: PlaylistDetailScreen expects local image path or null. 
      // We might need to update PlaylistDetailScreen to handle network images for temp playlists.
      // For now, let's just pass it.
      
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PlaylistDetailScreen(playlist: tempPlaylist),
          ),
        );
      }

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error opening album: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            hintText: 'Search songs, albums...',
            border: InputBorder.none,
          ),
          onChanged: _onSearchChanged,
          onSubmitted: (_) => _search(),
        ),
        actions: [
          IconButton(onPressed: _search, icon: const Icon(Icons.search)),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: "Songs"),
            Tab(text: "Albums"),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      // Songs Tab
                      ListView.builder(
                        itemCount: _songs.length,
                        itemBuilder: (context, index) {
                          final song = _songs[index];
                          return ListTile(
                            leading: CachedNetworkImage(
                              imageUrl: song.thumbnailUrl,
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => const Icon(Icons.music_note),
                            ),
                            title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
                            onTap: () => _playSong(song),
                          );
                        },
                      ),
                      // Albums Tab
                      ListView.builder(
                        itemCount: _albums.length,
                        itemBuilder: (context, index) {
                          final album = _albums[index];
                          String? imageUrl;
                          if (album.images != null && album.images!.isNotEmpty) {
                            imageUrl = album.images!.first.url;
                          }
                          
                          return ListTile(
                            leading: imageUrl != null 
                              ? CachedNetworkImage(
                                  imageUrl: imageUrl,
                                  width: 50,
                                  height: 50,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => const Icon(Icons.album),
                                )
                              : const Icon(Icons.album, size: 50),
                            title: Text(album.name ?? "Unknown Album", maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text(album.artists?.map((a) => a.name).join(", ") ?? "", maxLines: 1, overflow: TextOverflow.ellipsis),
                            onTap: () => _openAlbum(album),
                          );
                        },
                      ),
                    ],
                  ),
          ),
          const MiniPlayer(),
        ],
      ),
    );
  }
}
