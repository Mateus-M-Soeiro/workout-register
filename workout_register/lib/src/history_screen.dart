import 'package:flutter/material.dart';

import 'models.dart';
import 'ui.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({required this.sessions, this.routine, super.key});
  final List<Session> sessions;
  final Routine? routine;

  @override
  Widget build(BuildContext context) {
    final history = routine == null
        ? (List<Session>.of(sessions)..sort((a, b) => b.date.compareTo(a.date)))
        : historyForRoutine(sessions, routine!);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          routine == null
              ? 'Histórico de treinos'
              : 'Histórico · ${routine!.name}',
        ),
      ),
      body: SafeArea(
        child: PageContent(
          children: [
            if (history.isEmpty)
              const Panel(
                child: Text(
                  'Nenhum treino concluído ainda.',
                  style: TextStyle(color: muted),
                ),
              ),
            ...history.map(
              (session) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.routine,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Início: ${session.startedAt == null ? 'Não registrado' : timestamp(session.startedAt!)}',
                        style: const TextStyle(color: muted),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Fim: ${session.endedAt == null ? 'Não registrado' : timestamp(session.endedAt!)}',
                        style: const TextStyle(color: muted),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${session.repetitions} repetições · ${number(session.volume)} kg de volume',
                        style: const TextStyle(color: accent),
                      ),
                      const SizedBox(height: 8),
                      ...session.exercises.entries.map(
                        (exercise) => ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          title: Text(exercise.key),
                          leading:
                              session.completedExercises.contains(exercise.key)
                              ? const Tooltip(
                                  message: 'Exercício finalizado',
                                  child: Icon(
                                    Icons.check_circle,
                                    color: accent,
                                  ),
                                )
                              : null,
                          subtitle: Text('${exercise.value.length} séries'),
                          children: [
                            if (exercise.value.isEmpty)
                              const Padding(
                                padding: EdgeInsets.only(bottom: 16),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'Nenhuma série registrada.',
                                    style: TextStyle(color: muted),
                                  ),
                                ),
                              ),
                            if (exercise.value.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Table(
                                  defaultVerticalAlignment:
                                      TableCellVerticalAlignment.middle,
                                  children: [
                                    const TableRow(
                                      children: [
                                        Text(
                                          'Série',
                                          style: TextStyle(color: muted),
                                        ),
                                        Text(
                                          'Repetições',
                                          style: TextStyle(color: muted),
                                        ),
                                        Text(
                                          'Peso (kg)',
                                          style: TextStyle(color: muted),
                                        ),
                                      ],
                                    ),
                                    ...exercise.value.asMap().entries.map(
                                      (entry) => TableRow(
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 10,
                                            ),
                                            child: Text('${entry.key + 1}'),
                                          ),
                                          Text(entry.value.reps),
                                          Text(entry.value.weight),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
