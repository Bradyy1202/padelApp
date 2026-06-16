import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/api_client.dart';
import '../../state/me_controller.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _city = TextEditingController();
  String _hand = 'R';
  String _side = 'BOTH';
  String _gender = 'NA';
  double _level = 3.0;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _city.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(apiClientProvider).completeOnboarding({
        'fullName': _name.text.trim(),
        'city': _city.text.trim().isEmpty ? null : _city.text.trim(),
        'dominantHand': _hand,
        'favSide': _side,
        'gender': _gender,
        'estLevel': _level,
      });
      ref.invalidate(meProvider);
      if (mounted) context.go('/');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Completa tu perfil')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                if (_error != null) ...[
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 12),
                ],
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Nombre completo *'),
                  validator: (v) =>
                      (v == null || v.trim().length < 2) ? 'Mínimo 2 caracteres' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _city,
                  decoration: const InputDecoration(labelText: 'Ciudad'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _hand,
                  decoration: const InputDecoration(labelText: 'Mano dominante'),
                  items: const [
                    DropdownMenuItem(value: 'R', child: Text('Derecha')),
                    DropdownMenuItem(value: 'L', child: Text('Izquierda')),
                  ],
                  onChanged: (v) => setState(() => _hand = v!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _side,
                  decoration: const InputDecoration(labelText: 'Lado favorito'),
                  items: const [
                    DropdownMenuItem(value: 'DRIVE', child: Text('Drive')),
                    DropdownMenuItem(value: 'REVES', child: Text('Revés')),
                    DropdownMenuItem(value: 'BOTH', child: Text('Ambos')),
                  ],
                  onChanged: (v) => setState(() => _side = v!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _gender,
                  decoration: const InputDecoration(labelText: 'Género'),
                  items: const [
                    DropdownMenuItem(value: 'M', child: Text('Masculino')),
                    DropdownMenuItem(value: 'F', child: Text('Femenino')),
                    DropdownMenuItem(value: 'OTHER', child: Text('Otro')),
                    DropdownMenuItem(value: 'NA', child: Text('Prefiero no decir')),
                  ],
                  onChanged: (v) => setState(() => _gender = v!),
                ),
                const SizedBox(height: 16),
                Text('Nivel estimado: ${_level.toStringAsFixed(1)}'),
                Slider(
                  value: _level,
                  min: 1.0,
                  max: 7.0,
                  divisions: 60,
                  label: _level.toStringAsFixed(1),
                  onChanged: (v) => setState(() => _level = v),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox(
                          height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Guardar y continuar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
