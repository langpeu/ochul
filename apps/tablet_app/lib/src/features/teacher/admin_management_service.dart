import '../../core/edge_function_client.dart';
import 'student_management_service.dart';
import 'teacher_home_service.dart';

class AdminManagementService {
  const AdminManagementService({required this.edgeClient});

  final EdgeFunctionClient edgeClient;

  Future<List<AdminTeacherSummary>> fetchTeachers() async {
    final data = await edgeClient.call('/admin/teachers');
    final teachersJson = data['teachers'];
    return [
      if (teachersJson is List)
        for (final item in teachersJson)
          if (item is Map<String, dynamic>) AdminTeacherSummary.fromJson(item),
    ];
  }

  Future<List<StudyRoomSummary>> fetchTeacherStudyRooms(
    String teacherId,
  ) async {
    final data = await edgeClient.call(
      '/admin/teachers/$teacherId/study-rooms',
    );
    final studyRoomsJson = data['studyRooms'];
    return [
      if (studyRoomsJson is List)
        for (final item in studyRoomsJson)
          if (item is Map<String, dynamic>) StudyRoomSummary.fromJson(item),
    ];
  }

  Future<List<ManagedStudent>> fetchStudyRoomStudents(
    String studyRoomId,
  ) async {
    final data = await edgeClient.call(
      '/admin/study-rooms/$studyRoomId/students',
    );
    final studentsJson = data['students'];
    return [
      if (studentsJson is List)
        for (final item in studentsJson)
          if (item is Map<String, dynamic>) ManagedStudent.fromJson(item),
    ];
  }
}

class AdminTeacherSummary {
  const AdminTeacherSummary({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.createdAt,
  });

  factory AdminTeacherSummary.fromJson(Map<String, dynamic> json) {
    return AdminTeacherSummary(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '선생님',
      email: json['email'] as String?,
      role: json['role'] as String? ?? 'teacher',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
    );
  }

  final String id;
  final String name;
  final String? email;
  final String role;
  final DateTime? createdAt;
}
