import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_register/src/models.dart';
import 'package:workout_register/src/routine_editor.dart';
import 'package:workout_register/src/workout_screen.dart';
import 'package:workout_register/src/progress_screen.dart';

void main() {
  test('Session preserves sets and calculates repetitions and volume', () {
    final session = Session('Treino A', DateTime(2026, 9, 25), {
      'Supino': [
        TrainingSet(reps: '12', weight: '20,5'),
        TrainingSet(reps: '10', weight: '25'),
      ],
    });
    final restored = Session.fromJson(session.toJson());
    expect(restored.repetitions, 22);
    expect(restored.volume, 496);
    expect(restored.exercises['Supino']!.first.valid, isTrue);
    expect(TrainingSet(reps: '0', weight: '10').valid, isFalse);
    expect(TrainingSet(reps: '10', weight: 'NaN').valid, isFalse);
    expect(TrainingSet(reps: '10', weight: '0').valid, isTrue);
  });

  testWidgets('Routine modal validates and returns the new routine', (
    tester,
  ) async {
    Routine? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                saved = await showModalBottomSheet<Routine>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => const RoutineEditor(),
                );
              },
              child: const Text('Criar'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Criar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar rotina'));
    await tester.pumpAndSettle();
    expect(
      find.text('Informe um nome e pelo menos um exercício.'),
      findsOneWidget,
    );
    await tester.enterText(find.byType(TextField).at(0), 'Treino A');
    await tester.enterText(find.byType(TextField).at(1), 'Supino');
    await tester.tap(find.byTooltip('Adicionar exercício'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Salvar rotina'));
    await tester.tap(find.text('Salvar rotina'));
    await tester.pumpAndSettle();
    expect(saved?.name, 'Treino A');
    expect(saved?.exercises, ['Supino']);
  });

  testWidgets('Workout supports multiple sets, removal, and saving', (
    tester,
  ) async {
    Session? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: WorkoutScreen(
          routine: Routine('1', 'Treino A', ['Supino']),
          onFinish: (session) async {
            saved = session;
          },
        ),
      ),
    );
    await tester.tap(find.text('Adicionar série'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), '12');
    await tester.enterText(find.byType(TextFormField).at(1), '20,5');
    await tester.tap(find.text('Adicionar série'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(2), '10');
    await tester.enterText(find.byType(TextFormField).at(3), '25');
    await tester.ensureVisible(find.byTooltip('Remover série 1'));
    await tester.tap(find.byTooltip('Remover série 1'));
    await tester.pumpAndSettle();
    expect(find.text('10'), findsOneWidget);
    expect(find.text('25'), findsOneWidget);
    await tester.ensureVisible(find.text('Concluir treino'));
    await tester.tap(find.text('Concluir treino'));
    await tester.pumpAndSettle();
    expect(saved?.repetitions, 10);
    expect(saved?.volume, 250);
    expect(saved?.routineId, '1');
    expect(saved?.startedAt, isNotNull);
    expect(saved?.endedAt, isNotNull);
    expect(saved!.endedAt!.isBefore(saved!.startedAt!), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Workout rejects incomplete sets outside the viewport', (
    tester,
  ) async {
    var saved = false;
    await tester.pumpWidget(
      MaterialApp(
        home: WorkoutScreen(
          routine: Routine(
            'long',
            'Treino longo',
            List.generate(10, (i) => 'Exercício $i'),
          ),
          onFinish: (_) async {
            saved = true;
          },
        ),
      ),
    );
    await tester.tap(find.text('Adicionar série').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '10');
    await tester.scrollUntilVisible(
      find.text('Concluir treino'),
      450,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Concluir treino'));
    await tester.tap(find.text('Concluir treino'));
    await tester.pumpAndSettle();
    expect(saved, isFalse);
    expect(
      find.text(
        'Preencha repetições e peso de todas as séries antes de concluir.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('Progress renders empty state and chart at mobile width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ProgressScreen(sessions: [])),
      ),
    );
    expect(find.text('Sua evolução começa no próximo treino.'), findsOneWidget);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProgressScreen(
            sessions: [
              Session('Treino A', DateTime.now(), {
                'Supino': [TrainingSet(reps: '10', weight: '20')],
              }),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('200'), findsOneWidget);
    await tester.tap(find.text('30 dias'));
    await tester.tap(find.text('Volume em kg'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
