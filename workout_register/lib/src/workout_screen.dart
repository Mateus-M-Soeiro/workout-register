import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'models.dart';
import 'ui.dart';
import 'exercise_picker.dart';

class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({
    required this.routine,
    required this.onFinish,
    this.previous,
    this.draft,
    this.onDraft,
    this.onDiscard,
    this.catalog,
    this.onSaveExercise,
    super.key,
  });
  final Routine routine;
  final Session? previous;
  final ActiveWorkout? draft;
  final Future<void> Function(ActiveWorkout)? onDraft;
  final Future<void> Function()? onDiscard;
  final List<ExerciseDefinition> Function()? catalog;
  final Future<void> Function(ExerciseDefinition)? onSaveExercise;
  final Future<void> Function(Session) onFinish;
  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen>
    with WidgetsBindingObserver {
  final form = GlobalKey<FormState>();
  late final ActiveWorkout draft;
  Map<String, List<TrainingSet>> get exercises => draft.exercises;
  DateTime get startedAt => draft.startedAt;
  bool draftError = false;
  @override
  void initState() {
    super.initState();
    draft = widget.draft == null
        ? ActiveWorkout.start(widget.routine)
        : ActiveWorkout.fromJson(widget.draft!.toJson());
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && !saving && !mayLeave) persist();
  }

  Future<bool> persist() async {
    try {
      await widget.onDraft?.call(draft);
      if (mounted && draftError) setState(() => draftError = false);
      return true;
    } catch (_) {
      if (mounted) setState(() => draftError = true);
      return false;
    }
  }

  void changed(String name) {
    draft.completed.remove(name);
    setState(() {});
    persist();
  }

  late List<ExerciseDefinition> localCatalog = mergeExerciseCatalog(
    [],
    widget.routine.exercises,
  );

  Future<void> replaceExercise(String name) async {
    final selected = await pickExercise(
      context,
      catalog: widget.catalog?.call() ?? localCatalog,
      excluded: exercises.keys,
      onSave: (exercise) async {
        await widget.onSaveExercise?.call(exercise);
        localCatalog = mergeExerciseCatalog([
          for (final e in localCatalog)
            if (e.key != exercise.key) e,
          exercise,
        ], []);
      },
    );
    if (selected == null || !mounted) return;
    if (exercises[name]!.isNotEmpty) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Trocar exercício?'),
          content: Text(
            'Substituir $name por ${selected.name} apenas neste treino? As séries de $name serão removidas. A rotina não será alterada.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Trocar'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    final updated = {
      for (final entry in exercises.entries)
        if (entry.key == name)
          selected.name: <TrainingSet>[]
        else
          entry.key: entry.value,
    };
    exercises
      ..clear()
      ..addAll(updated);
    changed(name);
  }

  bool saving = false;
  Future<void> addExercise() async {
    final selected = await pickExercise(
      context,
      catalog: widget.catalog?.call() ?? localCatalog,
      excluded: exercises.keys,
      onSave: (exercise) async {
        await widget.onSaveExercise?.call(exercise);
        localCatalog = mergeExerciseCatalog([
          for (final e in localCatalog)
            if (e.key != exercise.key) e,
          exercise,
        ], []);
      },
    );
    if (selected == null || !mounted) return;
    exercises[selected.name] = [];
    changed(selected.name);
  }

  bool mayLeave = false;

  Future<void> leave() async {
    if (saving) return;
    setState(() => saving = true);
    final saved = await persist();
    if (!mounted) return;
    setState(() {
      saving = false;
      mayLeave = saved;
    });
    if (saved) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
    }
  }

  Future<void> discard() async {
    if (saving) return;
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Abortar treino?'),
            content: const Text(
              'O treino em andamento e suas séries serão removidos, sem registrar nada no histórico.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Continuar treino'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Abortar'),
              ),
            ],
          ),
        ) ==
        true;
    if (!confirmed || !mounted) return;
    setState(() => saving = true);
    try {
      await widget.onDiscard?.call();
    } catch (_) {
      if (mounted) {
        setState(() {
          saving = false;
          draftError = true;
        });
      }
      return;
    }
    if (!mounted) return;
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
          completedExercises: Set.of(draft.completed),
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
        actions: [
          TextButton.icon(
            onPressed: saving ? null : discard,
            label: const Text('Abortar treino'),
            icon: const Icon(Icons.cancel_outlined),
          ),
        ],
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
              if (draftError)
                MaterialBanner(
                  content: const Text(
                    'Não foi possível salvar o treino no dispositivo. Tente novamente antes de sair.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: persist,
                      child: const Text('Tentar novamente'),
                    ),
                  ],
                ),
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
                  key: ValueKey(name),
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
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CompletionToggle(
                              label: Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              selected: draft.completed.contains(name),
                              onSelected: saving
                                  ? null
                                  : (value) {
                                      if (value &&
                                          !sets.every((s) => s.valid)) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Preencha ou remova as séries incompletas deste exercício.',
                                                ),
                                              ),
                                            );
                                        return;
                                      }
                                      setState(() {
                                        if (value) {
                                          draft.completed.add(name);
                                        } else {
                                          draft.completed.remove(name);
                                        }
                                      });
                                      persist();
                                    },
                            ),
                            TextButton.icon(
                              onPressed: saving
                                  ? null
                                  : () => replaceExercise(name),
                              icon: const Icon(Icons.swap_horiz),
                              label: const Text('Trocar exercício'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
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
                                      changed(name);
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
                                      changed(name);
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
                                          changed(name);
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
                                  changed(name);
                                }),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Adicionar série'),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              OutlinedButton.icon(
                onPressed: saving ? null : addExercise,
                icon: const Icon(Icons.add),
                label: const Text('Adicionar exercício ao treino'),
              ),
              const SizedBox(height: 12),
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
