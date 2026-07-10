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

  Future<ManagedStudent> updateStudent({
    required String studentId,
    required String name,
    required String code,
    required String status,
  }) async {
    final data = await edgeClient.call(
      '/students/$studentId',
      method: EdgeHttpMethod.patch,
      body: <String, dynamic>{'name': name, 'code': code, 'status': status},
    );
    return _readStudent(data, '학생 수정 응답이 올바르지 않습니다.');
  }

  Future<ManagedStudent> resetStudentPin({
    required String studentId,
    required String pin,
  }) async {
    final data = await edgeClient.call(
      '/students/$studentId/pin/reset',
      method: EdgeHttpMethod.post,
      body: <String, dynamic>{'pin': pin},
    );
    return _readStudent(data, '비밀번호 리셋 응답이 올바르지 않습니다.');
  }

  Future<ManagedStudent> deleteStudent(String studentId) async {
    final data = await edgeClient.call(
      '/students/$studentId',
      method: EdgeHttpMethod.delete,
    );
    return _readStudent(data, '학생 삭제 응답이 올바르지 않습니다.');
  }

  ManagedStudent _readStudent(Map<String, dynamic> data, String message) {
    final studentJson = data['student'];
    if (studentJson is Map<String, dynamic>) {
      return ManagedStudent.fromJson(studentJson);
    }
    throw StudentManagementException(message);
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
