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

  Future<AttendanceUpdateResult> updateAttendanceRecord({
    required String attendanceRecordId,
    required String status,
    required String note,
  }) async {
    final data = await edgeClient.call(
      '/attendance-records/$attendanceRecordId',
      method: EdgeHttpMethod.patch,
      body: <String, dynamic>{'status': status, 'note': note},
    );
    return AttendanceUpdateResult.fromJson(data);
  }

  Future<TeacherAttendanceSession> updateSession({
    required String classSessionId,
    required String sessionDate,
    required String startsAt,
    required String endsAt,
    required String status,
    required String reason,
  }) async {
    final data = await edgeClient.call(
      '/class-sessions/$classSessionId',
      method: EdgeHttpMethod.patch,
      body: <String, dynamic>{
        'sessionDate': sessionDate,
        'startsAt': startsAt,
        'endsAt': endsAt,
        'status': status,
        if (reason.isNotEmpty) 'reason': reason,
      },
    );
    final sessionJson = data['session'];
    if (sessionJson is Map<String, dynamic>) {
      return TeacherAttendanceSession.fromJson(sessionJson);
    }
    throw const AttendanceManagementException('수업 회차 수정 응답이 올바르지 않습니다.');
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
    required this.sessionDate,
    required this.scheduleText,
    required this.startsAt,
    required this.endsAt,
    required this.status,
  });

  factory TeacherAttendanceSession.fromJson(Map<String, dynamic> json) {
    return TeacherAttendanceSession(
      id: json['id'] as String? ?? '',
      classId: json['classId'] as String? ?? '',
      className: json['className'] as String? ?? '수업',
      sessionDate: json['sessionDate'] as String? ?? '',
      scheduleText: json['scheduleText'] as String? ?? '',
      startsAt: json['startsAt'] as String? ?? '',
      endsAt: json['endsAt'] as String? ?? '',
      status: json['status'] as String? ?? 'open',
    );
  }

  final String id;
  final String classId;
  final String className;
  final String sessionDate;
  final String scheduleText;
  final String startsAt;
  final String endsAt;
  final String status;
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
    required this.recordId,
    required this.status,
    required this.avatarKey,
    required this.note,
  });

  factory TeacherAttendanceStudent.fromJson(Map<String, dynamic> json) {
    return TeacherAttendanceStudent(
      id: json['id'] as String? ?? '',
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '학생',
      recordId: json['recordId'] as String?,
      status: json['status'] as String? ?? 'waiting',
      avatarKey: json['avatarKey'] as String? ?? 'elementary_unspecified_01',
      note: json['note'] as String?,
    );
  }

  final String id;
  final String code;
  final String name;
  final String? recordId;
  final String status;
  final String avatarKey;
  final String? note;
}

class AttendanceManagementException implements Exception {
  const AttendanceManagementException(this.message);

  final String message;

  @override
  String toString() => message;
}
