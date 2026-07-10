import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TeacherPinStore {
  const TeacherPinStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _pinKey = 'ochul_teacher_admin_pin';

  final FlutterSecureStorage _storage;

  Future<bool> hasPin() async {
    final pin = await _storage.read(key: _pinKey);
    return _isSixDigitPin(pin);
  }

  Future<void> savePin(String pin) async {
    if (!_isSixDigitPin(pin)) {
      throw const TeacherPinStoreException('관리자 PIN은 숫자 6자리여야 합니다.');
    }
    await _storage.write(key: _pinKey, value: pin);
  }

  Future<bool> verifyPin(String pin) async {
    if (!_isSixDigitPin(pin)) {
      return false;
    }
    final savedPin = await _storage.read(key: _pinKey);
    return savedPin == pin;
  }

  bool _isSixDigitPin(String? pin) {
    return pin != null && RegExp(r'^\d{6}$').hasMatch(pin);
  }
}

class TeacherPinStoreException implements Exception {
  const TeacherPinStoreException(this.message);

  final String message;

  @override
  String toString() => message;
}
