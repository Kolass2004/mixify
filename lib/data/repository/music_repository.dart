import 'package:mixify/data/models/innertube_models.dart';
import 'package:mixify/data/network/spotify_api_service.dart';
import 'package:mixify/data/network/youtube_api_service.dart';
import 'package:mixify/data/preferences/user_preferences.dart';
import 'package:spotify/spotify.dart' as spotify;

class MusicRepository {
  final YouTubeApiService _youtubeApiService;
  final SpotifyApiService _spotifyApiService;
  final UserPreferences _userPreferences;

  MusicRepository(this._youtubeApiService, this._spotifyApiService, this._userPreferences);

  Future<List<spotify.Artist>> getTopArtists() async {
    try {
      final language = _userPreferences.language;
      final languageName = _getLanguageName(language);
      
      // Fetch from multiple sources to get a diverse list
      final futures = <Future<List<spotify.Artist>>>[
        _spotifyApiService.getTopArtists("Top Artists Global"), // Global
        _spotifyApiService.getTopArtists("Indie Artists"), // Indie
      ];
      
      if (languageName.isNotEmpty && languageName != 'English') {
        futures.add(_spotifyApiService.getTopArtists("Top Artists $languageName")); // Local
      }
      
      final results = await Future.wait(futures);
      
      // Merge and deduplicate
      final allArtists = <String, spotify.Artist>{};
      for (final list in results) {
        for (final artist in list) {
          if (artist.id != null) {
            allArtists[artist.id!] = artist;
          }
        }
      }
      
      // Sort alphabetically
      final sortedArtists = allArtists.values.toList()
        ..sort((a, b) => (a.name ?? "").toLowerCase().compareTo((b.name ?? "").toLowerCase()));
        
      return sortedArtists;
    } catch (e) {
      print("Error fetching top artists: $e");
      return [];
    }
  }

  // Expose helper methods for lazy loading
  Future<List<spotify.AlbumSimple>> getArtistAlbums(String artistId) async {
    return _spotifyApiService.getArtistAlbums(artistId);
  }

  Future<List<spotify.TrackSimple>> getAlbumTracks(String albumId) async {
    return _spotifyApiService.getAlbumTracks(albumId);
  }

  Future<List<Song>> getArtistTopTracks(String artistId) async {
    try {
      final tracks = await _spotifyApiService.getArtistTopTracks(artistId);
      return _mapSpotifyTracksToSongs(tracks);
    } catch (e) {
      print("Error fetching artist top tracks: $e");
      return [];
    }
  }

  List<Song> _mapSpotifyTracksToSongs(List<spotify.Track> tracks) {
    return tracks.map((t) {
      String? imageUrl;
      if (t.album != null && t.album!.images != null && t.album!.images!.isNotEmpty) {
        imageUrl = t.album!.images!.first.url;
      }
      
      return Song(
        videoId: t.id ?? "", // Use Spotify ID
        title: t.name ?? "Unknown",
        artist: t.artists?.map((a) => a.name).join(", ") ?? "Unknown Artist",
        thumbnailUrl: imageUrl ?? "",
      );
    }).toList();
  }

  Future<List<Song>> searchSongs(String query) async {
    try {
      // 1. Check if it's a direct URL (YouTube) - Not implemented yet, assuming query
      
      // 2. Search on YouTube
      // We use YouTube for search because Spotify search API is limited for streaming URLs
      // But for simplicity in this step, let's stick to YouTube for direct search,
      // and use Spotify for Home/Recommendations.
      
      final languageName = _getLanguageName(_userPreferences.language);
      String effectiveQuery = query;
      if (languageName.isNotEmpty && languageName != 'English' && !query.toLowerCase().contains(languageName.toLowerCase())) {
        effectiveQuery = "$query $languageName";
      }
      
      // Force English for labels (Video/Song)
      const hl = 'en'; 
      final gl = _userPreferences.region;
      final response = await _youtubeApiService.search(effectiveQuery, hl: hl, gl: gl);
      return _parseSearchResults(response);
    } catch (e) {
      throw Exception('Search failed: $e');
    }
  }

  Future<List<spotify.AlbumSimple>> searchAlbums(String query) async {
    return _spotifyApiService.searchAlbums(query);
  }

