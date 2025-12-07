import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixify/data/models/innertube_models.dart';
import 'package:mixify/data/models/playlist_model.dart';
import 'package:mixify/data/providers.dart';
import 'package:mixify/data/repository/playlist_repository.dart';
import 'package:mixify/main.dart';
import 'package:mixify/ui/screens/downloads_screen.dart';
import 'package:mixify/ui/screens/import_playlist_screen.dart';
import 'package:mixify/ui/screens/player_screen.dart';
import 'package:mixify/ui/screens/playlist_detail_screen.dart';
import 'package:spotify/spotify.dart' as spotify;

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _artistSearchQuery = "";
  
  @override
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this); // Changed to 4
    _tabController.addListener(() {
      setState(() {}); // Rebuild to update tab colors
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [

            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Row(
                  children: [
                    _buildTabHeader("Recent", 0, isDark, theme),
                    const SizedBox(width: 20),
                    _buildTabHeader("Playlists", 1, isDark, theme),
                    const SizedBox(width: 20),
                    _buildTabHeader("Artists", 2, isDark, theme),
                    const SizedBox(width: 20),
                    _buildTabHeader("Albums", 3, isDark, theme),
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
                  _buildRecentTab(),
                  _buildPlaylistsTab(),
                  _buildArtistsTab(),
                  _buildAlbumsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentTab() {
    final prefs = ref.watch(userPreferencesProvider);

    return ValueListenableBuilder(
      valueListenable: prefs.boxListenable,
      builder: (context, box, _) {
        final history = prefs.getSongHistory();

        if (history.isEmpty) {
          return const Center(child: Text("No recently played songs"));
        }

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {});
          },
          child: ListView.builder(
            padding: const EdgeInsets.only(left: 24, right: 24, bottom: 150),
            itemCount: history.length,
            itemBuilder: (context, index) {
              final songData = history[index];
              final song = Song(
                videoId: songData['id'],
                title: songData['title'],
                artist: songData['artist'] ?? "Unknown",
                thumbnailUrl: songData['artUri'] ?? "",
              );

              return ListTile(
                contentPadding: EdgeInsets.zero,
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
                onTap: () async {
                  // Play song
                  final url = await ref.read(musicRepositoryProvider).getStreamUrl(song.title, song.artist, videoId: song.videoId);
                  ref.read(audioHandlerProvider).playSong(song, url);
                },
              );
            },
          ),
        );
      },
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

  Widget _buildAlbumsTab() {
    // Since we don't have a dedicated "Saved Albums" feature yet, we can show albums from history
    // or just a placeholder. The user asked to "add new section 'albums' along with artists and playlists".
    // Let's infer they want to see albums of songs they played or saved.
    // For now, let's group history by album.
    
    final history = ref.watch(userPreferencesProvider).getSongHistory();
    // Group by Album name
    final Map<String, List<Map<String, dynamic>>> albums = {};
    for (final song in history) {
      final albumName = song['album'] ?? "Unknown Album";
      if (!albums.containsKey(albumName)) {
        albums[albumName] = [];
      }
      albums[albumName]!.add(song);
    }
    
    final albumNames = albums.keys.toList();

    if (albumNames.isEmpty) {
      return const Center(child: Text("No albums found in history"));
    }

    return RefreshIndicator(
      onRefresh: () async {
        setState(() {}); // Rebuild to refresh history if needed
      },
      child: GridView.builder(
        padding: const EdgeInsets.only(left: 24, right: 24, bottom: 150),
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
          final imageUrl = firstSong['artUri'];
          final artist = firstSong['artist'] ?? "Unknown Artist";
  
          return GestureDetector(
            onTap: () {
               // Open a playlist detail view with these songs
               // We can reuse PlaylistDetailScreen by creating a temporary LocalPlaylist
               final tempPlaylist = LocalPlaylist(
                 id: "temp_album_$index",
                 name: albumName,
                 songs: songs.map((s) => HiveSong(
                   videoId: s['id'],
                   title: s['title'],
                   artist: s['artist'],
                   thumbnailUrl: s['artUri'] ?? "",
                 )).toList(),
                 imagePath: null, // We don't have a local path, but we can handle it
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      child: imageUrl != null 
                        ? Image.network(imageUrl, fit: BoxFit.cover, width: double.infinity)
                        : const Center(child: Icon(Icons.album, size: 50, color: Colors.grey)),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          albumName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          artist,
                          style: const TextStyle(color: Colors.grey, fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildArtistsTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: TextField(
            decoration: InputDecoration(
              hintText: "Search Artists...",
              hintStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
              prefixIcon: Icon(Icons.search, color: isDark ? Colors.grey[400] : Colors.grey[600]),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: isDark ? Colors.grey[800] : Colors.grey[200],
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            onChanged: (query) {
              setState(() {
                _artistSearchQuery = query;
              });
            },
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              setState(() {}); // Rebuild to re-fetch future
            },
            child: FutureBuilder<List<spotify.Artist>>(
              future: ref.read(musicRepositoryProvider).getTopArtists(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.black));
                }
                if (snapshot.hasError) {
                  return Center(child: Text("Error: ${snapshot.error}"));
                }
                
                var artists = snapshot.data ?? [];
                
                if (_artistSearchQuery.isNotEmpty) {
                  artists = artists.where((a) => 
                    (a.name ?? "").toLowerCase().contains(_artistSearchQuery.toLowerCase())
                  ).toList();
                }
                
                if (artists.isEmpty) {
                  return const Center(child: Text("No artists found"));
                }
            
                return GridView.builder(
                  padding: const EdgeInsets.only(left: 24, right: 24, bottom: 150),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.8,
                  ),
                  itemCount: artists.length,
                  itemBuilder: (context, index) {
                    final artist = artists[index];
                    String? imageUrl;
                    if (artist.images != null && artist.images!.isNotEmpty) {
                      imageUrl = artist.images!.first.url;
                    }
            
                    return GestureDetector(
                      onTap: () => _showArtistDetails(artist),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.black.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(16),
                          image: imageUrl != null 
                            ? DecorationImage(image: NetworkImage(imageUrl), fit: BoxFit.cover)
                            : null,
                        ),
                        alignment: Alignment.bottomLeft,
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          artist.name ?? "Unknown",
                          style: const TextStyle(
                            color: AppColors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  void _showArtistDetails(spotify.Artist artist) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.yellow,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, controller) => _ArtistDetailView(artist: artist, controller: controller),
      ),
    );
  }

  Widget _buildPlaylistsTab() {
    final playlistRepo = ref.watch(playlistRepositoryProvider);

    return ValueListenableBuilder(
      valueListenable: playlistRepo.boxListenable,
      builder: (context, box, _) {
        final playlists = playlistRepo.getPlaylists();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _showCreatePlaylistDialog,
                      icon: const Icon(Icons.add, color: AppColors.white),
                      label: const Text("Create", style: TextStyle(color: AppColors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.black,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const ImportPlaylistScreen()),
                        );
                      },
                      icon: const Icon(Icons.download, color: AppColors.white),
                      label: const Text("Import", style: TextStyle(color: AppColors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.black, // Changed to Black for visibility
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: playlists.isEmpty 
              ? const Center(child: Text("No playlists yet"))
              : ListView.builder(
                padding: const EdgeInsets.only(left: 24, right: 24, bottom: 150),
                itemCount: playlists.length,
                itemBuilder: (context, index) {
                  final playlist = playlists[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: AppColors.black.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: playlist.imagePath != null 
                        ? Image.file(File(playlist.imagePath!), fit: BoxFit.cover)
                        : playlist.songs.isEmpty 
                          ? const Icon(Icons.music_note, color: AppColors.black)
                          : _buildPlaylistCollage(playlist),
                    ),
                    title: Text(
                      playlist.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    subtitle: Text("${playlist.songs.length} songs"),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PlaylistDetailScreen(playlist: playlist),
                        ),
                      );
                    },
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text("Delete Playlist"),
                            content: Text("Are you sure you want to delete '${playlist.name}'?"),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text("Cancel", style: TextStyle(color: AppColors.black)),
                              ),
                              TextButton(
                                onPressed: () async {
                                  await playlistRepo.deletePlaylist(playlist.id);
                                  if (context.mounted) Navigator.pop(context);
                                },
                                child: const Text("Delete", style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        );
      }
    );
  }

  Widget _buildPlaylistCollage(LocalPlaylist playlist) {
    final images = playlist.songs.take(4).map((s) => s.thumbnailUrl).toList();
    if (images.isEmpty) return const Icon(Icons.music_note, color: AppColors.black);
    
    if (images.length < 4) {
      return Image.network(images.first, fit: BoxFit.cover, errorBuilder: (_,__,___) => const Icon(Icons.music_note));
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

  void _showCreatePlaylistDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("New Playlist"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: "Playlist Name"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                await ref.read(playlistRepositoryProvider).createPlaylist(controller.text);
                Navigator.pop(context);
              }
            },
            child: const Text("Create"),
          ),
        ],
      ),
    );
  }
}

class _ArtistDetailView extends ConsumerStatefulWidget {
  final spotify.Artist artist;
  final ScrollController controller;

  const _ArtistDetailView({required this.artist, required this.controller});

  @override
  ConsumerState<_ArtistDetailView> createState() => _ArtistDetailViewState();
}

class _ArtistDetailViewState extends ConsumerState<_ArtistDetailView> {
  final List<Song> _songs = [];
  final List<Song> _filteredSongs = [];
  final _searchController = TextEditingController();
  
  // Lazy Loading State
  bool _isLoading = false;
  bool _hasMore = true;
  List<spotify.AlbumSimple> _albums = [];
  int _currentAlbumIndex = 0;
  final Set<String> _loadedSongTitles = {};

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    widget.controller.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    widget.controller.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    if (widget.controller.position.pixels >= widget.controller.position.maxScrollExtent - 200) {
      _loadMoreSongs();
    }
  }

  Future<void> _loadInitialData() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    
    try {
      final repo = ref.read(musicRepositoryProvider);
      
      // 1. Load Top Tracks (Fast)
      final topTracks = await repo.getArtistTopTracks(widget.artist.id!);
      _addSongs(topTracks);
      
      // 2. Fetch Albums for lazy loading later
      _albums = await repo.getArtistAlbums(widget.artist.id!);
      
    } catch (e) {
      print("Error loading initial artist data: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMoreSongs() async {
    if (_isLoading || !_hasMore || _currentAlbumIndex >= _albums.length) return;
    setState(() => _isLoading = true);

    try {
      final repo = ref.read(musicRepositoryProvider);
      final album = _albums[_currentAlbumIndex];
      _currentAlbumIndex++;
      
      final tracks = await repo.getAlbumTracks(album.id!);
      
      // Map tracks to songs
      String? imageUrl;
      if (album.images != null && album.images!.isNotEmpty) {
        imageUrl = album.images!.first.url;
      }
      
      final newSongs = <Song>[];
      for (final track in tracks) {
         newSongs.add(Song(
            videoId: track.id ?? "", 
            title: track.name!,
            artist: track.artists?.map((a) => a.name).join(", ") ?? "Unknown Artist",
            thumbnailUrl: imageUrl ?? "",
         ));
      }
      
      _addSongs(newSongs);
      
    } catch (e) {
      print("Error loading more songs: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _addSongs(List<Song> newSongs) {
    for (final song in newSongs) {
      if (!_loadedSongTitles.contains(song.title.toLowerCase())) {
        _loadedSongTitles.add(song.title.toLowerCase());
        _songs.add(song);
      }
    }
    _filterSongs(_searchController.text);
  }

  void _filterSongs(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredSongs.clear();
        _filteredSongs.addAll(_songs);
      } else {
        _filteredSongs.clear();
        _filteredSongs.addAll(_songs.where((song) => 
          song.title.toLowerCase().contains(query.toLowerCase())
        ));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.black : AppColors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                Text(
                  widget.artist.name ?? "Artist",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isDark ? AppColors.white : AppColors.black),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: "Search in songs...",
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
              ],
            ),
          ),
          Expanded(
            child: _songs.isEmpty && _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  controller: widget.controller,
                  itemCount: _filteredSongs.length + (_isLoading ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _filteredSongs.length) {
                      return const Center(child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: CircularProgressIndicator(),
                      ));
                    }
                    
                    final song = _filteredSongs[index];
                    return ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          song.thumbnailUrl, 
                          width: 50, 
                          height: 50, 
                          fit: BoxFit.cover,
                          errorBuilder: (_,__,___) => Container(color: Colors.grey, width: 50, height: 50),
                        ),
                      ),
                      title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
                      onTap: () async {
                        // Play song
                        final url = await ref.read(musicRepositoryProvider).getStreamUrl(song.title, song.artist, videoId: song.videoId);
                        ref.read(audioHandlerProvider).playSong(song, url);
                      },
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }
}
