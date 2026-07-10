enum AttendanceStatus {
  waiting('대기'),
  present('출석'),
  late('지각'),
  absent('결석');

  const AttendanceStatus(this.label);

  final String label;
}

class ClassSummary {
  const ClassSummary({
    required this.id,
    required this.name,
    required this.time,
    required this.kind,
    required this.students,
  });

  final String id;
  final String name;
  final String time;
  final String kind;
  final List<StudentSummary> students;
}

class StudentSummary {
  const StudentSummary({
    required this.id,
    required this.name,
    required this.code,
    required this.status,
  });

  final String id;
  final String name;
  final String code;
  final AttendanceStatus status;
}

class AuditLogSummary {
  const AuditLogSummary({
    required this.type,
    required this.title,
    required this.actor,
    required this.time,
  });

  final String type;
  final String title;
  final String actor;
  final String time;
}

const sampleClasses = <ClassSummary>[
  ClassSummary(
    id: 'math-a',
    name: '수학 A반',
    time: '월/수 15:00-16:00',
    kind: '기본',
    students: [
      StudentSummary(
        id: 's1',
        name: '김도윤',
        code: '1031',
        status: AttendanceStatus.present,
      ),
      StudentSummary(
        id: 's2',
        name: '이서연',
        code: '2042',
        status: AttendanceStatus.waiting,
      ),
      StudentSummary(
        id: 's3',
        name: '박지호',
        code: '3190',
        status: AttendanceStatus.late,
      ),
    ],
  ),
  ClassSummary(
    id: 'english-makeup',
    name: '영어 보강',
    time: '금 17:00-18:00',
    kind: '보강',
    students: [
      StudentSummary(
        id: 's4',
        name: '최하린',
        code: '8820',
        status: AttendanceStatus.waiting,
      ),
      StudentSummary(
        id: 's5',
        name: '정민재',
        code: '4551',
        status: AttendanceStatus.absent,
      ),
    ],
  ),
];

const sampleAuditLogs = <AuditLogSummary>[
  AuditLogSummary(
    type: '학생',
    title: '김도윤 학생 정보 수정',
    actor: '홍선생',
    time: '14:20',
  ),
  AuditLogSummary(
    type: '수업',
    title: '영어 보강 수업 등록',
    actor: '홍선생',
    time: '13:45',
  ),
  AuditLogSummary(
    type: '카카오',
    title: '수학 A반 출석 알림 발송 성공',
    actor: '시스템',
    time: '13:02',
  ),
];
