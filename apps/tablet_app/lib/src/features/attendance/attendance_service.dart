import '../../core/edge_function_client.dart';

class AttendanceService {
  const AttendanceService({required this.edgeClient});

  final EdgeFunctionClient edgeClient;

  Future<List<AttendanceSession>> fetchTodaySessions() async {
    final data = await edgeClient.call('/attendance/today');
    final sessionsJson = data['sessions'];
    return [
      if (sessionsJson is List)
        for (final item in sessionsJson)
          if (item is Map<String, dynamic>) AttendanceSession.fromJson(item),
    ];
  }

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

class AttendanceSession {
  const AttendanceSession({
    required this.id,
    required this.className,
    required this.classKind,
    required this.scheduleText,
    required this.students,
  });

  factory AttendanceSession.fromJson(Map<String, dynamic> json) {
    final studentsJson = json['students'];
    return AttendanceSession(
      id: json['id'] as String? ?? '',
      className: json['className'] as String? ?? '수업',
      classKind: json['classKind'] as String? ?? 'regular',
      scheduleText: json['scheduleText'] as String? ?? '',
      students: [
        if (studentsJson is List)
          for (final item in studentsJson)
            if (item is Map<String, dynamic>) AttendanceStudent.fromJson(item),
      ],
    );
  }

  final String id;
  final String className;
  final String classKind;
  final String scheduleText;
  final List<AttendanceStudent> students;
}

class AttendanceStudent {
  const AttendanceStudent({
    required this.id,
    required this.code,
    required this.name,
    required this.status,
  });

  factory AttendanceStudent.fromJson(Map<String, dynamic> json) {
    return AttendanceStudent(
      id: json['id'] as String? ?? '',
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '학생',
      status: json['status'] as String? ?? 'waiting',
    );
  }

  final String id;
  final String code;
  final String name;
  final String status;
}

class AttendanceException implements Exception {
  const AttendanceException(this.message);

  final String message;

  @override
  String toString() => message;
}
