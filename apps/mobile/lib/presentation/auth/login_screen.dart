import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.read(authControllerProvider.notifier);
    final supabase = auth.supabaseEnabled;

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(24),
            children: [
              Text('Pádel CR',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              const Text('Tu nivel real de pádel', textAlign: TextAlign.center),
              const SizedBox(height: 32),
              if (_error != null) ...[
                Text(_error!, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 12),
              ],
              if (supabase) ...[
                TextField(
                  controller: _email,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _password,
                  decoration: const InputDecoration(labelText: 'Contraseña'),
                  obscureText: true,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _busy
                      ? null
                      : () => _run(() => auth.signInWithEmail(_email.text.trim(), _password.text)),
                  child: const Text('Entrar'),
                ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => _run(() => auth.signUpWithEmail(_email.text.trim(), _password.text)),
                  child: const Text('Crear cuenta'),
                ),
                const Divider(height: 32),
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _run(auth.signInWithGoogle),
                  icon: const Icon(Icons.g_mobiledata),
                  label: const Text('Continuar con Google'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _run(auth.signInWithApple),
                  icon: const Icon(Icons.apple),
                  label: const Text('Continuar con Apple'),
                ),
              ] else ...[
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Supabase no está configurado en este build. '
                      'Usa el modo desarrollo para probar el flujo contra el backend local.',
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _busy ? null : () => _run(() async => auth.signInDev()),
                  icon: const Icon(Icons.developer_mode),
                  label: const Text('Entrar en modo desarrollo'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
