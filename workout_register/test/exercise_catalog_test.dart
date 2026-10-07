import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_register/src/exercise_picker.dart';
import 'package:workout_register/src/models.dart';
import 'package:workout_register/src/workout_screen.dart';

void main() {
  test(
    'Legacy names are recovered and catalog survives routine deletion',
    () async {
      String? disk = jsonEncode({
        'routines': [
          Routine('1', 'A', ['Supino']).toJson(),
        ],
        'sessions': [
          Session('A', DateTime(2026), {'Remada': []}).toJson(),
        ],
        'active': ActiveWorkout.start(Routine('2', 'B', ['Agachamento']))
            .toJson(),
      });
      WorkoutStore open() => WorkoutStore(
        read: () async => disk,
        write: (s) async {
          disk = s;
        },
      );
      final store = open();
      await store.load();
      expect(store.catalog.map((e) => e.name), [
        'Agachamento',
        'Remada',
        'Supino',
      ]);
      await store.save(
        exercise: ExerciseDefinition('Supino', {'peito', 'triceps'}),
      );
      await store.save(routines: [], sessions: [], clearActive: true);
      final reopened = open();
      await reopened.load();
      expect(reopened.catalog.length, 3);
      expect(reopened.catalog.singleWhere((e) => e.name == 'Supino').groups, {
        'peito',
        'triceps',
      });
    },
  );

  test('Catalog saves and active workout saves preserve one another', () async {
    String? disk;
    final store = WorkoutStore(
      read: () async => disk,
      write: (s) async {
        disk = s;
      },
    );
    final draft = ActiveWorkout.start(Routine('1', 'A', ['Supino']));
    await Future.wait([
      store.save(exercise: ExerciseDefinition('Flexão', {'peito', 'triceps'})),
      store.save(active: draft),
      store.save(exercise: ExerciseDefinition('Remada', {'costas', 'biceps'})),
    ]);
    final reopened = WorkoutStore(read: () async => disk);
    await reopened.load();
    expect(reopened.active!.routine.id, '1');
    expect(reopened.catalog.length, 3);
    expect(reopened.catalog.singleWhere((e) => e.name == 'Flexão').groups, {
      'peito',
      'triceps',
    });
  });

  testWidgets(
    'Picker filters saved exercises by each group and prevents duplicates',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExercisePicker(
              catalog: [
                ExerciseDefinition('Supino', {'peito', 'triceps'}),
                ExerciseDefinition('Remada', {'costas'}),
              ],
              excluded: const ['supino'],
              onSave: (_) async {},
            ),
          ),
        ),
      );
      await tester.tap(find.widgetWithText(ChoiceChip, 'Peitoral'));
      await tester.pumpAndSettle();
      expect(find.text('Supino'), findsOneWidget);
      expect(find.text('Remada'), findsNothing);
      expect(tester.widget<ListTile>(find.byType(ListTile)).enabled, isFalse);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Braço'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Tríceps'));
      await tester.pumpAndSettle();
      expect(find.text('Supino'), findsOneWidget);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Costas'));
      await tester.pumpAndSettle();
      expect(find.text('Remada'), findsOneWidget);
      expect(find.text('Supino'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Creation saves multiple groups and reports storage errors', (
    tester,
  ) async {
    ExerciseDefinition? saved;
    var fail = true;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => ExerciseEditor(
                  catalog: const [],
                  onSave: (e) async {
                    if (fail) throw StateError('storage unavailable');
                    saved = e;
                  },
                ),
              ),
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Flexão');
    await tester.tap(find.text('Peitoral'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'Peitoral Clavicular'));
    await tester.ensureVisible(find.text('Braço'));
    await tester.tap(find.text('Braço'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(FilterChip, 'Tríceps'));
    await tester.tap(find.widgetWithText(FilterChip, 'Tríceps'));
    await tester.tap(find.text('Salvar exercício'));
    await tester.pumpAndSettle();
    expect(saved, isNull);
    expect(
      find.text('Não foi possível salvar. Tente novamente.'),
      findsOneWidget,
    );
    fail = false;
    await tester.tap(find.text('Salvar exercício'));
    await tester.pumpAndSettle();
    expect(saved!.groups, {'peitoral_clavicular', 'triceps'});
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('Replacement uses filtered catalog and keeps routine unchanged', (
    tester,
  ) async {
    final routine = Routine('1', 'A', ['Supino']);
    ActiveWorkout? result;
    await tester.pumpWidget(
      MaterialApp(
        home: WorkoutScreen(
          routine: routine,
          onFinish: (_) async {},
          onDraft: (d) async {
            result = d;
          },
          catalog: () => [
            ExerciseDefinition('Flexão', {'peito', 'triceps'}),
            ExerciseDefinition('Remada', {'costas'}),
          ],
        ),
      ),
    );
    await tester.tap(find.text('Trocar exercício'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Peitoral'));
    await tester.pumpAndSettle();
    expect(find.text('Remada'), findsNothing);
    await tester.tap(find.text('Flexão'));
    await tester.pumpAndSettle();
    expect(result!.exercises.keys, ['Flexão']);
    expect(routine.exercises, ['Supino']);
    expect(find.byIcon(Icons.radio_button_unchecked), findsOneWidget);
    await tester.tap(find.byIcon(Icons.radio_button_unchecked));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
  });
}
