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
    required String gender,
    required String ageGroup,
    required String avatarKey,
  }) async {
    final data = await edgeClient.call(
      '/study-rooms/$studyRoomId/students',
      method: EdgeHttpMethod.post,
      body: <String, dynamic>{
        'name': name,
        'code': code,
        'pin': pin,
        'gender': gender,
        'ageGroup': ageGroup,
        'avatarKey': avatarKey,
      },
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
    required String gender,
    required String ageGroup,
    required String avatarKey,
  }) async {
    final data = await edgeClient.call(
      '/students/$studentId',
      method: EdgeHttpMethod.patch,
      body: <String, dynamic>{
        'name': name,
        'code': code,
        'status': status,
        'gender': gender,
        'ageGroup': ageGroup,
        'avatarKey': avatarKey,
      },
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

  Future<List<StudentGuardian>> fetchGuardians(String studentId) async {
    final data = await edgeClient.call('/students/$studentId/guardians');
    return _readGuardians(data);
  }

  Future<List<StudentGuardian>> saveGuardians({
    required String studentId,
    required List<StudentGuardian> guardians,
  }) async {
    final data = await edgeClient.call(
      '/students/$studentId/guardians',
      method: EdgeHttpMethod.put,
      body: <String, dynamic>{
        'guardians': guardians.map((guardian) => guardian.toJson()).toList(),
      },
    );
    return _readGuardians(data);
  }

  ManagedStudent _readStudent(Map<String, dynamic> data, String message) {
    final studentJson = data['student'];
    if (studentJson is Map<String, dynamic>) {
      return ManagedStudent.fromJson(studentJson);
    }
    throw StudentManagementException(message);
  }

  List<StudentGuardian> _readGuardians(Map<String, dynamic> data) {
    final guardiansJson = data['guardians'];
    return [
      if (guardiansJson is List)
        for (final item in guardiansJson)
          if (item is Map<String, dynamic>) StudentGuardian.fromJson(item),
    ];
  }
}

class ManagedStudent {
  const ManagedStudent({
    required this.id,
    required this.code,
    required this.name,
    required this.status,
    required this.gender,
    required this.ageGroup,
    required this.avatarKey,
  });

  factory ManagedStudent.fromJson(Map<String, dynamic> json) {
    return ManagedStudent(
      id: json['id'] as String? ?? '',
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '학생',
      status: json['status'] as String? ?? 'active',
      gender: json['gender'] as String? ?? 'unspecified',
      ageGroup: json['ageGroup'] as String? ?? 'elementary',
      avatarKey: json['avatarKey'] as String? ?? 'elementary_unspecified_01',
    );
  }

  final String id;
  final String code;
  final String name;
  final String status;
  final String gender;
  final String ageGroup;
  final String avatarKey;
}

class StudentGuardian {
  const StudentGuardian({
    required this.id,
    required this.name,
    required this.phone,
    required this.relationship,
    required this.kakaoOptIn,
    required this.consentConfirmed,
    required this.primaryContact,
  });

  factory StudentGuardian.fromJson(Map<String, dynamic> json) {
    return StudentGuardian(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      relationship: json['relationship'] as String? ?? '',
      kakaoOptIn: json['kakaoOptIn'] as bool? ?? true,
      consentConfirmed:
          json['consentConfirmed'] as bool? ??
          json['kakaoOptIn'] as bool? ??
          false,
      primaryContact: json['primaryContact'] as bool? ?? false,
    );
  }

  final String id;
  final String name;
  final String phone;
  final String relationship;
  final bool kakaoOptIn;
  final bool consentConfirmed;
  final bool primaryContact;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if (id.isNotEmpty) 'id': id,
      'name': name,
      'phone': phone,
      'relationship': relationship,
      'kakaoOptIn': kakaoOptIn,
      'consentConfirmed': consentConfirmed,
      'primaryContact': primaryContact,
    };
  }
}

class StudentManagementException implements Exception {
  const StudentManagementException(this.message);

  final String message;

  @override
  String toString() => message;
}
