import '../../core/edge_function_client.dart';
import 'student_management_service.dart';

class EnrollmentManagementService {
  const EnrollmentManagementService({required this.edgeClient});

  final EdgeFunctionClient edgeClient;

  Future<List<ManagedStudent>> fetchClassStudents(String classId) async {
    final data = await edgeClient.call('/classes/$classId/students');
    final studentsJson = data['students'];
    return [
      if (studentsJson is List)
        for (final item in studentsJson)
          if (item is Map<String, dynamic>) ManagedStudent.fromJson(item),
    ];
  }

  Future<List<ManagedStudent>> saveClassStudents({
    required String classId,
    required List<String> studentIds,
  }) async {
    final data = await edgeClient.call(
      '/classes/$classId/students',
      method: EdgeHttpMethod.put,
      body: <String, dynamic>{'studentIds': studentIds},
    );
    final studentsJson = data['students'];
    return [
      if (studentsJson is List)
        for (final item in studentsJson)
          if (item is Map<String, dynamic>) ManagedStudent.fromJson(item),
    ];
  }

  Future<List<ManagedStudent>> updateClassStudentOrder({
    required String classId,
    required List<String> studentIds,
  }) async {
    final data = await edgeClient.call(
      '/classes/$classId/students/order',
      method: EdgeHttpMethod.patch,
      body: <String, dynamic>{'studentIds': studentIds},
    );
    final studentsJson = data['students'];
    return [
      if (studentsJson is List)
        for (final item in studentsJson)
          if (item is Map<String, dynamic>) ManagedStudent.fromJson(item),
    ];
  }
}
