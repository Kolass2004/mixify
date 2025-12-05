// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'playlist_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class LocalPlaylistAdapter extends TypeAdapter<LocalPlaylist> {
  @override
  final int typeId = 1;

  @override
  LocalPlaylist read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LocalPlaylist(
      id: fields[0] as String,
      name: fields[1] as String,
      songs: (fields[2] as List).cast<HiveSong>(),
    );
  }

  @override
  void write(BinaryWriter writer, LocalPlaylist obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.songs);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocalPlaylistAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class HiveSongAdapter extends TypeAdapter<HiveSong> {
  @override
  final int typeId = 2;

  @override
  HiveSong read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HiveSong(
      videoId: fields[0] as String,
      title: fields[1] as String,
      artist: fields[2] as String,
      thumbnailUrl: fields[3] as String,
    );
  }

  @override
  void write(BinaryWriter writer, HiveSong obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.videoId)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.artist)
      ..writeByte(3)
      ..write(obj.thumbnailUrl);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HiveSongAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
