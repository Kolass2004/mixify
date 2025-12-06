import 'dart:ui';
import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixify/data/providers.dart';
import 'package:mixify/main.dart';
import 'package:mixify/ui/screens/player_screen.dart';

class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioHandler = ref.watch(audioHandlerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? Colors.black.withOpacity(0.6) : Colors.white.withOpacity(0.6);
    final textColor = isDark ? Colors.white : Colors.black;

    return StreamBuilder<MediaItem?>(
      stream: audioHandler.mediaItem,
      builder: (context, snapshot) {
        final mediaItem = snapshot.data;
        if (mediaItem == null) return const SizedBox.shrink();

        return GestureDetector(
          onTap: () {
            Navigator.of(context, rootNavigator: true).push(
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) => const PlayerScreen(),
                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                  const begin = Offset(0.0, 1.0);
                  const end = Offset.zero;
                  const curve = Curves.easeInOut;

                  var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

                  return SlideTransition(
                    position: animation.drive(tween),
                    child: child,
                  );
                },
              ),
            );
          },
          child: ClipRRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                color: backgroundColor,
                height: 70, // Increased height for progress bar
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Progress Bar
                    StreamBuilder<Duration>(
                      stream: AudioService.position,
                      builder: (context, snapshot) {
                        final position = snapshot.data ?? Duration.zero;
                        final duration = mediaItem.duration ?? Duration.zero;
                        double progress = 0.0;
                        if (duration.inMilliseconds > 0) {
                          progress = position.inMilliseconds / duration.inMilliseconds;
                          progress = progress.clamp(0.0, 1.0);
                        }
                        return LinearProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.transparent,
                          valueColor: AlwaysStoppedAnimation<Color>(isDark ? AppColors.yellow : AppColors.red),
                          minHeight: 2,
                        );
                      },
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: CachedNetworkImage(
                                imageUrl: mediaItem.artUri.toString(),
                                width: 48,
                                height: 48,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => Container(color: Colors.grey),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    mediaItem.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    mediaItem.artist ?? "",
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            // Controls
                            StreamBuilder<PlaybackState>(
                              stream: audioHandler.playbackState,
                              builder: (context, snapshot) {
                                final playing = snapshot.data?.playing ?? false;
                                return Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: Icon(Icons.skip_previous, color: textColor),
                                      onPressed: audioHandler.skipToPrevious,
                                    ),
                                    IconButton(
                                      icon: Icon(playing ? Icons.pause : Icons.play_arrow, color: textColor),
                                      onPressed: playing ? audioHandler.pause : audioHandler.play,
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.skip_next, color: textColor),
                                      onPressed: audioHandler.skipToNext,
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
