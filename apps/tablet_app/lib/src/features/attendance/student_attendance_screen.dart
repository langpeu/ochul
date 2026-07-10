import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/app_config.dart';
import '../../core/edge_function_client.dart';
import '../../models/sample_data.dart';
import '../../widgets/student_avatar.dart';
import 'attendance_service.dart';

class StudentAttendanceScreen extends StatefulWidget {
  const StudentAttendanceScreen({super.key, required this.config});

  final AppConfig config;

  @override
  State<StudentAttendanceScreen> createState() =>
      _StudentAttendanceScreenState();
}

class _StudentAttendanceScreenState extends State<StudentAttendanceScreen> {
  var _selectedClass = sampleClasses.first;

  AttendanceService get _attendanceService =>
      const AttendanceService(edgeClient: EdgeFunctionClient());

  @override
  Widget build(BuildContext context) {
    if (widget.config.isSupabaseConfigured) {
      return _LiveAttendanceView(attendanceService: _attendanceService);
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('학생 출석 모드', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 16),
          SegmentedButton<String>(
            segments: [
              for (final classRoom in sampleClasses)
                ButtonSegment(
                  value: classRoom.id,
                  label: Text(classRoom.name),
                  icon: Icon(
                    classRoom.kind == '보강'
                        ? Icons.event_repeat
                        : Icons.calendar_month,
                  ),
                ),
            ],
            selected: {_selectedClass.id},
            onSelectionChanged: (selection) {
              setState(() {
                _selectedClass = sampleClasses.firstWhere(
                  (classRoom) => classRoom.id == selection.first,
                );
              });
            },
          ),
          const SizedBox(height: 16),
          Text(
            '${_selectedClass.kind} 수업 · ${_selectedClass.time}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.count(
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.7,
              children: [
                for (final student in _selectedClass.students)
                  _StudentTile(
                    classSessionId: 'session-${_selectedClass.id}',
                    student: student,
                    attendanceService: _attendanceService,
                    designMode: !widget.config.isSupabaseConfigured,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveAttendanceView extends StatefulWidget {
  const _LiveAttendanceView({required this.attendanceService});

  final AttendanceService attendanceService;

  @override
  State<_LiveAttendanceView> createState() => _LiveAttendanceViewState();
}

class _LiveAttendanceViewState extends State<_LiveAttendanceView> {
  late Future<List<AttendanceSession>> _sessionsFuture;
  String? _selectedSessionId;

  @override
  void initState() {
    super.initState();
    _sessionsFuture = widget.attendanceService.fetchTodaySessions();
  }

  void _refreshSessions() {
    setState(() {
      _sessionsFuture = widget.attendanceService.fetchTodaySessions();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: FutureBuilder<List<AttendanceSession>>(
        future: _sessionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Text('출석 수업을 불러오지 못했습니다. ${snapshot.error}');
          }
          final sessions = snapshot.data ?? const <AttendanceSession>[];
          if (sessions.isEmpty) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '학생 출석 모드',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 16),
                const Text('현재 열린 출석 수업이 없습니다.'),
              ],
            );
          }
          final selectedSession = sessions.firstWhere(
            (session) =>
                session.id == (_selectedSessionId ?? sessions.first.id),
            orElse: () => sessions.first,
          );
          _selectedSessionId ??= selectedSession.id;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '학생 출석 모드',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 16),
              SegmentedButton<String>(
                segments: [
                  for (final session in sessions)
                    ButtonSegment(
                      value: session.id,
                      label: Text(session.className),
                      icon: Icon(
                        session.classKind == 'makeup'
                            ? Icons.event_repeat
                            : Icons.calendar_month,
                      ),
                    ),
                ],
                selected: {selectedSession.id},
                onSelectionChanged: (selection) {
                  setState(() => _selectedSessionId = selection.first);
                },
              ),
              const SizedBox(height: 16),
              Text(
                '${_classKindLabel(selectedSession.classKind)} 수업 · ${selectedSession.scheduleText}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              Expanded(
                child:
                    selectedSession.layout != null &&
                        selectedSession.layout!.seats.isNotEmpty
                    ? _LiveSeatAttendanceBoard(
                        session: selectedSession,
                        layout: selectedSession.layout!,
                        attendanceService: widget.attendanceService,
                        onCheckedIn: _refreshSessions,
                      )
                    : GridView.count(
                        crossAxisCount: 3,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.7,
                        children: [
                          for (final student in selectedSession.students)
                            _LiveStudentTile(
                              classSessionId: selectedSession.id,
                              student: student,
                              attendanceService: widget.attendanceService,
                              onCheckedIn: _refreshSessions,
                            ),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LiveStudentTile extends StatelessWidget {
  const _LiveStudentTile({
    required this.classSessionId,
    required this.student,
    required this.attendanceService,
    required this.onCheckedIn,
  });

  final String classSessionId;
  final AttendanceStudent student;
  final AttendanceService attendanceService;
  final VoidCallback onCheckedIn;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => showDialog<void>(
          context: context,
          builder: (context) => _LivePinDialog(
            classSessionId: classSessionId,
            student: student,
            attendanceService: attendanceService,
            onCheckedIn: onCheckedIn,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                student.name,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              _LiveStatusPill(status: student.status),
            ],
          ),
        ),
      ),
    );
  }
}

class _LiveSeatAttendanceBoard extends StatelessWidget {
  const _LiveSeatAttendanceBoard({
    required this.session,
    required this.layout,
    required this.attendanceService,
    required this.onCheckedIn,
  });

  final AttendanceSession session;
  final AttendanceClassroomLayout layout;
  final AttendanceService attendanceService;
  final VoidCallback onCheckedIn;

  @override
  Widget build(BuildContext context) {
    final waitingStudents = session.students
        .where((student) => student.status == 'waiting')
        .toList(growable: false);
    final studentsById = {
      for (final student in session.students) student.id: student,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 94,
          child: waitingStudents.isEmpty
              ? const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('출석 대기 중인 학생이 없습니다.'),
                )
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemBuilder: (context, index) {
                    final student = waitingStudents[index];
                    return Draggable<AttendanceStudent>(
                      data: student,
                      feedback: Material(
                        color: Colors.transparent,
                        child: _StudentDragChip(
                          student: student,
                          elevated: true,
                        ),
                      ),
                      childWhenDragging: Opacity(
                        opacity: 0.35,
                        child: _StudentDragChip(student: student),
                      ),
                      child: _StudentDragChip(student: student),
                    );
                  },
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemCount: waitingStudents.length,
                ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFFF7F8FA),
              border: Border.all(color: const Color(0xFFE0E4EA)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final boardWidth = constraints.maxWidth;
                  final boardHeight = constraints.maxHeight;
                  return Stack(
                    children: [
                      for (final seat in layout.seats)
                        _PositionedAttendanceSeat(
                          seat: seat,
                          layout: layout,
                          boardWidth: boardWidth,
                          boardHeight: boardHeight,
                          assignedStudent:
                              studentsById[layout
                                  .assignmentFor(seat.id)
                                  ?.studentId],
                          occupancy: layout.occupancyFor(seat.id),
                          onStudentDropped: (student) =>
                              _openSeatPinDialog(context, seat, student),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _openSeatPinDialog(
    BuildContext context,
    AttendanceSeat seat,
    AttendanceStudent student,
  ) {
    showDialog<void>(
      context: context,
      builder: (context) => _LivePinDialog(
        classSessionId: session.id,
        seatId: seat.id,
        student: student,
        attendanceService: attendanceService,
        onCheckedIn: onCheckedIn,
      ),
    );
  }
}

class _StudentDragChip extends StatelessWidget {
  const _StudentDragChip({required this.student, this.elevated = false});

  final AttendanceStudent student;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: elevated ? 6 : 0,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 168,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFD4DAE2)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            StudentAvatar(
              name: student.name,
              avatarKey: student.avatarKey,
              radius: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    student.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Text(
                    student.code,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
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

class _PositionedAttendanceSeat extends StatelessWidget {
  const _PositionedAttendanceSeat({
    required this.seat,
    required this.layout,
    required this.boardWidth,
    required this.boardHeight,
    required this.assignedStudent,
    required this.occupancy,
    required this.onStudentDropped,
  });

  final AttendanceSeat seat;
  final AttendanceClassroomLayout layout;
  final double boardWidth;
  final double boardHeight;
  final AttendanceStudent? assignedStudent;
  final AttendanceSeatOccupancy? occupancy;
  final ValueChanged<AttendanceStudent> onStudentDropped;

  @override
  Widget build(BuildContext context) {
    const seatWidth = 132.0;
    const seatHeight = 86.0;
    final left = _scaledPosition(seat.deskX, layout.canvasWidth, boardWidth);
    final top = _scaledPosition(seat.deskY, layout.canvasHeight, boardHeight);
    final clampedLeft = left.clamp(0, math.max(0, boardWidth - seatWidth));
    final clampedTop = top.clamp(0, math.max(0, boardHeight - seatHeight));
    final isOccupied = occupancy != null;

    return Positioned(
      left: clampedLeft.toDouble(),
      top: clampedTop.toDouble(),
      width: seatWidth,
      height: seatHeight,
      child: Transform.rotate(
        angle: seat.rotationDegrees * math.pi / 180,
        child: DragTarget<AttendanceStudent>(
          onWillAcceptWithDetails: (details) {
            if (isOccupied) return false;
            return assignedStudent == null ||
                assignedStudent!.id == details.data.id;
          },
          onAcceptWithDetails: (details) => onStudentDropped(details.data),
          builder: (context, candidates, rejected) {
            final active = candidates.isNotEmpty;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isOccupied
                    ? const Color(0xFFEAF6EF)
                    : active
                    ? const Color(0xFFE8F0FE)
                    : Colors.white,
                border: Border.all(
                  color: isOccupied
                      ? const Color(0xFF1B7F4D)
                      : active
                      ? const Color(0xFF3F6FB5)
                      : const Color(0xFFD4DAE2),
                  width: active ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    seat.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  Row(
                    children: [
                      if (occupancy != null || assignedStudent != null) ...[
                        StudentAvatar(
                          name:
                              occupancy?.studentName ??
                              assignedStudent?.name ??
                              '',
                          avatarKey:
                              occupancy?.avatarKey ??
                              assignedStudent?.avatarKey ??
                              '',
                          radius: 14,
                        ),
                        const SizedBox(width: 6),
                      ],
                      Expanded(
                        child: Text(
                          occupancy?.studentName ??
                              assignedStudent?.name ??
                              '빈 좌석',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    isOccupied
                        ? _attendanceStatusLabel(occupancy!.status)
                        : '드래그',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: isOccupied
                          ? const Color(0xFF1B7F4D)
                          : const Color(0xFF59636E),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  double _scaledPosition(double value, double canvasSize, double boardSize) {
    if (canvasSize <= 0) return 0;
    return value / canvasSize * boardSize;
  }
}

class _StudentTile extends StatelessWidget {
  const _StudentTile({
    required this.classSessionId,
    required this.student,
    required this.attendanceService,
    required this.designMode,
  });

  final String classSessionId;
  final StudentSummary student;
  final AttendanceService attendanceService;
  final bool designMode;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => showDialog<void>(
          context: context,
          builder: (context) => _PinDialog(
            classSessionId: classSessionId,
            student: student,
            attendanceService: attendanceService,
            designMode: designMode,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                student.name,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              _StatusPill(status: student.status),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final AttendanceStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      AttendanceStatus.present => const Color(0xFF1B7F4D),
      AttendanceStatus.late => const Color(0xFFB86E00),
      AttendanceStatus.absent => const Color(0xFFC62828),
      AttendanceStatus.waiting => const Color(0xFF59636E),
    };
    return Align(
      alignment: Alignment.centerLeft,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(status.label, style: TextStyle(color: color)),
        ),
      ),
    );
  }
}

class _LiveStatusPill extends StatelessWidget {
  const _LiveStatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'present' => const Color(0xFF1B7F4D),
      'late' => const Color(0xFFB86E00),
      'absent' => const Color(0xFFC62828),
      'excused' => const Color(0xFF4E6CB5),
      'left_early' => const Color(0xFF7B4FB0),
      _ => const Color(0xFF59636E),
    };
    return Align(
      alignment: Alignment.centerLeft,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(
            _attendanceStatusLabel(status),
            style: TextStyle(color: color),
          ),
        ),
      ),
    );
  }
}

class _LivePinDialog extends StatelessWidget {
  const _LivePinDialog({
    required this.classSessionId,
    required this.student,
    required this.attendanceService,
    required this.onCheckedIn,
    this.seatId,
  });

  final String classSessionId;
  final String? seatId;
  final AttendanceStudent student;
  final AttendanceService attendanceService;
  final VoidCallback onCheckedIn;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${student.name} 출석 체크'),
      content: _LivePinForm(
        classSessionId: classSessionId,
        seatId: seatId,
        student: student,
        attendanceService: attendanceService,
        onCheckedIn: onCheckedIn,
      ),
    );
  }
}

class _LivePinForm extends StatefulWidget {
  const _LivePinForm({
    required this.classSessionId,
    required this.student,
    required this.attendanceService,
    required this.onCheckedIn,
    this.seatId,
  });

  final String classSessionId;
  final String? seatId;
  final AttendanceStudent student;
  final AttendanceService attendanceService;
  final VoidCallback onCheckedIn;

  @override
  State<_LivePinForm> createState() => _LivePinFormState();
}

class _LivePinFormState extends State<_LivePinForm> {
  final _controller = TextEditingController();
  String? _errorText;
  var _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _errorText = null;
      _submitting = true;
    });
    try {
      final seatId = widget.seatId;
      if (seatId == null) {
        await widget.attendanceService.checkIn(
          classSessionId: widget.classSessionId,
          studentId: widget.student.id,
          pin: _controller.text,
        );
      } else {
        await widget.attendanceService.seatCheckIn(
          classSessionId: widget.classSessionId,
          studentId: widget.student.id,
          seatId: seatId,
          pin: _controller.text,
        );
      }
      if (mounted) {
        Navigator.pop(context);
        widget.onCheckedIn();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${widget.student.name} 출석 요청을 보냈습니다.')),
        );
      }
    } on AttendanceException catch (error) {
      setState(() => _errorText = error.message);
    } catch (_) {
      setState(() => _errorText = '출석 처리 중 문제가 발생했습니다.');
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _controller,
          autofocus: true,
          obscureText: true,
          maxLength: 6,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: '6자리 비밀번호',
            errorText: _errorText,
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (_) => _submitting ? null : _submit(),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: _submitting ? null : () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: Text(_submitting ? '처리 중' : '출석'),
            ),
          ],
        ),
      ],
    );
  }
}

class _PinDialog extends StatelessWidget {
  const _PinDialog({
    required this.classSessionId,
    required this.student,
    required this.attendanceService,
    required this.designMode,
  });

  final String classSessionId;
  final StudentSummary student;
  final AttendanceService attendanceService;
  final bool designMode;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${student.name} 출석 체크'),
      content: _PinForm(
        classSessionId: classSessionId,
        student: student,
        attendanceService: attendanceService,
        designMode: designMode,
      ),
    );
  }
}

class _PinForm extends StatefulWidget {
  const _PinForm({
    required this.classSessionId,
    required this.student,
    required this.attendanceService,
    required this.designMode,
  });

  final String classSessionId;
  final StudentSummary student;
  final AttendanceService attendanceService;
  final bool designMode;

  @override
  State<_PinForm> createState() => _PinFormState();
}

class _PinFormState extends State<_PinForm> {
  final _controller = TextEditingController();
  String? _errorText;
  var _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _errorText = null;
      _submitting = true;
    });

