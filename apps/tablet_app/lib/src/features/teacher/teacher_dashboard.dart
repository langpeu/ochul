import 'package:flutter/material.dart';

import '../../core/app_config.dart';
import '../../core/edge_function_client.dart';
import '../../core/teacher_gate.dart';
import '../../core/teacher_pin_store.dart';
import '../../models/sample_data.dart';
import 'admin_management_service.dart';
import 'audit_log_service.dart';
import 'attendance_management_service.dart';
import 'class_management_service.dart';
import 'classroom_layout_service.dart';
import 'enrollment_management_service.dart';
import 'notification_log_service.dart';
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
  final _pinStore = const TeacherPinStore();
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
  final _notificationLogService = const NotificationLogService(
    edgeClient: EdgeFunctionClient(),
  );
  final _attendanceManagementService = const AttendanceManagementService(
    edgeClient: EdgeFunctionClient(),
  );
  final _classroomLayoutService = const ClassroomLayoutService(
    edgeClient: EdgeFunctionClient(),
  );

  Future<void> _unlock() async {
    TeacherGateResult result;
    try {
      result = await _gate.authenticate();
    } catch (_) {
      result = TeacherGateResult.fallbackRequired;
    }
    if (!mounted) {
      return;
    }
    if (result == TeacherGateResult.authenticated) {
      setState(() => _unlocked = true);
      return;
    }
    await _unlockWithAdminPin();
  }

  Future<void> _unlockWithAdminPin() async {
    final hasPin = await _pinStore.hasPin();
    if (!mounted) {
      return;
    }

    if (!hasPin) {
      final newPin = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (context) => const _TeacherAdminPinSetupDialog(),
      );
      if (newPin == null) {
        _showGateFailedMessage('선생님 모드 관리자 PIN 설정이 필요합니다.');
        return;
      }
      await _pinStore.savePin(newPin);
      if (!mounted) {
        return;
      }
      setState(() => _unlocked = true);
      return;
    }

    final pin = await showDialog<String>(
      context: context,
      builder: (context) => const _TeacherAdminPinVerifyDialog(),
    );
    if (pin == null) {
      _showGateFailedMessage('기기 인증 또는 관리자 PIN 인증이 필요합니다.');
      return;
    }
    final verified = await _pinStore.verifyPin(pin);
    if (!mounted) {
      return;
    }
    setState(() => _unlocked = verified);
    if (!verified) {
      _showGateFailedMessage('관리자 PIN이 일치하지 않습니다.');
    }
  }

  void _showGateFailedMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
              notificationLogService: _notificationLogService,
              attendanceManagementService: _attendanceManagementService,
              classroomLayoutService: _classroomLayoutService,
            ),
          ),
        ],
      ),
    );
  }
}

class _TeacherAdminPinSetupDialog extends StatefulWidget {
  const _TeacherAdminPinSetupDialog();

  @override
  State<_TeacherAdminPinSetupDialog> createState() =>
      _TeacherAdminPinSetupDialogState();
}

class _TeacherAdminPinSetupDialogState
    extends State<_TeacherAdminPinSetupDialog> {
  final _pinController = TextEditingController();
  final _confirmController = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _pinController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _submit() {
    final pin = _pinController.text.trim();
    final confirm = _confirmController.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(pin)) {
      setState(() => _errorText = '관리자 PIN은 숫자 6자리여야 합니다.');
      return;
    }
    if (pin != confirm) {
      setState(() => _errorText = '확인 PIN이 일치하지 않습니다.');
      return;
    }
    Navigator.of(context).pop(pin);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('관리자 PIN 설정'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _pinController,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 6,
              decoration: const InputDecoration(labelText: '새 관리자 PIN'),
            ),
            TextField(
              controller: _confirmController,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 6,
              decoration: const InputDecoration(labelText: 'PIN 확인'),
              onSubmitted: (_) => _submit(),
            ),
            if (_errorText != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _errorText!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(onPressed: _submit, child: const Text('설정')),
      ],
    );
  }
}

class _TeacherAdminPinVerifyDialog extends StatefulWidget {
  const _TeacherAdminPinVerifyDialog();

  @override
  State<_TeacherAdminPinVerifyDialog> createState() =>
      _TeacherAdminPinVerifyDialogState();
}

class _TeacherAdminPinVerifyDialogState
    extends State<_TeacherAdminPinVerifyDialog> {
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
      setState(() => _errorText = '관리자 PIN은 숫자 6자리여야 합니다.');
      return;
    }
    Navigator.of(context).pop(pin);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('관리자 PIN 입력'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _pinController,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 6,
              decoration: const InputDecoration(labelText: '관리자 PIN'),
              onSubmitted: (_) => _submit(),
            ),
            if (_errorText != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _errorText!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
          ],
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

class _TeacherBoardContent extends StatefulWidget {
  const _TeacherBoardContent({
    required this.config,
    required this.homeService,
    required this.studentService,
    required this.classService,
    required this.enrollmentService,
    required this.auditLogService,
    required this.adminService,
    required this.paymentService,
    required this.notificationLogService,
    required this.attendanceManagementService,
    required this.classroomLayoutService,
  });

  final AppConfig config;
  final TeacherHomeService homeService;
  final StudentManagementService studentService;
  final ClassManagementService classService;
  final EnrollmentManagementService enrollmentService;
  final AuditLogService auditLogService;
  final AdminManagementService adminService;
  final PaymentManagementService paymentService;
  final NotificationLogService notificationLogService;
  final AttendanceManagementService attendanceManagementService;
  final ClassroomLayoutService classroomLayoutService;

  @override
  State<_TeacherBoardContent> createState() => _TeacherBoardContentState();
}

class _TeacherBoardContentState extends State<_TeacherBoardContent> {
  late Future<TeacherHome>? _homeFuture;
  String? _selectedStudyRoomId;

  @override
  void initState() {
    super.initState();
    _homeFuture = widget.config.isSupabaseConfigured
        ? widget.homeService.fetchMe()
        : null;
  }

  void _reloadHome({String? selectedStudyRoomId}) {
    final future = widget.homeService.fetchMe();
    setState(() {
      _selectedStudyRoomId = selectedStudyRoomId ?? _selectedStudyRoomId;
      _homeFuture = future;
    });
  }

  Future<void> _onboard({
    required String teacherName,
    required String studyRoomName,
  }) async {
    final home = await widget.homeService.onboard(
      teacherName: teacherName,
      studyRoomName: studyRoomName,
    );
    if (mounted) {
      setState(() {
        _selectedStudyRoomId = home.studyRooms.firstOrNull?.id;
        _homeFuture = Future.value(home);
      });
    }
  }