  Future<List<Song>> getAllArtistTracks(String artistId) async {
    try {
      // 1. Get Top Tracks first (high quality)
      final topTracks = await getArtistTopTracks(artistId);
      
      // 2. Get Albums
      final albums = await _spotifyApiService.getArtistAlbums(artistId);
      
      // 3. Get Tracks for each album (limit to recent/popular albums to save calls if needed)
      // For now, let's take top 5 albums to avoid rate limits or too many calls
      final albumTracksFutures = albums.take(5).map((album) => _spotifyApiService.getAlbumTracks(album.id!));
      final albumTracksLists = await Future.wait(albumTracksFutures);
      
      final allSongs = <Song>[...topTracks];
      final seenTitles = topTracks.map((s) => s.title.toLowerCase()).toSet();

      for (var i = 0; i < albumTracksLists.length; i++) {
        final tracks = albumTracksLists[i];
        final album = albums[i]; // Corresponding album
        
        for (final track in tracks) {
          if (!seenTitles.contains(track.name!.toLowerCase())) {
            seenTitles.add(track.name!.toLowerCase());
            // We need to map TrackSimple to Song. TrackSimple doesn't have album images directly usually,
            // but we have the album object.
            String? imageUrl;
            if (album.images != null && album.images!.isNotEmpty) {
              imageUrl = album.images!.first.url;
            }
            
            allSongs.add(Song(
              videoId: track.id ?? "", // Use Spotify ID
              title: track.name!,
              artist: track.artists?.map((a) => a.name).join(", ") ?? "Unknown Artist",
              thumbnailUrl: imageUrl ?? "",
            ));
          }
        }
      }
      
      return allSongs;
    } catch (e) {
      print("Error fetching all artist tracks: $e");
      // Fallback to top tracks
      return getArtistTopTracks(artistId);
    }
  }

  Future<List<Song>> getRecommendations(Song song) async {
    try {
      // For now, we use the artist's top tracks as recommendations.
      // In the future, we can use Spotify's recommendation API if we have seed tracks/artists.
      // We first need to find the artist ID if we don't have it.
      // But getArtistTopTracks needs an ID.
      // Our Song object doesn't always have the Artist ID (especially if from YouTube).
      
      // Strategy:
      // 1. Search for the artist on Spotify to get ID.
      // 2. Get Top Tracks for that artist.
      
      final artists = await _spotifyApiService.getTopArtists(song.artist);
      if (artists.isNotEmpty) {
        final artistId = artists.first.id!;
        final tracks = await getArtistTopTracks(artistId);
        // Filter out the current song
        return tracks.where((s) => s.title.toLowerCase() != song.title.toLowerCase()).toList();
      }
      
      return [];
    } catch (e) {
      print("Error fetching recommendations: $e");
      return [];
    }
  }

  Future<String> getStreamUrl(String title, String artist) async {
    try {
      // 1. Search YouTube for "Title Artist Audio"
      final query = "$title $artist Audio";
      final searchResponse = await _youtubeApiService.search(query);
      final songs = _parseSearchResults(searchResponse);
      
      if (songs.isEmpty) throw Exception('Song not found on YouTube');
      
      // 2. Try to get Stream URL from the first few results
      // Sometimes the first result is restricted or fails to load, so we try others.
      Exception? lastException;
      
      for (final song in songs.take(4)) { // Try top 4 results
        try {
          final playerResponse = await _youtubeApiService.getPlayer(song.videoId);
          return _extractStreamUrl(playerResponse);
        } catch (e) {
          print("Failed to play video ${song.videoId} (${song.title}): $e");
          lastException = Exception(e.toString());
          continue; // Try next video
        }
      }
      
      throw lastException ?? Exception('No working stream found for this song');
    } catch (e) {
      throw Exception('Failed to get stream URL: $e');
    }
  }

