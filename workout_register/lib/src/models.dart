import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

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
  Future<void> load() async {
    final raw = await _read();
    if (raw == null) return;
    final json = jsonDecode(raw) as Map<String, dynamic>;
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
  }

  Future<void> save({
    List<Routine>? routines,
    List<Session>? sessions,
    ActiveWorkout? active,
    bool clearActive = false,
  }) {
    // Snapshot mutable fields now, then serialize writes in request order.
    final snapshot = active == null
        ? null
        : ActiveWorkout.fromJson(active.toJson());
    final operation = _pending.then((_) async {
      final nextRoutines = routines ?? this.routines;
      final nextSessions = sessions ?? this.sessions;
      final nextActive = clearActive ? null : snapshot ?? this.active;
      await _write(
        jsonEncode({
          'routines': nextRoutines.map((r) => r.toJson()).toList(),
          'sessions': nextSessions.map((s) => s.toJson()).toList(),
          'active': nextActive?.toJson(),
        }),
      );
      this.routines = nextRoutines;
      this.sessions = nextSessions;
      this.active = nextActive;
    });
    _pending = operation.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return operation;
  }
}
