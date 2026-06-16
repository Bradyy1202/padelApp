import { validateEnv } from './env.validation';

describe('validateEnv', () => {
  it('acepta config con DATABASE_URL en desarrollo', () => {
    const cfg = { NODE_ENV: 'development', DATABASE_URL: 'postgres://x' };
    expect(validateEnv(cfg)).toBe(cfg);
  });

  it('falla si falta DATABASE_URL', () => {
    expect(() => validateEnv({ NODE_ENV: 'development' })).toThrow(/DATABASE_URL/);
  });

  it('exige variables de Supabase y QR en producción', () => {
    expect(() =>
      validateEnv({ NODE_ENV: 'production', DATABASE_URL: 'postgres://x' }),
    ).toThrow(/SUPABASE_URL/);
  });
});
