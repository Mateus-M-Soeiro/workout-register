import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

// Stable keys keep saved classifications compatible with future groups.
const exerciseGroups = {
  'peito': 'Peitoral',
  'costas': 'Costas',
  'pernas': 'Pernas',
  'braco': 'Braço',
  'abdomen': 'Abdômen',
  'peitoral_clavicular': 'Peitoral Clavicular',
  'peitoral_esternocostal': 'Peitoral Esternocostal',
  'peitoral_costal': 'Peitoral Costal',
  'dorsal': 'Dorsal',
  'trapezio': 'Trapézio',
  'romboides': 'Romboides',
  'lombar': 'Lombar',
  'quadriceps': 'Quadríceps',
  'posterior_coxa': 'Posterior da coxa',
  'adutor': 'Adutor',
  'abdutor': 'Abdutor',
  'panturrilha': 'Panturrilha',
  'gluteo': 'Glúteo',
  'antebraco': 'Antebraço',
  'biceps': 'Bíceps',
  'triceps': 'Tríceps',
};

const exerciseCategoryTree = <String, List<String>>{
  'peito': ['peitoral_clavicular', 'peitoral_esternocostal', 'peitoral_costal'],
  'costas': ['dorsal', 'trapezio', 'romboides', 'lombar'],
  'pernas': [
    'quadriceps',
    'posterior_coxa',
    'adutor',
    'abdutor',
    'panturrilha',
    'gluteo',
  ],
  'braco': ['triceps', 'biceps', 'antebraco'],
  'abdomen': [],
};

bool matchesExerciseGroup(ExerciseDefinition exercise, String? group) =>
    group == null ||
    (group == 'ungrouped'
        ? exercise.groups.isEmpty
        : exercise.groups.contains(group) ||
              (exerciseCategoryTree[group] ?? []).any(
                exercise.groups.contains,
              ));

String categoryParent(String key) => exerciseCategoryTree.keys.firstWhere(
  (parent) => parent == key || exerciseCategoryTree[parent]!.contains(key),
  orElse: () => key,
);

class ExerciseDefinition {
  ExerciseDefinition(this.name, [Set<String> groups = const {}])
    : groups = Set.unmodifiable(groups);
  final String name;
  final Set<String> groups;
  String get key => name.trim().toLowerCase();
  Map<String, dynamic> toJson() => {'name': name, 'groups': groups.toList()};
  factory ExerciseDefinition.fromJson(Map<String, dynamic> json) =>
      ExerciseDefinition(
        json['name'] as String,
        Set<String>.from(json['groups'] as List? ?? []),
      );
}

List<ExerciseDefinition> mergeExerciseCatalog(
  List<ExerciseDefinition> catalog,
  Iterable<String> names,
) {
  final entries = {for (final e in catalog) e.key: e};
  for (final name in names) {
    final exercise = ExerciseDefinition(name.trim());
    if (exercise.name.isNotEmpty) {
      entries.putIfAbsent(exercise.key, () => exercise);
    }
  }
  return entries.values.toList()..sort((a, b) => a.key.compareTo(b.key));
}

class Routine {
  Routine(this.id, this.name, this.exercises);
  final String id;
  final String name;
  final List<String> exercises;
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'exercises': exercises,
  };
  factory Routine.fromJson(Map<String, dynamic> json) => Routine(
    json['id'] as String,
    json['name'] as String,
    List<String>.from(json['exercises'] as List),
  );
}

class TrainingSet {
  TrainingSet({this.reps = '', this.weight = ''});
  String reps;
  String weight;
  int? get repetitions => int.tryParse(reps);
  double? get kilograms => double.tryParse(weight.replaceAll(',', '.'));
  bool get valid =>
      repetitions != null &&
      repetitions! > 0 &&
      kilograms != null &&
      kilograms!.isFinite &&
      kilograms! >= 0;
  Map<String, dynamic> toJson() => {'reps': reps, 'weight': weight};
  factory TrainingSet.fromJson(Map<String, dynamic> json) => TrainingSet(
    reps: json['reps'] as String,
    weight: json['weight'] as String,
  );
}

