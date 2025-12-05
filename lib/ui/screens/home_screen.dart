import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixify/data/models/innertube_models.dart';
import 'package:mixify/data/providers.dart';
import 'package:mixify/main.dart'; // For AppColors
import 'package:mixify/ui/screens/player_screen.dart';
import 'package:mixify/ui/screens/search_screen.dart';
import 'package:mixify/player/mixify_audio_handler.dart';

final homeSectionsProvider = FutureProvider<List<HomeSection>>((ref) async {
  final repository = ref.watch(musicRepositoryProvider);
  return repository.getHomeSections();
});

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homeSectionsAsync = ref.watch(homeSectionsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            return ref.refresh(homeSectionsProvider.future);
          },
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.all(24.0),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Mixify",
                        style: theme.textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.yellow : AppColors.black, // Yellow in dark mode
                          letterSpacing: -1,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.search, color: theme.colorScheme.onSurface, size: 30),
                        onPressed: () {
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SearchScreen()));
                        },
                      ),
                    ],
                  ),
                ),
              ),
              homeSectionsAsync.when(
                data: (sections) {
                  if (sections.isEmpty) {
                    return SliverFillRemaining(
                      child: Center(child: Text("No content found", style: TextStyle(color: theme.colorScheme.onSurface))),
                    );
                  }
                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final section = sections[index];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (index > 0) ...[
                              Padding(
                                padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                                child: Text(
                                  section.title,
                                  style: theme.textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                              ),
                            ],
                            _buildHorizontalList(context, section.items, ref),
                          ],
                        );
                      },
                      childCount: sections.length,
                    ),
                  );
                },
                loading: () => SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator(color: theme.colorScheme.onSurface)),
                ),
                error: (err, stack) => SliverFillRemaining(
                  child: Center(child: Text("Error: $err", style: TextStyle(color: theme.colorScheme.onSurface))),
                ),
              ),
              // Add padding at bottom for MiniPlayer
              const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickDialGrid(BuildContext context, List<MusicItem> items, WidgetRef ref) {
    if (items.isEmpty) return const SizedBox.shrink();
    
    // Take max 9 items for 3x3
    final displayItems = items.take(9).toList();
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.8,
        ),
        itemCount: displayItems.length,
        itemBuilder: (context, index) {
          final item = displayItems[index];
          return GestureDetector(
            onTap: () => _playItem(context, ref, displayItems, index),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      image: item.thumbnailUrl.isNotEmpty
                          ? DecorationImage(
                              image: NetworkImage(item.thumbnailUrl),
                              fit: BoxFit.cover,
                            )
                          : null,
                      color: Colors.grey[800],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
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
           // Fallback (shouldn't happen)
           final item = items[index];
           final repository = ref.read(musicRepositoryProvider);
           final url = await repository.getStreamUrl(item.title, item.subtitle);
           final song = songs[index];
           await audioHandler.playSong(song, url);
        }
        
        if (context.mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const PlayerScreen()),
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

  Widget _buildHorizontalList(BuildContext context, List<MusicItem> items, WidgetRef ref) {
    final theme = Theme.of(context);
    
    return SizedBox(
      height: 220,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return GestureDetector(
            onTap: () => _playItem(context, ref, items, index),
            child: Container(
              width: 160,
              margin: const EdgeInsets.only(right: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 160,
                    decoration: BoxDecoration(
                      color: Colors.grey[800], // Placeholder color
                      borderRadius: BorderRadius.circular(12),
                      image: item.thumbnailUrl.isNotEmpty
                          ? DecorationImage(
                              image: NetworkImage(item.thumbnailUrl),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: item.thumbnailUrl.isEmpty
                        ? const Center(child: Icon(Icons.album, size: 48, color: Colors.grey))
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    item.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
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
}
