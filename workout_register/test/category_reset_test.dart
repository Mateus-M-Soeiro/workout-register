import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_register/src/models.dart';
import 'package:workout_register/src/exercise_picker.dart';

void main() {
  test(
    'Existing categories reset once without changing routines or workouts',
    () async {
      final routine = Routine('1', 'A', ['Supino']);
      final session = Session('A', DateTime(2026, 10, 1), {
        'Supino': [TrainingSet(reps: '12', weight: '20')],
      });
      final active = ActiveWorkout.start(routine);
      String? disk = jsonEncode({
        'routines': [routine.toJson()],
        'sessions': [session.toJson()],
        'active': active.toJson(),
        'removedExercises': ['remada'],
        'catalog': [
          ExerciseDefinition('Supino', {
            'peito',
            'peitoral_clavicular',
            'triceps',
          }).toJson(),
        ],
      });
      WorkoutStore open() => WorkoutStore(
        read: () async => disk,
        write: (value) async {
          disk = value;
        },
      );
      final store = open();
      await store.load();
      expect(store.catalog.single.groups, isEmpty);
      expect(store.routines.single.toJson(), routine.toJson());
      expect(store.sessions.single.repetitions, 12);
      expect(store.sessions.single.volume, 240);
      expect(store.active!.toJson(), active.toJson());
      expect(jsonDecode(disk!)['removedExercises'], ['remada']);
      await store.save(
        exercise: ExerciseDefinition('Supino', {'peitoral_clavicular'}),
      );
      final reopened = open();
      await reopened.load();
      expect(reopened.catalog.single.groups, {'peitoral_clavicular'});
      await reopened.load();
      expect(reopened.catalog.single.groups, {'peitoral_clavicular'});
    },
  );

  test('Failed migration can be retried without losing saved data', () async {
    String? disk = jsonEncode({
      'routines': [],
      'sessions': [],
      'catalog': [
        ExerciseDefinition('Supino', {'peito'}).toJson(),
      ],
    });
    final original = disk;
    var fail = true;
    final store = WorkoutStore(
      read: () async => disk,
      write: (value) async {
        if (fail) throw StateError('disk unavailable');
        disk = value;
      },
    );
    await expectLater(store.load(), throwsStateError);
    expect(disk, original);
    fail = false;
    await store.load();
    expect(store.catalog.single.name, 'Supino');
    expect(store.catalog.single.groups, isEmpty);
  });

  testWidgets('Only subcategories and Abdomen are selectable', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExerciseEditor(catalog: const [], onSave: (_) async {}),
        ),
      ),
    );
    await tester.tap(find.text('Peitoral'));
    await tester.pumpAndSettle();
    expect(find.text('Geral'), findsNothing);
    expect(
      find.widgetWithText(FilterChip, 'Peitoral Clavicular'),
      findsOneWidget,
    );
    expect(find.widgetWithText(FilterChip, 'Peitoral'), findsNothing);
    expect(find.widgetWithText(FilterChip, 'Abdômen'), findsOneWidget);
  });
}
