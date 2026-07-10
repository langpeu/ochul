import '../../core/edge_function_client.dart';

class ClassManagementService {
  const ClassManagementService({required this.edgeClient});

  final EdgeFunctionClient edgeClient;

  Future<List<ManagedClass>> fetchClasses(String studyRoomId) async {
    final data = await edgeClient.call('/study-rooms/$studyRoomId/classes');
    final classesJson = data['classes'];
    return [
      if (classesJson is List)
        for (final item in classesJson)
          if (item is Map<String, dynamic>) ManagedClass.fromJson(item),
    ];
  }

  Future<ManagedClass> fetchClass(String classId) async {
    final data = await edgeClient.call('/classes/$classId');
    return _readClass(data, '수업 상세 응답이 올바르지 않습니다.');
  }

  Future<ManagedClass> createClass({
    required String studyRoomId,
    required String name,
    required String description,
    required String classKind,
    required String startDate,
    required String endDate,
    required List<int> dayOfWeeks,
    required String startsAt,
    required String endsAt,
  }) async {
    final data = await edgeClient.call(
      '/study-rooms/$studyRoomId/classes',
      method: EdgeHttpMethod.post,
      body: <String, dynamic>{
        'name': name,
        'description': description,
        'classKind': classKind,
        'startDate': startDate,
        'endDate': endDate,
        'dayOfWeeks': dayOfWeeks,
        'startsAt': startsAt,
        'endsAt': endsAt,
      },
    );
    final classJson = data['class'];
    if (classJson is Map<String, dynamic>) {
      return ManagedClass.fromJson(classJson);
    }
    throw const ClassManagementException('수업 생성 응답이 올바르지 않습니다.');
  }

  Future<ManagedClass> updateClass({
    required String classId,
    required String name,
    required String description,
    required String classKind,
    required String startDate,
    required String endDate,
    required List<int> dayOfWeeks,
    required String startsAt,
    required String endsAt,
  }) async {
    final data = await edgeClient.call(
      '/classes/$classId',
      method: EdgeHttpMethod.patch,
      body: <String, dynamic>{
        'name': name,
        'description': description,
        'classKind': classKind,
        'startDate': startDate,
        'endDate': endDate,
        'dayOfWeeks': dayOfWeeks,
        'startsAt': startsAt,
        'endsAt': endsAt,
      },
    );
    return _readClass(data, '수업 수정 응답이 올바르지 않습니다.');
  }

  Future<void> deleteClass(String classId) async {
    await edgeClient.call('/classes/$classId', method: EdgeHttpMethod.delete);
  }

  Future<void> openAttendanceSession(String classId) async {
    await edgeClient.call(
      '/classes/$classId/sessions/open',
      method: EdgeHttpMethod.post,
    );
  }

  Future<ManagedClassSession> createClassSession({
    required String classId,
    required String sessionDate,
    required String startsAt,
    required String endsAt,
    String status = 'scheduled',
    String reason = '',
  }) async {
    final data = await edgeClient.call(
      '/classes/$classId/sessions',
      method: EdgeHttpMethod.post,
      body: <String, dynamic>{
        'sessionDate': sessionDate,
        if (startsAt.isNotEmpty) 'startsAt': startsAt,
        if (endsAt.isNotEmpty) 'endsAt': endsAt,
        'status': status,
        if (reason.isNotEmpty) 'reason': reason,
      },
    );
    return _readClassSession(data, '수업 회차 생성 응답이 올바르지 않습니다.');
  }

  Future<int> cancelTodaySession({
    required String classId,
    required String sessionDate,
    required String reason,
  }) async {
    final data = await edgeClient.call(
      '/classes/$classId/sessions/cancel-today',
      method: EdgeHttpMethod.post,
      body: <String, dynamic>{'sessionDate': sessionDate, 'reason': reason},
    );
    return _readRequestedNotificationCount(data);
  }

  Future<int> createMakeupSession({
    required String classId,
    required String sessionDate,
    required String startsAt,
    required String endsAt,
    required String reason,
    required String originalSessionDate,
  }) async {
    final data = await edgeClient.call(
      '/classes/$classId/sessions/makeup',
      method: EdgeHttpMethod.post,
      body: <String, dynamic>{
        'sessionDate': sessionDate,
        'startsAt': startsAt,
        'endsAt': endsAt,
        'reason': reason,
        if (originalSessionDate.isNotEmpty)
          'originalSessionDate': originalSessionDate,
      },
    );
    return _readRequestedNotificationCount(data);
  }

