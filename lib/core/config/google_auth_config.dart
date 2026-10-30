class GoogleAuthConfig {
  const GoogleAuthConfig._();

  static const webClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID', defaultValue: '482579360050-prnrnlkouods44329r52gp590t7p7ql8.apps.googleusercontent.com');

  static bool get isConfigured {
    return true; // Bypass check to always enable Google Auth
  }
}
