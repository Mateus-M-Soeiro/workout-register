import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_register/src/models.dart';
import 'package:workout_register/src/workout_screen.dart';
import 'package:workout_register/src/progress_screen.dart';

void main() {
  test('Hierarchy supports old groups and all requested subcategories', () {
    expect(exerciseCategoryTree['peito']!.length, 3);
    expect(exerciseCategoryTree['costas']!.length, 4);
    expect(exerciseCategoryTree['pernas']!.length, 6);
    expect(exerciseCategoryTree['braco'], ['triceps', 'biceps', 'antebraco']);
    expect(exerciseCategoryTree['abdomen'], isEmpty);
    final exercise = ExerciseDefinition.fromJson(
      ExerciseDefinition('Supino', {'peitoral_clavicular', 'triceps'}).toJson(),
    );
    expect(matchesExerciseGroup(exercise, 'peito'), isTrue);
    expect(matchesExerciseGroup(exercise, 'braco'), isTrue);
    expect(matchesExerciseGroup(exercise, 'costas'), isFalse);
    expect(
      matchesExerciseGroup(ExerciseDefinition('Rosca', {'biceps'}), 'braco'),
      isTrue,
    );
  });

  testWidgets(
    'Added exercise belongs only to the active session and its history',
    (tester) async {
      final routine = Routine('1', 'A', ['Supino']);
      ActiveWorkout? draft;
      Session? finished;
      await tester.pumpWidget(
        MaterialApp(
          home: WorkoutScreen(
            routine: routine,
            catalog: () => [
              ExerciseDefinition('Remada', {'dorsal'}),
            ],
            onDraft: (value) async {
              draft = ActiveWorkout.fromJson(value.toJson());
            },
            onFinish: (value) async {
              finished = value;
            },
          ),
        ),
      );
      await tester.scrollUntilVisible(
        find.text('Adicionar exercício ao treino'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Adicionar exercício ao treino'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Costas'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remada'));
      await tester.pumpAndSettle();
      expect(draft!.exercises.keys, ['Supino', 'Remada']);
      expect(routine.exercises, ['Supino']);
      await tester.scrollUntilVisible(
        find.text('Concluir treino'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Concluir treino'));
      await tester.pumpAndSettle();
      expect(finished!.exercises.keys, ['Supino', 'Remada']);
      expect(routine.exercises, ['Supino']);
    },
  );

  testWidgets('History tab shows older sessions separately from charts', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProgressScreen(
            sessions: [
              Session('Treino antigo', DateTime(2020), {'Supino': []}),
            ],
          ),
        ),
      ),
    );
    expect(find.text('Treino antigo'), findsNothing);
    await tester.tap(find.text('Histórico'));
    await tester.pumpAndSettle();
    expect(find.text('Treino antigo'), findsOneWidget);
    expect(find.text('Atividade por dia'), findsNothing);
    await tester.tap(find.text('Evolução'));
    await tester.pumpAndSettle();
    expect(find.text('Atividade por dia'), findsOneWidget);
  });
}
