/// Configuración de entorno inyectada en tiempo de compilación con `--dart-define`.
///
/// Ejemplo:
/// flutter run \
///   --dart-define=API_BASE_URL=http://10.0.2.2:3000/api/v1 \
///   --dart-define=SUPABASE_URL=https://YOUR.supabase.co \
///   --dart-define=SUPABASE_ANON_KEY=...
class Env {
  /// Base del backend NestJS. En el emulador Android, localhost del host es 10.0.2.2.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000/api/v1',
  );

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  static const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Indica si las credenciales de Supabase están configuradas.
  static bool get hasSupabase => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