  Future<void> _createStudyRoom() async {
    final result = await showDialog<_StudyRoomEditResult>(
      context: context,
      builder: (context) => const _StudyRoomEditDialog(),
    );
    if (result == null) return;

    try {
      final studyRoom = await widget.homeService.createStudyRoom(
        name: result.name,
        description: result.description,
      );
      if (mounted) {
        _reloadHome(selectedStudyRoomId: studyRoom.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${studyRoom.name} 공부방을 만들었습니다.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('공부방 생성에 실패했습니다.')));
      }
    }
  }

  Future<void> _editStudyRoom(StudyRoomSummary studyRoom) async {
    final result = await showDialog<_StudyRoomEditResult>(
      context: context,
      builder: (context) => _StudyRoomEditDialog(studyRoom: studyRoom),
    );
    if (result == null) return;

    try {
      final updated = await widget.homeService.updateStudyRoom(
        studyRoomId: studyRoom.id,
        name: result.name,
        description: result.description,
      );
      if (mounted) {
        _reloadHome(selectedStudyRoomId: updated.id);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${updated.name} 공부방을 수정했습니다.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('공부방 수정에 실패했습니다.')));
      }
    }
  }

  void _selectStudyRoom(String studyRoomId) {
    setState(() => _selectedStudyRoomId = studyRoomId);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.config.isSupabaseConfigured) {
      return Column(
        children: [
          const _StudyRoomSummaryBar(
            teacherName: '홍선생',
            role: 'teacher',
            studyRooms: [
              StudyRoomSummary(
                id: 'sample-room-1',
                name: '홍선생 공부방',
                description: '화면 설계 모드 샘플',
              ),
            ],
            selectedStudyRoomId: 'sample-room-1',
            designMode: true,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _ClassPanel(classes: sampleClasses)),
                const SizedBox(width: 16),
                Expanded(child: _EnrollmentPanel(classes: sampleClasses)),
                const SizedBox(width: 16),
                const Expanded(child: _SampleAuditPanel()),
              ],
            ),
          ),
        ],
      );
    }

    return FutureBuilder<TeacherHome>(
      future: _homeFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
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
        if (home.teacher?.role == 'admin') {
          return Column(
            children: [
              _StudyRoomSummaryBar(
                teacherName: teacher.name,
                role: teacher.role,
                studyRooms: home.studyRooms,
                selectedStudyRoomId: _selectedStudyRoomId,
                designMode: false,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _AdminDashboardPanel(service: widget.adminService),
              ),
            ],
          );
        }
        final selectedStudyRoomBelongs = home.studyRooms.any(
          (studyRoom) => studyRoom.id == _selectedStudyRoomId,
        );
        final studyRoom = selectedStudyRoomBelongs
            ? home.studyRooms.firstWhere(
                (studyRoom) => studyRoom.id == _selectedStudyRoomId,
              )
            : home.studyRooms.firstOrNull;
        if (_selectedStudyRoomId == null && studyRoom != null) {
          _selectedStudyRoomId = studyRoom.id;
        }

        return Column(
          children: [
            _StudyRoomSummaryBar(
              teacherName: teacher.name,
              role: teacher.role,
              studyRooms: home.studyRooms,
              selectedStudyRoomId: studyRoom?.id,
              designMode: false,
              onSelected: _selectStudyRoom,
              onCreate: _createStudyRoom,
              onEdit: studyRoom == null
                  ? null
                  : () => _editStudyRoom(studyRoom),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: studyRoom == null
                          ? const _EmptyClassPanel()
                          : _ClassManagementPanel(
                              key: ValueKey('classes-${studyRoom.id}'),
                              studyRoom: studyRoom,
                              service: widget.classService,
                            ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: studyRoom == null
                          ? const _EmptyStudyRoomPanel()
                          : _StudentManagementPanel(
                              key: ValueKey('students-${studyRoom.id}'),
                              studyRoom: studyRoom,
                              service: widget.studentService,
                            ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: studyRoom == null
                          ? const _EmptyStudyRoomPanel()
                          : Column(
                              children: [
                                Expanded(
                                  child: _EnrollmentManagementPanel(
                                    key: ValueKey('enrollment-${studyRoom.id}'),
                                    studyRoom: studyRoom,
                                    classService: widget.classService,
                                    studentService: widget.studentService,
                                    enrollmentService: widget.enrollmentService,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Expanded(
                                  child: _ClassroomLayoutPanel(
                                    key: ValueKey('layout-${studyRoom.id}'),
                                    studyRoom: studyRoom,
                                    classService: widget.classService,
                                    enrollmentService: widget.enrollmentService,
                                    layoutService:
                                        widget.classroomLayoutService,
                                  ),
                                ),
                              ],
                            ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: studyRoom == null
                          ? const _EmptyStudyRoomPanel()
                          : Column(
                              children: [
                                Expanded(
                                  child: _AttendanceManagementPanel(
                                    service: widget.attendanceManagementService,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Expanded(
                                  child: _PaymentManagementPanel(
                                    key: ValueKey('payments-${studyRoom.id}'),
                                    studyRoom: studyRoom,
                                    service: widget.paymentService,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Expanded(
                                  child: _AuditHistoryPanel(
                                    key: ValueKey('history-${studyRoom.id}'),
                                    studyRoom: studyRoom,
                                    studentService: widget.studentService,
                                    classService: widget.classService,
                                    auditLogService: widget.auditLogService,
                                    notificationLogService:
                                        widget.notificationLogService,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
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
        selectedStudyRoomId: 'sample-room-1',
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
          selectedStudyRoomId: home.studyRooms.firstOrNull?.id,
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
    required this.selectedStudyRoomId,
    required this.designMode,
    this.onSelected,
    this.onCreate,
    this.onEdit,
  });

  final String teacherName;
  final String role;
  final List<StudyRoomSummary> studyRooms;
  final String? selectedStudyRoomId;
  final bool designMode;
  final ValueChanged<String>? onSelected;
  final VoidCallback? onCreate;
  final VoidCallback? onEdit;

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
                    ChoiceChip(
                      avatar: const Icon(Icons.meeting_room_outlined, size: 18),
                      label: Text(studyRoom.name),
                      selected: studyRoom.id == selectedStudyRoomId,
                      onSelected: onSelected == null
                          ? null
                          : (_) => onSelected!(studyRoom.id),
                    ),
                  if (onEdit != null)
                    IconButton(
                      tooltip: '공부방 수정',
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined),
                    ),
                  if (onCreate != null)
                    IconButton.filledTonal(
                      tooltip: '공부방 추가',
                      onPressed: onCreate,
                      icon: const Icon(Icons.add_business_outlined),
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

class _StudyRoomEditResult {
  const _StudyRoomEditResult({required this.name, required this.description});

  final String name;
  final String description;
}

class _StudyRoomEditDialog extends StatefulWidget {
  const _StudyRoomEditDialog({this.studyRoom});

  final StudyRoomSummary? studyRoom;

  @override
  State<_StudyRoomEditDialog> createState() => _StudyRoomEditDialogState();
}

class _StudyRoomEditDialogState extends State<_StudyRoomEditDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.studyRoom?.name ?? '');
    _descriptionController = TextEditingController(
      text: widget.studyRoom?.description ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.length < 2) {
      setState(() => _errorText = '공부방 이름은 2자 이상 입력해 주세요.');
      return;
    }
    Navigator.of(context).pop(
      _StudyRoomEditResult(
        name: name,
        description: _descriptionController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.studyRoom != null;
    return AlertDialog(
      title: Text(editing ? '공부방 수정' : '공부방 추가'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: '공부방 이름',
                errorText: _errorText,
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: '설명',
                border: OutlineInputBorder(),
              ),
              minLines: 2,
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(onPressed: _submit, child: Text(editing ? '저장' : '추가')),
      ],
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
  const _ClassManagementPanel({
    super.key,
    required this.studyRoom,
    required this.service,
  });

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
    final result = await showDialog<_ClassCancelResult>(
      context: context,
      builder: (context) => _ClassCancelDialog(className: classRoom.name),
    );
    if (result == null) return;

    setState(() => _processingClassId = classRoom.id);
    try {
      final count = await widget.service.cancelTodaySession(
        classId: classRoom.id,
        sessionDate: result.sessionDate,
        reason: result.reason,
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
        originalSessionDate: result.originalSessionDate,
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

  Future<void> _rescheduleToday(ManagedClass classRoom) async {
    final result = await showDialog<_ClassTimeChangeResult>(
      context: context,
      builder: (context) => _ClassTimeChangeDialog(className: classRoom.name),
    );
    if (result == null) return;

    setState(() => _processingClassId = classRoom.id);
    try {
      final count = await widget.service.rescheduleTodaySession(
        classId: classRoom.id,
        sessionDate: result.sessionDate,
        startsAt: result.startsAt,
        endsAt: result.endsAt,
        reason: result.reason,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('시간 변경 안내 $count건을 요청했습니다.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('시간 변경에 실패했습니다.')));
      }
    } finally {
      if (mounted) setState(() => _processingClassId = null);
    }
  }

  Future<void> _editClass(ManagedClass classRoom) async {
    final result = await showDialog<_ClassEditResult>(
      context: context,
      builder: (context) => _ClassEditDialog(classRoom: classRoom),
    );
    if (result == null) return;

    setState(() => _processingClassId = classRoom.id);
    try {
      await widget.service.updateClass(
        classId: classRoom.id,
        name: result.name,
        description: result.description,
        classKind: result.classKind,
        startDate: result.startDate,
        endDate: result.endDate,
        dayOfWeeks: result.dayOfWeeks,
        startsAt: result.startsAt,
        endsAt: result.endsAt,
      );
      if (mounted) {
        setState(() {
          _classesFuture = widget.service.fetchClasses(widget.studyRoom.id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${classRoom.name} 수업을 수정했습니다.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('수업 수정에 실패했습니다.')));
      }
    } finally {
      if (mounted) setState(() => _processingClassId = null);
    }
  }

  Future<void> _deleteClass(ManagedClass classRoom) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${classRoom.name} 삭제'),
        content: const Text('수업을 비활성화하고 목록에서 숨깁니다. 기존 출결과 납부 이력은 유지됩니다.'),
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

    setState(() => _processingClassId = classRoom.id);
    try {
      await widget.service.deleteClass(classRoom.id);
      if (mounted) {
        setState(() {
          _classesFuture = widget.service.fetchClasses(widget.studyRoom.id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${classRoom.name} 수업을 삭제했습니다.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('수업 삭제에 실패했습니다.')));
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
                                    case _ClassAction.rescheduleToday:
                                      _rescheduleToday(classRoom);
                                    case _ClassAction.edit:
                                      _editClass(classRoom);
                                    case _ClassAction.delete:
                                      _deleteClass(classRoom);
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
                                      title: Text('회차 휴강'),
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: _ClassAction.createMakeup,
                                    child: ListTile(
                                      leading: Icon(Icons.event_repeat),
                                      title: Text('보강 추가'),
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: _ClassAction.rescheduleToday,
                                    child: ListTile(
                                      leading: Icon(Icons.update),
                                      title: Text('회차 시간 변경'),
                                    ),
                                  ),
                                  PopupMenuDivider(),
                                  PopupMenuItem(
                                    value: _ClassAction.edit,
                                    child: ListTile(
                                      leading: Icon(Icons.edit_outlined),
                                      title: Text('수정'),
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: _ClassAction.delete,
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

enum _ClassAction {
  openAttendance,
  cancelToday,
  createMakeup,
  rescheduleToday,
  edit,
  delete,
}

class _ClassEditResult {
  const _ClassEditResult({
    required this.name,
    required this.description,
    required this.classKind,
    required this.startDate,
    required this.endDate,
    required this.dayOfWeeks,
    required this.startsAt,
    required this.endsAt,
  });

  final String name;
  final String description;
  final String classKind;
  final String startDate;
  final String endDate;
  final List<int> dayOfWeeks;
  final String startsAt;
  final String endsAt;
}

class _ClassEditDialog extends StatefulWidget {
  const _ClassEditDialog({required this.classRoom});

  final ManagedClass classRoom;

  @override
  State<_ClassEditDialog> createState() => _ClassEditDialogState();
}

class _ClassEditDialogState extends State<_ClassEditDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _startDateController;
  late final TextEditingController _endDateController;
  late final TextEditingController _startsAtController;
  late final TextEditingController _endsAtController;
  late final Set<int> _selectedDays;
  late String _classKind;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    final schedules = widget.classRoom.schedules;
    final firstSchedule = schedules.isEmpty ? null : schedules.first;
    _nameController = TextEditingController(text: widget.classRoom.name);
    _descriptionController = TextEditingController(
      text: widget.classRoom.description,
    );
    _startDateController = TextEditingController(
      text: widget.classRoom.startDate,
    );
    _endDateController = TextEditingController(text: widget.classRoom.endDate);
    _startsAtController = TextEditingController(
      text: firstSchedule?.startsAt.isNotEmpty == true
          ? firstSchedule!.startsAt
          : '15:00',
    );
    _endsAtController = TextEditingController(
      text: firstSchedule?.endsAt.isNotEmpty == true
          ? firstSchedule!.endsAt
          : '16:00',
    );
    _selectedDays = {
      for (final schedule in schedules) schedule.dayOfWeek,
      if (schedules.isEmpty) 1,
    };
    _classKind = widget.classRoom.classKind;
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

  void _submit() {
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

    Navigator.of(context).pop(
      _ClassEditResult(
        name: name,
        description: _descriptionController.text.trim(),
        classKind: _classKind,
        startDate: startDate,
        endDate: endDate,
        dayOfWeeks: _selectedDays.toList()..sort(),
        startsAt: startsAt,
        endsAt: endsAt,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${widget.classRoom.name} 수정'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '수업명',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _descriptionController,
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
                      decoration: const InputDecoration(
                        labelText: '시작일',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 130,
                    child: TextField(
                      controller: _endDateController,
                      decoration: const InputDecoration(
                        labelText: '종료일',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 105,
                    child: TextField(
                      controller: _startsAtController,
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
                onSelectionChanged: (selection) {
                  setState(() => _classKind = selection.first);
                },
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: [
                  for (var day = 0; day < _dayLabels.length; day++)
                    FilterChip(
                      label: Text(_dayLabels[day]),
                      selected: _selectedDays.contains(day),
                      onSelected: (selected) {
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
            ],
          ),
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

class _ClassCancelResult {
  const _ClassCancelResult({required this.sessionDate, required this.reason});

  final String sessionDate;
  final String reason;
}

class _ClassCancelDialog extends StatefulWidget {
  const _ClassCancelDialog({required this.className});

  final String className;

  @override
  State<_ClassCancelDialog> createState() => _ClassCancelDialogState();
}

class _ClassCancelDialogState extends State<_ClassCancelDialog> {
  final _dateController = TextEditingController();
  final _reasonController = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _dateController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  void _submit() {
    final sessionDate = _dateController.text.trim();
    if (!_datePattern.hasMatch(sessionDate)) {
      setState(() => _errorText = '휴강 날짜를 확인해 주세요.');
      return;
    }
    Navigator.of(context).pop(
      _ClassCancelResult(
        sessionDate: sessionDate,
        reason: _reasonController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${widget.className} 휴강'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _dateController,
              decoration: InputDecoration(
                labelText: '휴강일',
                hintText: '2026-07-31',
                errorText: _errorText,
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reasonController,
              decoration: const InputDecoration(
                labelText: '휴강 사유',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _submit(),
            ),
          ],
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
    required this.originalSessionDate,
  });

  final String sessionDate;
  final String startsAt;
  final String endsAt;
  final String reason;
  final String originalSessionDate;
}

class _ClassTimeChangeResult {
  const _ClassTimeChangeResult({
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

class _ClassTimeChangeDialog extends StatefulWidget {
  const _ClassTimeChangeDialog({required this.className});

  final String className;

  @override
  State<_ClassTimeChangeDialog> createState() => _ClassTimeChangeDialogState();
}

class _ClassTimeChangeDialogState extends State<_ClassTimeChangeDialog> {
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
    final sessionDate = _dateController.text.trim();
    final startsAt = _startsAtController.text.trim();
    final endsAt = _endsAtController.text.trim();
    if (!_datePattern.hasMatch(sessionDate) ||
        !_timePattern.hasMatch(startsAt) ||
        !_timePattern.hasMatch(endsAt) ||
        startsAt.compareTo(endsAt) >= 0) {
      setState(() => _errorText = '날짜와 시간을 확인해 주세요.');
      return;
    }
    Navigator.of(context).pop(
      _ClassTimeChangeResult(
        sessionDate: sessionDate,
        startsAt: startsAt,
        endsAt: endsAt,
        reason: _reasonController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${widget.className} 시간 변경'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _dateController,
              decoration: const InputDecoration(
                labelText: '변경일',
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
                labelText: '변경 사유',
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
        FilledButton(onPressed: _submit, child: const Text('변경')),
      ],
    );
  }
}

class _MakeupSessionDialog extends StatefulWidget {
  const _MakeupSessionDialog({required this.className});

  final String className;

  @override
  State<_MakeupSessionDialog> createState() => _MakeupSessionDialogState();
}

class _MakeupSessionDialogState extends State<_MakeupSessionDialog> {
  final _dateController = TextEditingController();
  final _originalDateController = TextEditingController();
  final _startsAtController = TextEditingController(text: '15:00');
  final _endsAtController = TextEditingController(text: '16:00');
  final _reasonController = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _dateController.dispose();
    _originalDateController.dispose();
    _startsAtController.dispose();
    _endsAtController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  void _submit() {
    final date = _dateController.text.trim();
    final originalDate = _originalDateController.text.trim();
    final startsAt = _startsAtController.text.trim();
    final endsAt = _endsAtController.text.trim();
    if (!_datePattern.hasMatch(date) ||
        (originalDate.isNotEmpty && !_datePattern.hasMatch(originalDate)) ||
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
        originalSessionDate: originalDate,
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
              controller: _originalDateController,
              decoration: InputDecoration(
                labelText: '연결할 휴강일',
                hintText: '선택 · 2026-07-24',
                errorText: _errorText,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
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
    super.key,
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

class _ClassroomLayoutPanel extends StatefulWidget {
  const _ClassroomLayoutPanel({
    super.key,
    required this.studyRoom,
    required this.classService,
    required this.enrollmentService,
    required this.layoutService,
  });

  final StudyRoomSummary studyRoom;
  final ClassManagementService classService;
  final EnrollmentManagementService enrollmentService;
  final ClassroomLayoutService layoutService;

  @override
  State<_ClassroomLayoutPanel> createState() => _ClassroomLayoutPanelState();
}

class _ClassroomLayoutPanelState extends State<_ClassroomLayoutPanel> {
  late Future<_ClassroomLayoutData> _dataFuture;
  String? _selectedClassId;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadData();
  }

  Future<_ClassroomLayoutData> _loadData() async {
    final classes = await widget.classService.fetchClasses(widget.studyRoom.id);
    final selectedClassId = _selectedClassId ?? classes.firstOrNull?.id;
    _selectedClassId = selectedClassId;
    if (selectedClassId == null) {
      return const _ClassroomLayoutData(
        classes: [],
        enrolled: [],
        layout: null,
      );
    }
    final enrolled = await widget.enrollmentService.fetchClassStudents(
      selectedClassId,
    );
    final layout = await widget.layoutService.fetchLayout(selectedClassId);
    return _ClassroomLayoutData(
      classes: classes,
      enrolled: enrolled,
      layout: layout,
    );
  }

  Future<void> _addSeat(_ClassroomLayoutData data) async {
    final layout = data.layout;
    if (layout == null) return;
    final nextIndex = layout.seats.length;
    final column = nextIndex % 3;
    final row = nextIndex ~/ 3;
    final nextSeat = ClassroomSeat(
      id: null,
      label: '${nextIndex + 1}',
      deskX: 0.18 + column * 0.28,
      deskY: 0.18 + row * 0.22,
      seatX: 0.18 + column * 0.28,
      seatY: 0.28 + row * 0.22,
      rotationDegrees: 0,
      displayOrder: nextIndex,
    );
    await _saveLayout(layout.copyWith(seats: [...layout.seats, nextSeat]));
  }

  Future<void> _createDefaultSeats(_ClassroomLayoutData data) async {
    final layout = data.layout;
    if (layout == null) return;
    final seats = [
      for (var index = 0; index < 6; index++)
        ClassroomSeat(
          id: null,
          label: '${index + 1}',
          deskX: 0.18 + (index % 3) * 0.28,
          deskY: 0.18 + (index ~/ 3) * 0.26,
          seatX: 0.18 + (index % 3) * 0.28,
          seatY: 0.29 + (index ~/ 3) * 0.26,
          rotationDegrees: 0,
          displayOrder: index,
        ),
    ];
    await _saveLayout(layout.copyWith(seats: seats));
  }

  Future<void> _saveLayout(ClassroomLayout layout) async {
    final classId = _selectedClassId;
    if (classId == null) return;
    setState(() => _saving = true);
    try {
      await widget.layoutService.saveLayout(classId: classId, layout: layout);
      if (mounted) setState(() => _dataFuture = _loadData());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _assignStudent({
    required ClassroomLayout layout,
    required String seatId,
    required String studentId,
  }) async {
    final classId = _selectedClassId;
    if (classId == null) return;
    final nextAssignments = [
      for (final assignment in layout.assignments)
        if (assignment.seatId != seatId && assignment.studentId != studentId)
          SeatAssignmentInput(
            seatId: assignment.seatId,
            studentId: assignment.studentId,
          ),
      SeatAssignmentInput(seatId: seatId, studentId: studentId),
    ];
    await _saveAssignments(classId, nextAssignments);
  }

  Future<void> _clearSeat({
    required ClassroomLayout layout,
    required String seatId,
  }) async {
    final classId = _selectedClassId;
    if (classId == null) return;
    final nextAssignments = [
      for (final assignment in layout.assignments)
        if (assignment.seatId != seatId)
          SeatAssignmentInput(
            seatId: assignment.seatId,
            studentId: assignment.studentId,
          ),
    ];
    await _saveAssignments(classId, nextAssignments);
  }

  Future<void> _saveAssignments(
    String classId,
    List<SeatAssignmentInput> assignments,
  ) async {
    setState(() => _saving = true);
    try {
      await widget.layoutService.saveAssignments(
        classId: classId,
        assignments: assignments,
      );
      if (mounted) setState(() => _dataFuture = _loadData());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _copyLayoutFromClass(_ClassroomLayoutData data) async {
    final targetClassId = _selectedClassId;
    if (targetClassId == null) return;
    final candidates = data.classes
        .where((classRoom) => classRoom.id != targetClassId)
        .toList(growable: false);
    if (candidates.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('복사할 다른 수업이 없습니다.')));
      return;
    }

    final sourceClassId = await showDialog<String>(
      context: context,
      builder: (context) => _CopyLayoutDialog(classes: candidates),
    );
    if (sourceClassId == null) return;

    setState(() => _saving = true);
    try {
      await widget.layoutService.copyLayout(
        targetClassId: targetClassId,
        sourceClassId: sourceClassId,
      );
      if (mounted) {
        setState(() => _dataFuture = _loadData());
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('교실 배치를 복사했습니다.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('교실 배치 복사에 실패했습니다.')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
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
            Text('좌석 배치', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(widget.studyRoom.name),
            const SizedBox(height: 12),
            Expanded(
              child: FutureBuilder<_ClassroomLayoutData>(
                future: _dataFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Text('좌석 배치를 불러오지 못했습니다. ${snapshot.error}');
                  }
                  final data = snapshot.requireData;
                  if (data.classes.isEmpty) {
                    return const Center(child: Text('수업을 먼저 생성해 주세요.'));
                  }
                  final layout = data.layout;
                  if (layout == null) {
                    return const Center(child: Text('좌석 배치 정보가 없습니다.'));
                  }
                  final assignedStudentIds = layout.assignments
                      .map((assignment) => assignment.studentId)
                      .toSet();
                  final unassigned = data.enrolled
                      .where(
                        (student) => !assignedStudentIds.contains(student.id),
                      )
                      .toList();
                  final assignmentBySeat = {
                    for (final assignment in layout.assignments)
                      assignment.seatId: assignment,
                  };

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: _selectedClassId,
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
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.tonalIcon(
                            onPressed: _saving ? null : () => _addSeat(data),
                            icon: const Icon(Icons.event_seat_outlined),
                            label: const Text('좌석 추가'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _saving || layout.seats.isNotEmpty
                                ? null
                                : () => _createDefaultSeats(data),
                            icon: const Icon(Icons.grid_view_outlined),
                            label: const Text('기본 6석'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _saving || data.classes.length < 2
                                ? null
                                : () => _copyLayoutFromClass(data),
                            icon: const Icon(Icons.copy_all_outlined),
                            label: const Text('다른 수업에서 복사'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final student in unassigned)
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
                          if (unassigned.isEmpty)
                            const Chip(label: Text('미배정 학생 없음')),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: layout.seats.isEmpty
                            ? const Center(child: Text('좌석을 추가해 주세요.'))
                            : GridView.builder(
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 3,
                                      childAspectRatio: 1.15,
                                      crossAxisSpacing: 8,
                                      mainAxisSpacing: 8,
                                    ),
                                itemCount: layout.seats.length,
                                itemBuilder: (context, index) {
                                  final seat = layout.seats[index];
                                  final seatId = seat.id;
                                  final assignment = seatId == null
                                      ? null
                                      : assignmentBySeat[seatId];
                                  return DragTarget<ManagedStudent>(
                                    onAcceptWithDetails:
                                        seatId == null || _saving
                                        ? null
                                        : (details) => _assignStudent(
                                            layout: layout,
                                            seatId: seatId,
                                            studentId: details.data.id,
                                          ),
                                    builder: (context, candidates, rejected) {
                                      return DecoratedBox(
                                        decoration: BoxDecoration(
                                          color: candidates.isEmpty
                                              ? const Color(0xFFF8FAFC)
                                              : Theme.of(
                                                  context,
                                                ).colorScheme.primaryContainer,
                                          border: Border.all(
                                            color: candidates.isEmpty
                                                ? const Color(0xFFD9E1E8)
                                                : Theme.of(
                                                    context,
                                                  ).colorScheme.primary,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(8),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  const Icon(
                                                    Icons.event_seat_outlined,
                                                    size: 18,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Expanded(
                                                    child: Text(
                                                      '좌석 ${seat.label}',
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  if (assignment != null)
                                                    IconButton(
                                                      tooltip: '비우기',
                                                      visualDensity:
                                                          VisualDensity.compact,
                                                      icon: const Icon(
                                                        Icons.close,
                                                        size: 18,
                                                      ),
                                                      onPressed:
                                                          _saving ||
                                                              seatId == null
                                                          ? null
                                                          : () => _clearSeat(
                                                              layout: layout,
                                                              seatId: seatId,
                                                            ),
                                                    ),
                                                ],
                                              ),
                                              const Spacer(),
                                              Text(
                                                assignment?.studentName ??
                                                    '학생을 놓아 배정',
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              if (assignment
                                                      ?.studentCode
                                                      .isNotEmpty ==
                                                  true)
                                                Text(
                                                  assignment!.studentCode,
                                                  style: Theme.of(
                                                    context,
                                                  ).textTheme.bodySmall,
                                                ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
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

class _ClassroomLayoutData {
  const _ClassroomLayoutData({
    required this.classes,
    required this.enrolled,
    required this.layout,
  });

  final List<ManagedClass> classes;
  final List<ManagedStudent> enrolled;
  final ClassroomLayout? layout;
}

class _CopyLayoutDialog extends StatelessWidget {
  const _CopyLayoutDialog({required this.classes});

  final List<ManagedClass> classes;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('교실 배치 복사'),
      content: SizedBox(
        width: 420,
        child: ListView.separated(
          shrinkWrap: true,
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
              onTap: () => Navigator.of(context).pop(classRoom.id),
            );
          },
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemCount: classes.length,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
      ],
    );
  }
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
    final auditLogs = effectiveStudyRoomId == null
        ? const <AppAuditLog>[]
        : await widget.service.fetchStudyRoomAuditLogs(effectiveStudyRoomId);
    final notifications = effectiveStudyRoomId == null
        ? const <KakaoNotificationLog>[]
        : await widget.service.fetchStudyRoomNotifications(
            effectiveStudyRoomId,
          );

    _selectedTeacherId = teacherId;
    _selectedStudyRoomId = effectiveStudyRoomId;
    return _AdminDashboardData(
      teachers: teachers,
      studyRooms: studyRooms,
      students: students,
      auditLogs: auditLogs,
      notifications: notifications,
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
            Expanded(
              flex: 2,
              child: _AdminStudyRoomDetailPanel(
                students: data.students,
                auditLogs: data.auditLogs,
                notifications: data.notifications,
              ),
            ),
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
    required this.auditLogs,
    required this.notifications,
  });

  final List<AdminTeacherSummary> teachers;
  final List<StudyRoomSummary> studyRooms;
  final List<ManagedStudent> students;
  final List<AppAuditLog> auditLogs;
  final List<KakaoNotificationLog> notifications;
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

class _StudentManagementPanel extends StatefulWidget {
  const _StudentManagementPanel({
    super.key,
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
  String _gender = 'unspecified';
  String _ageGroup = 'elementary';

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
        gender: _gender,
        ageGroup: _ageGroup,
        avatarKey: _studentAvatarKey(_gender, _ageGroup),
      );
      _nameController.clear();
      _codeController.clear();
      _pinController.clear();
      _gender = 'unspecified';
      _ageGroup = 'elementary';
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
        gender: result.gender,
        ageGroup: result.ageGroup,
        avatarKey: result.avatarKey,
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
                SizedBox(
                  width: 130,
                  child: DropdownButtonFormField<String>(
                    initialValue: _ageGroup,
                    decoration: const InputDecoration(
                      labelText: '연령대',
                      border: OutlineInputBorder(),
                    ),
                    items: _studentAgeGroupMenuItems(),
                    onChanged: _submitting
                        ? null
                        : (value) {
                            if (value != null) {
                              setState(() => _ageGroup = value);
                            }
                          },
                  ),
                ),
                SizedBox(
                  width: 130,
                  child: DropdownButtonFormField<String>(
                    initialValue: _gender,
                    decoration: const InputDecoration(
                      labelText: '아바타',
                      border: OutlineInputBorder(),
                    ),
                    items: _studentGenderMenuItems(),
                    onChanged: _submitting
                        ? null
                        : (value) {
                            if (value != null) {
                              setState(() => _gender = value);
                            }
                          },
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
                          '${student.code} · ${_studentStatusLabel(student.status)} · ${_studentAgeGroupLabel(student.ageGroup)} · ${_studentGenderLabel(student.gender)}',
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
    required this.gender,
    required this.ageGroup,
    required this.avatarKey,
  });

  final String name;
  final String code;
  final String status;
  final String gender;
  final String ageGroup;
  final String avatarKey;
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
  late String _gender;
  late String _ageGroup;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.student.name);
    _codeController = TextEditingController(text: widget.student.code);
    _status = widget.student.status;
    _gender = widget.student.gender;
    _ageGroup = widget.student.ageGroup;
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
    Navigator.of(context).pop(
      _StudentEditResult(
        name: name,
        code: code,
        status: _status,
        gender: _gender,
        ageGroup: _ageGroup,
        avatarKey: _studentAvatarKey(_gender, _ageGroup),
      ),
    );
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
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _ageGroup,
                    decoration: const InputDecoration(
                      labelText: '연령대',
                      border: OutlineInputBorder(),
                    ),
                    items: _studentAgeGroupMenuItems(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _ageGroup = value);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _gender,
                    decoration: const InputDecoration(
                      labelText: '아바타',
                      border: OutlineInputBorder(),
                    ),
                    items: _studentGenderMenuItems(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _gender = value);
                      }
                    },
                  ),
                ),
              ],
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

class _AdminStudyRoomDetailPanel extends StatelessWidget {
  const _AdminStudyRoomDetailPanel({
    required this.students,
    required this.auditLogs,
    required this.notifications,
  });

  final List<ManagedStudent> students;
  final List<AppAuditLog> auditLogs;
  final List<KakaoNotificationLog> notifications;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('공부방 상세', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              const TabBar(
                tabs: [
                  Tab(text: '학생'),
                  Tab(text: '히스토리'),
                  Tab(text: '카카오'),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: TabBarView(
                  children: [
                    _AdminStudentListView(students: students),
                    _AdminAuditLogListView(logs: auditLogs),
                    _AdminNotificationListView(notifications: notifications),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminStudentListView extends StatelessWidget {
  const _AdminStudentListView({required this.students});

  final List<ManagedStudent> students;

  @override
  Widget build(BuildContext context) {
    if (students.isEmpty) {
      return const Center(child: Text('선택한 공부방에 학생이 없습니다.'));
    }
    return ListView.builder(
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
    );
  }
}

class _AdminAuditLogListView extends StatelessWidget {
  const _AdminAuditLogListView({required this.logs});

  final List<AppAuditLog> logs;

  @override
  Widget build(BuildContext context) {
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
              if (log.summary != null && log.summary!.isNotEmpty) log.summary!,
            ].join(' · '),
          ),
        );
      },
    );
  }
}

class _AdminNotificationListView extends StatelessWidget {
  const _AdminNotificationListView({required this.notifications});

  final List<KakaoNotificationLog> notifications;

  @override
  Widget build(BuildContext context) {
    if (notifications.isEmpty) {
      return const Center(child: Text('표시할 카카오 이력이 없습니다.'));
    }
    return ListView.builder(
      itemCount: notifications.length,
      itemBuilder: (context, index) {
        final log = notifications[index];
        return ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: Icon(_notificationStatusIcon(log.status)),
          title: Text('${log.studentName} · ${log.className}'),
          subtitle: Text(
            [
              _notificationEventLabel(log.eventType),
              _notificationStatusLabel(log.status),
              log.recipientPhoneMasked,
              if (log.templateCode.isNotEmpty) log.templateCode,
              _formatAuditTime(log.sentAt ?? log.createdAt),
              if (log.errorMessage != null && log.errorMessage!.isNotEmpty)
                log.errorMessage!,
            ].join(' · '),
          ),
        );
      },
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
    required this.consentConfirmed,
    required this.primaryContact,
    required this.deleted,
  });

  factory _GuardianDraft.fromGuardian(StudentGuardian guardian) {
    return _GuardianDraft(
      id: guardian.id,
      name: guardian.name,
      phone: guardian.phone,
      relationship: guardian.relationship,
      kakaoOptIn: guardian.kakaoOptIn,
      consentConfirmed: guardian.consentConfirmed,
      primaryContact: guardian.primaryContact,
      deleted: guardian.deleted,
    );
  }

  String id;
  String name;
  String phone;
  String relationship;
  bool kakaoOptIn;
  bool consentConfirmed;
  bool primaryContact;
  bool deleted;

  StudentGuardian toGuardian() {
    return StudentGuardian(
      id: id,
      name: name.trim(),
      phone: phone.trim(),
      relationship: relationship.trim(),
      kakaoOptIn: deleted ? false : kakaoOptIn,
      consentConfirmed: deleted ? false : consentConfirmed,
      primaryContact: deleted ? false : primaryContact,
      deleted: deleted,
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
          kakaoOptIn: false,
          consentConfirmed: false,
          primaryContact: _drafts.isEmpty,
          deleted: false,
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
    if (guardians.any(
      (guardian) => guardian.kakaoOptIn && !guardian.consentConfirmed,
    )) {
      setState(() => _errorText = '카카오 수신 동의 확인 후 저장해 주세요.');
      return;
    }
    if (guardians.where((guardian) => guardian.primaryContact).length > 1) {
      setState(() => _errorText = '대표 연락처는 한 명만 선택해 주세요.');
      return;
    }
    if (guardians.any((guardian) => guardian.deleted && guardian.id.isEmpty)) {
      setState(() => _errorText = '새 보호자는 정보 삭제 요청 대신 목록에서 제거해 주세요.');
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
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '카카오 수신 동의는 고지 후 확인한 경우에만 켜 주세요. 수신 거부는 동의를 끄고, 정보 삭제 요청은 별도 표시해 저장합니다.',
                  ),
                ),
                const SizedBox(height: 8),
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
                                            label: const Text('카카오 수신 동의'),
                                            selected: draft.kakaoOptIn,
                                            showCheckmark: true,
                                            avatar: draft.deleted
                                                ? const Icon(Icons.block)
                                                : null,
                                            onSelected: (selected) {
                                              if (draft.deleted) return;
                                              setState(() {
                                                draft.kakaoOptIn = selected;
                                                draft.consentConfirmed =
                                                    selected;
                                              });
                                            },
                                          ),
                                          const SizedBox(width: 8),
                                          FilterChip(
                                            label: const Text('대표'),
                                            selected: draft.primaryContact,
                                            onSelected: (selected) {
                                              if (draft.deleted) return;
                                              setState(() {
                                                for (final item in _drafts) {
                                                  item.primaryContact = false;
                                                }
                                                draft.primaryContact = selected;
                                              });
                                            },
                                          ),
                                          const SizedBox(width: 8),
                                          FilterChip(
                                            label: const Text('정보 삭제 요청'),
                                            selected: draft.deleted,
                                            selectedColor: const Color(
                                              0xFFFFE7E7,
                                            ),
                                            onSelected: draft.id.isEmpty
                                                ? null
                                                : (selected) {
                                                    setState(() {
                                                      draft.deleted = selected;
                                                      if (selected) {
                                                        draft.kakaoOptIn =
                                                            false;
                                                        draft.consentConfirmed =
                                                            false;
                                                        draft.primaryContact =
                                                            false;
                                                      }
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

class _AttendanceManagementPanel extends StatefulWidget {
  const _AttendanceManagementPanel({required this.service});

  final AttendanceManagementService service;

  @override
  State<_AttendanceManagementPanel> createState() =>
      _AttendanceManagementPanelState();
}

class _AttendanceManagementPanelState
    extends State<_AttendanceManagementPanel> {
  late Future<_TeacherAttendancePanelData> _dataFuture;
  String? _selectedSessionId;
  String? _processingStudentId;

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadData();
  }

  Future<_TeacherAttendancePanelData> _loadData() async {
    final sessions = await widget.service.fetchTodaySessions();
    final sessionId = _selectedSessionId ?? sessions.firstOrNull?.id;
    final effectiveSessionId =
        sessions.any((session) => session.id == sessionId)
        ? sessionId
        : sessions.firstOrNull?.id;
    final attendance = effectiveSessionId == null
        ? null
        : await widget.service.fetchSessionAttendance(effectiveSessionId);
    _selectedSessionId = effectiveSessionId;
    return _TeacherAttendancePanelData(
      sessions: sessions,
      attendance: attendance,
    );
  }

  Future<void> _updateStatus(
    TeacherAttendanceStudent student,
    String status,
  ) async {
    final sessionId = _selectedSessionId;
    if (sessionId == null) return;
    setState(() => _processingStudentId = student.id);
    try {
      final result = await widget.service.updateAttendance(
        classSessionId: sessionId,
        studentId: student.id,
        status: status,
        note: '',
      );
      if (mounted) {
        setState(() => _dataFuture = _loadData());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '출결 상태를 저장하고 카카오 알림 ${result.requestedNotifications}건을 요청했습니다.',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('출결 상태 변경에 실패했습니다.')));
      }
    } finally {
      if (mounted) setState(() => _processingStudentId = null);
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
            Text('출결 관리', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Expanded(
              child: FutureBuilder<_TeacherAttendancePanelData>(
                future: _dataFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Text('출결 정보를 불러오지 못했습니다. ${snapshot.error}');
                  }
                  final data = snapshot.requireData;
                  if (data.sessions.isEmpty) {
                    return const Center(child: Text('열린 출석 회차가 없습니다.'));
                  }
                  final students =
                      data.attendance?.students ??
                      const <TeacherAttendanceStudent>[];
                  return Column(
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: _selectedSessionId,
                        decoration: const InputDecoration(
                          labelText: '수업 회차',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          for (final session in data.sessions)
                            DropdownMenuItem(
                              value: session.id,
                              child: Text(
                                '${session.className} · ${session.scheduleText}',
                              ),
                            ),
                        ],
                        onChanged: (sessionId) {
                          if (sessionId == null) return;
                          setState(() {
                            _selectedSessionId = sessionId;
                            _dataFuture = _loadData();
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: students.isEmpty
                            ? const Center(child: Text('출결 대상 학생이 없습니다.'))
                            : ListView.builder(
                                itemCount: students.length,
                                itemBuilder: (context, index) {
                                  final student = students[index];
                                  final processing =
                                      _processingStudentId == student.id;
                                  return ListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    leading: Icon(
                                      _teacherAttendanceStatusIcon(
                                        student.status,
                                      ),
                                    ),
                                    title: Text(student.name),
                                    subtitle: Text(
                                      '${student.code} · ${_teacherAttendanceStatusLabel(student.status)}',
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
                                            tooltip: '출결 상태 변경',
                                            icon: const Icon(Icons.more_vert),
                                            onSelected: (status) =>
                                                _updateStatus(student, status),
                                            itemBuilder: (context) => const [
                                              PopupMenuItem(
                                                value: 'present',
                                                child: Text('출석'),
                                              ),
                                              PopupMenuItem(
                                                value: 'late',
                                                child: Text('지각'),
                                              ),
                                              PopupMenuItem(
                                                value: 'absent',
                                                child: Text('결석'),
                                              ),
                                              PopupMenuItem(
                                                value: 'excused',
                                                child: Text('인정결석'),
                                              ),
                                              PopupMenuItem(
                                                value: 'left_early',
                                                child: Text('조퇴'),
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

class _TeacherAttendancePanelData {
  const _TeacherAttendancePanelData({
    required this.sessions,
    required this.attendance,
  });

  final List<TeacherAttendanceSession> sessions;
  final TeacherAttendanceData? attendance;
}

class _PaymentManagementPanel extends StatefulWidget {
  const _PaymentManagementPanel({
    super.key,
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
      final result = await widget.service.updateStatus(
        paymentStatusId: status.id,
        status: next,
        note: '',
      );
      if (mounted && result.notificationCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '납부 상태를 저장하고 카카오 알림 ${result.notificationCount}건을 요청했습니다.',
            ),
          ),
        );
      }
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

class _AuditHistoryPanel extends StatelessWidget {
  const _AuditHistoryPanel({
    super.key,
    required this.studyRoom,
    required this.studentService,
    required this.classService,
    required this.auditLogService,
    required this.notificationLogService,
  });

  final StudyRoomSummary studyRoom;
  final StudentManagementService studentService;
  final ClassManagementService classService;
  final AuditLogService auditLogService;
  final NotificationLogService notificationLogService;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('기록', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(studyRoom.name),
              const SizedBox(height: 8),
              const TabBar(
                tabs: [
                  Tab(text: '히스토리'),
                  Tab(text: '카카오'),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: TabBarView(
                  children: [
                    _AuditLogTab(
                      studyRoom: studyRoom,
                      studentService: studentService,
                      classService: classService,
                      service: auditLogService,
                    ),
                    _NotificationLogTab(
                      studyRoom: studyRoom,
                      studentService: studentService,
                      classService: classService,
                      service: notificationLogService,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuditLogTab extends StatefulWidget {
  const _AuditLogTab({
    required this.studyRoom,
    required this.studentService,
    required this.classService,
    required this.service,
  });

  final StudyRoomSummary studyRoom;
  final StudentManagementService studentService;
  final ClassManagementService classService;
  final AuditLogService service;

  @override
  State<_AuditLogTab> createState() => _AuditLogTabState();
}

class _AuditLogTabState extends State<_AuditLogTab> {
  var _category = AuditLogCategory.all;
  String? _studentId;
  String? _classId;
  late final TextEditingController _dateFromController;
  late final TextEditingController _dateToController;
  late Future<_HistoryFilterData> _filtersFuture;
  late Future<List<AppAuditLog>> _logsFuture;

  @override
  void initState() {
    super.initState();
    _dateFromController = TextEditingController();
    _dateToController = TextEditingController();
    _filtersFuture = _loadFilters();
    _logsFuture = _fetchLogs();
  }

  @override
  void dispose() {
    _dateFromController.dispose();
    _dateToController.dispose();
    super.dispose();
  }

  Future<_HistoryFilterData> _loadFilters() async {
    final results = await Future.wait([
      widget.studentService.fetchStudents(widget.studyRoom.id),
      widget.classService.fetchClasses(widget.studyRoom.id),
    ]);
    return _HistoryFilterData(
      students: results[0] as List<ManagedStudent>,
      classes: results[1] as List<ManagedClass>,
    );
  }

  Future<List<AppAuditLog>> _fetchLogs() {
    return widget.service.fetchLogs(
      studyRoomId: widget.studyRoom.id,
      category: _category,
      studentId: _studentId,
      classId: _classId,
      dateFrom: _dateFromController.text.trim(),
      dateTo: _dateToController.text.trim(),
    );
  }

  void _refreshLogs() {
    setState(() {
      _logsFuture = _fetchLogs();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FutureBuilder<_HistoryFilterData>(
          future: _filtersFuture,
          builder: (context, snapshot) {
            final filters = snapshot.data ?? const _HistoryFilterData();
            return _HistoryFilterBar(
              students: filters.students,
              classes: filters.classes,
              selectedStudentId: _studentId,
              selectedClassId: _classId,
              dateFromController: _dateFromController,
              dateToController: _dateToController,
              onStudentChanged: (value) {
                _studentId = value;
                _refreshLogs();
              },
              onClassChanged: (value) {
                _classId = value;
                _refreshLogs();
              },
              onDateSubmitted: _refreshLogs,
              trailing: [
                for (final category in AuditLogCategory.values)
                  FilterChip(
                    label: Text(category.label),
                    selected: _category == category,
                    onSelected: (_) {
                      _category = category;
                      _refreshLogs();
                    },
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 8),
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
    );
  }
}

class _NotificationLogTab extends StatefulWidget {
  const _NotificationLogTab({
    required this.studyRoom,
    required this.studentService,
    required this.classService,
    required this.service,
  });

  final StudyRoomSummary studyRoom;
  final StudentManagementService studentService;
  final ClassManagementService classService;
  final NotificationLogService service;

  @override
  State<_NotificationLogTab> createState() => _NotificationLogTabState();
}

class _NotificationLogTabState extends State<_NotificationLogTab> {
  var _status = 'all';
  String? _studentId;
  String? _classId;
  late final TextEditingController _dateFromController;
  late final TextEditingController _dateToController;
  late Future<_HistoryFilterData> _filtersFuture;
  late Future<List<KakaoNotificationLog>> _logsFuture;
  String? _resendingId;
  var _processingPending = false;

  @override
  void initState() {
    super.initState();
    _dateFromController = TextEditingController();
    _dateToController = TextEditingController();
    _filtersFuture = _loadFilters();
    _logsFuture = _fetchLogs();
  }

  @override
  void dispose() {
    _dateFromController.dispose();
    _dateToController.dispose();
    super.dispose();
  }

  Future<_HistoryFilterData> _loadFilters() async {
    final results = await Future.wait([
      widget.studentService.fetchStudents(widget.studyRoom.id),
      widget.classService.fetchClasses(widget.studyRoom.id),
    ]);
    return _HistoryFilterData(
      students: results[0] as List<ManagedStudent>,
      classes: results[1] as List<ManagedClass>,
    );
  }

  Future<List<KakaoNotificationLog>> _fetchLogs() {
    return widget.service.fetchLogs(
      studyRoomId: widget.studyRoom.id,
      status: _status,
      studentId: _studentId,
      classId: _classId,
      dateFrom: _dateFromController.text.trim(),
      dateTo: _dateToController.text.trim(),
    );
  }

  void _refreshLogs() {
    setState(() {
      _logsFuture = _fetchLogs();
    });
  }

  Future<void> _resend(KakaoNotificationLog log) async {
    setState(() => _resendingId = log.id);
    try {
      await widget.service.resend(log.id);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('카카오 재발송을 요청했습니다.')));
        setState(() => _logsFuture = _fetchLogs());
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('카카오 재발송 요청에 실패했습니다.')));
      }
    } finally {
      if (mounted) setState(() => _resendingId = null);
    }
  }

  Future<void> _processPending() async {
    setState(() => _processingPending = true);
    try {
      final result = await widget.service.processPending(widget.studyRoom.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '대기 ${result.processed}건 처리: 성공 ${result.sent}건, 실패 ${result.failed}건',
            ),
          ),
        );
        setState(() => _logsFuture = _fetchLogs());
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('대기 발송 처리에 실패했습니다.')));
      }
    } finally {
      if (mounted) setState(() => _processingPending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const statuses = [
      ('all', '전체'),
      ('pending', '대기'),
      ('sent', '성공'),
      ('failed', '실패'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FutureBuilder<_HistoryFilterData>(
          future: _filtersFuture,
          builder: (context, snapshot) {
            final filters = snapshot.data ?? const _HistoryFilterData();
            return _HistoryFilterBar(
              students: filters.students,
              classes: filters.classes,
              selectedStudentId: _studentId,
              selectedClassId: _classId,
              dateFromController: _dateFromController,
              dateToController: _dateToController,
              onStudentChanged: (value) {
                _studentId = value;
                _refreshLogs();
              },
              onClassChanged: (value) {
                _classId = value;
                _refreshLogs();
              },
              onDateSubmitted: _refreshLogs,
              trailing: [
                for (final item in statuses)
                  FilterChip(
                    label: Text(item.$2),
                    selected: _status == item.$1,
                    onSelected: (_) {
                      _status = item.$1;
                      _refreshLogs();
                    },
                  ),
                IconButton.filledTonal(
                  tooltip: '대기 발송 처리',
                  onPressed: _processingPending ? null : _processPending,
                  icon: _processingPending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_outlined),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 8),
        Expanded(
          child: FutureBuilder<List<KakaoNotificationLog>>(
            future: _logsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Text('카카오 이력을 불러오지 못했습니다. ${snapshot.error}');
              }
              final logs = snapshot.data ?? const <KakaoNotificationLog>[];
              if (logs.isEmpty) {
                return const Center(child: Text('표시할 카카오 이력이 없습니다.'));
              }
              return ListView.builder(
                itemCount: logs.length,
                itemBuilder: (context, index) {
                  final log = logs[index];
                  final resending = _resendingId == log.id;
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(_notificationStatusIcon(log.status)),
                    title: Text('${log.studentName} · ${log.className}'),
                    subtitle: Text(
                      [
                        _notificationEventLabel(log.eventType),
                        _notificationStatusLabel(log.status),
                        log.recipientPhoneMasked,
                        if (log.templateCode.isNotEmpty) log.templateCode,
                        _formatAuditTime(log.sentAt ?? log.createdAt),
                        if (log.retryCount > 0) '재시도 ${log.retryCount}회',
                        if (log.errorMessage != null &&
                            log.errorMessage!.isNotEmpty)
                          log.errorMessage!,
                        if (log.messagePreview.isNotEmpty) log.messagePreview,
                      ].join(' · '),
                    ),
                    trailing: resending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : IconButton(
                            tooltip: '재발송 요청',
                            icon: const Icon(Icons.refresh),
                            onPressed: () => _resend(log),
                          ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _HistoryFilterData {
  const _HistoryFilterData({
    this.students = const <ManagedStudent>[],
    this.classes = const <ManagedClass>[],
  });

  final List<ManagedStudent> students;
  final List<ManagedClass> classes;
}

class _HistoryFilterBar extends StatelessWidget {
  const _HistoryFilterBar({
    required this.students,
    required this.classes,
    required this.selectedStudentId,
    required this.selectedClassId,
    required this.dateFromController,
    required this.dateToController,
    required this.onStudentChanged,
    required this.onClassChanged,
    required this.onDateSubmitted,
    required this.trailing,
  });

  final List<ManagedStudent> students;
  final List<ManagedClass> classes;
  final String? selectedStudentId;
  final String? selectedClassId;
  final TextEditingController dateFromController;
  final TextEditingController dateToController;
  final ValueChanged<String?> onStudentChanged;
  final ValueChanged<String?> onClassChanged;
  final VoidCallback onDateSubmitted;
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 150,
          child: DropdownButtonFormField<String>(
            initialValue: selectedStudentId ?? '',
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: '학생',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: [
              const DropdownMenuItem(value: '', child: Text('전체')),
              for (final student in students)
                DropdownMenuItem(
                  value: student.id,
                  child: Text(student.name, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (value) =>
                onStudentChanged(value == null || value.isEmpty ? null : value),
          ),
        ),
        SizedBox(
          width: 170,
          child: DropdownButtonFormField<String>(
            initialValue: selectedClassId ?? '',
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: '수업',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: [
              const DropdownMenuItem(value: '', child: Text('전체')),
              for (final classRoom in classes)
                DropdownMenuItem(
                  value: classRoom.id,
                  child: Text(classRoom.name, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (value) =>
                onClassChanged(value == null || value.isEmpty ? null : value),
          ),
        ),
        SizedBox(
          width: 132,
          child: TextField(
            controller: dateFromController,
            decoration: const InputDecoration(
              labelText: '시작일',
              hintText: 'YYYY-MM-DD',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onSubmitted: (_) => onDateSubmitted(),
          ),
        ),
        SizedBox(
          width: 132,
          child: TextField(
            controller: dateToController,
            decoration: const InputDecoration(
              labelText: '종료일',
              hintText: 'YYYY-MM-DD',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onSubmitted: (_) => onDateSubmitted(),
          ),
        ),
        IconButton.filledTonal(
          tooltip: '기간 적용',
          onPressed: onDateSubmitted,
          icon: const Icon(Icons.search),
        ),
        ...trailing,
      ],
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

String _studentGenderLabel(String gender) {
  return switch (gender) {
    'male' => '남',
    'female' => '여',
    _ => '미지정',
  };
}

String _studentAgeGroupLabel(String ageGroup) {
  return switch (ageGroup) {
    'middle' => '중등',
    'high' => '고등',
    _ => '초등',
  };
}

String _studentAvatarKey(String gender, String ageGroup) {
  return '${ageGroup}_${gender}_01';
}

List<DropdownMenuItem<String>> _studentGenderMenuItems() {
  return const [
    DropdownMenuItem(value: 'unspecified', child: Text('미지정')),
    DropdownMenuItem(value: 'male', child: Text('남')),
    DropdownMenuItem(value: 'female', child: Text('여')),
  ];
}

List<DropdownMenuItem<String>> _studentAgeGroupMenuItems() {
  return const [
    DropdownMenuItem(value: 'elementary', child: Text('초등')),
    DropdownMenuItem(value: 'middle', child: Text('중등')),
    DropdownMenuItem(value: 'high', child: Text('고등')),
  ];
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

String _teacherAttendanceStatusLabel(String status) {
  return switch (status) {
    'present' => '출석',
    'late' => '지각',
    'absent' => '결석',
    'excused' => '인정결석',
    'left_early' => '조퇴',
    _ => '대기',
  };
}

IconData _teacherAttendanceStatusIcon(String status) {
  return switch (status) {
    'present' => Icons.check_circle_outline,
    'late' => Icons.schedule_outlined,
    'absent' => Icons.cancel_outlined,
    'excused' => Icons.event_available_outlined,
    'left_early' => Icons.logout_outlined,
    _ => Icons.hourglass_empty_outlined,
  };
}

String _notificationStatusLabel(String status) {
  return switch (status) {
    'sent' => '성공',
    'failed' => '실패',
    'cancelled' => '취소',
    _ => '대기',
  };
}

IconData _notificationStatusIcon(String status) {
  return switch (status) {
    'sent' => Icons.check_circle_outline,
    'failed' => Icons.error_outline,
    'cancelled' => Icons.cancel_outlined,
    _ => Icons.schedule_outlined,
  };
}

String _notificationEventLabel(String eventType) {
  return switch (eventType) {
    'attendance_checked_in' => '출석',
    'class_cancelled' => '휴강',
    'class_makeup_added' => '보강',
    'class_time_changed' => '시간 변경',
    'payment_due_reminder' => '납부',
    'payment_paid_confirmed' => '납부',
    _ => '알림',
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
