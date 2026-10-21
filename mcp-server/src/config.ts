export interface ServerConfig {
  supabaseUrl: string;
  publishableKey: string;
  accessToken: string;
  refreshToken?: string;
}

function required(
  environment: NodeJS.ProcessEnv,
  name: string,
): string {
  const value = environment[name]?.trim();
  if (!value) throw new Error(`Missing required environment variable: ${name}`);
  return value;
}

export function loadConfig(
  environment: NodeJS.ProcessEnv = process.env,
): ServerConfig {
  return {
    supabaseUrl: required(environment, 'SUPABASE_URL'),
    publishableKey: required(environment, 'SUPABASE_PUBLISHABLE_KEY'),
    accessToken: required(environment, 'TIME_TRACKER_ACCESS_TOKEN'),
    refreshToken: environment.TIME_TRACKER_REFRESH_TOKEN?.trim() || undefined,
  };
}
