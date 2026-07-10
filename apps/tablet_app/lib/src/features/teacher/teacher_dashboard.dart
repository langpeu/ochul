import 'package:flutter/material.dart';

import '../../core/app_config.dart';
import '../../core/edge_function_client.dart';
import '../../core/teacher_gate.dart';
import '../../models/sample_data.dart';
import 'class_management_service.dart';
import 'enrollment_management_service.dart';
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
  });

  final AppConfig config;
  final TeacherHomeService homeService;
  final StudentManagementService studentService;
  final ClassManagementService classService;
  final EnrollmentManagementService enrollmentService;

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
          const Expanded(child: _AuditPanel()),
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
            const Expanded(child: _AuditPanel()),
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
                      .where((student) => !enrolledIds.contains(student.id))
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
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.person_outline),
                        title: Text(student.name),
                        subtitle: Text('${student.code} · ${student.status}'),
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

class _AuditPanel extends StatelessWidget {
  const _AuditPanel();

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
