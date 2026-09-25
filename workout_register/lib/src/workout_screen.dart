import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'models.dart';
import 'ui.dart';

class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({
    required this.routine,
    required this.onFinish,
    this.previous,
    super.key,
  });
  final Routine routine;
  final Session? previous;
  final Future<void> Function(Session) onFinish;
  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  final form = GlobalKey<FormState>();
  late final exercises = {
    for (final name in widget.routine.exercises) name: <TrainingSet>[],
  };
  late final DateTime startedAt;
  @override
  void initState() {
    super.initState();
    startedAt = DateTime.now();
  }

  bool saving = false;
  bool mayLeave = false;
  bool edited = false;

  Future<void> leave() async {
    if (saving) return;
    final confirmed =
        !edited ||
        await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Sair do treino?'),
                content: const Text(
                  'As séries deste treino ainda não foram salvas.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Continuar treino'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Descartar'),
                  ),
                ],
              ),
            ) ==
            true;
    if (!confirmed || !mounted) return;
    setState(() => mayLeave = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  Future<void> finish() async {
    final visibleFieldsValid = form.currentState!.validate();
    final allSetsValid = exercises.values
        .expand((sets) => sets)
        .every((set) => set.valid);
    if (!visibleFieldsValid || !allSetsValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Preencha repetições e peso de todas as séries antes de concluir.',
          ),
        ),
      );
      return;
    }
    setState(() => saving = true);
    try {
      await widget.onFinish(
        Session(
          widget.routine.name,
          startedAt,
          exercises,
          routineId: widget.routine.id,
          startedAt: startedAt,
          endedAt: DateTime.now(),
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Treino salvo! Confira sua evolução.')),
      );
      setState(() {
        mayLeave = true;
        saving = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Não foi possível salvar. Suas séries continuam aqui; tente novamente.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: mayLeave,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) leave();
    },
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Seu treino'),
        leading: IconButton(
          onPressed: leave,
          tooltip: 'Voltar',
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: form,
          child: PageContent(
            children: [
              const Text(
                'HORA DE SE MOVIMENTAR',
                style: TextStyle(
                  color: accent,
                  fontSize: 11,
                  letterSpacing: 1.6,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                widget.routine.name,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Início: ${timestamp(startedAt)}',
                style: const TextStyle(color: accent),
              ),
              const SizedBox(height: 10),
              const Text(
                'Adicione as séries que realizar. Exercícios podem ficar sem séries. Use 0 kg para exercícios sem carga externa.',
                style: TextStyle(color: muted, height: 1.5),
              ),
              const SizedBox(height: 24),
              ...exercises.entries.toList().asMap().entries.map((entry) {
                final name = entry.value.key;
                final sets = entry.value.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'EXERCÍCIO ${(entry.key + 1).toString().padLeft(2, '0')}',
                          style: const TextStyle(
                            color: accent,
                            fontSize: 10,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (widget.previous != null) ...[
                          Text(
                            'Último treino · ${dateLabel(widget.previous!.date)}',
                            style: const TextStyle(color: accent, fontSize: 12),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            !widget.previous!.exercises.containsKey(name)
                                ? 'Exercício não registrado no último treino.'
                                : widget.previous!.exercises[name]!.isEmpty
                                ? 'Sem séries no último treino.'
                                : widget.previous!.exercises[name]!
                                      .asMap()
                                      .entries
                                      .map(
                                        (e) =>
                                            'Série ${e.key + 1}: ${e.value.reps} reps × ${e.value.weight} kg',
                                      )
                                      .join('\n'),
                            style: const TextStyle(color: muted, height: 1.6),
                          ),
                          const SizedBox(height: 16),
                        ] else ...[
                          const Text(
                            'Ainda não há treino anterior desta rotina.',
                            style: TextStyle(color: muted, fontSize: 12),
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (sets.isEmpty)
                          const Text(
                            'Nenhuma série neste treino.',
                            style: TextStyle(color: muted),
                          ),
                        ...sets.asMap().entries.map(
                          (item) => Padding(
                            key: ObjectKey(item.value),
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(
                                    top: 18,
                                    right: 12,
                                  ),
                                  child: Text(
                                    '${item.key + 1}',
                                    style: const TextStyle(color: muted),
                                  ),
                                ),
                                Expanded(
                                  child: TextFormField(
                                    initialValue: item.value.reps,
                                    enabled: !saving,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    decoration: const InputDecoration(
                                      labelText: 'Reps',
                                      hintText: '12',
                                    ),
                                    onChanged: (value) {
                                      item.value.reps = value;
                                      edited = true;
                                    },
                                    validator: (value) =>
                                        (int.tryParse(value ?? '') ?? 0) > 0
                                        ? null
                                        : 'Maior que 0',
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextFormField(
                                    initialValue: item.value.weight,
                                    enabled: !saving,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    decoration: const InputDecoration(
                                      labelText: 'Peso (kg)',
                                      hintText: '20',
                                    ),
                                    onChanged: (value) {
                                      item.value.weight = value;
                                      edited = true;
                                    },
                                    validator: (value) {
                                      final n = double.tryParse(
                                        (value ?? '').replaceAll(',', '.'),
                                      );
                                      return n != null && n.isFinite && n >= 0
                                          ? null
                                          : 'Peso inválido';
                                    },
                                  ),
                                ),
                                IconButton(
                                  onPressed: saving
                                      ? null
                                      : () => setState(() {
                                          sets.removeAt(item.key);
                                          edited = true;
                                        }),
                                  tooltip: 'Remover série ${item.key + 1}',
                                  icon: const Icon(Icons.close, size: 18),
                                ),
                              ],
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: saving
                              ? null
                              : () => setState(() {
                                  sets.add(TrainingSet());
                                  edited = true;
                                }),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Adicionar série'),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              FilledButton.icon(
                onPressed: saving ? null : finish,
                icon: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: Text(saving ? 'Salvando…' : 'Concluir treino'),
              ),
              const SizedBox(height: 12),
              const Text(
                'Ao concluir, suas séries entram no histórico.',
                textAlign: TextAlign.center,
                style: TextStyle(color: muted, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
