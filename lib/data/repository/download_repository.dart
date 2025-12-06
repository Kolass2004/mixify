import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

enum DownloadStatus { queued, downloading, completed, failed, paused }

class DownloadItem {
  final String id;
  final Map<String, dynamic> metadata;
  final String url;
  double progress;
  double speed; // in bytes per second
  DownloadStatus status;
  String? error;

  DownloadItem({
    required this.id,
    required this.metadata,
    required this.url,
    this.progress = 0.0,
    this.speed = 0.0,
    this.status = DownloadStatus.queued,
    this.error,
  });
}

class DownloadRepository {
  static const _boxSongs = 'downloaded_songs';
  static const _boxAlbums = 'downloaded_albums';
  static const _boxPlaylists = 'downloaded_playlists';

  late Box _songsBox;
  late Box _albumsBox;
  late Box _playlistsBox;
  final Dio _dio = Dio();
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  // Queue and Active Downloads
  final List<DownloadItem> _queue = [];
  DownloadItem? _currentDownload;
  final StreamController<List<DownloadItem>> _downloadStreamController = StreamController.broadcast();

  Stream<List<DownloadItem>> get downloadStream => _downloadStreamController.stream;

  Future<void> init() async {
    _songsBox = await Hive.openBox(_boxSongs);
    _albumsBox = await Hive.openBox(_boxAlbums);
    _playlistsBox = await Hive.openBox(_boxPlaylists);
    
    // Configure Dio
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 60);
    _dio.options.headers = {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
      'Referer': 'https://www.youtube.com/',
    };

