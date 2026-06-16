import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../core/config/env.dart';
import '../domain/auth_session.dart';

/// UUID fijo para el usuario en modo desarrollo (coincide con el bypass del backend).
const _devUserId = '11111111-1111-1111-1111-111111111111';

final authControllerProvider =
    NotifierProvider<AuthController, AuthSession?>(AuthController.new);

class AuthController extends Notifier<AuthSession?> {
  @override
  AuthSession? build() {
    if (Env.hasSupabase) {
      final session = sb.Supabase.instance.client.auth.currentSession;
      // Reacciona a cambios de sesión de Supabase.
      final sub = sb.Supabase.instance.client.auth.onAuthStateChange.listen((data) {
        final s = data.session;
        state = s == null
            ? null
            : AuthSession(userId: s.user.id, accessToken: s.accessToken);
      });
      ref.onDispose(sub.cancel);
      if (session != null) {
        return AuthSession(userId: session.user.id, accessToken: session.accessToken);
      }
    }
    return null;
  }

  bool get supabaseEnabled => Env.hasSupabase;

  Future<void> signInWithEmail(String email, String password) async {
    final res = await sb.Supabase.instance.client.auth
        .signInWithPassword(email: email, password: password);
    final s = res.session;
    if (s != null) {
      state = AuthSession(userId: s.user.id, accessToken: s.accessToken);
    }
  }

  Future<void> signUpWithEmail(String email, String password) async {
    await sb.Supabase.instance.client.auth.signUp(email: email, password: password);
  }

  Future<void> signInWithGoogle() =>
      sb.Supabase.instance.client.auth.signInWithOAuth(sb.OAuthProvider.google);

  Future<void> signInWithApple() =>
      sb.Supabase.instance.client.auth.signInWithOAuth(sb.OAuthProvider.apple);

  /// Login de desarrollo (sin Supabase): usa el bypass del backend.
  void signInDev() {
    state = const AuthSession(userId: _devUserId, isDev: true);
  }

  Future<void> signOut() async {
    if (Env.hasSupabase) {
      await sb.Supabase.instance.client.auth.signOut();
    }
    state = null;
  }
}
