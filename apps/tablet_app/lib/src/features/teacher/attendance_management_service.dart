import '../../core/edge_function_client.dart';

class AttendanceManagementService {
  const AttendanceManagementService({required this.edgeClient});

  final EdgeFunctionClient edgeClient;

  Future<List<TeacherAttendanceSession>> fetchTodaySessions() async {
    final data = await edgeClient.call('/attendance/today');
    final sessionsJson = data['sessions'];
    return [
      if (sessionsJson is List)
        for (final item in sessionsJson)
          if (item is Map<String, dynamic>)
            TeacherAttendanceSession.fromJson(item),
    ];
  }

  Future<TeacherAttendanceData> fetchSessionAttendance(
    String classSessionId,
  ) async {
    final data = await edgeClient.call(
      '/class-sessions/$classSessionId/attendance',
    );
    return TeacherAttendanceData.fromJson(data);
  }

  Future<AttendanceUpdateResult> updateAttendance({
    required String classSessionId,
    required String studentId,
    required String status,
    required String note,
  }) async {
    final data = await edgeClient.call(
      '/class-sessions/$classSessionId/attendance',
      method: EdgeHttpMethod.patch,
      body: <String, dynamic>{
        'studentId': studentId,
        'status': status,
        'note': note,
      },
    );
    return AttendanceUpdateResult.fromJson(data);
  }
}

class AttendanceUpdateResult {
  const AttendanceUpdateResult({required this.requestedNotifications});

  factory AttendanceUpdateResult.fromJson(Map<String, dynamic> json) {
    final notifications = json['notifications'];
    if (notifications is Map<String, dynamic>) {
      return AttendanceUpdateResult(
        requestedNotifications: notifications['requested'] as int? ?? 0,
      );
    }
    return const AttendanceUpdateResult(requestedNotifications: 0);
  }

  final int requestedNotifications;
}

class TeacherAttendanceSession {
  const TeacherAttendanceSession({
    required this.id,
    required this.classId,
    required this.className,
    required this.scheduleText,
  });

  factory TeacherAttendanceSession.fromJson(Map<String, dynamic> json) {
    return TeacherAttendanceSession(
      id: json['id'] as String? ?? '',
      classId: json['classId'] as String? ?? '',
      className: json['className'] as String? ?? '수업',
      scheduleText: json['scheduleText'] as String? ?? '',
    );
  }

  final String id;
  final String classId;
  final String className;
  final String scheduleText;
}

class TeacherAttendanceData {
  const TeacherAttendanceData({required this.students});

  factory TeacherAttendanceData.fromJson(Map<String, dynamic> json) {
    final studentsJson = json['students'];
    return TeacherAttendanceData(
      students: [
        if (studentsJson is List)
          for (final item in studentsJson)
            if (item is Map<String, dynamic>)
              TeacherAttendanceStudent.fromJson(item),
      ],
    );
  }

  final List<TeacherAttendanceStudent> students;
}

class TeacherAttendanceStudent {
  const TeacherAttendanceStudent({
    required this.id,
    required this.code,
    required this.name,
    required this.status,
    required this.avatarKey,
    required this.note,
  });

  factory TeacherAttendanceStudent.fromJson(Map<String, dynamic> json) {
    return TeacherAttendanceStudent(
      id: json['id'] as String? ?? '',
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '학생',
      status: json['status'] as String? ?? 'waiting',
      avatarKey: json['avatarKey'] as String? ?? 'elementary_unspecified_01',
      note: json['note'] as String?,
    );
  }

  final String id;
  final String code;
  final String name;
  final String status;
  final String avatarKey;
  final String? note;
}
