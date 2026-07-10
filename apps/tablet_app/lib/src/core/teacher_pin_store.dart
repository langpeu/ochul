import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TeacherPinStore {
  const TeacherPinStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _pinKey = 'ochul_teacher_admin_pin';
  static const _hashPrefix = 'v1';

  final FlutterSecureStorage _storage;

  Future<bool> hasPin() async {
    final storedPin = await _storage.read(key: _pinKey);
    return _isHashedPin(storedPin) || _isSixDigitPin(storedPin);
  }

  Future<void> savePin(String pin) async {
    if (!_isSixDigitPin(pin)) {
      throw const TeacherPinStoreException('관리자 PIN은 숫자 6자리여야 합니다.');
    }
    await _storage.write(key: _pinKey, value: _hashPin(pin, _createSalt()));
  }

  Future<bool> verifyPin(String pin) async {
    if (!_isSixDigitPin(pin)) {
      return false;
    }
    final savedPin = await _storage.read(key: _pinKey);
    if (_isHashedPin(savedPin)) {
      return _verifyHashedPin(savedPin!, pin);
    }
    if (savedPin == pin) {
      await savePin(pin);
      return true;
    }
    return false;
  }

  bool _isSixDigitPin(String? pin) {
    return pin != null && RegExp(r'^\d{6}$').hasMatch(pin);
  }

  bool _isHashedPin(String? storedPin) {
    final parts = storedPin?.split(r'$');
    return parts != null &&
        parts.length == 3 &&
        parts[0] == _hashPrefix &&
        parts[1].isNotEmpty &&
        parts[2].isNotEmpty;
  }

  bool _verifyHashedPin(String storedPin, String pin) {
    final parts = storedPin.split(r'$');
    if (parts.length != 3) {
      return false;
    }
    return storedPin == _hashPin(pin, parts[1]);
  }

  String _hashPin(String pin, String salt) {
    final digest = sha256.convert(utf8.encode('$salt:$pin'));
    return '$_hashPrefix\$$salt\$${digest.toString()}';
  }

  String _createSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64UrlEncode(bytes);
  }
}

class TeacherPinStoreException implements Exception {
  const TeacherPinStoreException(this.message);

  final String message;

  @override
  String toString() => message;
}
