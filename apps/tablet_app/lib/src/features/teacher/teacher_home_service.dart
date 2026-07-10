import '../../core/edge_function_client.dart';

class TeacherHomeService {
  const TeacherHomeService({required this.edgeClient});

  final EdgeFunctionClient edgeClient;

  Future<TeacherHome> fetchMe() async {
    final data = await edgeClient.call('/me');
    return TeacherHome.fromJson(data);
  }
}

class TeacherHome {
  const TeacherHome({required this.teacher, required this.studyRooms});

  factory TeacherHome.fromJson(Map<String, dynamic> json) {
    final teacherJson = json['teacher'];
    final studyRoomJson = json['studyRooms'];
    return TeacherHome(
      teacher: TeacherProfile.fromJson(
        teacherJson is Map<String, dynamic>
            ? teacherJson
            : const <String, dynamic>{},
      ),
      studyRooms: [
        if (studyRoomJson is List)
          for (final item in studyRoomJson)
            if (item is Map<String, dynamic>) StudyRoomSummary.fromJson(item),
      ],
    );
  }

  final TeacherProfile teacher;
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
