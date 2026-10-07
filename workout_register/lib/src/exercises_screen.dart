import 'package:flutter/material.dart';

import 'exercise_picker.dart';
import 'models.dart';
import 'ui.dart';

class ExercisesScreen extends StatefulWidget {
  const ExercisesScreen({required this.store, super.key});
  final WorkoutStore store;
  @override
  State<ExercisesScreen> createState() => _ExercisesScreenState();
}

class _ExercisesScreenState extends State<ExercisesScreen> {
  bool busy = false;

  Future<void> edit(ExerciseDefinition exercise) async {
    await showDialog<ExerciseDefinition>(
      context: context,
      builder: (_) => ExerciseEditor(
        catalog: widget.store.catalog,
        existing: exercise,
        allowRename: true,
        onSave: (updated) => widget.store.save(
          exercise: updated,
          previousExerciseName: exercise.name,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> remove(ExerciseDefinition exercise) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir exercício?'),
        content: Text(
          'Excluir “${exercise.name}” do catálogo? Ele deixará de aparecer para novas seleções. Rotinas existentes, histórico e treino em andamento serão preservados.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => busy = true);
    try {
      await widget.store.save(deleteExercise: exercise.name);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível excluir. Tente novamente.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Exercícios salvos')),
    body: SafeArea(
      child: PageContent(
        children: [
          if (busy) const LinearProgressIndicator(),
          if (widget.store.catalog.isEmpty)
            const Text(
              'Nenhum exercício salvo.',
              style: TextStyle(color: muted),
            ),
          for (final exercise in widget.store.catalog)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exercise.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      exercise.groups.isEmpty
                          ? 'Sem grupo'
                          : exercise.groups
                                .map((g) => exerciseGroups[g] ?? g)
                                .join(' · '),
                      style: const TextStyle(color: muted),
                    ),
                    Wrap(
                      spacing: 12,
                      children: [
                        TextButton.icon(
                          onPressed: busy ? null : () => edit(exercise),
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Editar'),
                        ),
                        TextButton.icon(
                          onPressed: busy ? null : () => remove(exercise),
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Excluir'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
