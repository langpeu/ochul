import 'package:flutter/material.dart';

import '../../models/sample_data.dart';

class StudentAttendanceScreen extends StatefulWidget {
  const StudentAttendanceScreen({super.key});

  @override
  State<StudentAttendanceScreen> createState() =>
      _StudentAttendanceScreenState();
}

class _StudentAttendanceScreenState extends State<StudentAttendanceScreen> {
  var _selectedClass = sampleClasses.first;

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
                  _StudentTile(student: student),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StudentTile extends StatelessWidget {
  const _StudentTile({required this.student});

  final StudentSummary student;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => showDialog<void>(
          context: context,
          builder: (context) => _PinDialog(student: student),
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
  const _PinDialog({required this.student});

  final StudentSummary student;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${student.name} 출석 체크'),
      content: const TextField(
        autofocus: true,
        obscureText: true,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: '6자리 비밀번호',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('출석'),
        ),
      ],
    );
  }
}
