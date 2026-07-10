import 'package:flutter/material.dart';

import '../../core/app_config.dart';
import '../../core/edge_function_client.dart';
import '../../core/teacher_gate.dart';
import '../../models/sample_data.dart';
import 'admin_management_service.dart';
import 'audit_log_service.dart';
import 'class_management_service.dart';
import 'enrollment_management_service.dart';
import 'payment_management_service.dart';
import 'student_management_service.dart';
import 'teacher_home_service.dart';

class TeacherDashboard extends StatefulWidget {
  const TeacherDashboard({super.key, required this.config});

  final AppConfig config;

  @override
  State<TeacherDashboard> createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends State<TeacherDashboard> {
  var _unlocked = false;
  final _gate = TeacherGate();
  final _homeService = const TeacherHomeService(
    edgeClient: EdgeFunctionClient(),
  );
  final _studentService = const StudentManagementService(
    edgeClient: EdgeFunctionClient(),
  );
  final _classService = const ClassManagementService(
    edgeClient: EdgeFunctionClient(),
  );
  final _enrollmentService = const EnrollmentManagementService(
    edgeClient: EdgeFunctionClient(),
  );
  final _auditLogService = const AuditLogService(
    edgeClient: EdgeFunctionClient(),
  );
  final _adminService = const AdminManagementService(
    edgeClient: EdgeFunctionClient(),
  );
  final _paymentService = const PaymentManagementService(
    edgeClient: EdgeFunctionClient(),
  );

  Future<void> _unlock() async {
    final ok = await _gate.authenticate();
    if (!mounted) {
      return;
    }
    setState(() => _unlocked = ok);
    if (!ok) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('기기 인증을 완료하지 못했습니다.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_unlocked) {
      return Center(
        child: FilledButton.icon(
          onPressed: _unlock,
          icon: const Icon(Icons.lock_open),
          label: const Text('선생님 모드 인증'),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('선생님 보드', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 16),
          _TeacherHomeHeader(config: widget.config, service: _homeService),
          const SizedBox(height: 16),
          Expanded(
            child: _TeacherBoardContent(
              config: widget.config,
              homeService: _homeService,
              studentService: _studentService,
              classService: _classService,
              enrollmentService: _enrollmentService,
              auditLogService: _auditLogService,
              adminService: _adminService,
              paymentService: _paymentService,
            ),
          ),
        ],
      ),
    );
  }
}

class _TeacherBoardContent extends StatelessWidget {
  const _TeacherBoardContent({
    required this.config,
    required this.homeService,
    required this.studentService,
    required this.classService,
    required this.enrollmentService,
    required this.auditLogService,
    required this.adminService,
    required this.paymentService,
  });

  final AppConfig config;
  final TeacherHomeService homeService;
  final StudentManagementService studentService;
  final ClassManagementService classService;
  final EnrollmentManagementService enrollmentService;
  final AuditLogService auditLogService;
  final AdminManagementService adminService;
  final PaymentManagementService paymentService;

