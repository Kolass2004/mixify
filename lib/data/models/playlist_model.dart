import 'package:hive_flutter/hive_flutter.dart';
import 'package:mixify/data/models/innertube_models.dart';

part 'playlist_model.g.dart';

@HiveType(typeId: 2)
class HiveSong extends HiveObject {
  @HiveField(0)
  final String videoId;
  @HiveField(1)
  final String title;
  @HiveField(2)
  final String artist;
  @HiveField(3)
  final String thumbnailUrl;

  HiveSong({
    required this.videoId,
    required this.title,
    required this.artist,
    required this.thumbnailUrl,
  });

  Song toSong() => Song(
    videoId: videoId,
    title: title,
    artist: artist,
    thumbnailUrl: thumbnailUrl,
  );

  factory HiveSong.fromSong(Song song) => HiveSong(
    videoId: song.videoId,
    title: song.title,
    artist: song.artist,
    thumbnailUrl: song.thumbnailUrl,
  );
}

@HiveType(typeId: 1)
class LocalPlaylist extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  List<HiveSong> songs;

  @HiveField(3)
  String? imagePath;

  LocalPlaylist({
    required this.id,
    required this.name,
    this.songs = const [],
    this.imagePath,
  });
}
