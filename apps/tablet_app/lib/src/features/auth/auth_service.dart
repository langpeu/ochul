import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_config.dart';

class AuthService {
  const AuthService({required this.config, this.client});

  final AppConfig config;
  final SupabaseClient? client;

  SupabaseClient get _supabase => client ?? Supabase.instance.client;

  Session? get currentSession => _supabase.auth.currentSession;

  Stream<AuthState> get onAuthStateChange => _supabase.auth.onAuthStateChange;

  Future<void> sendEmailLink(String email) async {
    await _supabase.auth.signInWithOtp(
      email: email.trim(),
      emailRedirectTo: config.authRedirectUrl,
    );
  }

  Future<bool> signInWithGoogle() {
    return _supabase.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: config.authRedirectUrl,
    );
  }

  Future<bool> signInWithApple() {
    return _supabase.auth.signInWithOAuth(
      OAuthProvider.apple,
      redirectTo: config.authRedirectUrl,
    );
  }

  Future<void> signOut() => _supabase.auth.signOut();
}
