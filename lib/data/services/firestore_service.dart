import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _userId => _auth.currentUser?.uid;

  // --- Settings Sync ---

  Future<void> saveSettings(Map<String, dynamic> settings) async {
    if (_userId == null) return;

    try {
      await _firestore.collection('users').doc(_userId).set({
        'settings': settings,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error saving settings to Firestore: $e');
    }
  }

  Future<void> saveUserInitialData({required String region, required String language}) async {
    if (_userId == null) return;

    try {
      await _firestore.collection('users').doc(_userId).set({
        'settings': {
          'region': region,
          'language': language,
        },
        'createdAt': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error saving initial data to Firestore: $e');
    }
  }

  Future<Map<String, dynamic>?> getSettings() async {
    if (_userId == null) return null;
    try {
      final doc = await _firestore.collection('users').doc(_userId).get();
      if (doc.exists && doc.data() != null) {
        return doc.data()!['settings'] as Map<String, dynamic>?;
      }
    } catch (e) {
      print("Error fetching settings from Firestore: $e");
    }
    return null;
  }

  // --- History Sync ---

  Future<void> saveHistory(List<Map<String, dynamic>> history) async {
    if (_userId == null) return;
    try {
      await _firestore.collection('users').doc(_userId).set({
        'history': history,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print("Error saving history to Firestore: $e");
    }
  }

  Future<List<Map<String, dynamic>>?> getHistory() async {
    if (_userId == null) return null;
    try {
      final doc = await _firestore.collection('users').doc(_userId).get();
      if (doc.exists && doc.data() != null && doc.data()!.containsKey('history')) {
        final List<dynamic> history = doc.data()!['history'];
        return history.map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (e) {
      print("Error fetching history from Firestore: $e");
    }
    return null;
  }

  // --- Playlist Sync ---

  Future<void> savePlaylist(Map<String, dynamic> playlist) async {
    if (_userId == null) return;
    try {
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('playlists')
          .doc(playlist['id'])
          .set(playlist);
    } catch (e) {
      print("Error saving playlist to Firestore: $e");
    }
  }

  Future<void> deletePlaylist(String playlistId) async {
    if (_userId == null) return;
    try {
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('playlists')
          .doc(playlistId)
          .delete();
    } catch (e) {
      print("Error deleting playlist from Firestore: $e");
    }
  }

  Future<List<Map<String, dynamic>>> getPlaylists() async {
    if (_userId == null) return [];
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('playlists')
          .get();
      
      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      print("Error fetching playlists from Firestore: $e");
      return [];
    }
  }
}
