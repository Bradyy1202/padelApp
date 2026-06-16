/// Sesión autenticada. Puede provenir de Supabase (accessToken) o del modo
/// desarrollo (isDev → el backend acepta el header x-dev-user-id).
class AuthSession {
  final String userId;
  final String? accessToken;
  final bool isDev;

  const AuthSession({required this.userId, this.accessToken, this.isDev = false});
}
