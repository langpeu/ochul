import 'package:flutter/material.dart';

import '../../core/app_config.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({
    super.key,
    required this.config,
    required this.onSignedIn,
  });

  final AppConfig config;
  final VoidCallback onSignedIn;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Ochul',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '공부방 출결과 알림을 한 곳에서 관리합니다.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 24),
                  _ConfigStatus(config: config),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: onSignedIn,
                    icon: const Icon(Icons.mail_outline),
                    label: const Text('이메일로 시작'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: onSignedIn,
                    icon: const Icon(Icons.g_mobiledata),
                    label: const Text('Google로 시작'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: onSignedIn,
                    icon: const Icon(Icons.apple),
                    label: const Text('Apple로 시작'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ConfigStatus extends StatelessWidget {
  const _ConfigStatus({required this.config});

  final AppConfig config;

  @override
  Widget build(BuildContext context) {
    final configured = config.isSupabaseConfigured;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: configured ? const Color(0xFFEAF7EF) : const Color(0xFFFFF7E6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: configured ? const Color(0xFF9AD4B0) : const Color(0xFFE7C36D),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          configured
              ? '${config.environmentName} Supabase 설정이 감지되었습니다.'
              : 'Supabase 설정 없이 화면 설계 모드로 실행 중입니다.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}
