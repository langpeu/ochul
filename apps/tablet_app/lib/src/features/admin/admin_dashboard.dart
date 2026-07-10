import 'package:flutter/material.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('관리자 모드', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              children: const [
                Expanded(
                  child: _AdminListCard(
                    title: '선생님',
                    items: ['홍선생', '김선생', '박선생'],
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: _AdminListCard(
                    title: '공부방',
                    items: ['홍선생 공부방', '수학 집중반'],
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: _AdminListCard(
                    title: '학생',
                    items: ['김도윤', '이서연', '박지호'],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminListCard extends StatelessWidget {
  const _AdminListCard({required this.title, required this.items});

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            for (final item in items)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.chevron_right),
                title: Text(item),
              ),
          ],
        ),
      ),
    );
  }
}
