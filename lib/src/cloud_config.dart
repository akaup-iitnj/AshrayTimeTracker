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
}
