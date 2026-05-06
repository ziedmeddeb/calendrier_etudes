import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum ActivationResult { success, keyNotFound, networkError }

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _keyDataKey = 'auth_data_key';

  final _firestore = FirebaseFirestore.instance;

  String? _cachedDataKey;

  String get dataKey {
    if (_cachedDataKey == null) throw StateError('AuthService: not activated');
    return _cachedDataKey!;
  }

  Future<bool> isActivated() async {
    final key = await _storage.read(key: _keyDataKey);
    if (key != null) _cachedDataKey = key;
    return key != null;
  }

  Future<ActivationResult> activate(String secretKey) async {
    try {
      final keySnap = await _firestore
          .collection('activation_keys')
          .doc(secretKey)
          .get();
      if (!keySnap.exists) return ActivationResult.keyNotFound;

      await _storage.write(key: _keyDataKey, value: secretKey);
      _cachedDataKey = secretKey;
      return ActivationResult.success;
    } catch (_) {
      return ActivationResult.networkError;
    }
  }

  // Returns null = ok/offline; 'revoked'; 'not_activated'
  Future<String?> verifyBinding() async {
    try {
      final key = await _storage.read(key: _keyDataKey);
      if (key == null) return 'not_activated';

      final keySnap = await _firestore
          .collection('activation_keys')
          .doc(key)
          .get();

      if (!keySnap.exists) {
        await wipe();
        return 'not_activated';
      }

      if (keySnap.data()!['revoked'] == true) {
        await wipe();
        return 'revoked';
      }

      _cachedDataKey = key;
      return null;
    } catch (_) {
      return null; // offline: allow proceed
    }
  }

  Future<void> wipe() async {
    await _storage.delete(key: _keyDataKey);
    _cachedDataKey = null;
  }
}
