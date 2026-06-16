import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:padel/main.dart';
import 'package:padel/state/health_provider.dart';

void main() {
  testWidgets('La app arranca y muestra la bienvenida', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        // Evita HTTP real en el test: el estado de salud se fija.
        overrides: [healthProvider.overrideWith((ref) async => 'ok')],
        child: const PadelApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('Bienvenido a Pádel CR'), findsOneWidget);
    expect(find.text('ok'), findsOneWidget);
  });
}
