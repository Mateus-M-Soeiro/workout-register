import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_register/src/models.dart';
import 'package:workout_register/src/exercises_screen.dart';
import 'package:workout_register/src/workout_screen.dart';

void main() {
  test(
    'Deleted exercises stay deleted through reload and unrelated saves',
    () async {
      String? disk;
      WorkoutStore open() => WorkoutStore(
        read: () async => disk,
        write: (s) async {
          disk = s;
        },
      );
      final store = open();
      final routine = Routine('1', 'A', ['Supino']);
      await store.save(
        routines: [routine],
        active: ActiveWorkout.start(routine),
      );
      await store.save(deleteExercise: 'Supino');
      await store.save(
        sessions: [
          Session('A', DateTime.now(), {'Supino': []}),
        ],
      );
      final reopened = open();
      await reopened.load();
      expect(reopened.catalog, isEmpty);
      expect(reopened.routines.single.exercises, ['Supino']);
      expect(reopened.active!.exercises.keys, ['Supino']);
      expect(reopened.sessions.single.exercises.keys, ['Supino']);
      await reopened.save(exercise: ExerciseDefinition('Supino', {'peito'}));
      expect(reopened.catalog.single.groups, {'peito'});
    },
  );

  test(
    'Rename updates routines but preserves historical and active snapshots',
    () async {
      final store = WorkoutStore(write: (_) async {});
      final routine = Routine('1', 'A', ['Supino']);
      await store.save(
        routines: [routine],
        active: ActiveWorkout.start(routine),
        sessions: [
          Session('A', DateTime.now(), {'Supino': []}),
        ],
      );
      await store.save(
        exercise: ExerciseDefinition('Supino reto', {'peito', 'triceps'}),
        previousExerciseName: 'Supino',
      );
      expect(store.catalog.map((e) => e.name), ['Supino reto']);
      expect(store.routines.single.exercises, ['Supino reto']);
      expect(store.active!.exercises.keys, ['Supino']);
      expect(store.sessions.single.exercises.keys, ['Supino']);
    },
  );

  testWidgets('Management allows edit and asks before deleting', (
    tester,
  ) async {
    final store = WorkoutStore(write: (_) async {});
    await store.save(exercise: ExerciseDefinition('Supino'));
    await tester.pumpWidget(MaterialApp(home: ExercisesScreen(store: store)));
    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Supino reto');
    await tester.tap(find.text('Peitoral'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'Peitoral Clavicular'));
    await tester.tap(find.text('Salvar exercício'));
    await tester.pumpAndSettle();
    expect(find.text('Supino reto'), findsOneWidget);
    expect(store.catalog.single.groups, {'peitoral_clavicular'});
    await tester.tap(find.text('Excluir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(store.catalog.length, 1);
    await tester.tap(find.text('Excluir'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Excluir'));
    await tester.pumpAndSettle();
    expect(store.catalog, isEmpty);
    expect(find.text('Nenhum exercício salvo.'), findsOneWidget);
  });

  testWidgets('Abort cancels safely or clears draft without creating history', (
    tester,
  ) async {
    final store = WorkoutStore(write: (_) async {});
    final routine = Routine('1', 'A', ['Supino']);
    await store.save(active: ActiveWorkout.start(routine));
    var finishes = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: WorkoutScreen(
          routine: routine,
          draft: store.active,
          onFinish: (_) async {
            finishes++;
          },
          onDiscard: () => store.save(clearActive: true),
        ),
      ),
    );
    await tester.tap(find.text('Abortar treino'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar treino'));
    await tester.pumpAndSettle();
    expect(store.active, isNotNull);
    await tester.tap(find.text('Abortar treino'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Abortar'));
    await tester.pumpAndSettle();
    expect(store.active, isNull);
    expect(store.sessions, isEmpty);
    expect(finishes, 0);
  });
}
