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

  Future<void> seatCheckIn({
    required String classSessionId,
    required String studentId,
    required String seatId,
    required String pin,
  }) async {
    if (!RegExp(r'^\d{6}$').hasMatch(pin)) {
      throw const AttendanceException('출결 비밀번호는 숫자 6자리여야 합니다.');
    }

    await edgeClient.call(
      '/class-sessions/$classSessionId/seat-check-in',
      method: EdgeHttpMethod.post,
      body: <String, dynamic>{
        'studentId': studentId,
        'seatId': seatId,
        'pin': pin,
      },
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
    required this.layout,
  });

  factory AttendanceSession.fromJson(Map<String, dynamic> json) {
    final studentsJson = json['students'];
    final layoutJson = json['layout'];
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
      layout: layoutJson is Map<String, dynamic>
          ? AttendanceClassroomLayout.fromJson(layoutJson)
          : null,
    );
  }

  final String id;
  final String className;
  final String classKind;
  final String scheduleText;
  final List<AttendanceStudent> students;
  final AttendanceClassroomLayout? layout;
}

class AttendanceStudent {
  const AttendanceStudent({
    required this.id,
    required this.code,
    required this.name,
    required this.status,
    required this.avatarKey,
  });

  factory AttendanceStudent.fromJson(Map<String, dynamic> json) {
    return AttendanceStudent(
      id: json['id'] as String? ?? '',
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '학생',
      status: json['status'] as String? ?? 'waiting',
      avatarKey: json['avatarKey'] as String? ?? 'elementary_unspecified_01',
    );
  }

  final String id;
  final String code;
  final String name;
  final String status;
  final String avatarKey;
}

class AttendanceClassroomLayout {
  const AttendanceClassroomLayout({
    required this.id,
    required this.name,
    required this.canvasWidth,
    required this.canvasHeight,
    required this.seats,
    required this.assignments,
    required this.occupiedSeats,
  });

  factory AttendanceClassroomLayout.fromJson(Map<String, dynamic> json) {
    final seatsJson = json['seats'];
    final assignmentsJson = json['assignments'];
    final occupiedSeatsJson = json['occupiedSeats'];
    return AttendanceClassroomLayout(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '교실 배치',
      canvasWidth: (json['canvasWidth'] as num?)?.toDouble() ?? 1000,
      canvasHeight: (json['canvasHeight'] as num?)?.toDouble() ?? 700,
      seats: [
        if (seatsJson is List)
          for (final item in seatsJson)
            if (item is Map<String, dynamic>) AttendanceSeat.fromJson(item),
      ],
      assignments: [
        if (assignmentsJson is List)
          for (final item in assignmentsJson)
            if (item is Map<String, dynamic>)
              AttendanceSeatAssignment.fromJson(item),
      ],
      occupiedSeats: [
        if (occupiedSeatsJson is List)
          for (final item in occupiedSeatsJson)
            if (item is Map<String, dynamic>)
              AttendanceSeatOccupancy.fromJson(item),
      ],
    );
  }

  final String id;
  final String name;
  final double canvasWidth;
  final double canvasHeight;
  final List<AttendanceSeat> seats;
  final List<AttendanceSeatAssignment> assignments;
  final List<AttendanceSeatOccupancy> occupiedSeats;

  AttendanceSeatAssignment? assignmentFor(String seatId) {
    for (final assignment in assignments) {
      if (assignment.seatId == seatId) return assignment;
    }
    return null;
  }

  AttendanceSeatOccupancy? occupancyFor(String seatId) {
    for (final occupancy in occupiedSeats) {
      if (occupancy.seatId == seatId) return occupancy;
    }
    return null;
  }
}

class AttendanceSeat {
  const AttendanceSeat({
    required this.id,
    required this.label,
    required this.deskX,
    required this.deskY,
    required this.seatX,
    required this.seatY,
    required this.rotationDegrees,
  });

  factory AttendanceSeat.fromJson(Map<String, dynamic> json) {
    return AttendanceSeat(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? '좌석',
      deskX: (json['deskX'] as num?)?.toDouble() ?? 0,
      deskY: (json['deskY'] as num?)?.toDouble() ?? 0,
      seatX: (json['seatX'] as num?)?.toDouble() ?? 0,
      seatY: (json['seatY'] as num?)?.toDouble() ?? 0,
      rotationDegrees: (json['rotationDegrees'] as num?)?.toDouble() ?? 0,
    );
  }

  final String id;
  final String label;
  final double deskX;
  final double deskY;
  final double seatX;
  final double seatY;
  final double rotationDegrees;
}

class AttendanceSeatAssignment {
  const AttendanceSeatAssignment({
    required this.seatId,
    required this.studentId,
    required this.studentName,
    required this.studentCode,
    required this.avatarKey,
  });

  factory AttendanceSeatAssignment.fromJson(Map<String, dynamic> json) {
    return AttendanceSeatAssignment(
      seatId: json['seatId'] as String? ?? '',
      studentId: json['studentId'] as String? ?? '',
      studentName: json['studentName'] as String? ?? '학생',
      studentCode: json['studentCode'] as String? ?? '',
      avatarKey: json['avatarKey'] as String? ?? 'elementary_unspecified_01',
    );
  }

  final String seatId;
  final String studentId;
  final String studentName;
  final String studentCode;
  final String avatarKey;
}

class AttendanceSeatOccupancy {
  const AttendanceSeatOccupancy({
    required this.seatId,
    required this.studentId,
    required this.studentName,
    required this.studentCode,
    required this.avatarKey,
    required this.status,
  });

  factory AttendanceSeatOccupancy.fromJson(Map<String, dynamic> json) {
    return AttendanceSeatOccupancy(
      seatId: json['seatId'] as String? ?? '',
      studentId: json['studentId'] as String? ?? '',
      studentName: json['studentName'] as String? ?? '학생',
      studentCode: json['studentCode'] as String? ?? '',
      avatarKey: json['avatarKey'] as String? ?? 'elementary_unspecified_01',
      status: json['status'] as String? ?? 'present',
    );
  }

  final String seatId;
  final String studentId;
  final String studentName;
  final String studentCode;
  final String avatarKey;
  final String status;
}

class AttendanceException implements Exception {
  const AttendanceException(this.message);

  final String message;

  @override
  String toString() => message;
}
