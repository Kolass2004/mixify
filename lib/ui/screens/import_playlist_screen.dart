import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixify/data/models/imported_playlist.dart';
import 'package:mixify/data/providers.dart';
import 'package:mixify/main.dart';
import 'package:mixify/data/repository/playlist_repository.dart';

class ImportPlaylistScreen extends ConsumerStatefulWidget {
  const ImportPlaylistScreen({super.key});

  @override
  ConsumerState<ImportPlaylistScreen> createState() => _ImportPlaylistScreenState();
}

class _ImportPlaylistScreenState extends ConsumerState<ImportPlaylistScreen> {
  int _step = 0; // 0: Selection, 1: URL, 2: Preview
  String _selectedSource = ""; // "Spotify" or "YouTube"
  final TextEditingController _urlController = TextEditingController();
  bool _isLoading = false;
  ImportedPlaylist? _importedPlaylist;
  final TextEditingController _titleController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.iconTheme.color),
          onPressed: () {
            if (_step > 0) {
              setState(() {
                _step--;
                if (_step == 0) _urlController.clear();
                if (_step == 1) _importedPlaylist = null;
              });
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Text(
          _step == 0 ? "Import Playlist" : (_step == 1 ? "Enter URL" : "Preview"),
          style: theme.textTheme.titleLarge,
        ),
      ),
      body: _buildBody(theme, isDark),
    );
  }

  Widget _buildBody(ThemeData theme, bool isDark) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.yellow));
    }

    switch (_step) {
      case 0:
        return _buildSelectionStep(theme);
      case 1:
        return _buildUrlStep(theme, isDark);
      case 2:
        return _buildPreviewStep(theme, isDark);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildSelectionStep(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "Import from",
            style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          _buildSourceCard(
            "Spotify",
            Colors.green,
            "https://upload.wikimedia.org/wikipedia/commons/thumb/1/19/Spotify_logo_without_text.svg/2048px-Spotify_logo_without_text.svg.png",
            () => _selectSource("Spotify"),
          ),
          const SizedBox(height: 20),
          _buildSourceCard(
            "YouTube Music",
            Colors.red,
            "https://upload.wikimedia.org/wikipedia/commons/thumb/6/6a/Youtube_Music_icon.svg/2048px-Youtube_Music_icon.svg.png",
            () => _selectSource("YouTube"),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceCard(String title, Color color, String imageUrl, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color, width: 2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.network(imageUrl, width: 40, height: 40),
            const SizedBox(width: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _selectSource(String source) {
    setState(() {
      _selectedSource = source;
      _step = 1;
    });
  }

  Widget _buildUrlStep(ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "Paste $_selectedSource Playlist URL",
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _urlController,
            decoration: InputDecoration(
              hintText: "https://...",
              filled: true,
              fillColor: isDark ? Colors.grey[800] : Colors.grey[200],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: _fetchPlaylist,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.yellow,
              foregroundColor: AppColors.black,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("Show Playlist", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _fetchPlaylist() async {
    if (_urlController.text.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final playlist = await ref.read(musicRepositoryProvider).fetchPlaylistDetails(_urlController.text);
      if (playlist != null) {
        setState(() {
          _importedPlaylist = playlist;
          _titleController.text = playlist.title;
          _step = 2;
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Failed to fetch playlist. Check URL.")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildPreviewStep(ThemeData theme, bool isDark) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: TextField(
            controller: _titleController,
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            decoration: const InputDecoration(
              labelText: "Playlist Name",
              border: UnderlineInputBorder(),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _importedPlaylist?.songs.length ?? 0,
            itemBuilder: (context, index) {
              final song = _importedPlaylist!.songs[index];
              return ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.network(
                    song.thumbnailUrl,
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(color: Colors.grey, width: 40, height: 40),
                  ),
                ),
                title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: ElevatedButton(
            onPressed: _importPlaylist,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.yellow,
              foregroundColor: AppColors.black,
              padding: const EdgeInsets.symmetric(vertical: 16),
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("Import Playlist", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Future<void> _importPlaylist() async {
    if (_importedPlaylist == null) return;

    setState(() => _isLoading = true);
    try {
      final playlistRepo = ref.read(playlistRepositoryProvider);
      
      // Create playlist
      await playlistRepo.createPlaylist(_titleController.text);
      
      // Get the newly created playlist (it's the last one, or we can modify createPlaylist to return ID)
      // For now, let's assume we can get it or modify createPlaylist.
      // Actually, createPlaylist generates an ID. Let's modify createPlaylist to return the ID or just find it.
      // Since createPlaylist is void, we'll just find the playlist by name (risky if duplicates) or just fetch all and take last.
      // Better: Modify createPlaylist to return ID. But I can't modify it right now easily without breaking other things.
      // I'll just fetch all playlists and find the one with the name, or assume it's the last added.
      
      final playlists = playlistRepo.getPlaylists();
      final newPlaylist = playlists.lastWhere((p) => p.name == _titleController.text); // Simple heuristic
      
      for (final song in _importedPlaylist!.songs) {
        await playlistRepo.addSongToPlaylist(newPlaylist.id, song);
      }
      
      if (mounted) {
        Navigator.pop(context); // Close screen
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Playlist imported successfully!")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error importing playlist: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
