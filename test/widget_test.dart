import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:app_empaque/main.dart';

void main() {
  test('normalizes server URL without empty query or fragment', () {
    expect(
      normalizeApiBaseUriForInput(
        'http://192.168.2.7:8081/api?source=app#settings',
      ).toString(),
      'http://192.168.2.7:8081/api',
    );
  });

  test('allows llenado before anillado and rejects same-group duplicates', () {
    const activity = ActivityInfo(nombre: 'Llenado de cajas');
    const pendingProcess = VinetaProcessInfo(
      steps: [
        VinetaProcessStepInfo(
          group: VinetaProcessGroup.anillado,
          label: 'Anillado',
        ),
        VinetaProcessStepInfo(
          group: VinetaProcessGroup.llenado,
          label: 'Llenado',
        ),
      ],
      canFill: false,
      fillBlockMessage: 'Falta completar anillado.',
    );
    const completedProcess = VinetaProcessInfo(
      steps: [
        VinetaProcessStepInfo(
          group: VinetaProcessGroup.llenado,
          label: 'Llenado',
          completed: true,
          employee: 'Empleado prueba',
        ),
      ],
      canFill: true,
    );

    expect(multiScanActivityErrorForProcess(activity, pendingProcess), isNull);
    expect(
      multiScanActivityErrorForProcess(activity, completedProcess),
      'Llenado ya esta registrado: Empleado prueba.',
    );
  });

  test(
    'sends task and hourly records with their respective time data',
    () async {
      final payloads = <Map<String, dynamic>>[];
      final api = AuthApi(
        client: MockClient((request) async {
          payloads.add(jsonDecode(request.body) as Map<String, dynamic>);

          return http.Response(
            jsonEncode({'registro': <String, dynamic>{}}),
            201,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      const vineta = VinetaInfo(id: 1, impreso: true);
      const activity = ActivityInfo(
        nombre: 'Llenado de cajas',
        precioMo: '2.5',
      );
      const employee = EmployeeInfo(
        id: 10,
        codigo: 'EMP-10',
        nombre: 'Empleado prueba',
        activo: true,
      );

      await api.saveVinetaRegistro(
        'token',
        vineta: vineta,
        activity: activity,
        employee: employee,
        cantidadPuros: 20,
        minutosTrabajados: 45,
        registradoEn: DateTime(2026, 8, 20, 8),
        taskMode: true,
      );
      await api.saveVinetaRegistro(
        'token',
        vineta: vineta,
        activity: activity,
        employee: employee,
        cantidadPuros: 20,
        minutosTrabajados: null,
        registradoEn: DateTime(2026, 8, 20, 9),
        taskMode: false,
      );

      expect(payloads[0]['modo_registro'], 'por_tarea');
      expect(payloads[0]['minutos_trabajados'], 45);
      expect(payloads[0]['precio_mo'], '2.5');
      expect(payloads[1]['modo_registro'], 'por_hora');
      expect(payloads[1].containsKey('minutos_trabajados'), isFalse);
      expect(payloads[1]['precio_mo'], 0);
    },
  );

  test('calculates pending multi-scan activities like the server', () {
    expect(multiScanActivityMultiplier('Rezagado'), 1);
    expect(multiScanActivityMultiplier('2 Anillos, Celofan'), 3);
    expect(multiScanActivityMultiplier('3 Sellos, 2 Bandas, Limpieza'), 6);
    expect(
      multiScanPendingActivities(
        quantityText: '20',
        activity: const ActivityInfo(nombre: '2 Anillos, Celofan'),
      ),
      60,
    );
    expect(multiScanPendingActivities(quantityText: '20', activity: null), 0);
    expect(
      multiScanPendingActivities(
        quantityText: '-10',
        activity: const ActivityInfo(nombre: 'Rezagado'),
      ),
      0,
    );
  });

  test('requests the general activity catalog only when enabled', () async {
    late Uri requestedUri;
    final api = AuthApi(
      client: MockClient((request) async {
        requestedUri = request.url;

        return http.Response(
          jsonEncode({
            'activities': [
              {
                'id': 7,
                'codigo_actividad': 'ACT-7',
                'nombre': 'Actividad general',
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final activities = await api.searchActivities(
      'token',
      generalCatalog: true,
    );

    expect(requestedUri.queryParameters['scope'], 'general');
    expect(requestedUri.queryParameters['limit'], '80');
    expect(activities.single.nombre, 'Actividad general');
  });

  test('updates a daily record with the selected catalog activity', () async {
    late http.Request sentRequest;
    final api = AuthApi(
      client: MockClient((request) async {
        sentRequest = request;

        return http.Response(
          jsonEncode({'message': 'Registro actualizado'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    const activity = ActivityInfo(
      id: 22,
      apiIdActividad: 202,
      codigoActividad: 'ACT-202',
      nombre: '2 Anillos, Celofan',
    );

    await api.updateDailyVinetaRegistro(
      'token',
      registroId: 15,
      date: DateTime(2026, 8, 19),
      time: '09:15',
      cantidadPuros: 20,
      empleadoCodigo: 'EMP-001',
      modoRegistro: 'por_tarea',
      minutosTrabajados: 45,
      activity: activity,
    );

    final payload = jsonDecode(sentRequest.body) as Map<String, dynamic>;

    expect(sentRequest.method, 'PATCH');
    expect(sentRequest.url.path, '/api/vineta-registros/15');
    expect(payload['actividad_id'], 22);
    expect(payload['api_id_actividad'], 202);
    expect(payload['codigo_actividad'], 'ACT-202');
    expect(payload['actividad_nombre'], '2 Anillos, Celofan');
    expect(payload.containsKey('actividad_tipo_empaque'), isFalse);
    expect(payload.containsKey('precio_mo'), isFalse);
  });

  testWidgets('record editor selects from the full activity catalog', (
    tester,
  ) async {
    Uri? searchUri;
    final api = AuthApi(
      client: MockClient((request) async {
        searchUri = request.url;

        return http.Response(
          jsonEncode({
            'activities': [
              {
                'id': 22,
                'api_id_actividad': 202,
                'codigo_actividad': 'ACT-202',
                'nombre': 'Actividad nueva',
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: appLightTheme,
        home: Scaffold(
          body: DailyRecordEditSheet(
            authApi: api,
            token: 'token',
            record: _dailyRecord(id: 1, brand: 'Padron'),
          ),
        ),
      ),
    );

    expect(find.text('Rezagado'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('daily-record-activity-selector')),
    );
    await tester.pumpAndSettle();

    expect(searchUri?.queryParameters['scope'], 'general');
    expect(searchUri?.queryParameters['limit'], '80');
    expect(find.text('Actividad nueva'), findsOneWidget);

    await tester.tap(find.text('Actividad nueva'));
    await tester.pumpAndSettle();

    expect(find.text('Actividad nueva'), findsOneWidget);
    expect(find.text('Rezagado'), findsNothing);
  });

  test('groups daily records by brand, item, ODS and customer order', () {
    final groups = dailyRecordsProductGroups([
      _dailyRecord(
        id: 1,
        brand: 'Padron',
        item: 'A',
        systemOrder: 'ODS-1',
        order: '100',
      ),
      _dailyRecord(
        id: 2,
        brand: 'Padron',
        item: 'B',
        systemOrder: 'ODS-1',
        order: '100',
      ),
      _dailyRecord(
        id: 3,
        brand: 'Padron',
        item: 'A',
        systemOrder: 'ODS-2',
        order: '100',
      ),
      _dailyRecord(
        id: 4,
        brand: 'Padron',
        item: 'A',
        systemOrder: 'ODS-1',
        order: '200',
      ),
      _dailyRecord(
        id: 5,
        brand: 'Oliva',
        item: 'A',
        systemOrder: 'ODS-1',
        order: '100',
      ),
    ]);

    expect(groups, hasLength(5));
    expect(groups.first.title, 'Padron');
    expect(groups.first.meta, 'Item A · ODS ODS-1 · Orden cliente 100');
    expect(groups.first.records, hasLength(1));
    expect(groups[1].title, 'Padron');
    expect(groups.last.title, 'Oliva');
  });

  test('calculates grouped vinetas, activities and puros', () {
    final group = dailyRecordsProductGroups([
      _dailyRecord(
        id: 1,
        brand: 'Padron',
        cajones: 2,
        activities: 3,
        puros: 1250,
      ),
      _dailyRecord(
        id: 2,
        brand: 'Padron',
        cajones: 1,
        activities: 4,
        puros: 1000,
      ),
    ]).single;

    expect(group.records, hasLength(2));
    expect(group.totalActividades, 7);
    expect(group.totalPuros, 2250);
  });

  test('orders daily record employees by activities before puros', () {
    final summaries = dailyRecordsEmployeeSummaries([
      _dailyRecord(
        id: 1,
        brand: 'Padron',
        employeeId: 1,
        employeeCode: '001',
        employeeName: 'Empleado Puros',
        puros: 200,
        activities: 1,
      ),
      _dailyRecord(
        id: 2,
        brand: 'Oliva',
        employeeId: 2,
        employeeCode: '002',
        employeeName: 'Empleado Actividades',
        puros: 20,
        activities: 4,
      ),
    ]);

    expect(summaries.first.codigo, '002');
    expect(summaries.first.totalActividades, 4);
  });

  test('classifies special records into their process groups', () {
    final llenadoActivities = [
      'Hecha de Paquete TUBO/5',
      'Hecha de Paquete TUBO/25',
      'Petaca 4 Puros',
      'Sampler COTSCO 10 Puros',
      'Sampler de 5',
    ];
    final anilladoActivities = [
      'Esponja',
      'Lamina',
      'Pegado de sello en celofan',
    ];

    for (final activityName in llenadoActivities) {
      final record = _dailyRecord(
        id: activityName.hashCode,
        brand: 'Padron',
        activityName: activityName,
      );

      expect(dailyRecordMatchesActivityGroup(record, 'llenado'), isTrue);
      expect(
        ActivityInfo(nombre: activityName).processGroup,
        VinetaProcessGroup.llenado,
      );
    }

    for (final activityName in anilladoActivities) {
      final record = _dailyRecord(
        id: activityName.hashCode,
        brand: 'Padron',
        activityName: activityName,
      );

      expect(dailyRecordMatchesActivityGroup(record, 'anillado'), isTrue);
      expect(
        ActivityInfo(nombre: activityName).processGroup,
        VinetaProcessGroup.anillado,
      );
    }
  });

  test('uses server activity group before local text matching', () {
    final record = _dailyRecord(
      id: 1,
      brand: 'Padron',
      activityName: 'Actividad especial',
      activityGroup: 'llenado',
    );

    expect(dailyRecordMatchesActivityGroup(record, 'llenado'), isTrue);
    expect(dailyRecordMatchesActivityGroup(record, 'rezago'), isFalse);
  });

  test('groups task records by employee position and hourly records apart', () {
    final rezagoDoingAnillado = _dailyRecord(
      id: 1,
      brand: 'Padron',
      activityName: 'Anillado',
      activityGroup: 'anillado',
      employeeGroup: 'rezago',
      employeeCargo: 'Rezaga Puros',
    );
    final hourly = _dailyRecord(
      id: 2,
      brand: 'Oliva',
      activityName: 'Llenado de cajas',
      activityGroup: 'llenado',
      employeeGroup: 'por_hora',
      porHora: true,
    );

    expect(
      dailyRecordMatchesEmployeeGroup(rezagoDoingAnillado, 'rezago'),
      isTrue,
    );
    expect(
      dailyRecordMatchesEmployeeGroup(rezagoDoingAnillado, 'anillado'),
      isFalse,
    );
    expect(dailyRecordsForEmployeeGroup([hourly], 'por_hora'), [hourly]);
    expect(dailyRecordsForEmployeeGroup([hourly], 'llenado'), isEmpty);
  });

  testWidgets('brand groups work as a single-open accordion', (tester) async {
    final records = [
      _dailyRecord(id: 1, brand: 'Padron'),
      _dailyRecord(id: 2, brand: 'Oliva'),
    ];
    final groups = dailyRecordsProductGroups(records);

    await tester.pumpWidget(
      MaterialApp(
        theme: appLightTheme,
        home: DailyRecordsEmployeeRecordsPage(
          authApi: AuthApi(),
          token: 'token',
          date: DateTime(2026, 8, 12),
          activityGroupKey: 'rezago',
          initialSummary: DailyRecordsEmployeeSummary(
            key: 'employee:1',
            codigo: '001',
            nombre: 'Empleado prueba',
            records: records,
          ),
        ),
      ),
    );

    DailyRecordsProductGroupCard card(String key) {
      return tester.widget<DailyRecordsProductGroupCard>(
        find.byKey(ValueKey('brand-group-$key')),
      );
    }

    expect(card(groups.first.key).expanded, isFalse);
    expect(card(groups.last.key).expanded, isFalse);
    expect(find.text('Subtotal'), findsNothing);
    expect(find.text('1 viñeta'), findsNWidgets(2));
    expect(find.text('1 actividad'), findsNWidgets(2));
    expect(find.text('20 puros'), findsNWidgets(2));
    expect(
      tester.widget<Text>(find.text('1 viñeta').first).style?.fontWeight,
      FontWeight.w400,
    );
    expect(
      tester.widget<Text>(find.text('1 actividad').first).style?.fontWeight,
      FontWeight.w900,
    );
    expect(
      tester.widget<Text>(find.text('20 puros').first).style?.fontWeight,
      FontWeight.w400,
    );

    final firstHeader = find.byKey(
      ValueKey('brand-accordion-${groups.first.key}'),
    );
    await tester.ensureVisible(firstHeader);
    await tester.tap(firstHeader);
    await tester.pumpAndSettle();

    expect(card(groups.first.key).expanded, isTrue);
    expect(card(groups.last.key).expanded, isFalse);

    final secondHeader = find.byKey(
      ValueKey('brand-accordion-${groups.last.key}'),
    );
    await tester.ensureVisible(secondHeader);
    await tester.tap(secondHeader);
    await tester.pumpAndSettle();

    expect(card(groups.first.key).expanded, isFalse);
    expect(card(groups.last.key).expanded, isTrue);
  });

  test('requests and parses the employee hours overview', () async {
    late Uri requestedUri;
    final api = AuthApi(
      client: MockClient((request) async {
        requestedUri = request.url;

        return http.Response(
          jsonEncode(_employeeHoursOverviewJson()),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final result = await api.employeeHoursOverview(
      'token',
      date: DateTime(2026, 8, 13),
    );

    expect(requestedUri.path, '/api/empleados/horas-ordinarias/resumen');
    expect(requestedUri.queryParameters['fecha'], '2026-08-13');
    expect(result.groupCounts, {'rezago': 2, 'anillado': 1, 'llenado': 1});
    expect(result.employees, hasLength(4));
    expect(result.employees.first.summary.totalMinutos, 180);
    expect(result.employees.first.summary.totalVinetas, 1);
    expect(result.employees.first.summary.totalPuros, 20);
    expect(result.employees.first.summary.totalActividades, 40);
    expect(result.employees.first.summary.minutosVinetas, 180);
  });

  test('sends the selected group when distributing a workday', () async {
    late http.Request capturedRequest;
    final api = AuthApi(
      client: MockClient((request) async {
        capturedRequest = request;

        return http.Response(
          jsonEncode({
            'message': 'Jornada laboral distribuida correctamente.',
            'registros_actualizados': 2,
            'minutos_distribuidos': 480,
            'tiempo_distribuido_texto': '8 h',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final result = await api.distributeEmployeeWorkday(
      'token',
      employeeId: 7,
      date: DateTime(2026, 8, 13),
      group: 'anillado',
      minutes: 480,
    );
    final payload = jsonDecode(capturedRequest.body) as Map<String, dynamic>;

    expect(capturedRequest.url.path, '/api/empleados/7/jornada-laboral');
    expect(payload['fecha'], '2026-08-13');
    expect(payload['grupo'], 'anillado');
    expect(payload['minutos'], 480);
    expect(result.registrosActualizados, 2);
  });

  test('sends the selected group when deleting an employee workday', () async {
    late http.Request capturedRequest;
    final api = AuthApi(
      client: MockClient((request) async {
        capturedRequest = request;

        return http.Response(
          jsonEncode({
            'message': 'Distribucion eliminada correctamente.',
            'registros_actualizados': 2,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    await api.deleteEmployeeWorkday(
      'token',
      employeeId: 7,
      date: DateTime(2026, 8, 13),
      group: 'rezago',
    );

    expect(capturedRequest.method, 'DELETE');
    expect(capturedRequest.url.path, '/api/empleados/7/jornada-laboral');
    expect(capturedRequest.url.queryParameters['fecha'], '2026-08-13');
    expect(capturedRequest.url.queryParameters['grupo'], 'rezago');
  });

  testWidgets('employee hours uses tabs, search and single-open accordions', (
    tester,
  ) async {
    Uri? requestedDetailUri;
    Map<String, dynamic>? updatedHourPayload;
    Map<String, dynamic>? updatedWorkdayPayload;
    final api = AuthApi(
      client: MockClient((request) async {
        if (request.url.path.endsWith('/horas-ordinarias/resumen')) {
          return http.Response(
            jsonEncode(_employeeHoursOverviewJson()),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        if (request.url.path.endsWith('/horas-ordinarias')) {
          requestedDetailUri = request.url;
          return http.Response(
            jsonEncode(_employeeHoursDayJson()),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        if (request.method == 'PATCH' &&
            request.url.path.endsWith('/horas-ordinarias/91')) {
          updatedHourPayload = jsonDecode(request.body) as Map<String, dynamic>;

          return http.Response(
            jsonEncode({
              'message': 'Hora ordinaria actualizada correctamente.',
              'hora_ordinaria': {
                'id': 91,
                'fecha': '2026-08-13',
                'minutos': 135,
                'tiempo_texto': '2 h 15 min',
                'observacion': 'Apoyo actualizado',
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        if (request.method == 'POST' &&
            request.url.path.endsWith('/jornada-laboral')) {
          updatedWorkdayPayload =
              jsonDecode(request.body) as Map<String, dynamic>;

          return http.Response(
            jsonEncode({
              'message': 'Jornada laboral distribuida correctamente.',
              'registros_actualizados': 1,
              'minutos_distribuidos': 195,
              'tiempo_distribuido_texto': '3 h 15 min',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        return http.Response(jsonEncode({'message': 'No encontrado'}), 404);
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: appLightTheme,
        home: EmployeeHoursSearchPage(authApi: api, token: 'token'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Rezago\n2'), findsOneWidget);
    expect(find.text('Anillado\n1'), findsOneWidget);
    expect(find.text('Llenado\n1'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(3));
    expect(find.text('Distribuir jornada laboral'), findsOneWidget);
    expect(
      find.textContaining('Se aplicara a los 2 empleados de Rezago'),
      findsOneWidget,
    );
    expect(find.text('Maria Rezago'), findsOneWidget);
    expect(find.text('Ana Anillado'), findsNothing);
    expect(find.text('1 viñetas · 20 puros · 40 actividades'), findsOneWidget);

    EmployeeHoursAccordionCard card(int employeeId) {
      return tester.widget<EmployeeHoursAccordionCard>(
        find.byKey(ValueKey('employee-hours-$employeeId')),
      );
    }

    expect(card(1).expanded, isFalse);

    await tester.tap(find.byKey(const ValueKey('employee-hours-toggle-1')));
    await tester.pumpAndSettle();

    expect(card(1).expanded, isTrue);
    expect(find.text('Resumen del dia'), findsOneWidget);
    expect(find.text('Viñetas del dia'), findsNothing);
    expect(requestedDetailUri?.queryParameters['grupo'], 'rezago');
    expect(find.text('Horas ordinarias agregadas'), findsOneWidget);
    expect(
      find.text('Distribución de jornada laboral agregada'),
      findsOneWidget,
    );
    expect(find.text('Agregar hora ordinaria'), findsOneWidget);
    expect(find.text('Distribuir jornada laboral'), findsOneWidget);
    expect(find.text('Cajones escaneados'), findsNothing);

    tester
        .widget<EmployeeHoursEntryTile>(
          find.byKey(const ValueKey('employee-workday-1')),
        )
        .onTap!();
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Editar'));
    await tester.pumpAndSettle();

    expect(find.text('Editar jornada distribuida'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('employee-workday-hours')),
      '3',
    );
    await tester.enterText(
      find.byKey(const ValueKey('employee-workday-minutes')),
      '15',
    );
    tester
        .widget<FilledButton>(
          find.byKey(const ValueKey('employee-workday-submit')),
        )
        .onPressed!();
    await tester.pumpAndSettle();

    expect(
      updatedWorkdayPayload?['fecha'],
      requestedDetailUri?.queryParameters['fecha'],
    );
    expect(updatedWorkdayPayload?['grupo'], 'rezago');
    expect(updatedWorkdayPayload?['minutos'], 195);

    final overviewScroll = find
        .descendant(
          of: find.byKey(const ValueKey('employee-hours-overview-list')),
          matching: find.byType(Scrollable),
        )
        .first;
    final hourTile = tester.widget<EmployeeHoursEntryTile>(
      find.widgetWithText(EmployeeHoursEntryTile, 'Apoyo de inventario'),
    );
    hourTile.onTap!();
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Editar'));
    await tester.pumpAndSettle();

    expect(find.text('Editar hora ordinaria'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('ordinary-hour-hours')))
          .controller
          ?.text,
      '1',
    );

    await tester.enterText(
      find.byKey(const ValueKey('ordinary-hour-hours')),
      '2',
    );
    await tester.enterText(
      find.byKey(const ValueKey('ordinary-hour-minutes')),
      '15',
    );
    await tester.enterText(
      find.byKey(const ValueKey('ordinary-hour-observation')),
      'Apoyo actualizado',
    );
    tester
        .widget<FilledButton>(
          find.byKey(const ValueKey('ordinary-hour-submit')),
        )
        .onPressed!();
    await tester.pumpAndSettle();

    expect(updatedHourPayload?['minutos'], 135);
    expect(updatedHourPayload?['observacion'], 'Apoyo actualizado');
    expect(find.text('Agregar hora ordinaria'), findsOneWidget);

    final secondToggle = find.byKey(const ValueKey('employee-hours-toggle-2'));
    await tester.scrollUntilVisible(
      secondToggle,
      500,
      scrollable: overviewScroll,
    );
    tester.widget<InkWell>(secondToggle).onTap!();
    await tester.pumpAndSettle();

    expect(card(2).expanded, isTrue);
    expect(find.text('Resumen del dia'), findsOneWidget);

    await tester.fling(
      find.byKey(const ValueKey('employee-hours-overview-list')),
      const Offset(0, 2000),
      2000,
    );
    await tester.pumpAndSettle();

    final anilladoTab = find.text('Anillado\n1');
    await tester.ensureVisible(anilladoTab);
    await tester.tap(anilladoTab);
    await tester.pumpAndSettle();

    expect(find.text('Ana Anillado'), findsOneWidget);
    expect(find.text('Maria Rezago'), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('employee-hours-search')),
      '999',
    );
    await tester.pump();

    expect(find.text('Ana Anillado'), findsNothing);
    expect(
      find.text('No hay empleados que coincidan con la busqueda.'),
      findsOneWidget,
    );
  });

  testWidgets('shows animated branded splash', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: SplashPage()));

    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
    expect(find.text('SISTEMA DE EMPAQUE'), findsOneWidget);
    expect(find.text('Plasencia Cigars'), findsOneWidget);
  });

  testWidgets('light login uses a transparent brand logo', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appLightTheme,
        home: LoginPage(
          authApi: AuthApi(),
          onLogin: (_) {},
          onServerUrlChanged: (value) async => value,
          isDarkMode: false,
          onToggleTheme: () {},
        ),
      ),
    );

    final background = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('login-background-decoration')),
    );
    final gradient = (background.decoration as BoxDecoration).gradient;

    expect(gradient, isA<LinearGradient>());
    expect((gradient! as LinearGradient).colors.first, Colors.white);
    expect(find.byType(LoginBrandHeader), findsOneWidget);
    expect(
      find.byKey(const ValueKey('login-transparent-logo')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('login-brand-image')), findsOneWidget);
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

Map<String, dynamic> _employeeHoursOverviewJson() {
  Map<String, dynamic> item({
    required int id,
    required String code,
    required String name,
    required String group,
    required String role,
    int totalMinutes = 0,
    int totalVinetas = 1,
    int totalPuros = 10,
    int totalActivities = 10,
  }) {
    return {
      'grupo': group,
      'empleado': {
        'id': id,
        'codigo': code,
        'nombre': name,
        'cargo': role,
        'area': 'Empaque',
        'activo': true,
      },
      'resumen': {
        'meta_minutos': 570,
        'meta_texto': '9 h 30 min',
        'total_vinetas': totalVinetas,
        'total_puros': totalPuros,
        'total_actividades': totalActivities,
        'minutos_vinetas': totalMinutes,
        'tiempo_vinetas_texto': '$totalMinutes min',
        'minutos_cajones': totalMinutes,
        'tiempo_cajones_texto': '$totalMinutes min',
        'minutos_ordinarios': 0,
        'tiempo_ordinario_texto': '0 min',
        'total_minutos': totalMinutes,
        'total_texto': '$totalMinutes min',
        'faltante_minutos': 570 - totalMinutes,
        'faltante_texto': '${570 - totalMinutes} min',
        'completado': false,
        'porcentaje': totalMinutes / 570 * 100,
      },
    };
  }

  return {
    'fecha': '2026-08-13',
    'tabla_disponible': true,
    'grupos': {'rezago': 2, 'anillado': 1, 'llenado': 1},
    'empleados': [
      item(
        id: 1,
        code: '100',
        name: 'Maria Rezago',
        group: 'rezago',
        role: 'Rezaga Puros',
        totalMinutes: 180,
        totalPuros: 20,
        totalActivities: 40,
      ),
      item(
        id: 2,
        code: '101',
        name: 'Jose Rezago',
        group: 'rezago',
        role: 'Rezaga Puros',
        totalPuros: 15,
        totalActivities: 15,
      ),
      item(
        id: 3,
        code: '200',
        name: 'Ana Anillado',
        group: 'anillado',
        role: 'Anilladora',
        totalPuros: 30,
        totalActivities: 30,
      ),
      item(
        id: 4,
        code: '300',
        name: 'Luis Llenado',
        group: 'llenado',
        role: 'Llenado de Cajas y Paquetes',
        totalPuros: 40,
        totalActivities: 120,
      ),
    ],
  };
}

Map<String, dynamic> _employeeHoursDayJson() {
  return {
    'tabla_disponible': true,
    'empleado': {
      'id': 1,
      'codigo': '100',
      'nombre': 'Maria Rezago',
      'cargo': 'Rezaga Puros',
      'area': 'Empaque',
      'activo': true,
    },
    'fecha': '2026-08-13',
    'resumen': {
      'meta_minutos': 570,
      'meta_texto': '9 h 30 min',
      'total_vinetas': 1,
      'total_puros': 20,
      'total_actividades': 40,
      'minutos_vinetas': 120,
      'tiempo_vinetas_texto': '2 h',
      'minutos_cajones': 120,
      'tiempo_cajones_texto': '2 h',
      'minutos_ordinarios': 60,
      'tiempo_ordinario_texto': '1 h',
      'total_minutos': 180,
      'total_texto': '3 h',
      'faltante_minutos': 390,
      'faltante_texto': '6 h 30 min',
      'completado': false,
      'porcentaje': 31.6,
    },
    'cajones': [
      {
        'id': 1,
        'vineta': 'ID 1',
        'actividad': 'Rezagado',
        'producto': 'Toro',
        'cantidad_puros': 20,
        'cantidad_actividades': 2,
        'total_actividades': 40,
        'minutos': 120,
        'tiempo_texto': '2 h',
        'registrado_en_texto': '13/08/2026 08:00 AM',
      },
    ],
    'horas_ordinarias': [
      {
        'id': 91,
        'fecha': '2026-08-13',
        'minutos': 60,
        'tiempo_texto': '1 h',
        'observacion': 'Apoyo de inventario',
        'registrado_por': 'Administrador',
        'created_at_texto': '13/08/2026 05:00 PM',
      },
    ],
    'jornada_laboral': {
      'registros_actualizados': 1,
      'minutos_distribuidos': 120,
      'tiempo_distribuido_texto': '2 h',
    },
  };
}

DailyVinetaRegistroInfo _dailyRecord({
  required int id,
  required String brand,
  String item = 'ITEM',
  String order = '100',
  String? systemOrder,
  int cajones = 1,
  int activities = 1,
  int puros = 20,
  int employeeId = 1,
  String employeeCode = '001',
  String employeeName = 'Empleado prueba',
  String activityName = 'Rezagado',
  String? activityGroup,
  String? employeeGroup,
  String? employeeCargo,
  bool porHora = false,
}) {
  return DailyVinetaRegistroInfo(
    id: id,
    producto: DailyVinetaRegistroProductInfo(
      codigoProducto: 'CODE-$id',
      item: item,
      nombre: brand,
      marca: brand,
    ),
    actividad: DailyVinetaRegistroActivityInfo(nombre: activityName),
    empleado: DailyVinetaRegistroEmployeeInfo(
      id: employeeId,
      codigo: employeeCode,
      nombre: employeeName,
      cargo: employeeCargo,
    ),
    cantidadPuros: puros,
    cantidadCajones: cajones,
    cantidadActividades: 1,
    modoRegistro: porHora ? 'por_hora' : 'por_tarea',
    porHora: porHora,
    totalActividades: activities,
    totalMo: 0,
    estado: 'activo',
    activityGroup: activityGroup,
    employeeGroup: employeeGroup,
    orden: order,
    ordenDelSistema: systemOrder,
  );
}
