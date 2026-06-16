import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';

/// Inicializa el cliente Supabase (auth, storage, realtime) si hay credenciales.
/// En Sprint 0 es opcional: la app arranca aunque no estén configuradas.
Future<void> initSupabase() async {
  if (!Env.hasSupabase) return;
  await Supabase.initialize(
    url: Env.supabaseUrl,
    // En supabase_flutter 2.14+ el parámetro es publishableKey (antes anonKey).
    publishableKey: Env.supabaseAnonKey,
  );
}
