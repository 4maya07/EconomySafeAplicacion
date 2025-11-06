// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:appeconomysafe/datos/supabase/supabase_servicio.dart';
import 'package:appeconomysafe/main.dart';

void main() {
  testWidgets('EconomySafeApp muestra la vista de login', (WidgetTester tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await SupabaseServicio.iniciar();
    await tester.pumpWidget(
      const EconomySafeApp(temaInicial: ThemeMode.system),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Iniciar Sesión'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
  });
}
