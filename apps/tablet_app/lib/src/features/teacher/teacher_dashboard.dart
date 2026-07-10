import 'package:flutter/material.dart';

import '../../core/app_config.dart';
import '../../core/edge_function_client.dart';
import '../../core/teacher_gate.dart';
import '../../models/sample_data.dart';
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

class _TeacherHomeHeader extends StatelessWidget {
  const _TeacherHomeHeader({required this.config, required this.service});

  final AppConfig config;
  final TeacherHomeService service;

  @override
  Widget build(BuildContext context) {
    if (!config.isSupabaseConfigured) {
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
      future: service.fetchMe(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const LinearProgressIndicator();
        }
        if (snapshot.hasError) {
          return _TeacherHomeError(message: snapshot.error.toString());
        }
        final home = snapshot.requireData;
        return _StudyRoomSummaryBar(
          teacherName: home.teacher.name,
          role: home.teacher.role,
          studyRooms: home.studyRooms,
          designMode: false,
        );
      },
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
