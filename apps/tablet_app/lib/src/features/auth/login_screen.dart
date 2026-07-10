import 'package:flutter/material.dart';

import '../../core/app_config.dart';
import 'auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.config,
    required this.authService,
    required this.onDesignModeSignedIn,
  });

  final AppConfig config;
  final AuthService? authService;
  final VoidCallback onDesignModeSignedIn;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  String? _message;
  var _submitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendEmailLink() async {
    if (!widget.config.isSupabaseConfigured) {
      widget.onDesignModeSignedIn();
      return;
    }

    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _message = '이메일 주소를 입력해 주세요.');
      return;
    }

    await _runAuthAction(() async {
      await widget.authService!.sendEmailLink(email);
      if (mounted) {
        setState(() => _message = '로그인 링크를 이메일로 보냈습니다.');
      }
    });
  }

  Future<void> _signInWithGoogle() async {
    if (!widget.config.isSupabaseConfigured) {
      widget.onDesignModeSignedIn();
      return;
    }
    await _runAuthAction(() async {
      final launched = await widget.authService!.signInWithGoogle();
      if (!launched && mounted) {
        setState(() => _message = 'Google 로그인 창을 열지 못했습니다.');
      }
    });
  }

  Future<void> _signInWithApple() async {
    if (!widget.config.isSupabaseConfigured) {
      widget.onDesignModeSignedIn();
      return;
    }
    await _runAuthAction(() async {
      final launched = await widget.authService!.signInWithApple();
      if (!launched && mounted) {
        setState(() => _message = 'Apple 로그인 창을 열지 못했습니다.');
      }
    });
  }

  Future<void> _runAuthAction(Future<void> Function() action) async {
    setState(() {
      _submitting = true;
      _message = null;
    });

    try {
      await action();
    } catch (_) {
      if (mounted) {
        setState(() => _message = '로그인 요청을 처리하지 못했습니다.');
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final configured = widget.config.isSupabaseConfigured;
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
                  _ConfigStatus(config: widget.config),
                  if (configured) ...[
                    const SizedBox(height: 24),
                    TextField(
                      controller: _emailController,
                      enabled: !_submitting,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(
                        labelText: '이메일',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _sendEmailLink(),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _submitting ? null : _sendEmailLink,
                    icon: const Icon(Icons.mail_outline),
                    label: Text(configured ? '이메일 링크 받기' : '이메일로 시작'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _submitting ? null : _signInWithGoogle,
                    icon: const Icon(Icons.g_mobiledata),
                    label: const Text('Google로 시작'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _submitting ? null : _signInWithApple,
                    icon: const Icon(Icons.apple),
                    label: const Text('Apple로 시작'),
                  ),
                  if (_message != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _message!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
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
