import '../../core/edge_function_client.dart';

class ClassroomLayoutService {
  const ClassroomLayoutService({required this.edgeClient});

  final EdgeFunctionClient edgeClient;

  Future<ClassroomLayout> fetchLayout(String classId) async {
    final data = await edgeClient.call('/classes/$classId/classroom-layout');
    final layoutJson = data['layout'];
    if (layoutJson is Map<String, dynamic>) {
      return ClassroomLayout.fromJson(layoutJson);
    }
    throw const ClassroomLayoutException('교실 배치 응답이 올바르지 않습니다.');
  }

  Future<ClassroomLayout> saveLayout({
    required String classId,
    required ClassroomLayout layout,
  }) async {
    final data = await edgeClient.call(
      '/classes/$classId/classroom-layout',
      method: EdgeHttpMethod.put,
      body: <String, dynamic>{
        'name': layout.name,
        'canvasWidth': layout.canvasWidth,
        'canvasHeight': layout.canvasHeight,
        'seats': [for (final seat in layout.seats) seat.toJson()],
      },
    );
    final layoutJson = data['layout'];
    if (layoutJson is Map<String, dynamic>) {
      return ClassroomLayout.fromJson(layoutJson);
    }
    throw const ClassroomLayoutException('교실 배치 저장 응답이 올바르지 않습니다.');
  }

  Future<ClassroomLayout> saveAssignments({
    required String classId,
    required List<SeatAssignmentInput> assignments,
  }) async {
    final data = await edgeClient.call(
      '/classes/$classId/seat-assignments',
      method: EdgeHttpMethod.put,
      body: <String, dynamic>{
        'assignments': [
          for (final assignment in assignments) assignment.toJson(),
        ],
      },
    );
    final layoutJson = data['layout'];
    if (layoutJson is Map<String, dynamic>) {
      return ClassroomLayout.fromJson(layoutJson);
    }
    throw const ClassroomLayoutException('좌석 배정 저장 응답이 올바르지 않습니다.');
  }

  Future<ClassroomLayout> copyLayout({
    required String targetClassId,
    required String sourceClassId,
  }) async {
    final data = await edgeClient.call(
      '/classes/$targetClassId/classroom-layout/copy',
      method: EdgeHttpMethod.post,
      body: <String, dynamic>{'sourceClassId': sourceClassId},
    );
    final layoutJson = data['layout'];
    if (layoutJson is Map<String, dynamic>) {
      return ClassroomLayout.fromJson(layoutJson);
    }
    throw const ClassroomLayoutException('교실 배치 복사 응답이 올바르지 않습니다.');
  }
}

class ClassroomLayout {
  const ClassroomLayout({
    required this.id,
    required this.classId,
    required this.name,
    required this.canvasWidth,
    required this.canvasHeight,
    required this.seats,
    required this.assignments,
  });

  factory ClassroomLayout.fromJson(Map<String, dynamic> json) {
    return ClassroomLayout(
      id: json['id'] as String?,
      classId: json['classId'] as String? ?? '',
      name: json['name'] as String? ?? '기본 배치',
      canvasWidth: (json['canvasWidth'] as num?)?.toDouble() ?? 1000,
      canvasHeight: (json['canvasHeight'] as num?)?.toDouble() ?? 700,
      seats: [
        if (json['seats'] is List)
          for (final seat in json['seats'] as List)
            if (seat is Map<String, dynamic>) ClassroomSeat.fromJson(seat),
      ],
      assignments: [
        if (json['assignments'] is List)
          for (final assignment in json['assignments'] as List)
            if (assignment is Map<String, dynamic>)
              SeatAssignment.fromJson(assignment),
      ],
    );
  }

  final String? id;
  final String classId;
  final String name;
  final double canvasWidth;
  final double canvasHeight;
  final List<ClassroomSeat> seats;
  final List<SeatAssignment> assignments;

  ClassroomLayout copyWith({
    String? id,
    String? classId,
    String? name,
    double? canvasWidth,
    double? canvasHeight,
    List<ClassroomSeat>? seats,
    List<SeatAssignment>? assignments,
  }) {
    return ClassroomLayout(
      id: id ?? this.id,
      classId: classId ?? this.classId,
      name: name ?? this.name,
      canvasWidth: canvasWidth ?? this.canvasWidth,
      canvasHeight: canvasHeight ?? this.canvasHeight,
      seats: seats ?? this.seats,
      assignments: assignments ?? this.assignments,
    );
  }
}

class ClassroomSeat {
  const ClassroomSeat({
    required this.id,
    required this.label,
    required this.deskX,
    required this.deskY,
    required this.seatX,
    required this.seatY,
    required this.rotationDegrees,
    required this.displayOrder,
  });

  factory ClassroomSeat.fromJson(Map<String, dynamic> json) {
    return ClassroomSeat(
      id: json['id'] as String?,
      label: json['label'] as String? ?? '',
      deskX: (json['deskX'] as num?)?.toDouble() ?? 0,
      deskY: (json['deskY'] as num?)?.toDouble() ?? 0,
      seatX: (json['seatX'] as num?)?.toDouble() ?? 0,
      seatY: (json['seatY'] as num?)?.toDouble() ?? 0,
      rotationDegrees: (json['rotationDegrees'] as num?)?.toDouble() ?? 0,
      displayOrder: json['displayOrder'] as int? ?? 0,
    );
  }

  final String? id;
  final String label;
  final double deskX;
  final double deskY;
  final double seatX;
  final double seatY;
  final double rotationDegrees;
  final int displayOrder;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if (id != null) 'id': id,
      'label': label,
      'deskX': deskX,
      'deskY': deskY,
      'seatX': seatX,
      'seatY': seatY,
      'rotationDegrees': rotationDegrees,
      'displayOrder': displayOrder,
    };
  }
}

class SeatAssignment {
  const SeatAssignment({
    required this.seatId,
    required this.studentId,
    required this.studentName,
    required this.studentCode,
  });

  factory SeatAssignment.fromJson(Map<String, dynamic> json) {
    return SeatAssignment(
      seatId: json['seatId'] as String? ?? '',
      studentId: json['studentId'] as String? ?? '',
      studentName: json['studentName'] as String? ?? '',
      studentCode: json['studentCode'] as String? ?? '',
    );
  }

  final String seatId;
  final String studentId;
  final String studentName;
  final String studentCode;
}

class SeatAssignmentInput {
  const SeatAssignmentInput({required this.seatId, required this.studentId});

  final String seatId;
  final String studentId;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'seatId': seatId, 'studentId': studentId};
  }
}

class ClassroomLayoutException implements Exception {
  const ClassroomLayoutException(this.message);

  final String message;

  @override
  String toString() => message;
}