class Session {
  Session(
    this.routine,
    this.date,
    this.exercises, {
    this.routineId,
    this.startedAt,
    this.endedAt,
    this.completedExercises = const {},
  });
  final String routine;
  final String? routineId;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final Set<String> completedExercises;
  final DateTime date;
  final Map<String, List<TrainingSet>> exercises;
  int get repetitions => exercises.values
      .expand((s) => s)
      .fold(0, (sum, s) => sum + (s.repetitions ?? 0));
  double get volume => exercises.values
      .expand((s) => s)
      .fold(0, (sum, s) => sum + (s.repetitions ?? 0) * (s.kilograms ?? 0));
  Map<String, dynamic> toJson() => {
    'routine': routine,
    'routineId': routineId,
    'startedAt': startedAt?.toIso8601String(),
    'endedAt': endedAt?.toIso8601String(),
    'completedExercises': completedExercises.toList(),
    'date': date.toIso8601String(),
    'exercises': exercises.map(
      (name, sets) => MapEntry(name, sets.map((s) => s.toJson()).toList()),
    ),
  };
  factory Session.fromJson(Map<String, dynamic> json) => Session(
    json['routine'] as String,
    DateTime.parse(json['date'] as String),
    (json['exercises'] as Map<String, dynamic>).map(
      (name, sets) => MapEntry(
        name,
        (sets as List)
            .map((s) => TrainingSet.fromJson(s as Map<String, dynamic>))
            .toList(),
      ),
    ),
    routineId: json['routineId'] as String?,
    startedAt: json['startedAt'] == null
        ? null
        : DateTime.parse(json['startedAt'] as String),
    endedAt: json['endedAt'] != null
        ? DateTime.parse(json['endedAt'] as String)
        : json['startedAt'] == null
        ? DateTime.parse(json['date'] as String)
        : null,
    completedExercises: Set<String>.from(
      json['completedExercises'] as List? ?? [],
    ),
  );
}

class ActiveWorkout {
  ActiveWorkout(this.routine, this.startedAt, this.exercises, this.completed);
  final Routine routine;
  final DateTime startedAt;
  final Map<String, List<TrainingSet>> exercises;
  final Set<String> completed;

  factory ActiveWorkout.start(Routine routine) => ActiveWorkout(
    Routine.fromJson(routine.toJson()),
    DateTime.now(),
    {for (final name in routine.exercises) name: <TrainingSet>[]},
    {},
  );
  Map<String, dynamic> toJson() => {
    'routine': routine.toJson(),
    'startedAt': startedAt.toIso8601String(),
    'exercises': exercises.map(
      (name, sets) => MapEntry(name, sets.map((s) => s.toJson()).toList()),
    ),
    'completed': completed.toList(),
  };
  factory ActiveWorkout.fromJson(Map<String, dynamic> json) => ActiveWorkout(
    Routine.fromJson(json['routine'] as Map<String, dynamic>),
    DateTime.parse(json['startedAt'] as String),
    (json['exercises'] as Map<String, dynamic>).map(
      (name, sets) => MapEntry(
        name,
        (sets as List)
            .map((s) => TrainingSet.fromJson(s as Map<String, dynamic>))
            .toList(),
      ),
    ),
    Set<String>.from(json['completed'] as List? ?? []),
  );
}

List<Session> historyForRoutine(List<Session> sessions, Routine routine) =>
    sessions.where((s) => s.routineId == routine.id).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