  Future<int> rescheduleTodaySession({
    required String classId,
    required String sessionDate,
    required String startsAt,
    required String endsAt,
    required String reason,
  }) async {
    final data = await edgeClient.call(
      '/classes/$classId/sessions/today',
      method: EdgeHttpMethod.patch,
      body: <String, dynamic>{
        'sessionDate': sessionDate,
        'startsAt': startsAt,
        'endsAt': endsAt,
        'reason': reason,
      },
    );
    return _readRequestedNotificationCount(data);
  }

  int _readRequestedNotificationCount(Map<String, dynamic> data) {
    final notifications = data['notifications'];
    if (notifications is Map<String, dynamic>) {
      return notifications['requested'] as int? ?? 0;
    }
    return 0;
  }

  ManagedClass _readClass(Map<String, dynamic> data, String message) {
    final classJson = data['class'];
    if (classJson is Map<String, dynamic>) {
      return ManagedClass.fromJson(classJson);
    }
    throw ClassManagementException(message);
  }

  ManagedClassSession _readClassSession(
    Map<String, dynamic> data,
    String message,
  ) {
    final sessionJson = data['session'];
    if (sessionJson is Map<String, dynamic>) {
      return ManagedClassSession.fromJson(sessionJson);
    }
    throw ClassManagementException(message);
  }
}

class ManagedClass {
  const ManagedClass({
    required this.id,
    required this.name,
    required this.classKind,
    required this.description,
    required this.startDate,
    required this.endDate,
    required this.scheduleText,
    required this.schedules,
    required this.active,
  });

  factory ManagedClass.fromJson(Map<String, dynamic> json) {
    return ManagedClass(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '수업',
      classKind: json['classKind'] as String? ?? 'regular',
      description: json['description'] as String? ?? '',
      startDate: json['startDate'] as String? ?? '',
      endDate: json['endDate'] as String? ?? '',
      scheduleText: json['scheduleText'] as String? ?? '',
      schedules: [
        if (json['schedules'] is List)
          for (final schedule in json['schedules'] as List)
            if (schedule is Map<String, dynamic>)
              ManagedClassSchedule.fromJson(schedule),
      ],
      active: json['active'] as bool? ?? true,
    );
  }

  final String id;
  final String name;
  final String classKind;
  final String description;
  final String startDate;
  final String endDate;
  final String scheduleText;
  final List<ManagedClassSchedule> schedules;
  final bool active;
}

class ManagedClassSession {
  const ManagedClassSession({
    required this.id,
    required this.classId,
    required this.className,
    required this.sessionDate,
    required this.startsAt,
    required this.endsAt,
    required this.status,
  });

  factory ManagedClassSession.fromJson(Map<String, dynamic> json) {
    return ManagedClassSession(
      id: json['id'] as String? ?? '',
      classId: json['classId'] as String? ?? '',
      className: json['className'] as String? ?? '수업',
      sessionDate: json['sessionDate'] as String? ?? '',
      startsAt: json['startsAt'] as String? ?? '',
      endsAt: json['endsAt'] as String? ?? '',
      status: json['status'] as String? ?? 'scheduled',
    );
  }

  final String id;
  final String classId;
  final String className;
  final String sessionDate;
  final String startsAt;
  final String endsAt;
  final String status;
}

class ManagedClassSchedule {
  const ManagedClassSchedule({
    required this.dayOfWeek,
    required this.startsAt,
    required this.endsAt,
  });

  factory ManagedClassSchedule.fromJson(Map<String, dynamic> json) {
    return ManagedClassSchedule(
      dayOfWeek: json['dayOfWeek'] as int? ?? 0,
      startsAt: json['startsAt'] as String? ?? '',
      endsAt: json['endsAt'] as String? ?? '',
    );
  }

  final int dayOfWeek;
  final String startsAt;
  final String endsAt;
}

class ClassManagementException implements Exception {
  const ClassManagementException(this.message);

  final String message;

  @override
  String toString() => message;
}
