import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';

import 'auth_service.dart';
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

  String get _userDocPath =>
      'users/${AuthService.instance.stableUserId}/sync/state';

  final DatabaseService _databaseService = DatabaseService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<SyncResult> pushData() async {
    try {
      final Map<String, dynamic> localSnapshot =
          await _databaseService.exportAllTablesForSync();
      final String localHash = _computeHash(localSnapshot);

      await _firestore.doc(_userDocPath).set({
        'version': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
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
      final remoteDoc = await _firestore.doc(_userDocPath).get();

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


}