  @override
  Widget build(BuildContext context) {
    if (!config.isSupabaseConfigured) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _ClassPanel(classes: sampleClasses)),
          const SizedBox(width: 16),
          Expanded(child: _EnrollmentPanel(classes: sampleClasses)),
          const SizedBox(width: 16),
          const Expanded(child: _SampleAuditPanel()),
        ],
      );
    }

    return FutureBuilder<TeacherHome>(
      future: homeService.fetchMe(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _TeacherHomeError(message: snapshot.error.toString());
        }
        final home = snapshot.requireData;
        if (home.teacher?.role == 'admin') {
          return _AdminDashboardPanel(service: adminService);
        }
        final studyRoom = home.studyRooms.isEmpty
            ? null
            : home.studyRooms.first;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: studyRoom == null
                  ? const _EmptyClassPanel()
                  : _ClassManagementPanel(
                      studyRoom: studyRoom,
                      service: classService,
                    ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: studyRoom == null
                  ? const _EmptyStudyRoomPanel()
                  : _StudentManagementPanel(
                      studyRoom: studyRoom,
                      service: studentService,
                    ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: studyRoom == null
                  ? const _EmptyStudyRoomPanel()
                  : _EnrollmentManagementPanel(
                      studyRoom: studyRoom,
                      classService: classService,
                      studentService: studentService,
                      enrollmentService: enrollmentService,
                    ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: studyRoom == null
                  ? const _EmptyStudyRoomPanel()
                  : Column(
                      children: [
                        Expanded(
                          child: _PaymentManagementPanel(
                            studyRoom: studyRoom,
                            service: paymentService,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: _AuditHistoryPanel(
                            studyRoom: studyRoom,
                            service: auditLogService,
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _TeacherHomeHeader extends StatefulWidget {
  const _TeacherHomeHeader({required this.config, required this.service});

  final AppConfig config;
  final TeacherHomeService service;

  @override
  State<_TeacherHomeHeader> createState() => _TeacherHomeHeaderState();
}

class _TeacherHomeHeaderState extends State<_TeacherHomeHeader> {
  late Future<TeacherHome>? _homeFuture;

  @override
  void initState() {
    super.initState();
    _homeFuture = widget.config.isSupabaseConfigured
        ? widget.service.fetchMe()
        : null;
  }

  Future<void> _onboard({
    required String teacherName,
    required String studyRoomName,
  }) async {
    final home = await widget.service.onboard(
      teacherName: teacherName,
      studyRoomName: studyRoomName,
    );
    if (mounted) {
      setState(() => _homeFuture = Future.value(home));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.config.isSupabaseConfigured) {
      return const _StudyRoomSummaryBar(
        teacherName: '홍선생',
        role: 'teacher',
        studyRooms: [
          StudyRoomSummary(
            id: 'sample-room-1',
            name: '홍선생 공부방',
            description: '화면 설계 모드 샘플',
          ),
        ],
        designMode: true,
      );
    }

    return FutureBuilder<TeacherHome>(
      future: _homeFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const LinearProgressIndicator();
        }
        if (snapshot.hasError) {
          return _TeacherHomeError(message: snapshot.error.toString());
        }
        final home = snapshot.requireData;
        if (home.needsOnboarding) {
          return _TeacherOnboardingCard(onSubmit: _onboard);
        }
        final teacher = home.teacher;
        if (teacher == null) {
          return const _TeacherHomeError(message: '선생님 프로필이 필요합니다.');
        }
        return _StudyRoomSummaryBar(
          teacherName: teacher.name,
          role: teacher.role,
          studyRooms: home.studyRooms,
          designMode: false,
        );
      },
    );
  }
}

class _TeacherOnboardingCard extends StatefulWidget {
  const _TeacherOnboardingCard({required this.onSubmit});

  final Future<void> Function({
    required String teacherName,
    required String studyRoomName,
  })
  onSubmit;

  @override
  State<_TeacherOnboardingCard> createState() => _TeacherOnboardingCardState();
}

class _TeacherOnboardingCardState extends State<_TeacherOnboardingCard> {
  final _teacherNameController = TextEditingController();
  final _studyRoomNameController = TextEditingController();
  String? _errorText;
  var _submitting = false;

  @override
  void dispose() {
    _teacherNameController.dispose();
    _studyRoomNameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final teacherName = _teacherNameController.text.trim();
    final studyRoomName = _studyRoomNameController.text.trim();
    if (teacherName.length < 2 || studyRoomName.length < 2) {
      setState(() => _errorText = '선생님 이름과 공부방 이름을 2자 이상 입력해 주세요.');
      return;
    }

    setState(() {
      _errorText = null;
      _submitting = true;
    });
    try {
      await widget.onSubmit(
        teacherName: teacherName,
        studyRoomName: studyRoomName,
      );
    } catch (_) {
      if (mounted) {
        setState(() => _errorText = '공부방 생성에 실패했습니다.');
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.add_business_outlined),
            const SizedBox(width: 12),
            Expanded(
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 180,
                    child: TextField(
                      controller: _teacherNameController,
                      enabled: !_submitting,
                      decoration: const InputDecoration(
                        labelText: '선생님 이름',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    child: TextField(
                      controller: _studyRoomNameController,
                      enabled: !_submitting,
                      decoration: InputDecoration(
                        labelText: '공부방 이름',
                        errorText: _errorText,
                        border: const OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _submitting ? null : _submit(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: const Icon(Icons.check),
              label: Text(_submitting ? '생성 중' : '공부방 생성'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StudyRoomSummaryBar extends StatelessWidget {
  const _StudyRoomSummaryBar({
    required this.teacherName,
    required this.role,
    required this.studyRooms,
    required this.designMode,
  });

  final String teacherName;
  final String role;
  final List<StudyRoomSummary> studyRooms;
  final bool designMode;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.account_circle_outlined),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    teacherName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${role == 'admin' ? '관리자' : '선생님'} · 공부방 ${studyRooms.length}개',
                  ),
                ],
              ),
            ),
            if (designMode)
              const Chip(
                avatar: Icon(Icons.visibility_outlined, size: 18),
                label: Text('설계 모드'),
              ),
            const SizedBox(width: 12),
            Flexible(
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final studyRoom in studyRooms)
                    Chip(
                      avatar: const Icon(Icons.meeting_room_outlined, size: 18),
                      label: Text(studyRoom.name),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TeacherHomeError extends StatelessWidget {
  const _TeacherHomeError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text('선생님 정보를 불러오지 못했습니다. $message')),
          ],
        ),
      ),
    );
  }
}

class _ClassPanel extends StatelessWidget {
  const _ClassPanel({required this.classes});

  final List<ClassSummary> classes;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('수업 목록', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            for (final classRoom in classes)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  classRoom.kind == '보강'
                      ? Icons.event_repeat
                      : Icons.school_outlined,
                ),
                title: Text(classRoom.name),
                subtitle: Text('${classRoom.kind} · ${classRoom.time}'),
              ),
          ],
        ),
      ),
    );
  }
}

class _ClassManagementPanel extends StatefulWidget {
  const _ClassManagementPanel({required this.studyRoom, required this.service});

  final StudyRoomSummary studyRoom;
  final ClassManagementService service;

  @override
  State<_ClassManagementPanel> createState() => _ClassManagementPanelState();
}

class _ClassManagementPanelState extends State<_ClassManagementPanel> {
  late Future<List<ManagedClass>> _classesFuture;
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _startDateController = TextEditingController();
  final _endDateController = TextEditingController();
  final _startsAtController = TextEditingController(text: '15:00');
  final _endsAtController = TextEditingController(text: '16:00');
  final _selectedDays = <int>{1, 3};
  var _classKind = 'regular';
  String? _errorText;
  var _submitting = false;
  String? _openingClassId;
  String? _processingClassId;

  @override
  void initState() {
    super.initState();
    _classesFuture = widget.service.fetchClasses(widget.studyRoom.id);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    _startsAtController.dispose();
    _endsAtController.dispose();
    super.dispose();
  }

  Future<void> _createClass() async {
    final name = _nameController.text.trim();
    final startDate = _startDateController.text.trim();
    final endDate = _endDateController.text.trim();
    final startsAt = _startsAtController.text.trim();
    final endsAt = _endsAtController.text.trim();
    if (name.length < 2 ||
        !_datePattern.hasMatch(startDate) ||
        !_datePattern.hasMatch(endDate) ||
        !_timePattern.hasMatch(startsAt) ||
        !_timePattern.hasMatch(endsAt) ||
        _selectedDays.isEmpty) {
      setState(() => _errorText = '수업명, 기간, 요일, 시간을 입력해 주세요.');
      return;
    }

    setState(() {
      _errorText = null;
      _submitting = true;
    });
    try {
      await widget.service.createClass(
        studyRoomId: widget.studyRoom.id,
        name: name,
        description: _descriptionController.text.trim(),
        classKind: _classKind,
        startDate: startDate,
        endDate: endDate,
        dayOfWeeks: _selectedDays.toList()..sort(),
        startsAt: startsAt,
        endsAt: endsAt,
      );
      _nameController.clear();
      _descriptionController.clear();
      if (mounted) {
        setState(() {
          _classesFuture = widget.service.fetchClasses(widget.studyRoom.id);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _errorText = '수업 생성에 실패했습니다.');
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _openAttendance(ManagedClass classRoom) async {
    setState(() => _openingClassId = classRoom.id);
    try {
      await widget.service.openAttendanceSession(classRoom.id);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${classRoom.name} 출석을 열었습니다.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('출석 열기에 실패했습니다.')));
      }
    } finally {
      if (mounted) {
        setState(() => _openingClassId = null);
      }
    }
  }

  Future<void> _cancelToday(ManagedClass classRoom) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => _ClassChangeReasonDialog(
        title: '${classRoom.name} 휴강',
        labelText: '휴강 사유',
      ),
    );
    if (reason == null) return;

    setState(() => _processingClassId = classRoom.id);
    try {
      final count = await widget.service.cancelTodaySession(
        classId: classRoom.id,
        reason: reason,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('휴강 안내 $count건을 요청했습니다.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('휴강 처리에 실패했습니다.')));
      }
    } finally {
      if (mounted) setState(() => _processingClassId = null);
    }
  }

  Future<void> _createMakeup(ManagedClass classRoom) async {
    final result = await showDialog<_MakeupSessionResult>(
      context: context,
      builder: (context) => _MakeupSessionDialog(className: classRoom.name),
    );
    if (result == null) return;

    setState(() => _processingClassId = classRoom.id);
    try {
      final count = await widget.service.createMakeupSession(
        classId: classRoom.id,
        sessionDate: result.sessionDate,
        startsAt: result.startsAt,
        endsAt: result.endsAt,
        reason: result.reason,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('보강 안내 $count건을 요청했습니다.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('보강 생성에 실패했습니다.')));
      }
    } finally {
      if (mounted) setState(() => _processingClassId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('수업 관리', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(widget.studyRoom.name),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              enabled: !_submitting,
              decoration: const InputDecoration(
                labelText: '수업명',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _descriptionController,
              enabled: !_submitting,
              decoration: const InputDecoration(
                labelText: '수업 설명',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                SizedBox(
                  width: 130,
                  child: TextField(
                    controller: _startDateController,
                    enabled: !_submitting,
                    decoration: const InputDecoration(
                      labelText: '시작일',
                      hintText: '2026-07-10',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(
                  width: 130,
                  child: TextField(
                    controller: _endDateController,
                    enabled: !_submitting,
                    decoration: const InputDecoration(
                      labelText: '종료일',
                      hintText: '2026-10-10',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(
                  width: 105,
                  child: TextField(
                    controller: _startsAtController,
                    enabled: !_submitting,
                    decoration: const InputDecoration(
                      labelText: '시작',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(
                  width: 105,
                  child: TextField(
                    controller: _endsAtController,
                    enabled: !_submitting,
                    decoration: InputDecoration(
                      labelText: '종료',
                      errorText: _errorText,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'regular', label: Text('기본')),
                ButtonSegment(value: 'makeup', label: Text('보강')),
                ButtonSegment(value: 'extra', label: Text('추가')),
              ],
              selected: {_classKind},
              onSelectionChanged: _submitting
                  ? null
                  : (selection) => setState(() => _classKind = selection.first),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: [
                for (var day = 0; day < _dayLabels.length; day++)
                  FilterChip(
                    label: Text(_dayLabels[day]),
                    selected: _selectedDays.contains(day),
                    onSelected: _submitting
                        ? null
                        : (selected) {
                            setState(() {
                              if (selected) {
                                _selectedDays.add(day);
                              } else {
                                _selectedDays.remove(day);
                              }
                            });
                          },
                  ),
              ],
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _submitting ? null : _createClass,
              icon: const Icon(Icons.add),
              label: Text(_submitting ? '생성 중' : '수업 생성'),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: FutureBuilder<List<ManagedClass>>(
                future: _classesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Text('수업 목록을 불러오지 못했습니다. ${snapshot.error}');
                  }
                  final classes = snapshot.data ?? const <ManagedClass>[];
                  if (classes.isEmpty) {
                    return const Center(child: Text('등록된 수업이 없습니다.'));
                  }
                  return ListView.builder(
                    itemCount: classes.length,
                    itemBuilder: (context, index) {
                      final classRoom = classes[index];
                      final processing = _processingClassId == classRoom.id;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          classRoom.classKind == 'makeup'
                              ? Icons.event_repeat
                              : Icons.school_outlined,
                        ),
                        title: Text(classRoom.name),
                        subtitle: Text(
                          '${_classKindLabel(classRoom.classKind)} · ${classRoom.scheduleText}',
                        ),
                        trailing: processing || _openingClassId == classRoom.id
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : PopupMenuButton<_ClassAction>(
                                tooltip: '수업 작업',
                                icon: const Icon(Icons.more_vert),
                                onSelected: (action) {
                                  switch (action) {
                                    case _ClassAction.openAttendance:
                                      _openAttendance(classRoom);
                                    case _ClassAction.cancelToday:
                                      _cancelToday(classRoom);
                                    case _ClassAction.createMakeup:
                                      _createMakeup(classRoom);
                                  }
                                },
                                itemBuilder: (context) => const [
                                  PopupMenuItem(
                                    value: _ClassAction.openAttendance,
                                    child: ListTile(
                                      leading: Icon(Icons.play_circle_outline),
                                      title: Text('출석 열기'),
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: _ClassAction.cancelToday,
                                    child: ListTile(
                                      leading: Icon(Icons.event_busy_outlined),
                                      title: Text('오늘 휴강'),
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: _ClassAction.createMakeup,
                                    child: ListTile(
                                      leading: Icon(Icons.event_repeat),
                                      title: Text('보강 추가'),
                                    ),
                                  ),
                                ],
                              ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _ClassAction { openAttendance, cancelToday, createMakeup }

class _ClassChangeReasonDialog extends StatefulWidget {
  const _ClassChangeReasonDialog({
    required this.title,
    required this.labelText,
  });

  final String title;
  final String labelText;

  @override
  State<_ClassChangeReasonDialog> createState() =>
      _ClassChangeReasonDialogState();
}

class _ClassChangeReasonDialogState extends State<_ClassChangeReasonDialog> {
  final _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.of(context).pop(_reasonController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 320,
        child: TextField(
          controller: _reasonController,
          decoration: InputDecoration(
            labelText: widget.labelText,
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(onPressed: _submit, child: const Text('확인')),
      ],
    );
  }
}

class _MakeupSessionResult {
  const _MakeupSessionResult({
    required this.sessionDate,
    required this.startsAt,
    required this.endsAt,
    required this.reason,
  });

  final String sessionDate;
  final String startsAt;
  final String endsAt;
  final String reason;
}

class _MakeupSessionDialog extends StatefulWidget {
  const _MakeupSessionDialog({required this.className});

  final String className;

  @override
  State<_MakeupSessionDialog> createState() => _MakeupSessionDialogState();
}

class _MakeupSessionDialogState extends State<_MakeupSessionDialog> {
  final _dateController = TextEditingController();
  final _startsAtController = TextEditingController(text: '15:00');
  final _endsAtController = TextEditingController(text: '16:00');
  final _reasonController = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _dateController.dispose();
    _startsAtController.dispose();
    _endsAtController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  void _submit() {
    final date = _dateController.text.trim();
    final startsAt = _startsAtController.text.trim();
    final endsAt = _endsAtController.text.trim();
    if (!_datePattern.hasMatch(date) ||
        !_timePattern.hasMatch(startsAt) ||
        !_timePattern.hasMatch(endsAt) ||
        startsAt.compareTo(endsAt) >= 0) {
      setState(() => _errorText = '날짜와 시간을 확인해 주세요.');
      return;
    }
    Navigator.of(context).pop(
      _MakeupSessionResult(
        sessionDate: date,
        startsAt: startsAt,
        endsAt: endsAt,
        reason: _reasonController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${widget.className} 보강 추가'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _dateController,
              decoration: const InputDecoration(
                labelText: '보강일',
                hintText: '2026-07-31',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _startsAtController,
                    decoration: const InputDecoration(
                      labelText: '시작',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _endsAtController,
                    decoration: InputDecoration(
                      labelText: '종료',
                      errorText: _errorText,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reasonController,
              decoration: const InputDecoration(
                labelText: '보강 사유',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(onPressed: _submit, child: const Text('생성')),
      ],
    );
  }
}

class _EmptyClassPanel extends StatelessWidget {
  const _EmptyClassPanel();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('수업 관리', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            const Text('공부방을 먼저 생성해 주세요.'),
          ],
        ),
      ),
    );
  }
}

class _EnrollmentPanel extends StatelessWidget {
  const _EnrollmentPanel({required this.classes});

  final List<ClassSummary> classes;

  @override
  Widget build(BuildContext context) {
    final waitingStudents = classes.expand((classRoom) => classRoom.students);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('드래그앤드롭 등록', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final student in waitingStudents)
                  Draggable<StudentSummary>(
                    data: student,
                    feedback: Material(
                      color: Colors.transparent,
                      child: Chip(label: Text(student.name)),
                    ),
                    childWhenDragging: Opacity(
                      opacity: 0.35,
                      child: Chip(label: Text(student.name)),
                    ),
                    child: Chip(label: Text(student.name)),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            for (final classRoom in classes)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: DragTarget<StudentSummary>(
                  builder: (context, candidate, rejected) {
                    return DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: candidate.isEmpty
                              ? const Color(0xFFE3E7EB)
                              : Theme.of(context).colorScheme.primary,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.input),
                        title: Text(classRoom.name),
                        subtitle: const Text('학생을 여기에 놓아 등록'),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EnrollmentManagementPanel extends StatefulWidget {
  const _EnrollmentManagementPanel({
    required this.studyRoom,
    required this.classService,
    required this.studentService,
    required this.enrollmentService,
  });

  final StudyRoomSummary studyRoom;
  final ClassManagementService classService;
  final StudentManagementService studentService;
  final EnrollmentManagementService enrollmentService;

  @override
  State<_EnrollmentManagementPanel> createState() =>
      _EnrollmentManagementPanelState();
}

class _EnrollmentManagementPanelState
    extends State<_EnrollmentManagementPanel> {
  late Future<_EnrollmentData> _dataFuture;
  String? _selectedClassId;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadData();
  }

  Future<_EnrollmentData> _loadData() async {
    final classes = await widget.classService.fetchClasses(widget.studyRoom.id);
    final students = await widget.studentService.fetchStudents(
      widget.studyRoom.id,
    );
    final selectedClassId = _selectedClassId ?? classes.firstOrNull?.id;
    final enrolled = selectedClassId == null
        ? const <ManagedStudent>[]
        : await widget.enrollmentService.fetchClassStudents(selectedClassId);
    _selectedClassId = selectedClassId;
    return _EnrollmentData(
      classes: classes,
      students: students,
      enrolled: enrolled,
    );
  }

  Future<void> _saveEnrollment(List<String> studentIds) async {
    final classId = _selectedClassId;
    if (classId == null) {
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.enrollmentService.saveClassStudents(
        classId: classId,
        studentIds: studentIds,
      );
      if (mounted) {
        setState(() => _dataFuture = _loadData());
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('수강 등록', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(widget.studyRoom.name),
            const SizedBox(height: 12),
            Expanded(
              child: FutureBuilder<_EnrollmentData>(
                future: _dataFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Text('수강 등록 정보를 불러오지 못했습니다. ${snapshot.error}');
                  }
                  final data = snapshot.requireData;
                  if (data.classes.isEmpty) {
                    return const Center(child: Text('수업을 먼저 생성해 주세요.'));
                  }
                  final selectedClass = data.classes.firstWhere(
                    (classRoom) => classRoom.id == _selectedClassId,
                    orElse: () => data.classes.first,
                  );
                  final enrolledIds = data.enrolled
                      .map((student) => student.id)
                      .toSet();
                  final availableStudents = data.students
                      .where(
                        (student) =>
                            student.status == 'active' &&
                            !enrolledIds.contains(student.id),
                      )
                      .toList();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: selectedClass.id,
                        decoration: const InputDecoration(
                          labelText: '수업',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          for (final classRoom in data.classes)
                            DropdownMenuItem(
                              value: classRoom.id,
                              child: Text(classRoom.name),
                            ),
                        ],
                        onChanged: _saving
                            ? null
                            : (classId) {
                                setState(() {
                                  _selectedClassId = classId;
                                  _dataFuture = _loadData();
                                });
                              },
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '미등록 학생',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final student in availableStudents)
                            Draggable<ManagedStudent>(
                              data: student,
                              feedback: Material(
                                color: Colors.transparent,
                                child: Chip(label: Text(student.name)),
                              ),
                              childWhenDragging: Opacity(
                                opacity: 0.35,
                                child: Chip(label: Text(student.name)),
                              ),
                              child: Chip(label: Text(student.name)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '등록 학생',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: DragTarget<ManagedStudent>(
                          onAcceptWithDetails: (details) {
                            if (_saving) return;
                            final nextIds = [
                              ...data.enrolled.map((student) => student.id),
                              details.data.id,
                            ];
                            _saveEnrollment(nextIds);
                          },
                          builder: (context, candidates, rejected) {
                            return DecoratedBox(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: candidates.isEmpty
                                      ? const Color(0xFFE3E7EB)
                                      : Theme.of(context).colorScheme.primary,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: data.enrolled.isEmpty
                                  ? const Center(child: Text('학생을 이 영역에 놓아 등록'))
                                  : ListView.builder(
                                      itemCount: data.enrolled.length,
                                      itemBuilder: (context, index) {
                                        final student = data.enrolled[index];
                                        return ListTile(
                                          dense: true,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 8,
                                              ),
                                          leading: const Icon(Icons.person),
                                          title: Text(student.name),
                                          subtitle: Text(student.code),
                                          trailing: IconButton(
                                            tooltip: '제외',
                                            icon: const Icon(
                                              Icons.remove_circle_outline,
                                            ),
                                            onPressed: _saving
                                                ? null
                                                : () {
                                                    final nextIds = data
                                                        .enrolled
                                                        .where(
                                                          (item) =>
                                                              item.id !=
                                                              student.id,
                                                        )
                                                        .map((item) => item.id)
                                                        .toList();
                                                    _saveEnrollment(nextIds);
                                                  },
                                          ),
                                        );
                                      },
                                    ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EnrollmentData {
  const _EnrollmentData({
    required this.classes,
    required this.students,
    required this.enrolled,
  });

  final List<ManagedClass> classes;
  final List<ManagedStudent> students;
  final List<ManagedStudent> enrolled;
}

class _AdminDashboardPanel extends StatefulWidget {
  const _AdminDashboardPanel({required this.service});

  final AdminManagementService service;

  @override
  State<_AdminDashboardPanel> createState() => _AdminDashboardPanelState();
}

class _AdminDashboardPanelState extends State<_AdminDashboardPanel> {
  late Future<_AdminDashboardData> _dataFuture;
  String? _selectedTeacherId;
  String? _selectedStudyRoomId;

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadData();
  }

  Future<_AdminDashboardData> _loadData() async {
    final teachers = await widget.service.fetchTeachers();
    final teacherId = _selectedTeacherId ?? teachers.firstOrNull?.id;
    final studyRooms = teacherId == null
        ? const <StudyRoomSummary>[]
        : await widget.service.fetchTeacherStudyRooms(teacherId);
    final studyRoomId = _selectedStudyRoomId ?? studyRooms.firstOrNull?.id;
    final selectedStudyRoomBelongs = studyRooms.any(
      (studyRoom) => studyRoom.id == studyRoomId,
    );
    final effectiveStudyRoomId = selectedStudyRoomBelongs
        ? studyRoomId
        : studyRooms.firstOrNull?.id;
    final students = effectiveStudyRoomId == null
        ? const <ManagedStudent>[]
        : await widget.service.fetchStudyRoomStudents(effectiveStudyRoomId);

    _selectedTeacherId = teacherId;
    _selectedStudyRoomId = effectiveStudyRoomId;
    return _AdminDashboardData(
      teachers: teachers,
      studyRooms: studyRooms,
      students: students,
    );
  }

  void _selectTeacher(String teacherId) {
    setState(() {
      _selectedTeacherId = teacherId;
      _selectedStudyRoomId = null;
      _dataFuture = _loadData();
    });
  }

  void _selectStudyRoom(String studyRoomId) {
    setState(() {
      _selectedStudyRoomId = studyRoomId;
      _dataFuture = _loadData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_AdminDashboardData>(
      future: _dataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _TeacherHomeError(message: snapshot.error.toString());
        }
        final data = snapshot.requireData;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _AdminTeacherListPanel(
                teachers: data.teachers,
                selectedTeacherId: _selectedTeacherId,
                onSelected: _selectTeacher,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _AdminStudyRoomListPanel(
                studyRooms: data.studyRooms,
                selectedStudyRoomId: _selectedStudyRoomId,
                onSelected: _selectStudyRoom,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(child: _AdminStudentListPanel(students: data.students)),
          ],
        );
      },
    );
  }
}

class _AdminDashboardData {
  const _AdminDashboardData({
    required this.teachers,
    required this.studyRooms,
    required this.students,
  });

  final List<AdminTeacherSummary> teachers;
  final List<StudyRoomSummary> studyRooms;
  final List<ManagedStudent> students;
}

class _AdminTeacherListPanel extends StatelessWidget {
  const _AdminTeacherListPanel({
    required this.teachers,
    required this.selectedTeacherId,
    required this.onSelected,
  });

  final List<AdminTeacherSummary> teachers;
  final String? selectedTeacherId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('선생님 목록', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Expanded(
              child: teachers.isEmpty
                  ? const Center(child: Text('등록된 선생님이 없습니다.'))
                  : ListView.builder(
                      itemCount: teachers.length,
                      itemBuilder: (context, index) {
                        final teacher = teachers[index];
                        return ListTile(
                          selected: teacher.id == selectedTeacherId,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            teacher.role == 'admin'
                                ? Icons.admin_panel_settings_outlined
                                : Icons.account_circle_outlined,
                          ),
                          title: Text(teacher.name),
                          subtitle: Text(
                            [
                              teacher.email ?? '이메일 없음',
                              teacher.role == 'admin' ? '관리자' : '선생님',
                              _formatAuditTime(teacher.createdAt),
                            ].join(' · '),
                          ),
                          onTap: () => onSelected(teacher.id),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminStudyRoomListPanel extends StatelessWidget {
  const _AdminStudyRoomListPanel({
    required this.studyRooms,
    required this.selectedStudyRoomId,
    required this.onSelected,
  });

  final List<StudyRoomSummary> studyRooms;
  final String? selectedStudyRoomId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('공부방 목록', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Expanded(
              child: studyRooms.isEmpty
                  ? const Center(child: Text('선택한 선생님의 공부방이 없습니다.'))
                  : ListView.builder(
                      itemCount: studyRooms.length,
                      itemBuilder: (context, index) {
                        final studyRoom = studyRooms[index];
                        return ListTile(
                          selected: studyRoom.id == selectedStudyRoomId,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.meeting_room_outlined),
                          title: Text(studyRoom.name),
                          subtitle: Text(studyRoom.description ?? '설명 없음'),
                          onTap: () => onSelected(studyRoom.id),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminStudentListPanel extends StatelessWidget {
  const _AdminStudentListPanel({required this.students});

  final List<ManagedStudent> students;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('학생 목록', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Expanded(
              child: students.isEmpty
                  ? const Center(child: Text('선택한 공부방에 학생이 없습니다.'))
                  : ListView.builder(
                      itemCount: students.length,
                      itemBuilder: (context, index) {
                        final student = students[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.person_outline),
                          title: Text(student.name),
                          subtitle: Text(
                            '${student.code} · ${_studentStatusLabel(student.status)}',
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StudentManagementPanel extends StatefulWidget {
  const _StudentManagementPanel({
    required this.studyRoom,
    required this.service,
  });

  final StudyRoomSummary studyRoom;
  final StudentManagementService service;

  @override
  State<_StudentManagementPanel> createState() =>
      _StudentManagementPanelState();
}

class _StudentManagementPanelState extends State<_StudentManagementPanel> {
  late Future<List<ManagedStudent>> _studentsFuture;
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _pinController = TextEditingController();
  String? _errorText;
  var _submitting = false;
  String? _processingStudentId;

  @override
  void initState() {
    super.initState();
    _studentsFuture = widget.service.fetchStudents(widget.studyRoom.id);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _createStudent() async {
    final name = _nameController.text.trim();
    final code = _codeController.text.trim();
    final pin = _pinController.text.trim();
    if (name.length < 2 || code.isEmpty || !RegExp(r'^\d{6}$').hasMatch(pin)) {
      setState(() => _errorText = '학생 이름, 학생번호, 숫자 6자리 비밀번호를 입력해 주세요.');
      return;
    }

    setState(() {
      _errorText = null;
      _submitting = true;
    });
    try {
      await widget.service.createStudent(
        studyRoomId: widget.studyRoom.id,
        name: name,
        code: code,
        pin: pin,
      );
      _nameController.clear();
      _codeController.clear();
      _pinController.clear();
      if (mounted) {
        setState(() {
          _studentsFuture = widget.service.fetchStudents(widget.studyRoom.id);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _errorText = '학생 등록에 실패했습니다.');
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _refreshStudents() async {
    setState(() {
      _studentsFuture = widget.service.fetchStudents(widget.studyRoom.id);
    });
  }

  Future<void> _editStudent(ManagedStudent student) async {
    final result = await showDialog<_StudentEditResult>(
      context: context,
      builder: (context) => _StudentEditDialog(student: student),
    );
    if (result == null) return;

    setState(() => _processingStudentId = student.id);
    try {
      await widget.service.updateStudent(
        studentId: student.id,
        name: result.name,
        code: result.code,
        status: result.status,
      );
      if (mounted) {
        await _refreshStudents();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('학생 수정에 실패했습니다.')));
      }
    } finally {
      if (mounted) {
        setState(() => _processingStudentId = null);
      }
    }
  }

  Future<void> _resetPin(ManagedStudent student) async {
    final pin = await showDialog<String>(
      context: context,
      builder: (context) => _StudentPinResetDialog(studentName: student.name),
    );
    if (pin == null) return;

    setState(() => _processingStudentId = student.id);
    try {
      await widget.service.resetStudentPin(studentId: student.id, pin: pin);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${student.name} 비밀번호를 리셋했습니다.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('비밀번호 리셋에 실패했습니다.')));
      }
    } finally {
      if (mounted) {
        setState(() => _processingStudentId = null);
      }
    }
  }

  Future<void> _deleteStudent(ManagedStudent student) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('학생 삭제'),
        content: Text('${student.name} 학생을 삭제 처리할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _processingStudentId = student.id);
    try {
      await widget.service.deleteStudent(student.id);
      if (mounted) {
        await _refreshStudents();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('학생 삭제 처리에 실패했습니다.')));
      }
    } finally {
      if (mounted) {
        setState(() => _processingStudentId = null);
      }
    }
  }

  Future<void> _manageGuardians(ManagedStudent student) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) =>
          _StudentGuardiansDialog(student: student, service: widget.service),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${student.name} 보호자 정보를 저장했습니다.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('학생 관리', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(widget.studyRoom.name),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 120,
                  child: TextField(
                    controller: _nameController,
                    enabled: !_submitting,
                    decoration: const InputDecoration(
                      labelText: '학생명',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(
                  width: 120,
                  child: TextField(
                    controller: _codeController,
                    enabled: !_submitting,
                    decoration: const InputDecoration(
                      labelText: '학생번호',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(
                  width: 150,
                  child: TextField(
                    controller: _pinController,
                    enabled: !_submitting,
                    obscureText: true,
                    maxLength: 6,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: '출결 비밀번호',
                      errorText: _errorText,
                      border: const OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _submitting ? null : _createStudent(),
                  ),
                ),
                FilledButton.icon(
                  onPressed: _submitting ? null : _createStudent,
                  icon: const Icon(Icons.person_add_alt_1),
                  label: Text(_submitting ? '등록 중' : '등록'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: FutureBuilder<List<ManagedStudent>>(
                future: _studentsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Text('학생 목록을 불러오지 못했습니다. ${snapshot.error}');
                  }
                  final students = snapshot.data ?? const <ManagedStudent>[];
                  if (students.isEmpty) {
                    return const Center(child: Text('등록된 학생이 없습니다.'));
                  }
                  return ListView.builder(
                    itemCount: students.length,
                    itemBuilder: (context, index) {
                      final student = students[index];
                      final processing = _processingStudentId == student.id;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.person_outline),
                        title: Text(student.name),
                        subtitle: Text(
                          '${student.code} · ${_studentStatusLabel(student.status)}',
                        ),
                        trailing: processing
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : PopupMenuButton<_StudentAction>(
                                tooltip: '학생 작업',
                                icon: const Icon(Icons.more_vert),
                                onSelected: (action) {
                                  switch (action) {
                                    case _StudentAction.edit:
                                      _editStudent(student);
                                    case _StudentAction.resetPin:
                                      _resetPin(student);
                                    case _StudentAction.guardians:
                                      _manageGuardians(student);
                                    case _StudentAction.delete:
                                      _deleteStudent(student);
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: _StudentAction.edit,
                                    child: ListTile(
                                      leading: Icon(Icons.edit_outlined),
                                      title: Text('수정'),
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: _StudentAction.resetPin,
                                    child: ListTile(
                                      leading: Icon(Icons.password_outlined),
                                      title: Text('비밀번호 리셋'),
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: _StudentAction.guardians,
                                    child: ListTile(
                                      leading: Icon(
                                        Icons.contact_phone_outlined,
                                      ),
                                      title: Text('보호자 관리'),
                                    ),
                                  ),
                                  if (student.status != 'left')
                                    const PopupMenuItem(
                                      value: _StudentAction.delete,
                                      child: ListTile(
                                        leading: Icon(Icons.delete_outline),
                                        title: Text('삭제'),
                                      ),
                                    ),
                                ],
                              ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _StudentAction { edit, resetPin, guardians, delete }

class _StudentEditResult {
  const _StudentEditResult({
    required this.name,
    required this.code,
    required this.status,
  });

  final String name;
  final String code;
  final String status;
}

class _StudentEditDialog extends StatefulWidget {
  const _StudentEditDialog({required this.student});

  final ManagedStudent student;

  @override
  State<_StudentEditDialog> createState() => _StudentEditDialogState();
}

class _StudentEditDialogState extends State<_StudentEditDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _codeController;
  late String _status;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.student.name);
    _codeController = TextEditingController(text: widget.student.code);
    _status = widget.student.status;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    final code = _codeController.text.trim();
    if (name.length < 2 || code.isEmpty) {
      setState(() => _errorText = '학생 이름과 학생번호를 입력해 주세요.');
      return;
    }
    Navigator.of(
      context,
    ).pop(_StudentEditResult(name: name, code: code, status: _status));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('학생 수정'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '학생명',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _codeController,
              decoration: InputDecoration(
                labelText: '학생번호',
                errorText: _errorText,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: const InputDecoration(
                labelText: '상태',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'active', child: Text('재원')),
                DropdownMenuItem(value: 'paused', child: Text('일시중지')),
                DropdownMenuItem(value: 'left', child: Text('퇴원')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _status = value);
                }
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(onPressed: _submit, child: const Text('저장')),
      ],
    );
  }
}

class _StudentPinResetDialog extends StatefulWidget {
  const _StudentPinResetDialog({required this.studentName});

  final String studentName;

  @override
  State<_StudentPinResetDialog> createState() => _StudentPinResetDialogState();
}

class _StudentPinResetDialogState extends State<_StudentPinResetDialog> {
  final _pinController = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  void _submit() {
    final pin = _pinController.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(pin)) {
      setState(() => _errorText = '숫자 6자리를 입력해 주세요.');
      return;
    }
    Navigator.of(context).pop(pin);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${widget.studentName} 비밀번호 리셋'),
      content: SizedBox(
        width: 280,
        child: TextField(
          controller: _pinController,
          obscureText: true,
          maxLength: 6,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: '새 출결 비밀번호',
            errorText: _errorText,
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(onPressed: _submit, child: const Text('리셋')),
      ],
    );
  }
}

class _GuardianDraft {
  _GuardianDraft({
    required this.id,
    required this.name,
    required this.phone,
    required this.relationship,
    required this.kakaoOptIn,
    required this.primaryContact,
  });

  factory _GuardianDraft.fromGuardian(StudentGuardian guardian) {
    return _GuardianDraft(
      id: guardian.id,
      name: guardian.name,
      phone: guardian.phone,
      relationship: guardian.relationship,
      kakaoOptIn: guardian.kakaoOptIn,
      primaryContact: guardian.primaryContact,
    );
  }

  String id;
  String name;
  String phone;
  String relationship;
  bool kakaoOptIn;
  bool primaryContact;

  StudentGuardian toGuardian() {
    return StudentGuardian(
      id: id,
      name: name.trim(),
      phone: phone.trim(),
      relationship: relationship.trim(),
      kakaoOptIn: kakaoOptIn,
      primaryContact: primaryContact,
    );
  }
}

class _StudentGuardiansDialog extends StatefulWidget {
  const _StudentGuardiansDialog({required this.student, required this.service});

  final ManagedStudent student;
  final StudentManagementService service;

  @override
  State<_StudentGuardiansDialog> createState() =>
      _StudentGuardiansDialogState();
}

class _StudentGuardiansDialogState extends State<_StudentGuardiansDialog> {
  late Future<List<StudentGuardian>> _guardiansFuture;
  final _drafts = <_GuardianDraft>[];
  String? _errorText;
  var _loaded = false;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    _guardiansFuture = widget.service.fetchGuardians(widget.student.id);
  }

  void _hydrate(List<StudentGuardian> guardians) {
    if (_loaded) return;
    _drafts
      ..clear()
      ..addAll(guardians.map(_GuardianDraft.fromGuardian));
    _loaded = true;
  }

  void _addGuardian() {
    setState(() {
      _drafts.add(
        _GuardianDraft(
          id: '',
          name: '',
          phone: '',
          relationship: '',
          kakaoOptIn: true,
          primaryContact: _drafts.isEmpty,
        ),
      );
    });
  }

  Future<void> _save() async {
    final guardians = _drafts.map((draft) => draft.toGuardian()).toList();
    if (guardians.any((guardian) => guardian.phone.trim().length < 7)) {
      setState(() => _errorText = '보호자 전화번호를 입력해 주세요.');
      return;
    }
    if (guardians.where((guardian) => guardian.primaryContact).length > 1) {
      setState(() => _errorText = '대표 연락처는 한 명만 선택해 주세요.');
      return;
    }

    setState(() {
      _errorText = null;
      _saving = true;
    });
    try {
      await widget.service.saveGuardians(
        studentId: widget.student.id,
        guardians: guardians,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) setState(() => _errorText = '보호자 정보 저장에 실패했습니다.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${widget.student.name} 보호자 관리'),
      content: SizedBox(
        width: 560,
        child: FutureBuilder<List<StudentGuardian>>(
          future: _guardiansFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const SizedBox(
                height: 180,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return Text('보호자 정보를 불러오지 못했습니다. ${snapshot.error}');
            }
            _hydrate(snapshot.data ?? const <StudentGuardian>[]);
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_errorText != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      _errorText!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 360),
                  child: _drafts.isEmpty
                      ? const Center(child: Text('등록된 보호자가 없습니다.'))
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: _drafts.length,
                          itemBuilder: (context, index) {
                            final draft = _drafts[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: const Color(0xFFE3E7EB),
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: TextFormField(
                                              initialValue: draft.name,
                                              decoration: const InputDecoration(
                                                labelText: '보호자명',
                                                border: OutlineInputBorder(),
                                              ),
                                              onChanged: (value) =>
                                                  draft.name = value,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: TextFormField(
                                              initialValue: draft.phone,
                                              keyboardType: TextInputType.phone,
                                              decoration: const InputDecoration(
                                                labelText: '전화번호',
                                                border: OutlineInputBorder(),
                                              ),
                                              onChanged: (value) =>
                                                  draft.phone = value,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: TextFormField(
                                              initialValue: draft.relationship,
                                              decoration: const InputDecoration(
                                                labelText: '관계',
                                                border: OutlineInputBorder(),
                                              ),
                                              onChanged: (value) =>
                                                  draft.relationship = value,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          FilterChip(
                                            label: const Text('카카오 수신'),
                                            selected: draft.kakaoOptIn,
                                            onSelected: (selected) {
                                              setState(() {
                                                draft.kakaoOptIn = selected;
                                              });
                                            },
                                          ),
                                          const SizedBox(width: 8),
                                          FilterChip(
                                            label: const Text('대표'),
                                            selected: draft.primaryContact,
                                            onSelected: (selected) {
                                              setState(() {
                                                for (final item in _drafts) {
                                                  item.primaryContact = false;
                                                }
                                                draft.primaryContact = selected;
                                              });
                                            },
                                          ),
                                          IconButton(
                                            tooltip: '삭제',
                                            icon: const Icon(
                                              Icons.delete_outline,
                                            ),
                                            onPressed: () {
                                              setState(
                                                () => _drafts.removeAt(index),
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _saving ? null : _addGuardian,
                    icon: const Icon(Icons.add),
                    label: const Text('보호자 추가'),
                  ),
                ),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? '저장 중' : '저장'),
        ),
      ],
    );
  }
}

class _EmptyStudyRoomPanel extends StatelessWidget {
  const _EmptyStudyRoomPanel();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('학생 관리', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            const Text('공부방을 먼저 생성해 주세요.'),
          ],
        ),
      ),
    );
  }
}

class _PaymentManagementPanel extends StatefulWidget {
  const _PaymentManagementPanel({
    required this.studyRoom,
    required this.service,
  });

  final StudyRoomSummary studyRoom;
  final PaymentManagementService service;

  @override
  State<_PaymentManagementPanel> createState() =>
      _PaymentManagementPanelState();
}

class _PaymentManagementPanelState extends State<_PaymentManagementPanel> {
  late Future<_PaymentPanelData> _dataFuture;
  final _nameController = TextEditingController();
  final _dueDateController = TextEditingController();
  final _amountController = TextEditingController(text: '0');
  String? _selectedPeriodId;
  String? _errorText;
  var _submitting = false;
  String? _processingStatusId;
  var _notifying = false;

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dueDateController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<_PaymentPanelData> _loadData() async {
    final periods = await widget.service.fetchPeriods(widget.studyRoom.id);
    final periodId = _selectedPeriodId ?? periods.firstOrNull?.id;
    final effectivePeriodId = periods.any((period) => period.id == periodId)
        ? periodId
        : periods.firstOrNull?.id;
    final statusData = effectivePeriodId == null
        ? null
        : await widget.service.fetchStatuses(effectivePeriodId);
    _selectedPeriodId = effectivePeriodId;
    return _PaymentPanelData(periods: periods, statusData: statusData);
  }

  Future<void> _refresh() async {
    setState(() => _dataFuture = _loadData());
  }

  Future<void> _createPeriod() async {
    final name = _nameController.text.trim();
    final dueDate = _dueDateController.text.trim();
    final amount = int.tryParse(_amountController.text.trim()) ?? -1;
    if (name.length < 2 || !_datePattern.hasMatch(dueDate) || amount < 0) {
      setState(() => _errorText = '기간명, 마감일, 금액을 확인해 주세요.');
      return;
    }

    setState(() {
      _errorText = null;
      _submitting = true;
    });
    try {
      final period = await widget.service.createPeriod(
        studyRoomId: widget.studyRoom.id,
        name: name,
        dueDate: dueDate,
        amount: amount,
      );
      _nameController.clear();
      _dueDateController.clear();
      if (mounted) {
        setState(() {
          _selectedPeriodId = period.id;
          _dataFuture = _loadData();
        });
      }
    } catch (_) {
      if (mounted) setState(() => _errorText = '납부 기간 생성에 실패했습니다.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _updateStatus(PaymentStatusSummary status, String next) async {
    setState(() => _processingStatusId = status.id);
    try {
      await widget.service.updateStatus(
        paymentStatusId: status.id,
        status: next,
        note: '',
      );
      if (mounted) await _refresh();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('납부 상태 변경에 실패했습니다.')));
      }
    } finally {
      if (mounted) setState(() => _processingStatusId = null);
    }
  }

  Future<void> _notifyUnpaid() async {
    final periodId = _selectedPeriodId;
    if (periodId == null) return;
    setState(() => _notifying = true);
    try {
      final count = await widget.service.notifyUnpaid(periodId);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('미납 안내 $count건을 요청했습니다.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('미납 안내 요청에 실패했습니다.')));
      }
    } finally {
      if (mounted) setState(() => _notifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('납부 관리', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                SizedBox(
                  width: 116,
                  child: TextField(
                    controller: _nameController,
                    enabled: !_submitting,
                    decoration: const InputDecoration(
                      labelText: '기간명',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(
                  width: 126,
                  child: TextField(
                    controller: _dueDateController,
                    enabled: !_submitting,
                    decoration: InputDecoration(
                      labelText: '마감일',
                      hintText: '2026-07-31',
                      errorText: _errorText,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(
                  width: 96,
                  child: TextField(
                    controller: _amountController,
                    enabled: !_submitting,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '금액',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: _submitting ? null : _createPeriod,
                  icon: const Icon(Icons.add),
                  label: Text(_submitting ? '생성 중' : '생성'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: FutureBuilder<_PaymentPanelData>(
                future: _dataFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Text('납부 정보를 불러오지 못했습니다. ${snapshot.error}');
                  }
                  final data = snapshot.requireData;
                  if (data.periods.isEmpty) {
                    return const Center(child: Text('등록된 납부 기간이 없습니다.'));
                  }
                  final statuses =
                      data.statusData?.statuses ??
                      const <PaymentStatusSummary>[];
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _selectedPeriodId,
                              decoration: const InputDecoration(
                                labelText: '납부 기간',
                                border: OutlineInputBorder(),
                              ),
                              items: [
                                for (final period in data.periods)
                                  DropdownMenuItem(
                                    value: period.id,
                                    child: Text(
                                      '${period.name} · ${period.dueDate}',
                                    ),
                                  ),
                              ],
                              onChanged: (periodId) {
                                if (periodId == null) return;
                                setState(() {
                                  _selectedPeriodId = periodId;
                                  _dataFuture = _loadData();
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filledTonal(
                            tooltip: '미납 안내 요청',
                            onPressed: _notifying ? null : _notifyUnpaid,
                            icon: _notifying
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.sms_outlined),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: statuses.isEmpty
                            ? const Center(child: Text('납부 대상 학생이 없습니다.'))
                            : ListView.builder(
                                itemCount: statuses.length,
                                itemBuilder: (context, index) {
                                  final status = statuses[index];
                                  final processing =
                                      _processingStatusId == status.id;
                                  return ListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    leading: Icon(
                                      _paymentStatusIcon(status.status),
                                    ),
                                    title: Text(status.studentName),
                                    subtitle: Text(
                                      '${status.studentCode} · ${status.amount}원 · ${_paymentStatusLabel(status.status)}',
                                    ),
                                    trailing: processing
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : PopupMenuButton<String>(
                                            tooltip: '납부 상태 변경',
                                            icon: const Icon(Icons.more_vert),
                                            onSelected: (next) =>
                                                _updateStatus(status, next),
                                            itemBuilder: (context) => const [
                                              PopupMenuItem(
                                                value: 'unpaid',
                                                child: Text('미납'),
                                              ),
                                              PopupMenuItem(
                                                value: 'partial',
                                                child: Text('부분납'),
                                              ),
                                              PopupMenuItem(
                                                value: 'paid',
                                                child: Text('완납'),
                                              ),
                                              PopupMenuItem(
                                                value: 'exempt',
                                                child: Text('면제'),
                                              ),
                                            ],
                                          ),
                                  );
                                },
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentPanelData {
  const _PaymentPanelData({required this.periods, required this.statusData});

  final List<PaymentPeriodSummary> periods;
  final PaymentStatusData? statusData;
}

class _SampleAuditPanel extends StatelessWidget {
  const _SampleAuditPanel();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('사용 히스토리', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: const [
                FilterChip(label: Text('전체'), selected: true, onSelected: null),
                FilterChip(
                  label: Text('학생'),
                  selected: false,
                  onSelected: null,
                ),
                FilterChip(
                  label: Text('수업'),
                  selected: false,
                  onSelected: null,
                ),
                FilterChip(
                  label: Text('카카오'),
                  selected: false,
                  onSelected: null,
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final log in sampleAuditLogs)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(log.title),
                subtitle: Text('${log.type} · ${log.actor} · ${log.time}'),
              ),
          ],
        ),
      ),
    );
  }
}

class _AuditHistoryPanel extends StatefulWidget {
  const _AuditHistoryPanel({required this.studyRoom, required this.service});

  final StudyRoomSummary studyRoom;
  final AuditLogService service;

  @override
  State<_AuditHistoryPanel> createState() => _AuditHistoryPanelState();
}

class _AuditHistoryPanelState extends State<_AuditHistoryPanel> {
  var _category = AuditLogCategory.all;
  late Future<List<AppAuditLog>> _logsFuture;

  @override
  void initState() {
    super.initState();
    _logsFuture = _fetchLogs();
  }

  Future<List<AppAuditLog>> _fetchLogs() {
    return widget.service.fetchLogs(
      studyRoomId: widget.studyRoom.id,
      category: _category,
    );
  }

  void _setCategory(AuditLogCategory category) {
    setState(() {
      _category = category;
      _logsFuture = _fetchLogs();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('사용 히스토리', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(widget.studyRoom.name),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (final category in AuditLogCategory.values)
                  FilterChip(
                    label: Text(category.label),
                    selected: _category == category,
                    onSelected: (_) => _setCategory(category),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: FutureBuilder<List<AppAuditLog>>(
                future: _logsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Text('히스토리를 불러오지 못했습니다. ${snapshot.error}');
                  }
                  final logs = snapshot.data ?? const <AppAuditLog>[];
                  if (logs.isEmpty) {
                    return const Center(child: Text('표시할 히스토리가 없습니다.'));
                  }
                  return ListView.builder(
                    itemCount: logs.length,
                    itemBuilder: (context, index) {
                      final log = logs[index];
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(_auditIcon(log.category)),
                        title: Text(log.title),
                        subtitle: Text(
                          [
                            _auditCategoryLabel(log.category),
                            log.actor,
                            _formatAuditTime(log.createdAt),
                            if (log.summary != null && log.summary!.isNotEmpty)
                              log.summary!,
                          ].join(' · '),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const _dayLabels = ['일', '월', '화', '수', '목', '금', '토'];
final _datePattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');
final _timePattern = RegExp(r'^\d{2}:\d{2}$');

String _classKindLabel(String classKind) {
  return switch (classKind) {
    'makeup' => '보강',
    'extra' => '추가',
    _ => '기본',
  };
}

String _studentStatusLabel(String status) {
  return switch (status) {
    'paused' => '일시중지',
    'left' => '퇴원',
    _ => '재원',
  };
}

String _paymentStatusLabel(String status) {
  return switch (status) {
    'paid' => '완납',
    'partial' => '부분납',
    'exempt' => '면제',
    'refunded' => '환불',
    _ => '미납',
  };
}

IconData _paymentStatusIcon(String status) {
  return switch (status) {
    'paid' => Icons.check_circle_outline,
    'partial' => Icons.timelapse_outlined,
    'exempt' => Icons.remove_circle_outline,
    _ => Icons.pending_outlined,
  };
}

IconData _auditIcon(String category) {
  return switch (category) {
    'student' => Icons.person_outline,
    'kakao' => Icons.sms_outlined,
    _ => Icons.school_outlined,
  };
}

String _auditCategoryLabel(String category) {
  return switch (category) {
    'student' => '학생',
    'kakao' => '카카오',
    _ => '수업',
  };
}

String _formatAuditTime(DateTime? value) {
  if (value == null) return '-';
  final local = value.toLocal();
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  return '${twoDigits(local.month)}/${twoDigits(local.day)} '
      '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
}
