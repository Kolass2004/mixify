import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixify/data/models/innertube_models.dart';
import 'package:mixify/data/providers.dart';
import 'package:mixify/player/mixify_audio_handler.dart';
import 'package:mixify/ui/screens/player_screen.dart';

class SectionViewScreen extends ConsumerWidget {
  final String title;
  final List<MusicItem> items;

  const SectionViewScreen({
    super.key,
    required this.title,
    required this.items,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Container(
                width: 48,
                height: 48,
                color: Colors.grey[800],
                child: item.thumbnailUrl.isNotEmpty
                    ? Image.network(item.thumbnailUrl, fit: BoxFit.cover)
                    : const Icon(Icons.music_note, color: Colors.white),
              ),
            ),
            title: Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              item.subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
            onTap: () => _playItem(context, ref, items, index),
          );
        },
      ),
    );
  }

  Future<void> _playItem(BuildContext context, WidgetRef ref, List<MusicItem> items, int index) async {
      try {
        // Convert MusicItems to Songs
        final songs = items.map((item) => Song(
          videoId: item.videoId,
          title: item.title,
          artist: item.subtitle,
          thumbnailUrl: item.thumbnailUrl,
        )).toList();

        final audioHandler = ref.read(audioHandlerProvider);
        
        // Play the list starting from this index
        if (audioHandler is MixifyAudioHandler) {
           await audioHandler.playList(songs, index);
        } else {
           // Fallback
           final item = items[index];
           final repository = ref.read(musicRepositoryProvider);
           final url = await repository.getStreamUrl(item.title, item.subtitle, videoId: item.videoId);
           final song = songs[index];
           await audioHandler.playSong(song, url);
        }
        
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
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error playing song: $e')),
          );
        }
      }
  }
}
