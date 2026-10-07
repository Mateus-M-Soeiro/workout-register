import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_register/src/models.dart';
import 'package:workout_register/src/history_screen.dart';
import 'package:workout_register/src/workout_screen.dart';

void main() {
  test(
    'Timing survives serialization and legacy records have no invented start',
    () {
      final start = DateTime(2026, 9, 25, 23, 50);
      final end = DateTime(2026, 9, 26, 0, 30);
      final restored = Session.fromJson(
        Session(
          'A',
          start,
          {'Supino': []},
          routineId: '1',
          startedAt: start,
          endedAt: end,
        ).toJson(),
      );
      expect(restored.startedAt, start);
      expect(restored.endedAt, end);
      expect(restored.routineId, '1');
      final legacy = Session.fromJson({
        'routine': 'A',
        'date': end.toIso8601String(),
        'exercises': <String, dynamic>{},
      });
      expect(legacy.startedAt, isNull);
      expect(legacy.endedAt, end);
    },
  );

  test('History uses routine identity after rename and sorts newest first', () {
    final older = Session(
      'Nome antigo',
      DateTime(2026, 1, 1),
      {},
      routineId: '1',
    );
    final newest = Session(
      'Nome antigo',
      DateTime(2026, 1, 2),
      {},
      routineId: '1',
    );
    final unrelated = Session(
      'Nome novo',
      DateTime(2026, 1, 3),
      {},
      routineId: '2',
    );
    expect(
      historyForRoutine([
        older,
        unrelated,
        newest,
      ], Routine('1', 'Nome novo', [])),
      [newest, older],
    );
  });

  testWidgets('Last set can be removed and exercise saved without sets', (
    tester,
  ) async {
    Session? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: WorkoutScreen(
          routine: Routine('1', 'A', ['Supino']),
          onFinish: (session) async {
            saved = session;
          },
        ),
      ),
    );
    expect(find.byType(TextFormField), findsNothing);
    await tester.tap(find.text('Adicionar série'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Remover série 1'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Concluir treino'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Concluir treino'));
    await tester.pumpAndSettle();
    expect(saved, isNotNull);
    expect(saved!.exercises['Supino'], isEmpty);
    expect(saved!.repetitions, 0);
  });

  testWidgets('Previous workout values are shown without filling new sets', (
    tester,
  ) async {
    final previous = Session('A', DateTime(2026, 9, 24), {
      'Supino': [TrainingSet(reps: '12', weight: '22,5')],
    }, routineId: '1');
    await tester.pumpWidget(
      MaterialApp(
        home: WorkoutScreen(
          routine: Routine('1', 'A', ['Supino']),
          previous: previous,
          onFinish: (_) async {},
        ),
      ),
    );
    expect(find.text('Série 1: 12 reps × 22,5 kg'), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
  });

  testWidgets('History shows individual values and empty exercises', (
    tester,
  ) async {
    final start = DateTime(2026, 9, 25, 10);
    await tester.pumpWidget(
      MaterialApp(
        home: HistoryScreen(
          sessions: [
            Session(
              'A',
              start,
              {
                'Supino': [TrainingSet(reps: '12', weight: '22,5')],
                'Agachamento': [],
              },
              routineId: '1',
              startedAt: start,
              endedAt: start.add(const Duration(minutes: 30)),
            ),
          ],
        ),
      ),
    );
    expect(find.text('Início: 25/09/2026 às 10:00:00'), findsOneWidget);
    expect(find.text('Fim: 25/09/2026 às 10:30:00'), findsOneWidget);
    await tester.tap(find.text('Supino'));
    await tester.pumpAndSettle();
    expect(find.text('22,5'), findsOneWidget);
    await tester.tap(find.text('Agachamento'));
    await tester.pumpAndSettle();
    expect(find.text('Nenhuma série registrada.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
