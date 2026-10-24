abstract final class CloudConfig {
  static const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://zezemjwngaqcccnqzirl.supabase.co',
  );

  // Supabase publishable keys are intended to be embedded in public clients.
  static const publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_1G7ieKegP4uNNhoY6iSf4w_1v0li7P_',
  );

  /// Where Google sign-in returns to on Android: a link the app claims in
  /// AndroidManifest.xml. It must be in Supabase's Redirect URLs list.
  static const mobileAuthRedirect = 'chronicler://login-callback';
}
