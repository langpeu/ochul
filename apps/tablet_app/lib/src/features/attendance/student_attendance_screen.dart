import 'package:flutter/material.dart';

import '../../core/app_config.dart';
import '../../core/edge_function_client.dart';
import '../../models/sample_data.dart';
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
