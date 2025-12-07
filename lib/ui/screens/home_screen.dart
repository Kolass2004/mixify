import 'package:flutter/material.dart';
import 'package:mixify/ui/screens/category_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixify/data/models/innertube_models.dart';
import 'package:mixify/data/providers.dart';
import 'package:mixify/main.dart'; // For AppColors
import 'package:mixify/ui/screens/player_screen.dart';
import 'package:mixify/ui/screens/search_screen.dart';
import 'package:mixify/player/mixify_audio_handler.dart';
import 'package:mixify/ui/screens/main_screen.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mixify/ui/screens/section_view_screen.dart';
final homeSectionsProvider = FutureProvider<List<HomeSection>>((ref) async {
  final repository = ref.watch(musicRepositoryProvider);
  return repository.getHomeSections();
});

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homeSectionsAsync = ref.watch(homeSectionsProvider);
    final connectivityAsync = ref.watch(connectivityProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await ref.read(musicRepositoryProvider).clearHomeCache();
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
                          color: isDark ? AppColors.yellow : AppColors.black,
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
              
              // Check connectivity first
              connectivityAsync.when(
                data: (results) {
                  final isOffline = results.contains(ConnectivityResult.none);
                  if (isOffline) {
                    return SliverFillRemaining(
                      child: _buildOfflineUI(context, theme),
                    );
                  }
                  
                  // If online, show content
                  return homeSectionsAsync.when(
                    data: (sections) {
                      if (sections.isEmpty) {
                         if (isOffline) {
                            return SliverFillRemaining(
                              child: _buildOfflineUI(context, theme),
                            );
                         }
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
                                if (section.title == "Speed dial") ...[
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                                    child: Text(
                                      "Recents",
                                      style: theme.textTheme.headlineSmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.onSurface,
                                      ),
                                    ),
                                  ),
                                  _buildQuickDialGrid(context, section.items, ref),
                                ] else ...[
                                  if (index > 0) ...[
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            section.title,
                                            style: theme.textTheme.headlineSmall?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: theme.colorScheme.onSurface,
                                            ),
                                          ),
                                          TextButton(
                                            onPressed: () {
                                              Navigator.of(context).push(
                                                MaterialPageRoute(
                                                  builder: (_) => SectionViewScreen(
                                                    title: section.title,
                                                    items: section.items,
                                                  ),
                                                ),
                                              );
                                            },
                                            child: Text(
                                              "See all",
                                              style: TextStyle(
                                                color: theme.colorScheme.primary,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  if (section.type == HomeSectionType.playlists)
                                    _buildFeaturedPlaylists(context, section.items, ref)
                                  else if (section.type == HomeSectionType.categories)
                                    _buildCategoryList(context, section.items, ref)
                                  else if (section.type == HomeSectionType.albums)
                                    _buildNewReleasesList(context, section.items, ref)
                                  else
                                    _buildHorizontalList(context, section.items, ref),
                                ],
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
                    error: (err, stack) {
                      // If error and offline, show offline UI
                      if (isOffline) {
                         return SliverFillRemaining(
                            child: _buildOfflineUI(context, theme),
                         );
                      }
                      return SliverFillRemaining(
                        child: Center(child: Text("Error: $err", style: TextStyle(color: theme.colorScheme.onSurface))),
                      );
                    },
                  );
                },
                loading: () => SliverFillRemaining(
                   child: Center(child: CircularProgressIndicator(color: theme.colorScheme.onSurface)),
                ),
                error: (error, stack) => SliverFillRemaining(
                   // If connectivity check fails, assume offline? Or just show error.
                   child: _buildOfflineUI(context, theme),
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



  Widget _buildOfflineUI(BuildContext context, ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off, size: 64, color: theme.colorScheme.onSurface.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text(
            "Network not available",
            style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.onSurface),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              // Navigate to Downloads tab
              final mainScreenState = context.findAncestorStateOfType<MainScreenState>();
              if (mainScreenState != null) {
                 mainScreenState.switchToDownloads();
              } else {
                 // Fallback: Just print or show toast
                 print("Could not find MainScreenState");
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.yellow,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text("Explore Downloads"),
          ),
        ],
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
          crossAxisSpacing: 10, // Reduced spacing slightly
          mainAxisSpacing: 10,
          childAspectRatio: 1.0, // Square tiles
        ),
        itemCount: displayItems.length,
        itemBuilder: (context, index) {
          final item = displayItems[index];
          return GestureDetector(
            onTap: () => _playItem(context, ref, displayItems, index),
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
              child: Stack(
                children: [
                  if (item.thumbnailUrl.isEmpty)
                    const Center(child: Icon(Icons.music_note, color: Colors.white)),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.8),
                          ],
                        ),
                      ),
                      padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
                      child: Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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

  Widget _buildFeaturedPlaylists(BuildContext context, List<MusicItem> items, WidgetRef ref) {
    return SizedBox(
      height: 240,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return GestureDetector(
            onTap: () {
               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Playlist selection coming soon!")));
            },
            child: Container(
              width: 280,
              margin: const EdgeInsets.only(right: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                image: item.thumbnailUrl.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(item.thumbnailUrl),
                        fit: BoxFit.cover,
                      )
                    : null,
                color: Colors.grey[800],
              ),
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.9),
                        ],
                        stops: const [0.5, 1.0],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 12,
                          ),
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

  Widget _buildCategoryList(BuildContext context, List<MusicItem> items, WidgetRef ref) {
    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          final color = Colors.primaries[index % Colors.primaries.length];
          
          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CategoryScreen(
                    categoryId: item.videoId,
                    categoryName: item.title,
                  ),
                ),
              );
            },
            child: Container(
              width: 120,
              margin: const EdgeInsets.only(right: 16),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
                image: item.thumbnailUrl.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(item.thumbnailUrl),
                        fit: BoxFit.cover,
                        colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.3), BlendMode.darken),
                      )
                    : null,
              ),
              child: Center(
                child: Text(
                  item.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(blurRadius: 4, color: Colors.black, offset: Offset(0, 2))],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
  Widget _buildNewReleasesList(BuildContext context, List<MusicItem> items, WidgetRef ref) {
    return SizedBox(
      height: 180,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return GestureDetector(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Album selection coming soon!")));
            },
            child: Container(
              width: 140,
              margin: const EdgeInsets.only(right: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 140,
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
                  const SizedBox(height: 8),
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    item.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      fontSize: 12,
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
