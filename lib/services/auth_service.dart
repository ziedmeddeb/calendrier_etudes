import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

enum ActivationResult { success, keyNotFound, keyAlreadyUsed, networkError }

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _keyUserId = 'auth_user_id';
  static const _keyStableUserId = 'auth_stable_user_id';
  static const _keyInstallToken = 'auth_install_token';
  static const _keyFpUuid = 'auth_fp_uuid';

  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String? _cachedUserId;
  String? _cachedStableUserId;

  // Firebase Auth UID — used for authentication only
  String get userId {
    if (_cachedUserId == null) throw StateError('AuthService: not activated');
    return _cachedUserId!;
  }

  // Stable ID from the activation key — used as the Firestore data namespace.
  // Survives reinstall+new-key as long as you reuse the same stableUserId in
  // the new key document.
  String get stableUserId {
    if (_cachedStableUserId == null) throw StateError('AuthService: not activated');
    return _cachedStableUserId!;
  }

  Future<bool> isActivated() async {
    final uid = await _storage.read(key: _keyUserId);
    final stableId = await _storage.read(key: _keyStableUserId);
    if (uid != null) _cachedUserId = uid;
    if (stableId != null) _cachedStableUserId = stableId;
    return uid != null && stableId != null;
  }

  Future<ActivationResult> activate(String secretKey) async {
    try {
      final cred = await _auth.signInAnonymously();
      final uid = cred.user!.uid;

      final installToken = const Uuid().v4();
      final fingerprint = await _buildFingerprint();

      final keyRef = _firestore.collection('activation_keys').doc(secretKey);

      bool claimed = false;
      String? capturedStableId;

      await _firestore.runTransaction((tx) async {
        final keySnap = await tx.get(keyRef);
        if (!keySnap.exists) throw _ActivationException('not_found');
        if (keySnap.data()!['used'] == true) throw _ActivationException('already_used');

        // stableUserId is set by the admin in the key document.
        // Reusing the same stableUserId in a reset key preserves data continuity.
        final stableId = keySnap.data()!['stableUserId'] as String? ?? uid;
        capturedStableId = stableId;

        final userRef = _firestore.collection('users').doc(stableId);

        // Replaces the binding doc entirely (safe — sync subcollection is unaffected).
        tx.set(userRef, {
          'ownedBy': uid,
          'installToken': _hash(installToken),
          'deviceFingerprintHash': _hash(fingerprint),
          'activatedAt': FieldValue.serverTimestamp(),
          'revoked': false,
        });
        tx.update(keyRef, {
          'used': true,
          'usedBy': uid,
          'usedAt': FieldValue.serverTimestamp(),
        });
        claimed = true;
      });

      if (claimed && capturedStableId != null) {
        await _storage.write(key: _keyUserId, value: uid);
        await _storage.write(key: _keyStableUserId, value: capturedStableId!);
        await _storage.write(key: _keyInstallToken, value: installToken);
        _cachedUserId = uid;
        _cachedStableUserId = capturedStableId;
      }
      return ActivationResult.success;
    } on _ActivationException catch (e) {
      try {
        await _auth.currentUser?.delete();
      } catch (_) {}
      return e.reason == 'not_found'
          ? ActivationResult.keyNotFound
          : ActivationResult.keyAlreadyUsed;
    } catch (_) {
      return ActivationResult.networkError;
    }
  }

  // Returns null = ok/offline; 'revoked'; 'cloned'; 'not_activated'
  Future<String?> verifyBinding() async {
    try {
      final uid = await _storage.read(key: _keyUserId);
      final stableId = await _storage.read(key: _keyStableUserId);
      final storedToken = await _storage.read(key: _keyInstallToken);
      if (uid == null || stableId == null || storedToken == null) return 'not_activated';

      final firebaseUser = _auth.currentUser;
      if (firebaseUser == null || firebaseUser.uid != uid) return 'not_activated';

      final doc = await _firestore.collection('users').doc(stableId).get();
      if (!doc.exists) return 'not_activated';

      final data = doc.data()!;
      if (data['revoked'] == true) {
        await wipe();
        return 'revoked';
      }

      // ownedBy must match this device's Firebase Auth UID
      if (data['ownedBy'] != uid) return 'cloned';

      final currentFingerprint = await _buildFingerprint();
      if (_hash(currentFingerprint) != data['deviceFingerprintHash']) return 'cloned';
      if (_hash(storedToken) != data['installToken']) return 'cloned';

      _cachedStableUserId = stableId;
      return null;
    } catch (_) {
      return null; // offline: allow proceed
    }
  }

  Future<void> wipe() async {
    await _storage.delete(key: _keyUserId);
    await _storage.delete(key: _keyStableUserId);
    await _storage.delete(key: _keyInstallToken);
    await _storage.delete(key: _keyFpUuid);
    _cachedUserId = null;
    _cachedStableUserId = null;
    try {
      await _auth.currentUser?.delete();
    } catch (_) {}
  }

  Future<String> _buildFingerprint() async {
    String rawId;
    try {
      final deviceInfo = DeviceInfoPlugin();
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
          rawId = 'android-${(await deviceInfo.androidInfo).id}';
          break;
        case TargetPlatform.iOS:
          rawId = 'ios-${(await deviceInfo.iosInfo).identifierForVendor ?? 'unknown'}';
          break;
        case TargetPlatform.windows:
          rawId = 'windows-${(await deviceInfo.windowsInfo).deviceId}';
          break;
        default:
          rawId = 'other';
      }
    } catch (_) {
      rawId = 'unknown';
    }

    // Mixed in so fingerprint can't be reconstructed without Keystore access.
    String? fpUuid = await _storage.read(key: _keyFpUuid);
    if (fpUuid == null) {
      fpUuid = const Uuid().v4();
      await _storage.write(key: _keyFpUuid, value: fpUuid);
    }
    return '$rawId:$fpUuid';
  }

  String _hash(String input) =>
      sha256.convert(utf8.encode(input)).toString();
}

class _ActivationException implements Exception {
  final String reason;
  _ActivationException(this.reason);
}
