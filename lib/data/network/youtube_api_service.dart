import 'package:dio/dio.dart';
import 'package:mixify/data/models/innertube_models.dart';

class YouTubeApiService {
  final Dio _dio;

  YouTubeApiService()
      : _dio = Dio(BaseOptions(
          baseUrl: 'https://music.youtube.com/youtubei/v1/',
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Origin': 'https://music.youtube.com',
            'Referer': 'https://music.youtube.com/',
            'Content-Type': 'application/json',
          },
        ));

  Future<Map<String, dynamic>> search(String query, {String hl = "en", String gl = "US"}) async {
    try {
      final body = InnerTubeBody(query: query, hl: hl, gl: gl);
      final response = await _dio.post('search', data: body.toJson());
      return response.data;
    } catch (e) {
      throw Exception('Failed to search: $e');
    }
  }

  Future<Map<String, dynamic>> getPlayer(String videoId) async {
    try {
      // Use ANDROID client for better chance of direct URLs
      final body = InnerTubeBody(
        videoId: videoId,
        clientName: "ANDROID",
        clientVersion: "19.05.36",
      );
      final response = await _dio.post('player', data: body.toJson());
      return response.data;
    } catch (e) {
      throw Exception('Failed to get player data: $e');
    }
  }

  Future<Map<String, dynamic>> browse(String browseId, {String hl = "en", String gl = "US"}) async {
    try {
      final body = InnerTubeBody(browseId: browseId, hl: hl, gl: gl);
      final response = await _dio.post('browse', data: body.toJson());
      return response.data;
    } catch (e) {
      throw Exception('Failed to get browse data: $e');
    }
  }
}
