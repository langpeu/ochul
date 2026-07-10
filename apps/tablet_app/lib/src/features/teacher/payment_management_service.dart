import '../../core/edge_function_client.dart';

class PaymentManagementService {
  const PaymentManagementService({required this.edgeClient});

  final EdgeFunctionClient edgeClient;

  Future<List<PaymentPeriodSummary>> fetchPeriods(String studyRoomId) async {
    final data = await edgeClient.call(
      '/study-rooms/$studyRoomId/payment-periods',
    );
    final periodsJson = data['periods'];
    return [
      if (periodsJson is List)
        for (final item in periodsJson)
          if (item is Map<String, dynamic>) PaymentPeriodSummary.fromJson(item),
    ];
  }

  Future<PaymentPeriodSummary> createPeriod({
    required String studyRoomId,
    required String name,
    required String dueDate,
    required int amount,
  }) async {
    final data = await edgeClient.call(
      '/study-rooms/$studyRoomId/payment-periods',
      method: EdgeHttpMethod.post,
      body: <String, dynamic>{
        'name': name,
        'dueDate': dueDate,
        'amount': amount,
      },
    );
    final periodJson = data['period'];
    if (periodJson is Map<String, dynamic>) {
      return PaymentPeriodSummary.fromJson(periodJson);
    }
    throw const PaymentManagementException('납부 기간 생성 응답이 올바르지 않습니다.');
  }

  Future<PaymentStatusData> fetchStatuses(String paymentPeriodId) async {
    final data = await edgeClient.call(
      '/payment-periods/$paymentPeriodId/statuses',
    );
    return PaymentStatusData.fromJson(data);
  }

  Future<PaymentStatusSummary> updateStatus({
    required String paymentStatusId,
    required String status,
    required String note,
  }) async {
    final data = await edgeClient.call(
      '/payment-statuses/$paymentStatusId',
      method: EdgeHttpMethod.patch,
      body: <String, dynamic>{'status': status, 'note': note},
    );
    final statusJson = data['status'];
    if (statusJson is Map<String, dynamic>) {
      return PaymentStatusSummary.fromJson(statusJson);
    }
    throw const PaymentManagementException('납부 상태 변경 응답이 올바르지 않습니다.');
  }

  Future<int> notifyUnpaid(String paymentPeriodId) async {
    final data = await edgeClient.call(
      '/payment-periods/$paymentPeriodId/unpaid/notify',
      method: EdgeHttpMethod.post,
    );
    final notifications = data['notifications'];
    if (notifications is Map<String, dynamic>) {
      return notifications['requested'] as int? ?? 0;
    }
    return 0;
  }
}

class PaymentPeriodSummary {
  const PaymentPeriodSummary({
    required this.id,
    required this.name,
    required this.dueDate,
  });

  factory PaymentPeriodSummary.fromJson(Map<String, dynamic> json) {
    return PaymentPeriodSummary(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '납부 기간',
      dueDate: json['dueDate'] as String? ?? '',
    );
  }

  final String id;
  final String name;
  final String dueDate;
}

class PaymentStatusData {
  const PaymentStatusData({required this.period, required this.statuses});

  factory PaymentStatusData.fromJson(Map<String, dynamic> json) {
    final periodJson = json['period'];
    final statusesJson = json['statuses'];
    return PaymentStatusData(
      period: periodJson is Map<String, dynamic>
          ? PaymentPeriodSummary.fromJson(periodJson)
          : const PaymentPeriodSummary(id: '', name: '납부 기간', dueDate: ''),
      statuses: [
        if (statusesJson is List)
          for (final item in statusesJson)
            if (item is Map<String, dynamic>)
              PaymentStatusSummary.fromJson(item),
      ],
    );
  }

  final PaymentPeriodSummary period;
  final List<PaymentStatusSummary> statuses;
}

class PaymentStatusSummary {
  const PaymentStatusSummary({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.studentCode,
    required this.amount,
    required this.status,
    required this.note,
  });

  factory PaymentStatusSummary.fromJson(Map<String, dynamic> json) {
    return PaymentStatusSummary(
      id: json['id'] as String? ?? '',
      studentId: json['studentId'] as String? ?? '',
      studentName: json['studentName'] as String? ?? '학생',
      studentCode: json['studentCode'] as String? ?? '',
      amount: json['amount'] as int? ?? 0,
      status: json['status'] as String? ?? 'unpaid',
      note: json['note'] as String?,
    );
  }

  final String id;
  final String studentId;
  final String studentName;
  final String studentCode;
  final int amount;
  final String status;
  final String? note;
}

class PaymentManagementException implements Exception {
  const PaymentManagementException(this.message);

  final String message;

  @override
  String toString() => message;
}