    try {
      if (widget.designMode) {
        if (!RegExp(r'^\d{6}$').hasMatch(_controller.text)) {
          throw const AttendanceException('출결 비밀번호는 숫자 6자리여야 합니다.');
        }
      } else {
        await widget.attendanceService.checkIn(
          classSessionId: widget.classSessionId,
          studentId: widget.student.id,
          pin: _controller.text,
        );
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${widget.student.name} 출석 요청을 보냈습니다.')),
        );
      }
    } on AttendanceException catch (error) {
      setState(() => _errorText = error.message);
    } catch (_) {
      setState(() => _errorText = '출석 처리 중 문제가 발생했습니다.');
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _controller,
          autofocus: true,
          obscureText: true,
          maxLength: 6,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: '6자리 비밀번호',
            errorText: _errorText,
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (_) => _submitting ? null : _submit(),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: _submitting ? null : () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: Text(_submitting ? '처리 중' : '출석'),
            ),
          ],
        ),
      ],
    );
  }
}

String _classKindLabel(String classKind) {
  return switch (classKind) {
    'makeup' => '보강',
    'extra' => '추가',
    _ => '기본',
  };
}

String _attendanceStatusLabel(String status) {
  return switch (status) {
    'present' => '출석',
    'late' => '지각',
    'absent' => '결석',
    'excused' => '인정결석',
    'left_early' => '조퇴',
    _ => '대기',
  };
}
