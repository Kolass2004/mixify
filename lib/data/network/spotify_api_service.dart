import 'package:spotify/spotify.dart';

class SpotifyApiService {
  // TODO: Replace with your own Client ID and Client Secret
  // You can get them from https://developer.spotify.com/dashboard
  static const String _clientId = '8ddbbf24b0aa467bb8583572952c1684';
  static const String _clientSecret = '4f3121ce10ef42babc89a91be39a9171';

  late SpotifyApi _spotify;

  SpotifyApiService() {
    final credentials = SpotifyApiCredentials(_clientId, _clientSecret);
    _spotify = SpotifyApi(credentials);
  }

  Future<List<Track>> getTopTracks({String market = 'US'}) async {
    try {
      String query = 'Top 50 - Global';
      if (market == 'IN') query = 'Top 50 - India';
      else if (market == 'US') query = 'Top 50 - USA';

      // Search for the playlist first to get a valid ID
      final search = await _spotify.search.get(query, types: [SearchType.playlist]).first();
      
      if (search.isEmpty || search.first.items == null || search.first.items!.isEmpty) {
        print('No playlist found for $market');
        return [];
      }

      final playlistId = search.first.items!.first.id!;
      // Use .first() to get the first page of tracks (usually 50) instead of .all()
      // This avoids potential paging errors and is faster
      final tracksPage = await _spotify.playlists.getTracksByPlaylistId(playlistId).first();
      return tracksPage.items?.toList() ?? [];
    } catch (e) {
      print('Error fetching top tracks for market $market: $e');
      return [];
    }
  }

  Future<List<Track>> getLanguageHits(String language) async {
    try {
      // Search for a playlist named "Top [Language] Hits"
      final search = await _spotify.search.get('Top $language Hits', types: [SearchType.playlist]).first();
      if (search.isEmpty || search.first.items == null || search.first.items!.isEmpty) {
        return [];
      }
      
      final playlistId = search.first.items!.first.id!;
      final tracksPage = await _spotify.playlists.getTracksByPlaylistId(playlistId).first();
      return tracksPage.items?.toList() ?? [];
    } catch (e) {
      print('Error fetching $language hits: $e');
      return [];
    }
  }
  
  Future<List<Track>> getNewReleases(String language) async {
     try {
      // Search for a playlist named "New [Language] Songs" or similar
      final search = await _spotify.search.get('New $language Songs', types: [SearchType.playlist]).first();
      if (search.isEmpty || search.first.items == null || search.first.items!.isEmpty) {
         // Fallback to generic new releases if specific not found
         return [];
      }
      
      final playlistId = search.first.items!.first.id!;
      final tracksPage = await _spotify.playlists.getTracksByPlaylistId(playlistId).first();
      return tracksPage.items?.toList() ?? [];
    } catch (e) {
      print('Error fetching new $language songs: $e');
      return [];
    }
  }

  Future<List<Artist>> getTopArtists(String language) async {
    try {
      // Search for artists associated with the language
      // Using a broader search query to get relevant artists
      final search = await _spotify.search.get(language, types: [SearchType.artist]).first();
      if (search.isEmpty || search.first.items == null) return [];
      return search.first.items!.toList().cast<Artist>();
    } catch (e) {
       print('Error fetching artists: $e');
       return [];
    }
  }

  Future<List<Track>> getArtistTopTracks(String artistId) async {
    try {
      final tracks = await _spotify.artists.getTopTracks(artistId, 'US'); // Country code is required
      return tracks.toList();
    } catch (e) {
      print('Error fetching artist top tracks: $e');
      return [];
    }
  }

  Future<List<AlbumSimple>> getArtistAlbums(String artistId) async {
    try {
      final albums = await _spotify.artists.albums(artistId).all();
      return albums.toList();
    } catch (e) {
      print('Error fetching artist albums: $e');
      return [];
    }
  }

  Future<List<TrackSimple>> getAlbumTracks(String albumId) async {
    try {
      final tracks = await _spotify.albums.getTracks(albumId).all();
      return tracks.toList();
    } catch (e) {
      print('Error fetching album tracks: $e');
      return [];
    }
  }
  Future<List<AlbumSimple>> searchAlbums(String query) async {
    try {
      final search = await _spotify.search.get(query, types: [SearchType.album]).first();
      if (search.isEmpty || search.first.items == null) return [];
      return search.first.items!.toList().cast<AlbumSimple>();
    } catch (e) {
      print('Error searching albums: $e');
      return [];
    }
  }
}
