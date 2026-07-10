import 'package:local_auth/local_auth.dart';

class TeacherGate {
  TeacherGate({LocalAuthentication? localAuth})
    : _localAuth = localAuth ?? LocalAuthentication();

  final LocalAuthentication _localAuth;

  Future<bool> authenticate() async {
    final supported = await _localAuth.isDeviceSupported();
    final canCheck = await _localAuth.canCheckBiometrics;
    if (!supported && !canCheck) {
      return false;
    }

    return _localAuth.authenticate(
      localizedReason: '선생님 모드로 들어가기 위해 인증이 필요합니다.',
      biometricOnly: false,
      persistAcrossBackgrounding: true,
    );
  }
}
