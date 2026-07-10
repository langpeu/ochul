import '../../core/edge_function_client.dart';

class NotificationLogService {
  const NotificationLogService({required this.edgeClient});

  final EdgeFunctionClient edgeClient;

  Future<List<KakaoNotificationLog>> fetchLogs({
    required String studyRoomId,
    required String status,
  }) async {
    final data = await edgeClient.call(
      '/study-rooms/$studyRoomId/notifications',
      body: <String, dynamic>{'status': status, 'limit': 80},
    );
    final notificationsJson = data['notifications'];
    return [
      if (notificationsJson is List)
        for (final item in notificationsJson)
          if (item is Map<String, dynamic>) KakaoNotificationLog.fromJson(item),
    ];
  }

  Future<KakaoNotificationLog> resend(String notificationId) async {
    final data = await edgeClient.call(
      '/notifications/$notificationId/resend',
      method: EdgeHttpMethod.post,
    );
    final notificationJson = data['notification'];
    if (notificationJson is Map<String, dynamic>) {
      return KakaoNotificationLog.fromJson(notificationJson);
    }
    throw const NotificationLogException('카카오 재발송 응답이 올바르지 않습니다.');
  }

  Future<NotificationProcessResult> processPending(String studyRoomId) async {
    final data = await edgeClient.call(
      '/notifications/process-pending',
      method: EdgeHttpMethod.post,
      body: <String, dynamic>{'studyRoomId': studyRoomId, 'limit': 20},
    );
    return NotificationProcessResult.fromJson(data);
  }
}

class KakaoNotificationLog {
  const KakaoNotificationLog({
    required this.id,
    required this.eventType,
    required this.recipientPhoneMasked,
    required this.studentName,
    required this.className,
    required this.status,
    required this.errorMessage,
    required this.retryCount,
    required this.createdAt,
    required this.sentAt,
  });

  factory KakaoNotificationLog.fromJson(Map<String, dynamic> json) {
    return KakaoNotificationLog(
      id: json['id'] as String? ?? '',
      eventType: json['eventType'] as String? ?? '',
      recipientPhoneMasked: json['recipientPhoneMasked'] as String? ?? '',
      studentName: json['studentName'] as String? ?? '학생',
      className: json['className'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      errorMessage: json['errorMessage'] as String?,
      retryCount: json['retryCount'] as int? ?? 0,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
      sentAt: DateTime.tryParse(json['sentAt'] as String? ?? ''),
    );
  }

  final String id;
  final String eventType;
  final String recipientPhoneMasked;
  final String studentName;
  final String className;
  final String status;
  final String? errorMessage;
  final int retryCount;
  final DateTime? createdAt;
  final DateTime? sentAt;
}

class NotificationLogException implements Exception {
  const NotificationLogException(this.message);

  final String message;

  @override
  String toString() => message;
}

class NotificationProcessResult {
  const NotificationProcessResult({
    required this.processed,
    required this.sent,
    required this.failed,
  });

  factory NotificationProcessResult.fromJson(Map<String, dynamic> json) {
    return NotificationProcessResult(
      processed: json['processed'] as int? ?? 0,
      sent: json['sent'] as int? ?? 0,
      failed: json['failed'] as int? ?? 0,
    );
  }

  final int processed;
  final int sent;
  final int failed;
}
