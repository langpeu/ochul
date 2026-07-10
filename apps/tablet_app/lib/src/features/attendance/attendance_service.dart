import '../../core/edge_function_client.dart';

class AttendanceService {
  const AttendanceService({required this.edgeClient});

  final EdgeFunctionClient edgeClient;

  Future<void> checkIn({
    required String classSessionId,
    required String studentId,
    required String pin,
  }) async {
    if (!RegExp(r'^\d{6}$').hasMatch(pin)) {
      throw const AttendanceException('출결 비밀번호는 숫자 6자리여야 합니다.');
    }

    await edgeClient.call(
      '/class-sessions/$classSessionId/check-in',
      method: EdgeHttpMethod.post,
      body: <String, dynamic>{'studentId': studentId, 'pin': pin},
    );
  }
}

class AttendanceException implements Exception {
  const AttendanceException(this.message);

  final String message;

  @override
  String toString() => message;
}
