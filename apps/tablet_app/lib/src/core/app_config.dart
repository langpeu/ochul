class AppConfig {
  const AppConfig({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.environmentName,
    required this.authRedirectUrl,
  });

  factory AppConfig.fromEnvironment() {
    const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
    const publishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
    return AppConfig(
      supabaseUrl: const String.fromEnvironment('SUPABASE_URL'),
      supabaseAnonKey: anonKey.isNotEmpty ? anonKey : publishableKey,
      authRedirectUrl: const String.fromEnvironment(
        'AUTH_REDIRECT_URL',
        defaultValue: 'ochul://auth-callback',
      ),
      environmentName: const String.fromEnvironment(
        'APP_ENV',
        defaultValue: 'development',
      ),
    );
  }

  final String supabaseUrl;
  final String supabaseAnonKey;
  final String environmentName;
  final String authRedirectUrl;

  bool get isSupabaseConfigured =>
      supabaseUrl.trim().isNotEmpty && supabaseAnonKey.trim().isNotEmpty;
}
