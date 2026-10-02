import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'models.dart';
import 'ui.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({required this.sessions, super.key});
  final List<Session> sessions;
  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  int days = 7;
  bool volume = false;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dates = List.generate(
      days,
      (i) => DateTime(today.year, today.month, today.day - days + 1 + i),
    );
    final tomorrow = DateTime(today.year, today.month, today.day + 1);
    final sessions =
        widget.sessions
            .where(
              (s) => !s.date.isBefore(dates.first) && s.date.isBefore(tomorrow),
            )
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    final values = dates
        .map(
          (date) => sessions
              .where(
                (s) =>
                    s.date.year == date.year &&
                    s.date.month == date.month &&
                    s.date.day == date.day,
              )
              .fold<double>(
                0,
                (sum, s) => sum + (volume ? s.volume : s.repetitions),
              ),
        )
        .toList();
    final totalReps = sessions.fold<int>(0, (sum, s) => sum + s.repetitions);
    final totalVolume = sessions.fold<double>(0, (sum, s) => sum + s.volume);

    return PageContent(
      children: [
        const Text(
          'CADA REPETIÇÃO CONTA',
          style: TextStyle(
            color: accent,
            fontSize: 11,
            letterSpacing: 1.6,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Sua evolução',
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w800,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Pequenos passos. Resultados que se somam.',
          style: TextStyle(color: muted, height: 1.5),
        ),
        const SizedBox(height: 24),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 7, label: Text('7 dias')),
            ButtonSegment(value: 30, label: Text('30 dias')),
          ],
          selected: {days},
          onSelectionChanged: (value) => setState(() => days = value.first),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: metric('Repetições', number(totalReps), Icons.repeat),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: metric(
                'Volume (kg)',
                number(totalVolume),
                Icons.fitness_center,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Atividade por dia',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Repetições'),
                    selected: !volume,
                    onSelected: (_) => setState(() => volume = false),
                  ),
                  ChoiceChip(
                    label: const Text('Volume em kg'),
                    selected: volume,
                    onSelected: (_) => setState(() => volume = true),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (sessions.isEmpty)
                const SizedBox(
                  height: 180,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.insights, size: 40, color: accent),
                        SizedBox(height: 12),
                        Text(
                          'Sua evolução começa no próximo treino.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: muted),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Semantics(
                  label:
                      'Gráfico diário de ${volume ? 'volume em quilogramas' : 'repetições'}. ${List.generate(days, (i) => '${dateLabel(dates[i])}: ${number(values[i])}').join('; ')}',
                  child: SizedBox(
                    height: 200,
                    width: double.infinity,
                    child: CustomPaint(painter: ActivityChart(values, dates)),
                  ),
                ),
              const SizedBox(height: 12),
              Text(
                volume
                    ? 'Volume = peso × repetições, somado em todas as séries do dia.'
                    : 'Total de repetições de todos os exercícios concluídos no dia.',
                style: const TextStyle(fontSize: 12, color: muted, height: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        Text(
          'Histórico · ${sessions.length} treinos',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 14),
        if (sessions.isEmpty)
          const Text(
            'Nenhum treino concluído neste período. Crie uma rotina e registre suas primeiras séries.',
            style: TextStyle(color: muted, height: 1.5),
          ),
        ...sessions.map(
          (session) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Início: ${session.startedAt == null ? 'Não registrado' : timestamp(session.startedAt!)}\nFim: ${session.endedAt == null ? 'Não registrado' : timestamp(session.endedAt!)}',
                    style: const TextStyle(color: accent, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    session.routine,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${session.repetitions} repetições · ${number(session.volume)} kg de volume',
                    style: const TextStyle(color: muted),
                  ),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: const Text(
                      'Ver séries',
                      style: TextStyle(fontSize: 13),
                    ),
                    children: [
                      ...session.exercises.entries.map(
                        (e) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '${e.key}\n${e.value.map((s) => '${s.reps} reps × ${s.weight} kg').join('  •  ')}',
                              style: const TextStyle(color: muted, height: 1.6),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget metric(String title, String value, IconData icon) => Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: accent, size: 20),
        const SizedBox(height: 12),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 4),
        Text(title, style: const TextStyle(color: muted, fontSize: 12)),
      ],
    ),
  );
}

class ActivityChart extends CustomPainter {
  ActivityChart(this.values, this.dates);
  final List<double> values;
  final List<DateTime> dates;
  @override
  void paint(Canvas canvas, Size size) {
    final maxValue = math.max(1.0, values.reduce(math.max));
    final maxLabel = number(maxValue);
    final left = math.min(
      size.width * .35,
      math.max(34.0, maxLabel.length * 7.0 + 10),
    );
    final width = size.width - left;
    final height = size.height - 32;
    final step = width / values.length;
    void label(String text, Offset offset, {bool centered = false}) {
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: const TextStyle(color: muted, fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(
        canvas,
        Offset(centered ? offset.dx - painter.width / 2 : offset.dx, offset.dy),
      );
    }

    for (var i = 0; i <= 2; i++) {
      final y = 8 + (height - 8) * i / 2;
      canvas.drawLine(
        Offset(left, y),
        Offset(size.width, y),
        Paint()..color = const Color(0xFF354030),
      );
      label(number(maxValue * (1 - i / 2)), Offset(0, y - 6));
    }
    for (var i = 0; i < values.length; i++) {
      final barHeight = (height - 8) * values[i] / maxValue;
      final x = left + step * (i + .5);
      if (barHeight > 0) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              x - step * .29,
              height - barHeight,
              step * .58,
              barHeight,
            ),
            const Radius.circular(4),
          ),
          Paint()..color = accent,
        );
      }
      if (i == 0 || i == values.length - 1 || i == values.length ~/ 2) {
        label(dateLabel(dates[i]), Offset(x, height + 12), centered: true);
      }
    }
  }

  @override
  bool shouldRepaint(covariant ActivityChart oldDelegate) => true;
}