class WorkoutStore {
  WorkoutStore({
    Future<String?> Function()? read,
    Future<void> Function(String)? write,
  }) : _read = read ?? (() => SharedPreferencesAsync().getString('ritmo_v1')),
       _write =
           write ??
           ((value) => SharedPreferencesAsync().setString('ritmo_v1', value));
  final Future<String?> Function() _read;
  final Future<void> Function(String) _write;
  Future<void> _pending = Future.value();
  ActiveWorkout? active;
  List<Routine> routines = [];
  List<Session> sessions = [];
  List<ExerciseDefinition> catalog = [];
  Set<String> _removedExercises = {};
  Future<void> load() async {
    final raw = await _read();
    if (raw == null) return;
    final json = jsonDecode(raw) as Map<String, dynamic>;
    // Reset existing classifications once when upgrading to leaf-only categories.
    // Persist before exposing the data so retries cannot erase new classifications.
    if ((json['categorySchemaVersion'] as int? ?? 0) < 1) {
      for (final exercise in json['catalog'] as List? ?? []) {
        (exercise as Map<String, dynamic>)['groups'] = <String>[];
      }
      json['categorySchemaVersion'] = 1;
      await _write(jsonEncode(json));
    }
    final loadedRoutines = (json['routines'] as List)
        .map((r) => Routine.fromJson(r as Map<String, dynamic>))
        .toList();
    final loadedSessions = (json['sessions'] as List).map((s) {
      final data = Map<String, dynamic>.from(s as Map);
      if (data['routineId'] == null) {
        final matches = loadedRoutines
            .where((r) => r.name == data['routine'])
            .toList();
        if (matches.length == 1) data['routineId'] = matches.single.id;
      }
      return Session.fromJson(data);
    }).toList();
    routines = loadedRoutines;
    sessions = loadedSessions;
    active = json['active'] == null
        ? null
        : ActiveWorkout.fromJson(json['active'] as Map<String, dynamic>);
    _removedExercises = Set<String>.from(
      json['removedExercises'] as List? ?? [],
    );
    catalog = mergeExerciseCatalog(
      (json['catalog'] as List? ?? [])
          .map((e) => ExerciseDefinition.fromJson(e as Map<String, dynamic>))
          .toList(),
      [
        for (final r in routines) ...r.exercises,
        for (final s in sessions) ...s.exercises.keys,
        ...?active?.exercises.keys,
      ],
    ).where((e) => !_removedExercises.contains(e.key)).toList();
  }

  Future<void> save({
    List<Routine>? routines,
    List<Session>? sessions,
    ActiveWorkout? active,
    bool clearActive = false,
    ExerciseDefinition? exercise,
    String? previousExerciseName,
    String? deleteExercise,
  }) {
    // Snapshot mutable fields now, then serialize writes in request order.
    final snapshot = active == null
        ? null
        : ActiveWorkout.fromJson(active.toJson());
    final operation = _pending.then((_) async {
      var nextRoutines = routines ?? this.routines;
      final removed = {..._removedExercises};
      final oldKey = previousExerciseName?.trim().toLowerCase();
      if (deleteExercise != null) {
        removed.add(deleteExercise.trim().toLowerCase());
      }
      if (exercise != null) {
        if (oldKey != null && oldKey != exercise.key) removed.add(oldKey);
        removed.remove(exercise.key);
        if (oldKey != null) {
          nextRoutines = nextRoutines
              .map(
                (r) => Routine(
                  r.id,
                  r.name,
                  r.exercises
                      .map(
                        (name) => name.trim().toLowerCase() == oldKey
                            ? exercise.name
                            : name,
                      )
                      .toList(),
                ),
              )
              .toList();
        }
      }
      final nextSessions = sessions ?? this.sessions;
      final nextActive = clearActive ? null : snapshot ?? this.active;
      final nextCatalog = mergeExerciseCatalog(
        [
          for (final e in catalog)
            if (e.key != exercise?.key && e.key != oldKey) e,
          ?exercise,
        ],
        [
          for (final r in nextRoutines) ...r.exercises,
          for (final s in nextSessions) ...s.exercises.keys,
          ...?nextActive?.exercises.keys,
        ],
      ).where((e) => !removed.contains(e.key)).toList();
      await _write(
        jsonEncode({
          'categorySchemaVersion': 1,
          'routines': nextRoutines.map((r) => r.toJson()).toList(),
          'sessions': nextSessions.map((s) => s.toJson()).toList(),
          'active': nextActive?.toJson(),
          'catalog': nextCatalog.map((e) => e.toJson()).toList(),
          'removedExercises': removed.toList(),
        }),
      );
      this.routines = nextRoutines;
      this.sessions = nextSessions;
      this.active = nextActive;
      catalog = nextCatalog;
      _removedExercises = removed;
    });
    _pending = operation.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return operation;
  }
}
