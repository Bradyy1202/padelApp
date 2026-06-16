import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:padel/main.dart';

void main() {
  testWidgets('Sin sesión, la app muestra el login', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: PadelApp()));
    await tester.pumpAndSettle();

    expect(find.byType(MaterialApp), findsOneWidget);
    // Sin Supabase configurado, el login ofrece el modo desarrollo.
    expect(find.text('Entrar en modo desarrollo'), findsOneWidget);
  });
}
