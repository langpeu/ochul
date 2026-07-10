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
}

class ManagedClass {
  const ManagedClass({
    required this.id,
    required this.name,
    required this.classKind,
    required this.startDate,
    required this.endDate,
    required this.scheduleText,
    required this.active,
  });

  factory ManagedClass.fromJson(Map<String, dynamic> json) {
    return ManagedClass(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '수업',
      classKind: json['classKind'] as String? ?? 'regular',
      startDate: json['startDate'] as String? ?? '',
      endDate: json['endDate'] as String? ?? '',
      scheduleText: json['scheduleText'] as String? ?? '',
      active: json['active'] as bool? ?? true,
    );
  }

  final String id;
  final String name;
  final String classKind;
  final String startDate;
  final String endDate;
  final String scheduleText;
  final bool active;
}

class ClassManagementException implements Exception {
  const ClassManagementException(this.message);

  final String message;

  @override
  String toString() => message;
}
