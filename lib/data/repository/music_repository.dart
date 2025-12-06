import 'package:hive_flutter/hive_flutter.dart';
import 'package:mixify/data/models/imported_playlist.dart';
import 'package:mixify/data/models/innertube_models.dart';
import 'package:mixify/data/network/spotify_api_service.dart';
import 'package:mixify/data/network/youtube_api_service.dart';
import 'package:mixify/data/preferences/user_preferences.dart';
import 'package:spotify/spotify.dart' as spotify;

class MusicRepository {
  final YouTubeApiService _youtubeApiService;
  final SpotifyApiService _spotifyApiService;
  final UserPreferences _userPreferences;
  final Box _cacheBox;

  MusicRepository(this._youtubeApiService, this._spotifyApiService, this._userPreferences, this._cacheBox);

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

  // YouTube Music "Songs" filter param
  static const String kSongFilterParams = "EgWKAQIIAWoKEAkQCRADEAQQBQ==";

  Future<String> getStreamUrl(String title, String artist, {String? videoId}) async {
    try {
      // 1. If we have a videoId, try to get the stream directly
      if (videoId != null && videoId.isNotEmpty) {
        try {
          final playerResponse = await _youtubeApiService.getPlayer(videoId);
          return _extractStreamUrl(playerResponse);
        } catch (e) {
          print("Direct playback failed for $videoId, falling back to search: $e");
          // Fallback to search if direct ID fails (e.g. if ID is from Spotify and not valid on YouTube)
        }
      }

      // 2. Search YouTube with "Songs" filter first
      // This is much more accurate for finding the official audio
      final language = _userPreferences.language;
      final languageName = _getLanguageName(language);
      
      String query = "$title $artist";
      if (language.isNotEmpty && language != 'en') {
         query += " $languageName";
      }
      
      try {
        final searchResponse = await _youtubeApiService.search(query, params: kSongFilterParams);
        final songs = _parseSearchResults(searchResponse);
        
        if (songs.isNotEmpty) {
           for (final song in songs.take(4)) {
             try {
               final playerResponse = await _youtubeApiService.getPlayer(song.videoId);
               return _extractStreamUrl(playerResponse);
             } catch (e) {
               continue;
             }
           }
        }
      } catch (e) {
        print("Filtered search failed: $e");
      }

      // 3. Fallback to general search if filtered search failed or returned no playable songs
      final generalQuery = "$title $artist Audio";
      final searchResponse = await _youtubeApiService.search(generalQuery);
      final songs = _parseSearchResults(searchResponse);
      
      if (songs.isEmpty) throw Exception('Song not found on YouTube');
      
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

  Future<ImportedPlaylist?> fetchPlaylistDetails(String url) async {
    try {
      if (url.contains("spotify.com")) {
        // Parse Spotify URL
        final uri = Uri.parse(url);
        String? playlistId;
        if (uri.pathSegments.contains('playlist')) {
          playlistId = uri.pathSegments.last;
        }
        
        if (playlistId != null) {
          final playlist = await _spotifyApiService.getPlaylist(playlistId);
          final tracks = await _spotifyApiService.getPlaylistTracks(playlistId);
          
          if (playlist != null) {
             return ImportedPlaylist(
               title: playlist.name ?? "Imported Playlist",
               songs: tracks.map((t) => Song(
                 videoId: "", // No video ID yet, will be searched on playback
                 title: t.name ?? "",
                 artist: t.artists?.map((a) => a.name).join(", ") ?? "",
                 thumbnailUrl: t.album?.images?.first.url ?? "",
               )).toList(),
             );
          }
        }
      } else if (url.contains("music.youtube.com") || url.contains("youtube.com")) {
        // Parse YouTube URL
        final uri = Uri.parse(url);
        final listId = uri.queryParameters['list'];
        
        if (listId != null) {
          final data = await _youtubeApiService.getPlaylist(listId);
          
          // Parse InnerTube Response (This is complex, simplified for now)
          // We need to navigate the JSON to find tracks.
          // Usually: contents -> twoColumnBrowseResultsRenderer -> tabs -> tabRenderer -> content -> sectionListRenderer -> contents -> musicPlaylistShelfRenderer -> contents
          
          try {
             final tabs = data['contents']?['twoColumnBrowseResultsRenderer']?['tabs'] as List?;
             final tab = tabs?.firstWhere((t) => t['tabRenderer']?['selected'] == true);
             final content = tab?['tabRenderer']?['content']?['sectionListRenderer']?['contents']?.first;
             final playlistShelf = content?['musicPlaylistShelfRenderer'];
             
             final title = data['header']?['musicDetailHeaderRenderer']?['title']?['runs']?.first?['text'] ?? "Imported Playlist";
             
             final items = playlistShelf?['contents'] as List?;
             if (items != null) {
               final songs = <Song>[];
               for (final item in items) {
                 final mrl = item['musicResponsiveListItemRenderer'];
                 if (mrl != null) {
                   final title = mrl['flexColumns']?[0]?['musicResponsiveListItemFlexColumnRenderer']?['text']?['runs']?[0]?['text'];
                   final artist = mrl['flexColumns']?[1]?['musicResponsiveListItemFlexColumnRenderer']?['text']?['runs']?[0]?['text'];
                   final videoId = mrl['playlistItemData']?['videoId'];
                   final thumbnail = mrl['thumbnail']?['musicThumbnailRenderer']?['thumbnail']?['thumbnails']?.last?['url'];
                   
                   if (title != null && videoId != null) {
                     songs.add(Song(
                       videoId: videoId,
                       title: title,
                       artist: artist ?? "Unknown",
                       thumbnailUrl: thumbnail ?? "",
                     ));
                   }
                 }
               }
               return ImportedPlaylist(title: title, songs: songs);
             }
          } catch (e) {
            print("Error parsing YouTube playlist: $e");
          }
        }
      }
    } catch (e) {
      print("Error fetching playlist details: $e");
    }
    return null;
  }

  Future<void> clearHomeCache() async {
    await _cacheBox.delete('home_sections');
    await _cacheBox.delete('home_sections_timestamp');
  }

  Future<List<HomeSection>> getHomeSections() async {
    // 1. Check Cache
    try {
      final timestamp = _cacheBox.get('home_sections_timestamp');
      if (timestamp != null) {
        final difference = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(timestamp));
        // Cache valid for 1 hour
        if (difference.inHours < 1) {
           final cachedData = _cacheBox.get('home_sections');
           if (cachedData != null) {
             print("Loading Home Sections from Cache");
             final List<dynamic> decoded = cachedData;
             return decoded.map((e) => HomeSection.fromJson(Map<String, dynamic>.from(e))).toList();
           }
        }
      }
    } catch (e) {
      print("Error reading cache: $e");
    }

    final List<HomeSection> sections = [];
    final language = _userPreferences.language;
    final languageName = _getLanguageName(language);

    try {
      // 0. Quick Dial (Recently Played + Suggestions to fill 9 tiles)
      final history = _userPreferences.getSongHistory();
      List<MusicItem> quickDialItems = history.map((s) => MusicItem(
        videoId: s['id'] ?? "",
        title: s['title'] ?? "",
        subtitle: s['artist'] ?? "",
        thumbnailUrl: s['artUri'] ?? "",
      )).toList();

      // If less than 9, fill with language specific hits
      if (quickDialItems.length < 9) {
        try {
          final needed = 9 - quickDialItems.length;
          // Try to get language hits first
          var fillTracks = <spotify.Track>[];
          if (language.isNotEmpty && language != 'en') {
             fillTracks = await _spotifyApiService.getLanguageHits(languageName);
          }
          
          // If still not enough or no language, try global
          if (fillTracks.isEmpty) {
             fillTracks = await _spotifyApiService.getTopTracks();
          }
          
          // Take what we need
          final fillItems = _mapSpotifyTracksToMusicItems(fillTracks.take(needed).toList());
          
          // Filter duplicates (simple check by ID)
          final existingIds = quickDialItems.map((i) => i.videoId).toSet();
          for (final item in fillItems) {
            if (!existingIds.contains(item.videoId)) {
              quickDialItems.add(item);
            }
          }
          
          // If still < 9 (e.g. duplicates removed), we might need more, but for now let's accept it might be slightly less 
          // or we could fetch more. But this is a good start.
        } catch (e) {
          print("Error filling Quick Dial: $e");
        }
      }
      
      // Limit to 9 if we have more (history could be long)
      if (quickDialItems.length > 9) {
        quickDialItems = quickDialItems.take(9).toList();
      }

      if (quickDialItems.isNotEmpty) {
        sections.add(HomeSection(
          title: "Speed dial", // Renamed from Quick Dial as per user request
          items: quickDialItems,
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

      // Save to Cache
      if (sections.isNotEmpty) {
        try {
           final encoded = sections.map((s) => s.toJson()).toList();
           await _cacheBox.put('home_sections', encoded);
           await _cacheBox.put('home_sections_timestamp', DateTime.now().millisecondsSinceEpoch);
        } catch (e) {
           print("Error saving to cache: $e");
        }
      }

      return sections;
    } catch (e) {
      print("Error fetching home sections: $e");
      // Try to return stale cache if fetch fails
      try {
         final cachedData = _cacheBox.get('home_sections');
         if (cachedData != null) {
           print("Returning stale cache due to error");
           final List<dynamic> decoded = cachedData;
           return decoded.map((e) => HomeSection.fromJson(Map<String, dynamic>.from(e))).toList();
         }
      } catch (_) {}
      
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