    // Initialize Notifications
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    await _notificationsPlugin.initialize(initializationSettings);
  }

  Future<bool> requestPermission() async {
    if (Platform.isAndroid) {
       var status = await Permission.storage.status;
       
       if (await Permission.audio.status.isGranted || await Permission.storage.status.isGranted) {
         return true;
       }
       
       if (await Permission.audio.request().isGranted) return true;
       if (await Permission.storage.request().isGranted) return true;
       
       return false;
    }
    return true;
  }

  ValueListenable<Box> get songsBoxListenable => _songsBox.listenable();

  Future<String> _getDownloadPath(String filename) async {
    Directory? directory;
    if (Platform.isAndroid) {
      // Use public Download directory
      directory = Directory('/storage/emulated/0/Download/Mixify');
    } else {
      final dir = await getApplicationDocumentsDirectory();
      directory = Directory('${dir.path}/Mixify');
    }

    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return '${directory.path}/$filename';
  }

  Future<void> downloadSongWithUrl(Map<String, dynamic> song, String downloadUrl) async {
    // Add to queue
    final item = DownloadItem(
      id: song['id'],
      metadata: song,
      url: downloadUrl,
    );
    
    // Check if already downloading or queued
    if (_currentDownload?.id == item.id || _queue.any((i) => i.id == item.id)) {
      return; // Already in progress
    }
    
    // Check if already downloaded
    if (isSongDownloaded(item.id)) {
      return;
    }

    _queue.add(item);
    _notifyListeners();
    _processQueue();
  }

  void _notifyListeners() {
    final allItems = <DownloadItem>[];
    if (_currentDownload != null) allItems.add(_currentDownload!);
    allItems.addAll(_queue);
    _downloadStreamController.add(allItems);
  }

  Future<void> _showNotification(DownloadItem item) async {
    if (Platform.isAndroid) {
      final androidPlatformChannelSpecifics = AndroidNotificationDetails(
        'download_channel',
        'Downloads',
        channelDescription: 'Show download progress',
        importance: Importance.low,
        priority: Priority.low,
        showProgress: true,
        maxProgress: 100,
        progress: (item.progress * 100).toInt(),
        onlyAlertOnce: true,
      );
      final platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);
      await _notificationsPlugin.show(
        item.id.hashCode,
        'Downloading ${item.metadata['title']}',
        '${(item.progress * 100).toInt()}%',
        platformChannelSpecifics,
      );
    }
  }

  Future<void> _cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id);
  }

  Future<void> _processQueue() async {
    if (_currentDownload != null || _queue.isEmpty) return;

    _currentDownload = _queue.removeAt(0);
    _currentDownload!.status = DownloadStatus.downloading;
    _notifyListeners();

    try {
      final filename = '${_currentDownload!.id}.m4a';
      final savePath = await _getDownloadPath(filename);

      // Download Audio
      await _downloadInChunks(_currentDownload!, savePath);

      // Download Thumbnail
      String? localThumbnailPath;
      try {
        final thumbnailUrl = _currentDownload!.metadata['thumbnailUrl'];
        if (thumbnailUrl != null && thumbnailUrl.isNotEmpty) {
           final thumbFilename = '${_currentDownload!.id}.jpg';
           localThumbnailPath = await _getDownloadPath(thumbFilename);
           await _dio.download(thumbnailUrl, localThumbnailPath);
        }
      } catch (e) {
        print("Thumbnail download failed: $e");
        // Continue even if thumbnail fails
      }

      // Success
      _currentDownload!.status = DownloadStatus.completed;
      _currentDownload!.progress = 1.0;
      _notifyListeners();
      _cancelNotification(_currentDownload!.id.hashCode);

      // Save metadata
      final downloadedSong = Map<String, dynamic>.from(_currentDownload!.metadata);
      downloadedSong['localPath'] = savePath;
      if (localThumbnailPath != null) {
        downloadedSong['localThumbnailPath'] = localThumbnailPath;
      }
      downloadedSong['downloadedAt'] = DateTime.now().toIso8601String();
      await _songsBox.put(_currentDownload!.id, downloadedSong);

    } catch (e) {
      print("Download error: $e");
      _currentDownload!.status = DownloadStatus.failed;
      _currentDownload!.error = e.toString();
      _notifyListeners();
      _cancelNotification(_currentDownload!.id.hashCode);
    } finally {
      // Move to next
      await Future.delayed(const Duration(seconds: 1)); // Show completion briefly
      _currentDownload = null;
      _notifyListeners();
      _processQueue();
    }
  }

  Future<void> _downloadInChunks(DownloadItem item, String savePath) async {
    const int chunkSize = 1024 * 1024 * 2; // 2MB chunks
    int maxRetries = 5;
    final file = File(savePath);
    
    // 1. Get total size
    int totalBytes = await _getContentLength(item.url);
    if (totalBytes == 0) {
       // Fallback to simple download if we can't get length
       // But actually, for YouTube streams, we really want chunking.
       // Let's try to just download without range if length is unknown, 
       // but usually length IS known for these streams.
       await _downloadSimple(item, savePath); 
       return;
    }

    // 2. Prepare file
    if (!await file.exists()) {
      await file.create();
    } else {
      // If file exists and is larger than total, truncate it? 
      // Or maybe it's a previous finished download?
      // For safety, let's check size.
      int currentSize = await file.length();
      if (currentSize == totalBytes) {
        return; // Already done
      } else if (currentSize > totalBytes) {
        // Corrupted or wrong file, delete and start over
        await file.delete();
        await file.create();
      }
    }
    
    int downloadedBytes = await file.length();
    RandomAccessFile raf = await file.open(mode: FileMode.append);

    try {
      while (downloadedBytes < totalBytes) {
        int end = downloadedBytes + chunkSize - 1;
        if (end >= totalBytes) {
          end = totalBytes - 1;
        }
        
        bool chunkSuccess = false;
        int retryCount = 0;
        
        while (!chunkSuccess && retryCount < maxRetries) {
          try {
            final options = Options(
              headers: {
                'Range': 'bytes=$downloadedBytes-$end',
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
                'Referer': 'https://www.youtube.com/',
                'Connection': 'keep-alive',
              },
              responseType: ResponseType.bytes,
            );
            
            final response = await _dio.get(item.url, options: options);
            
            if (response.statusCode == 206) {
              final List<int> bytes = response.data;
              raf.writeFromSync(bytes);
              downloadedBytes += bytes.length;
              chunkSuccess = true;
              
              // Update progress
              item.progress = downloadedBytes / totalBytes;
              _notifyListeners();
              _showNotification(item);
            } else {
               // If server returns 200, it ignored range. 
               // If we are at 0 bytes, we can accept it.
               if (response.statusCode == 200 && downloadedBytes == 0) {
                 final List<int> bytes = response.data;
                 raf.writeFromSync(bytes);
                 downloadedBytes += bytes.length;
                 // If it gave us the whole file, we are done.
                 if (downloadedBytes == totalBytes) {
                   chunkSuccess = true;
                   break;
                 }
                 // If it gave us a chunk but 200 OK? Unlikely for a full file request.
                 // Usually 200 means full resource.
                 chunkSuccess = true;
               } else {
                 throw Exception("Expected 206 Partial Content but got ${response.statusCode}");
               }
            }
          } catch (e) {
            retryCount++;
            print("Chunk download failed ($retryCount/$maxRetries): $e");
            await Future.delayed(const Duration(seconds: 1));
          }
        }
        
        if (!chunkSuccess) {
          throw Exception("Failed to download chunk after $maxRetries retries");
        }
      }
    } finally {
      await raf.close();
    }
  }

  Future<int> _getContentLength(String url) async {
    try {
      final response = await _dio.head(url, options: Options(
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
          'Referer': 'https://www.youtube.com/',
        }
      ));
      final length = response.headers.value('content-length');
      if (length != null) {
        return int.parse(length);
      }
    } catch (e) {
      print("HEAD request failed: $e");
    }
    
    // Try GET with range 0-0
    try {
      final response = await _dio.get(url, options: Options(
        headers: {
          'Range': 'bytes=0-0',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
          'Referer': 'https://www.youtube.com/',
        }
      ));
      final range = response.headers.value('content-range');
      if (range != null) {
        // bytes 0-0/12345
        final parts = range.split('/');
        if (parts.length > 1) {
          return int.parse(parts[1]);
        }
      }
    } catch (e) {
      print("GET 0-0 request failed: $e");
    }
    
    return 0;
  }

  Future<void> _downloadSimple(DownloadItem item, String savePath) async {
    await _dio.download(
      item.url,
      savePath,
      onReceiveProgress: (received, total) {
        if (total != -1) {
          item.progress = received / total;
          _notifyListeners();
          _showNotification(item);
        }
      },
    );
  }

  bool isSongDownloaded(String songId) {
    return _songsBox.containsKey(songId);
  }

  Map<String, dynamic>? getDownloadedSong(String songId) {
    final data = _songsBox.get(songId);
    if (data != null) {
      return Map<String, dynamic>.from(data);
    }
    return null;
  }

  Future<void> deleteSong(String songId) async {
    final song = getDownloadedSong(songId);
    if (song != null) {
      final path = song['localPath'];
      if (path != null) {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      }
      
      final thumbPath = song['localThumbnailPath'];
      if (thumbPath != null) {
        final thumbFile = File(thumbPath);
        if (await thumbFile.exists()) {
          await thumbFile.delete();
        }
      }

      await _songsBox.delete(songId);
    }
  }
  
  List<Map<String, dynamic>> getAllDownloadedSongs() {
    return _songsBox.values.map((e) => Map<String, dynamic>.from(e)).toList();
  }
}
