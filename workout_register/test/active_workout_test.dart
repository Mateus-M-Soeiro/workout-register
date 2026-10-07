import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_register/src/models.dart';
import 'package:workout_register/src/workout_screen.dart';
import 'package:workout_register/src/progress_screen.dart';

void main() {
  test('Missing end time never becomes the start time', () {
    final start = DateTime(2026, 10, 1, 10);
    final session = Session.fromJson(
      Session('A', start, {}, startedAt: start).toJson(),
    );
    expect(session.endedAt, isNull);
  });

  testWidgets(
    'Finishing a resumed workout preserves start and records a later end',
    (tester) async {
      final routine = Routine('1', 'A', ['Supino']);
      final originalStart = DateTime.now().subtract(const Duration(hours: 1));
      Session? result;
      await tester.pumpWidget(
        MaterialApp(
          home: WorkoutScreen(
            routine: routine,
            draft: ActiveWorkout(
              routine,
              originalStart,
              {'Supino': []},
              {'Supino'},
            ),
            onFinish: (session) async {
              result = session;
            },
          ),
        ),
      );
      await tester.scrollUntilVisible(
        find.text('Concluir treino'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Concluir treino'));
      await tester.pumpAndSettle();
      expect(result!.startedAt, originalStart);
      expect(result!.endedAt!.isAfter(originalStart), isTrue);
      expect(result!.completedExercises, {'Supino'});
    },
  );

  test(
    'Draft survives a fresh store, preserves partial sets and original start',
    () async {
      String? disk;
      WorkoutStore open() => WorkoutStore(
        read: () async => disk,
        write: (s) async {
          disk = s;
        },
      );
      final store = open();
      final routine = Routine('1', 'A', ['Supino', 'Agachamento']);
      final draft = ActiveWorkout(
        routine,
        DateTime(2026, 10, 1, 10),
        {
          'Flexão': [TrainingSet(reps: '12', weight: '')],
          'Agachamento': [],
        },
        {'Agachamento'},
      );
      await store.save(routines: [routine], active: draft);
      final reopened = open();
      await reopened.load();
      expect(reopened.active!.startedAt, draft.startedAt);
      expect(reopened.active!.exercises['Flexão']!.single.reps, '12');
      expect(reopened.active!.exercises['Flexão']!.single.weight, '');
      expect(reopened.active!.completed, {'Agachamento'});
      expect(reopened.routines.single.exercises, ['Supino', 'Agachamento']);
      await reopened.save(
        clearActive: true,
        sessions: [
          Session(
            'A',
            draft.startedAt,
            draft.exercises,
            routineId: '1',
            startedAt: draft.startedAt,
            endedAt: draft.startedAt.add(const Duration(hours: 1)),
            completedExercises: draft.completed,
          ),
        ],
      );
      final finished = open();
      await finished.load();
      expect(finished.active, isNull);
      expect(finished.sessions.single.endedAt, DateTime(2026, 10, 1, 11));
      expect(finished.sessions.single.completedExercises, {'Agachamento'});
    },
  );

  test('Queued autosaves cannot resurrect a finished workout', () async {
    String? disk;
    final gate = Completer<void>();
    var writes = 0;
    final store = WorkoutStore(
      read: () async => disk,
      write: (s) async {
        if (writes++ == 0) await gate.future;
        disk = s;
      },
    );
    final draft = ActiveWorkout.start(Routine('1', 'A', ['Supino']));
    draft.exercises['Supino']!.add(TrainingSet(reps: '1', weight: '10'));
    final first = store.save(active: draft);
    draft.exercises['Supino']!.single.reps = '12';
    final second = store.save(active: draft);
    final finish = store.save(
      clearActive: true,
      sessions: [
        Session('A', draft.startedAt, draft.exercises, endedAt: DateTime.now()),
      ],
    );
    gate.complete();
    await Future.wait([first, second, finish]);
    final restored = WorkoutStore(read: () async => disk);
    await restored.load();
    expect(restored.active, isNull);
    expect(restored.sessions.single.repetitions, 12);
  });

  test('A failed finish retains draft and permits another save', () async {
    String? disk;
    var fail = false;
    final store = WorkoutStore(
      read: () async => disk,
      write: (s) async {
        if (fail) throw StateError('disk unavailable');
        disk = s;
      },
    );
    await store.save(
      active: ActiveWorkout.start(Routine('1', 'A', ['Supino'])),
    );
    fail = true;
    await expectLater(store.save(clearActive: true), throwsStateError);
    expect(store.active, isNotNull);
    fail = false;
    await store.save(clearActive: true);
    expect(store.active, isNull);
  });

  testWidgets(
    'Resume restores fields, completion and start after widget destruction',
    (tester) async {
      ActiveWorkout? disk;
      final routine = Routine('1', 'A', ['Supino']);
      Widget screen({ActiveWorkout? draft}) => MaterialApp(
        home: WorkoutScreen(
          routine: routine,
          draft: draft,
          onFinish: (_) async {},
          onDraft: (d) async {
            disk = ActiveWorkout.fromJson(d.toJson());
          },
        ),
      );
      await tester.pumpWidget(screen());
      await tester.tap(find.text('Adicionar série'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), '12');
      await tester.enterText(find.byType(TextFormField).at(1), '20');
      await tester.ensureVisible(find.byIcon(Icons.radio_button_unchecked));
      await tester.tap(find.byIcon(Icons.radio_button_unchecked));
      await tester.pumpAndSettle();
      final start = disk!.startedAt;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(screen(draft: disk));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText).at(0))
            .controller
            .text,
        '12',
      );
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText).at(1))
            .controller
            .text,
        '20',
      );
      expect(disk!.startedAt, start);
    },
  );

  testWidgets(
    'Replacement affects only current session and completion is reversible',
    (tester) async {
      final routine = Routine('1', 'A', ['Supino']);
      ActiveWorkout? draft;
      await tester.pumpWidget(
        MaterialApp(
          home: WorkoutScreen(
            routine: routine,
            onFinish: (_) async {},
            onDraft: (d) async {
              draft = ActiveWorkout.fromJson(d.toJson());
            },
          ),
        ),
      );
      await tester.tap(find.byIcon(Icons.radio_button_unchecked));
      await tester.pumpAndSettle();
      expect(draft!.completed, {'Supino'});
      await tester.tap(find.byIcon(Icons.radio_button_checked));
      await tester.pumpAndSettle();
      expect(draft!.completed, isEmpty);
      await tester.tap(find.text('Trocar exercício'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Criar exercício'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'Flexão');
      await tester.tap(find.text('Salvar exercício'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Flexão'));
      await tester.pumpAndSettle();
      expect(find.text('Flexão'), findsOneWidget);
      expect(draft!.exercises.keys, ['Flexão']);
      expect(draft!.exercises['Flexão'], isEmpty);
      expect(routine.exercises, ['Supino']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Progress history displays both start and finish', (
    tester,
  ) async {
    final start = DateTime.now().subtract(const Duration(hours: 1));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProgressScreen(
            sessions: [
              Session(
                'A',
                start,
                {},
                startedAt: start,
                endedAt: DateTime.now(),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.text('Histórico'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.textContaining('Início:'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('Fim:'), findsOneWidget);
  });
}
