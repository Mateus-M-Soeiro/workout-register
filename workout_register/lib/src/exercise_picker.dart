import 'package:flutter/material.dart';

import 'models.dart';
import 'ui.dart';

Future<ExerciseDefinition?> pickExercise(
  BuildContext context, {
  required List<ExerciseDefinition> catalog,
  required Future<void> Function(ExerciseDefinition) onSave,
  Iterable<String> excluded = const [],
}) => showModalBottomSheet<ExerciseDefinition>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) =>
      ExercisePicker(catalog: catalog, onSave: onSave, excluded: excluded),
);

class ExercisePicker extends StatefulWidget {
  const ExercisePicker({
    required this.catalog,
    required this.onSave,
    this.excluded = const [],
    super.key,
  });
  final List<ExerciseDefinition> catalog;
  final Future<void> Function(ExerciseDefinition) onSave;
  final Iterable<String> excluded;
  @override
  State<ExercisePicker> createState() => _ExercisePickerState();
}

class _ExercisePickerState extends State<ExercisePicker> {
  late List<ExerciseDefinition> catalog = List.of(widget.catalog);
  String? group;

  Future<void> edit([ExerciseDefinition? existing]) async {
    final result = await showDialog<ExerciseDefinition>(
      context: context,
      builder: (_) => ExerciseEditor(
        existing: existing,
        catalog: catalog,
        onSave: widget.onSave,
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      catalog = mergeExerciseCatalog([
        for (final e in catalog)
          if (e.key != result.key) e,
        result,
      ], []);
      // Show the saved exercise even when the previous filter would hide it.
      group = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final excluded = widget.excluded.map((e) => e.trim().toLowerCase()).toSet();
    final visible = catalog
        .where((e) => matchesExerciseGroup(e, group))
        .toList();
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .8,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Escolher exercício',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                ChoiceChip(
                  label: const Text('Todos'),
                  selected: group == null,
                  onSelected: (_) => setState(() => group = null),
                ),
                for (final g in exerciseGroups.entries.where(
                  (g) => exerciseCategoryTree.containsKey(g.key),
                ))
                  ChoiceChip(
                    label: Text(g.value),
                    selected: group != null && categoryParent(group!) == g.key,
                    onSelected: (_) =>
                        setState(() => group = group == g.key ? null : g.key),
                  ),
                ChoiceChip(
                  label: const Text('Sem grupo'),
                  selected: group == 'ungrouped',
                  onSelected: (_) => setState(
                    () => group = group == 'ungrouped' ? null : 'ungrouped',
                  ),
                ),
              ],
            ),
            if (group != null && group != 'ungrouped')
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final child
                        in exerciseCategoryTree[categoryParent(group!)] ??
                            <String>[])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(exerciseGroups[child]!),
                          selected: group == child,
                          onSelected: (_) => setState(
                            () => group = group == child
                                ? categoryParent(child)
                                : child,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            Expanded(
              child: visible.isEmpty
                  ? const Center(
                      child: Text(
                        'Nenhum exercício neste grupo.',
                        style: TextStyle(color: muted),
                      ),
                    )
                  : ListView.builder(
                      itemCount: visible.length,
                      itemBuilder: (context, index) {
                        final exercise = visible[index];
                        final unavailable = excluded.contains(exercise.key);
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(exercise.name),
                          subtitle: Text(
                            unavailable
                                ? 'Já está neste treino'
                                : exercise.groups.isEmpty
                                ? 'Sem grupo'
                                : exercise.groups
                                      .map((g) => exerciseGroups[g] ?? g)
                                      .join(' · '),
                          ),
                          enabled: !unavailable,
                          onTap: unavailable
                              ? null
                              : () => Navigator.pop(context, exercise),
                          trailing: IconButton(
                            tooltip: 'Classificar ${exercise.name}',
                            onPressed: () => edit(exercise),
                            icon: const Icon(Icons.tune),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => edit(),
                icon: const Icon(Icons.add),
                label: const Text('Criar exercício'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ExerciseEditor extends StatefulWidget {
  const ExerciseEditor({
    required this.catalog,
    required this.onSave,
    this.existing,
    this.allowRename = false,
    super.key,
  });
  final List<ExerciseDefinition> catalog;
  final ExerciseDefinition? existing;
  final bool allowRename;
  final Future<void> Function(ExerciseDefinition) onSave;
  @override
  State<ExerciseEditor> createState() => _ExerciseEditorState();
}

class _ExerciseEditorState extends State<ExerciseEditor> {
  final form = GlobalKey<FormState>();
  late String name = widget.existing?.name ?? '';
  late final groups = {...?widget.existing?.groups};
  bool saving = false;
  String? error;

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    final exercise = ExerciseDefinition(name.trim(), groups);
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.onSave(exercise);
      if (mounted) Navigator.pop(context, exercise);
    } catch (_) {
      if (mounted) {
        setState(() {
          saving = false;
          error = 'Não foi possível salvar. Tente novamente.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: AlertDialog(
      title: Text(
        widget.existing == null
            ? 'Criar exercício'
            : widget.allowRename
            ? 'Editar exercício'
            : 'Classificar exercício',
      ),
      scrollable: true,
      content: Form(
        key: form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              initialValue: name,
              enabled:
                  !saving && (widget.existing == null || widget.allowRename),
              maxLength: 80,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Nome do exercício'),
              onChanged: (value) => name = value,
              validator: (value) => name.trim().isEmpty
                  ? 'Informe o nome.'
                  : widget.catalog.any(
                      (e) =>
                          e.key == name.trim().toLowerCase() &&
                          e.key != widget.existing?.key,
                    )
                  ? 'Esse exercício já está salvo.'
                  : null,
            ),
            const SizedBox(height: 12),
            const Text(
              'Grupos musculares',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Você pode selecionar mais de um.',
              style: TextStyle(color: muted),
            ),
            const SizedBox(height: 8),
            for (final category in exerciseCategoryTree.entries)
              if (category.value.isEmpty)
                FilterChip(
                  label: Text(exerciseGroups[category.key]!),
                  selected: groups.contains(category.key),
                  onSelected: saving
                      ? null
                      : (value) => setState(() {
                          value
                              ? groups.add(category.key)
                              : groups.remove(category.key);
                        }),
                )
              else
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text(exerciseGroups[category.key]!),
                  subtitle: Text(
                    '${groups.where(category.value.contains).length} selecionadas',
                  ),
                  children: [
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final key in category.value)
                          FilterChip(
                            label: Text(exerciseGroups[key]!),
                            selected: groups.contains(key),
                            onSelected: saving
                                ? null
                                : (value) => setState(() {
                                    value
                                        ? groups.add(key)
                                        : groups.remove(key);
                                  }),
                          ),
                      ],
                    ),
                  ],
                ),
            if (error != null)
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: saving ? null : save,
          child: Text(saving ? 'Salvando…' : 'Salvar exercício'),
        ),
      ],
    ),
  );
}
