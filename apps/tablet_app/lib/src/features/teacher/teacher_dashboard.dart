import 'package:flutter/material.dart';

import '../../core/teacher_gate.dart';
import '../../models/sample_data.dart';

class TeacherDashboard extends StatefulWidget {
  const TeacherDashboard({super.key});

  @override
  State<TeacherDashboard> createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends State<TeacherDashboard> {
  var _unlocked = false;
  final _gate = TeacherGate();

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
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _ClassPanel(classes: sampleClasses)),
                const SizedBox(width: 16),
                Expanded(child: _EnrollmentPanel(classes: sampleClasses)),
                const SizedBox(width: 16),
                const Expanded(child: _AuditPanel()),
              ],
            ),
          ),
        ],
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
