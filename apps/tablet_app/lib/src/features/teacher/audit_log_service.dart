import '../../core/edge_function_client.dart';

class AuditLogService {
  const AuditLogService({required this.edgeClient});

  final EdgeFunctionClient edgeClient;

  Future<List<AppAuditLog>> fetchLogs({
    required String studyRoomId,
    required AuditLogCategory category,
    String? studentId,
    String? classId,
    String? dateFrom,
    String? dateTo,
  }) async {
    final data = await edgeClient.call(
      '/study-rooms/$studyRoomId/audit-logs',
      body: <String, dynamic>{
        'category': category.value,
        'limit': 60,
        if (studentId != null && studentId.isNotEmpty) 'studentId': studentId,
        if (classId != null && classId.isNotEmpty) 'classId': classId,
        if (dateFrom != null && dateFrom.isNotEmpty) 'dateFrom': dateFrom,
        if (dateTo != null && dateTo.isNotEmpty) 'dateTo': dateTo,
      },
    );
    final logsJson = data['logs'];
    return [
      if (logsJson is List)
        for (final item in logsJson)
          if (item is Map<String, dynamic>) AppAuditLog.fromJson(item),
    ];
  }
}

enum AuditLogCategory {
  all('all', '전체'),
  student('student', '학생'),
  classRoom('class', '수업'),
  kakao('kakao', '카카오');

  const AuditLogCategory(this.value, this.label);

  final String value;
  final String label;
}

class AppAuditLog {
  const AppAuditLog({
    required this.id,
    required this.category,
    required this.entityType,
    required this.action,
    required this.title,
    required this.summary,
    required this.actor,
    required this.createdAt,
  });

  factory AppAuditLog.fromJson(Map<String, dynamic> json) {
    return AppAuditLog(
      id: json['id'] as String? ?? '',
      category: json['category'] as String? ?? 'class',
      entityType: json['entityType'] as String? ?? '',
      action: json['action'] as String? ?? '',
      title: json['title'] as String? ?? '히스토리',
      summary: json['summary'] as String?,
      actor: json['actor'] as String? ?? '시스템',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
    );
  }

  final String id;
  final String category;
  final String entityType;
  final String action;
  final String title;
  final String? summary;
  final String actor;
  final DateTime? createdAt;
}
