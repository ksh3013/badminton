abstract final class SupabaseConfig {
  static const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://ceyznuktsbuzvodolrdx.supabase.co',
  );

  static const publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_X0NXpaxZCVR63pfZF7szPg_4KhPtFDU',
  );

  static bool get isConfigured => publishableKey.isNotEmpty;
}
