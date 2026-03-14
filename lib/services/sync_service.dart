import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

import 'database_service.dart';

class SyncResult {
  final bool success;
  final String message;
  final DateTime syncedAt;

  SyncResult({
    required this.success,
    required this.message,
    required this.syncedAt,
  });
}

class SyncService {
  SyncService._();

  static final SyncService instance = SyncService._();
  static const String _collection = 'app_sync';
  static const String _docId = 'shared_state';

  final DatabaseService _databaseService = DatabaseService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<SyncResult> pushData() async {
    try {
      final String deviceId = await _getDeviceId();
      final Map<String, dynamic> localSnapshot =
          await _databaseService.exportAllTablesForSync();
      final String localHash = _computeHash(localSnapshot);

      await _firestore.collection(_collection).doc(_docId).set({
        'version': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': deviceId,
        'hash': localHash,
        'payload': localSnapshot,
      }, SetOptions(merge: true));

      return SyncResult(
        success: true,
        message: 'Donnees locales envoyees avec succes.',
        syncedAt: DateTime.now(),
      );
    } catch (e) {
      return SyncResult(
        success: false,
        message: 'Erreur lors de l\'envoi: $e',
        syncedAt: DateTime.now(),
      );
    }
  }

  Future<SyncResult> receiveData() async {
    try {
      final docRef = _firestore.collection(_collection).doc(_docId);
      final remoteDoc = await docRef.get();

      if (!remoteDoc.exists) {
        return SyncResult(
          success: false,
          message: 'Aucune donnee distante disponible.',
          syncedAt: DateTime.now(),
        );
      }

      final Map<String, dynamic> remoteData = remoteDoc.data() ?? {};
      final Map<String, dynamic> remotePayload =
          (remoteData['payload'] as Map<String, dynamic>?) ?? {};

      if (remotePayload.isEmpty) {
        return SyncResult(
          success: false,
          message: 'Le cloud ne contient aucune donnee importable.',
          syncedAt: DateTime.now(),
        );
      }

      await _databaseService.importAllTablesFromSync(remotePayload);

      return SyncResult(
        success: true,
        message: 'Donnees recues et appliquees localement.',
        syncedAt: DateTime.now(),
      );
    } catch (e) {
      return SyncResult(
        success: false,
        message: 'Erreur lors de la reception: $e',
        syncedAt: DateTime.now(),
      );
    }
  }

  String _computeHash(Map<String, dynamic> payload) {
    final String jsonPayload = jsonEncode(payload);
    return sha256.convert(utf8.encode(jsonPayload)).toString();
  }

  Future<String> _getDeviceId() async {
    try {
      final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      if (kIsWeb) {
        final webInfo = await deviceInfo.webBrowserInfo;
        return 'web-${webInfo.vendor}-${webInfo.userAgent}'.replaceAll(' ', '_');
      }

      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
          final androidInfo = await deviceInfo.androidInfo;
          return 'android-${androidInfo.id}';
        case TargetPlatform.iOS:
          final iosInfo = await deviceInfo.iosInfo;
          return 'ios-${iosInfo.identifierForVendor ?? 'unknown'}';
        case TargetPlatform.windows:
          final windowsInfo = await deviceInfo.windowsInfo;
          return 'windows-${windowsInfo.deviceId}';
        case TargetPlatform.linux:
          final linuxInfo = await deviceInfo.linuxInfo;
          return 'linux-${linuxInfo.machineId ?? linuxInfo.name}';
        case TargetPlatform.macOS:
          final macInfo = await deviceInfo.macOsInfo;
          return 'macos-${macInfo.systemGUID ?? macInfo.model}';
        case TargetPlatform.fuchsia:
          return 'fuchsia-device';
      }
    } catch (_) {
      return 'unknown-device';
    }
  }
}