  Future<List<HomeSection>> getHomeSections() async {
    final List<HomeSection> sections = [];
    final language = _userPreferences.language;
    final languageName = _getLanguageName(language);

    try {
      // 0. Quick Dial (Recently Played)
      final history = _userPreferences.getSongHistory();
      if (history.isNotEmpty) {
        sections.add(HomeSection(
          title: "Quick Dial",
          items: history.map((s) => MusicItem(
            videoId: s['id'] ?? "",
            title: s['title'] ?? "",
            subtitle: s['artist'] ?? "",
            thumbnailUrl: s['artUri'] ?? "",
          )).toList(),
        ));
      }

      // 1. Fetch Language Specific Hits (Spotify)
      if (language.isNotEmpty && language != 'en') {
        try {
          final langTracks = await _spotifyApiService.getLanguageHits(languageName);
          if (langTracks.isNotEmpty) {
            sections.add(HomeSection(
              title: "Top $languageName Hits",
              items: _mapSpotifyTracksToMusicItems(langTracks),
            ));
          }
          
          final newLangTracks = await _spotifyApiService.getNewReleases(languageName);
          if (newLangTracks.isNotEmpty) {
             sections.add(HomeSection(
              title: "New $languageName Songs",
              items: _mapSpotifyTracksToMusicItems(newLangTracks),
            ));
          }
        } catch (e) {
          print("Spotify fetch failed: $e");
        }
      }

      // 2. India Charts (if applicable)
      if (['hi', 'ta', 'ml', 'kn', 'te', 'pa'].contains(language)) {
         try {
           final indiaTracks = await _spotifyApiService.getTopTracks(market: 'IN');
           if (indiaTracks.isNotEmpty) {
             sections.add(HomeSection(
               title: "India Top 50",
               items: _mapSpotifyTracksToMusicItems(indiaTracks),
             ));
           }
         } catch (e) {
           print("India charts fetch failed: $e");
         }
      }

      // 3. Fetch Global/English Hits (Spotify)
      try {
        final globalTracks = await _spotifyApiService.getTopTracks();
        if (globalTracks.isNotEmpty) {
          sections.add(HomeSection(
            title: "Global Top 50",
            items: _mapSpotifyTracksToMusicItems(globalTracks),
          ));
        }
      } catch (e) {
        print("Spotify global fetch failed: $e");
      }

      // 4. Fallback to YouTube if Spotify returned nothing (likely due to missing credentials)
      if (sections.isEmpty || sections.length == 1) { // Only Quick Dial or empty
        print("Spotify returned no content, falling back to YouTube with filtering...");
        
        // Fetch Language Specific Content from YouTube
        if (language.isNotEmpty) {
          // Use more specific queries to avoid unwanted content
          final queries = [
            "Top $languageName Music Charts",
            "Latest $languageName Movie Songs",
            "Best $languageName Melodies"
          ];

          for (final query in queries) {
            try {
              final songs = await searchSongs(query);
              final filteredSongs = _filterUnwantedContent(songs);
              
              if (filteredSongs.isNotEmpty) {
                sections.add(HomeSection(
                  title: query,
                  items: filteredSongs.map((s) => MusicItem(
                    videoId: s.videoId,
                    title: s.title,
                    subtitle: s.artist,
                    thumbnailUrl: s.thumbnailUrl
                  )).toList()
                ));
              }
            } catch (e) {
              print("YouTube fallback fetch failed for $query: $e");
            }
          }
        }
        
        // Always add English/Global content
        try {
           final globalSongs = await searchSongs("Global Top Music Hits");
           final filteredGlobal = _filterUnwantedContent(globalSongs);
           if (filteredGlobal.isNotEmpty) {
             sections.add(HomeSection(
               title: "Global Top Hits",
               items: filteredGlobal.map((s) => MusicItem(
                 videoId: s.videoId,
                 title: s.title,
                 subtitle: s.artist,
                 thumbnailUrl: s.thumbnailUrl
               )).toList()
             ));
           }
        } catch (e) {
           print("YouTube global fetch failed: $e");
        }
      }

      // 5. Trending Music Videos (YouTube) - Moved to bottom
      try {
        final trendingVideos = await searchSongs("Trending Music Videos ${languageName}");
        if (trendingVideos.isNotEmpty) {
          sections.add(HomeSection(
            title: "Trending Music Videos",
            items: trendingVideos.take(10).map((s) => MusicItem(
              videoId: s.videoId,
              title: s.title,
              subtitle: s.artist,
              thumbnailUrl: s.thumbnailUrl
            )).toList(),
          ));
        }
      } catch (e) {
        print("Trending videos fetch failed: $e");
      }

      return sections;
    } catch (e) {
      print("Error fetching home sections: $e");
      return [];
    }
  }

