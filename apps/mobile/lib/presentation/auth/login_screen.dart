import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
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
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 16),
                _brandHero(theme),
                const SizedBox(height: 32),
                if (_error != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(_error!,
                        style: TextStyle(color: theme.colorScheme.onErrorContainer)),
                  ),
                if (supabase) ...[
                  TextField(
                    controller: _email,
                    decoration: const InputDecoration(
                        labelText: 'Email', prefixIcon: Icon(Icons.mail_outline)),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _password,
                    decoration: const InputDecoration(
                        labelText: 'Contraseña', prefixIcon: Icon(Icons.lock_outline)),
                    obscureText: true,
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _busy
                        ? null
                        : () => _run(
                            () => auth.signInWithEmail(_email.text.trim(), _password.text)),
                    child: _busy ? _spinner() : const Text('Entrar'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => _run(
                            () => auth.signUpWithEmail(_email.text.trim(), _password.text)),
                    child: const Text('Crear cuenta'),
                  ),
                  Row(children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('o', style: theme.textTheme.bodySmall),
                    ),
                    const Expanded(child: Divider()),
                  ]),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => _run(auth.signInWithGoogle),
                    icon: const Icon(Icons.g_mobiledata, size: 28),
                    label: const Text('Continuar con Google'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => _run(auth.signInWithApple),
                    icon: const Icon(Icons.apple),
                    label: const Text('Continuar con Apple'),
                  ),
                ] else ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: theme.colorScheme.primary),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Supabase no está configurado en este build. '
                              'Entra en modo desarrollo para probar el flujo.',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _busy ? null : () => _run(() async => auth.signInDev()),
                    icon: const Icon(Icons.bolt),
                    label: _busy ? _spinner() : const Text('Entrar en modo desarrollo'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _brandHero(ThemeData theme) {
    return Column(
      children: [
        Container(
          height: 88,
          width: 88,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: AppColors.heroGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppColors.brand.withValues(alpha: 0.35),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Icon(Icons.sports_tennis, color: Colors.white, size: 44),
        ),
        const SizedBox(height: 20),
        Text('Pádel CR', style: theme.textTheme.displaySmall),
        const SizedBox(height: 6),
        Text(
          'Tu nivel real de pádel',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _spinner() => const SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
      );
}
