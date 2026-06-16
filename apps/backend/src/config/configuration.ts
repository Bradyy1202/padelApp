/**
 * Configuración centralizada leída de variables de entorno.
 * Se carga vía ConfigModule (ver app.module.ts).
 */
export interface AppConfig {
  env: string;
  port: number;
  apiPrefix: string;
  databaseUrl: string;
  supabase: {
    url: string;
    jwksUrl: string;
    serviceRoleKey: string;
    anonKey: string;
  };
  redis: { host: string; port: number };
  qr: { jwtSecret: string; ttlSeconds: number };
}

export default (): AppConfig => ({
  env: process.env.NODE_ENV ?? 'development',
  port: parseInt(process.env.PORT ?? '3000', 10),
  apiPrefix: process.env.API_PREFIX ?? 'api/v1',
  databaseUrl: process.env.DATABASE_URL ?? '',
  supabase: {
    url: process.env.SUPABASE_URL ?? '',
    jwksUrl: process.env.SUPABASE_JWKS_URL ?? '',
    serviceRoleKey: process.env.SUPABASE_SERVICE_ROLE_KEY ?? '',
    anonKey: process.env.SUPABASE_ANON_KEY ?? '',
  },
  redis: {
    host: process.env.REDIS_HOST ?? 'localhost',
    port: parseInt(process.env.REDIS_PORT ?? '6379', 10),
  },
  qr: {
    jwtSecret: process.env.QR_JWT_SECRET ?? 'dev-secret',
    ttlSeconds: parseInt(process.env.QR_TOKEN_TTL_SECONDS ?? '7200', 10),
  },
});
