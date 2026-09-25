import 'package:flutter/material.dart';

import 'models.dart';
import 'ui.dart';

class RoutineEditor extends StatefulWidget {
  const RoutineEditor({this.routine, super.key});
  final Routine? routine;
  @override
  State<RoutineEditor> createState() => _RoutineEditorState();
}

class _RoutineEditorState extends State<RoutineEditor> {
  late final name = TextEditingController(text: widget.routine?.name);
  final exercise = TextEditingController();
  late final exercises = [...?widget.routine?.exercises];
  String? error;
  @override
  void dispose() {
    name.dispose();
    exercise.dispose();
    super.dispose();
  }

  void add() {
    final value = exercise.text.trim();
    if (value.isEmpty) return;
    if (exercises.any((e) => e.toLowerCase() == value.toLowerCase())) {
      setState(() => error = 'Esse exercício já está na rotina.');
      return;
    }
    setState(() {
      exercises.add(value);
      exercise.clear();
      error = null;
    });
  }

  void save() {
    if (exercise.text.trim().isNotEmpty) {
      add();
      if (exercise.text.trim().isNotEmpty) return;
    }
    if (name.text.trim().isEmpty || exercises.isEmpty) {
      setState(() => error = 'Informe um nome e pelo menos um exercício.');
      return;
    }
    Navigator.pop(
      context,
      Routine(
        widget.routine?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        name.text.trim(),
        List.of(exercises),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .8,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.routine == null ? 'Uma nova rotina' : 'Editar rotina',
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Organize os exercícios na ordem do seu treino.',
              style: TextStyle(color: muted),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: name,
              maxLength: 60,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Nome da rotina',
                hintText: 'Ex.: Treino A — Peito e tríceps',
              ),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: exercise,
                    maxLength: 80,
                    textCapitalization: TextCapitalization.sentences,
                    onSubmitted: (_) => add(),
                    decoration: const InputDecoration(
                      labelText: 'Exercício',
                      hintText: 'Ex.: Supino reto',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: add,
                  tooltip: 'Adicionar exercício',
                  icon: const Icon(Icons.add),
                  style: IconButton.styleFrom(minimumSize: const Size(52, 56)),
                ),
              ],
            ),
            ...exercises.asMap().entries.map(
              (entry) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  radius: 16,
                  backgroundColor: const Color(0xFF34432A),
                  child: Text(
                    '${entry.key + 1}',
                    style: const TextStyle(color: accent, fontSize: 12),
                  ),
                ),
                title: Text(entry.value),
                trailing: IconButton(
                  tooltip: 'Remover ${entry.value}',
                  onPressed: () =>
                      setState(() => exercises.removeAt(entry.key)),
                  icon: const Icon(Icons.close, size: 20),
                ),
              ),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: save,
                child: const Text('Salvar rotina'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
