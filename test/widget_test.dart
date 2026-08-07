import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:app_empaque/main.dart';

void main() {
  testWidgets('shows splash loader', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: SplashPage()));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('renders vineta detail page', (WidgetTester tester) async {
    final api = AuthApi(
      client: MockClient((request) async {
        return http.Response(
          jsonEncode({
            'message': 'OK',
            'product': {
              'id': 1,
              'codigo_producto': 'P-23955',
              'nombre': 'Toro',
            },
            'activities': [],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: appLightTheme,
        home: VinetaDetailPage(
          authApi: api,
          token: 'token',
          vineta: const VinetaInfo(
            id: 1,
            apiId: 1,
            nombre: 'Toro',
            marca: 'Marca',
            codigoProducto: 'P-23955',
            impreso: true,
          ),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('Informacion de viñeta'), findsOneWidget);
    expect(find.text('Empleado'), findsOneWidget);
    expect(find.text('Cant. puros'), findsOneWidget);
    expect(find.text('Actividades producto'), findsOneWidget);
  });
}
