class InnerTubeBody {
  final Map<String, dynamic> context;
  final String? videoId;
  final String? query;
  final String? params;
  final String? browseId;

  InnerTubeBody({
    this.videoId,
    this.query,
    this.params,
    this.browseId,
    String clientName = "WEB_REMIX",
    String clientVersion = "1.20240404.01.00",
    String hl = "en",
    String gl = "US",
  }) : context = {
          "client": {
            "clientName": clientName,
            "clientVersion": clientVersion,
            "hl": hl,
            "gl": gl,
          }
        };

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {"context": context};
    if (videoId != null) data["videoId"] = videoId;
    if (query != null) data["query"] = query;
    if (params != null) data["params"] = params;
    if (browseId != null) data["browseId"] = browseId;
    return data;
  }
}

class Song {
  final String videoId;
  final String title;
  final String artist;
  final String thumbnailUrl;

  Song({
    required this.videoId,
    required this.title,
    required this.artist,
    required this.thumbnailUrl,
  });
}

enum HomeSectionType { tracks, playlists, categories, albums }

class HomeSection {
  final String title;
  final List<MusicItem> items;
  final HomeSectionType type;

  HomeSection({required this.title, required this.items, this.type = HomeSectionType.tracks});

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'items': items.map((e) => e.toJson()).toList(),
      'type': type.toString(),
    };
  }

  factory HomeSection.fromJson(Map<String, dynamic> json) {
    return HomeSection(
      title: json['title'],
      items: (json['items'] as List).map((e) => MusicItem.fromJson(e)).toList(),
      type: json['type'] != null 
          ? HomeSectionType.values.firstWhere((e) => e.toString() == json['type'], orElse: () => HomeSectionType.tracks)
          : HomeSectionType.tracks,
    );
  }
}

class MusicItem {
  final String videoId;
  final String title;
  final String subtitle;
  final String thumbnailUrl;

  MusicItem({
    required this.videoId,
    required this.title,
    required this.subtitle,
    required this.thumbnailUrl,
  });

  Map<String, dynamic> toJson() => {
    'videoId': videoId,
    'title': title,
    'subtitle': subtitle,
    'thumbnailUrl': thumbnailUrl,
  };

  factory MusicItem.fromJson(Map<String, dynamic> json) {
    return MusicItem(
      videoId: json['videoId'] ?? "",
      title: json['title'] ?? "",
      subtitle: json['subtitle'] ?? "",
      thumbnailUrl: json['thumbnailUrl'] ?? "",
    );
  }
}
