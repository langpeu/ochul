import '../../core/edge_function_client.dart';

class StudentManagementService {
  const StudentManagementService({required this.edgeClient});

  final EdgeFunctionClient edgeClient;

  Future<List<ManagedStudent>> fetchStudents(String studyRoomId) async {
    final data = await edgeClient.call('/study-rooms/$studyRoomId/students');
    final studentsJson = data['students'];
    return [
      if (studentsJson is List)
        for (final item in studentsJson)
          if (item is Map<String, dynamic>) ManagedStudent.fromJson(item),
    ];
  }

  Future<ManagedStudent> createStudent({
    required String studyRoomId,
    required String name,
    required String code,
    required String pin,
  }) async {
    final data = await edgeClient.call(
      '/study-rooms/$studyRoomId/students',
      method: EdgeHttpMethod.post,
      body: <String, dynamic>{'name': name, 'code': code, 'pin': pin},
    );
    final studentJson = data['student'];
    if (studentJson is Map<String, dynamic>) {
      return ManagedStudent.fromJson(studentJson);
    }
    throw const StudentManagementException('학생 등록 응답이 올바르지 않습니다.');
  }
}

class ManagedStudent {
  const ManagedStudent({
    required this.id,
    required this.code,
    required this.name,
    required this.status,
  });

  factory ManagedStudent.fromJson(Map<String, dynamic> json) {
    return ManagedStudent(
      id: json['id'] as String? ?? '',
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '학생',
      status: json['status'] as String? ?? 'active',
    );
  }

  final String id;
  final String code;
  final String name;
  final String status;
}

class StudentManagementException implements Exception {
  const StudentManagementException(this.message);

  final String message;

  @override
  String toString() => message;
}
