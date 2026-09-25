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
  });
  final String routine;
  final String? routineId;
  final DateTime? startedAt;
  final DateTime? endedAt;
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
    endedAt: DateTime.parse((json['endedAt'] ?? json['date']) as String),
  );
}

List<Session> historyForRoutine(List<Session> sessions, Routine routine) =>
    sessions.where((s) => s.routineId == routine.id).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

class WorkoutStore {
  final preferences = SharedPreferencesAsync();
  List<Routine> routines = [];
  List<Session> sessions = [];
  Future<void> load() async {
    final raw = await preferences.getString('ritmo_v1');
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
  }

  Future<void> save({List<Routine>? routines, List<Session>? sessions}) async {
    final nextRoutines = routines ?? this.routines;
    final nextSessions = sessions ?? this.sessions;
    await preferences.setString(
      'ritmo_v1',
      jsonEncode({
        'routines': nextRoutines.map((r) => r.toJson()).toList(),
        'sessions': nextSessions.map((s) => s.toJson()).toList(),
      }),
    );
    this.routines = nextRoutines;
    this.sessions = nextSessions;
  }
}
