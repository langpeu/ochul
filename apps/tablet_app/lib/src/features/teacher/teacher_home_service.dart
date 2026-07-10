import '../../core/edge_function_client.dart';

class TeacherHomeService {
  const TeacherHomeService({required this.edgeClient});

  final EdgeFunctionClient edgeClient;

  Future<TeacherHome> fetchMe() async {
    final data = await edgeClient.call('/me');
    return TeacherHome.fromJson(data);
  }

  Future<TeacherHome> onboard({
    required String teacherName,
    required String studyRoomName,
  }) async {
    final data = await edgeClient.call(
      '/me/onboard',
      method: EdgeHttpMethod.post,
      body: <String, dynamic>{
        'teacherName': teacherName,
        'studyRoomName': studyRoomName,
      },
    );
    return TeacherHome.fromJson(data);
  }

  Future<List<StudyRoomSummary>> fetchStudyRooms() async {
    final data = await edgeClient.call('/study-rooms');
    final studyRoomsJson = data['studyRooms'];
    return [
      if (studyRoomsJson is List)
        for (final item in studyRoomsJson)
          if (item is Map<String, dynamic>) StudyRoomSummary.fromJson(item),
    ];
  }

  Future<StudyRoomSummary> createStudyRoom({
    required String name,
    required String description,
  }) async {
    final data = await edgeClient.call(
      '/study-rooms',
      method: EdgeHttpMethod.post,
      body: <String, dynamic>{'name': name, 'description': description},
    );
    final studyRoomJson = data['studyRoom'];
    if (studyRoomJson is Map<String, dynamic>) {
      return StudyRoomSummary.fromJson(studyRoomJson);
    }
    throw const TeacherHomeException('공부방 생성 응답이 올바르지 않습니다.');
  }

  Future<StudyRoomSummary> updateStudyRoom({
    required String studyRoomId,
    required String name,
    required String description,
  }) async {
    final data = await edgeClient.call(
      '/study-rooms/$studyRoomId',
      method: EdgeHttpMethod.patch,
      body: <String, dynamic>{'name': name, 'description': description},
    );
    final studyRoomJson = data['studyRoom'];
    if (studyRoomJson is Map<String, dynamic>) {
      return StudyRoomSummary.fromJson(studyRoomJson);
    }
    throw const TeacherHomeException('공부방 수정 응답이 올바르지 않습니다.');
  }
}

class TeacherHome {
  const TeacherHome({
    required this.needsOnboarding,
    required this.teacher,
    required this.studyRooms,
  });

  factory TeacherHome.fromJson(Map<String, dynamic> json) {
    final teacherJson = json['teacher'];
    final studyRoomJson = json['studyRooms'];
    return TeacherHome(
      needsOnboarding: json['needsOnboarding'] == true,
      teacher: teacherJson is Map<String, dynamic>
          ? TeacherProfile.fromJson(teacherJson)
          : null,
      studyRooms: [
        if (studyRoomJson is List)
          for (final item in studyRoomJson)
            if (item is Map<String, dynamic>) StudyRoomSummary.fromJson(item),
      ],
    );
  }

  final bool needsOnboarding;
  final TeacherProfile? teacher;
  final List<StudyRoomSummary> studyRooms;
}

class TeacherProfile {
  const TeacherProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
  });

  factory TeacherProfile.fromJson(Map<String, dynamic> json) {
    return TeacherProfile(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '선생님',
      email: json['email'] as String?,
      role: json['role'] as String? ?? 'teacher',
    );
  }

  final String id;
  final String name;
  final String? email;
  final String role;
}

class StudyRoomSummary {
  const StudyRoomSummary({
    required this.id,
    required this.name,
    required this.description,
  });

  factory StudyRoomSummary.fromJson(Map<String, dynamic> json) {
    return StudyRoomSummary(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '공부방',
      description: json['description'] as String?,
    );
  }

  final String id;
  final String name;
  final String? description;
}

class TeacherHomeException implements Exception {
  const TeacherHomeException(this.message);

  final String message;

  @override
  String toString() => message;
}
