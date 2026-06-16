/**
 * Validación mínima de variables de entorno al arrancar.
 * Falla rápido si falta una variable crítica en producción.
 */
export function validateEnv(config: Record<string, unknown>): Record<string, unknown> {
  const isProd = config.NODE_ENV === 'production';
  const required = ['DATABASE_URL'];
  const requiredInProd = [
    'SUPABASE_URL',
    'SUPABASE_JWKS_URL',
    'SUPABASE_SERVICE_ROLE_KEY',
    'QR_JWT_SECRET',
  ];

  const missing: string[] = [];
  for (const key of required) {
    if (!config[key]) missing.push(key);
  }
  if (isProd) {
    for (const key of requiredInProd) {
      if (!config[key]) missing.push(key);
    }
  }

  if (missing.length > 0) {
    throw new Error(`Variables de entorno faltantes: ${missing.join(', ')}`);
  }
  return config;
}