  List<Song> _filterUnwantedContent(List<Song> songs) {
    final unwantedKeywords = [
      'rasi palan', 'horoscope', 'jothidam', 'astrology', 
      'devotional', 'bakthi', 'god', 'amman', 'murugan', 'jesus', 'allah' // Add more if needed based on user request "religious contents"
    ];
    
    return songs.where((song) {
      final titleLower = song.title.toLowerCase();
      final artistLower = song.artist.toLowerCase();
      
      for (final keyword in unwantedKeywords) {
        if (titleLower.contains(keyword) || artistLower.contains(keyword)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  List<MusicItem> _mapSpotifyTracksToMusicItems(List<spotify.Track> tracks) {
    return tracks.map((t) {
      String? imageUrl;
      if (t.album != null && t.album!.images != null && t.album!.images!.isNotEmpty) {
        imageUrl = t.album!.images!.first.url;
      }
      
      return MusicItem(
        videoId: t.id ?? "", // Use Spotify ID
        title: t.name ?? "Unknown",
        subtitle: t.artists?.map((a) => a.name).join(", ") ?? "Unknown Artist",
        thumbnailUrl: imageUrl ?? "",
      );
    }).toList();
  }

  // ... (Keep helper methods for YouTube parsing as they are needed for search/stream)
  
  String _getLanguageName(String code) {
    switch (code) {
      case 'en': return 'English';
      case 'hi': return 'Hindi';
      case 'ta': return 'Tamil';
      case 'ml': return 'Malayalam';
      case 'kn': return 'Kannada';
      case 'te': return 'Telugu';
      case 'es': return 'Spanish';
      case 'ja': return 'Japanese';
      default: return code;
    }
  }

  List<Song> _parseSearchResults(Map<String, dynamic> response) {
    final List<Song> songs = [];
    try {
      final contents = response['contents']?['tabbedSearchResultsRenderer']?['tabs']?[0]
          ?['tabRenderer']?['content']?['sectionListRenderer']?['contents'];

      if (contents == null) return [];

      for (final section in contents) {
        final musicShelf = section['musicShelfRenderer'];
        if (musicShelf != null) {
          final items = musicShelf['contents'];
          if (items != null) {
            for (final item in items) {
              final renderer = item['musicResponsiveListItemRenderer'];
              if (renderer != null) {
                final song = _parseSongItem(renderer);
                if (song != null) {
                  songs.add(song);
                }
              }
            }
          }
        }
      }
    } catch (e) {
      print('Error parsing search results: $e');
    }
    return songs;
  }

  Song? _parseSongItem(Map<String, dynamic> renderer) {
    try {
      final flexColumns = renderer['flexColumns'];
      final title = flexColumns[0]['musicResponsiveListItemFlexColumnRenderer']['text']
          ['runs'][0]['text'];
      
      final videoId = renderer['playlistItemData']?['videoId'] ??
          flexColumns[0]['musicResponsiveListItemFlexColumnRenderer']['text']['runs'][0]
              ['navigationEndpoint']?['watchEndpoint']?['videoId'];

      if (videoId == null) return null;

      final artistRuns = flexColumns[1]['musicResponsiveListItemFlexColumnRenderer']
          ['text']['runs'];
      String artist = "Unknown Artist";
      if (artistRuns != null && artistRuns.isNotEmpty) {
        artist = artistRuns[0]['text'];
      }

      final thumbnails = renderer['thumbnail']?['musicThumbnailRenderer']?['thumbnail']
          ?['thumbnails'];
      String thumbnailUrl = "";
      if (thumbnails != null && thumbnails.isNotEmpty) {
        thumbnailUrl = thumbnails.last['url'];
      }

      return Song(
        videoId: videoId,
        title: title,
        artist: artist,
        thumbnailUrl: thumbnailUrl,
      );
    } catch (e) {
      return null;
    }
  }

  String _extractStreamUrl(Map<String, dynamic> response) {
    try {
      final streamingData = response['streamingData'];
      if (streamingData == null) throw Exception('No streaming data found');

      final adaptiveFormats = streamingData['adaptiveFormats'] as List<dynamic>?;
      if (adaptiveFormats == null) throw Exception('No adaptive formats found');

      final audioFormats = adaptiveFormats.where((format) {
        final mimeType = format['mimeType'] as String?;
        final hasUrl = format['url'] != null;
        return mimeType != null && mimeType.startsWith('audio/') && hasUrl;
      }).toList();

      if (audioFormats.isEmpty) {
        throw Exception('No audio formats with direct URLs found.');
      }

      audioFormats.sort((a, b) {
        final bitrateA = a['bitrate'] as int? ?? 0;
        final bitrateB = b['bitrate'] as int? ?? 0;
        return bitrateB.compareTo(bitrateA);
      });

      final url = audioFormats.first['url'] as String;
      return url;
    } catch (e) {
      throw Exception('Failed to extract stream URL: $e');
    }
  }
}
