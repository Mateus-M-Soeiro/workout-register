import 'package:flutter/material.dart';

import 'models.dart';
import 'ui.dart';
import 'routine_editor.dart';
import 'workout_screen.dart';
import 'progress_screen.dart';
import 'history_screen.dart';

class MainApp extends StatelessWidget {
  const MainApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Ritmo • Registro de treinos',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        primary: accent,
        onPrimary: Color(0xFF18210F),
        surface: surface,
        onSurface: Color(0xFFF2F5EC),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        centerTitle: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: background,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF3D4738)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: Color(0xFF34432A),
      ),
    ),
    home: const HomeScreen(),
  );
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final store = WorkoutStore();
  bool loading = true;
  bool failed = false;
  bool saving = false;
  int tab = 0;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      failed = false;
    });
    try {
      await store.load();
    } catch (_) {
      failed = true;
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> saveRoutines(List<Routine> routines) async {
    setState(() => saving = true);
    try {
      await store.save(routines: routines);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível salvar. Tente novamente.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> edit([Routine? routine]) async {
    final result = await showModalBottomSheet<Routine>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => RoutineEditor(routine: routine),
    );
    if (result == null || !mounted) return;
    final next = [...store.routines];
    final index = next.indexWhere((r) => r.id == result.id);
    if (index < 0) {
      next.add(result);
    } else {
      next[index] = result;
    }
    await saveRoutines(next);
  }

  Future<void> remove(Routine routine) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir rotina?'),
        content: Text(
          '“${routine.name}” será removida. O histórico será mantido.',
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
    if (yes == true && mounted) {
      await saveRoutines(
        store.routines.where((r) => r.id != routine.id).toList(),
      );
    }
  }

  Future<void> start(Routine routine) async {
    if (saving) return;
    setState(() => saving = true);
    try {
      if (store.active == null) {
        await store.save(active: ActiveWorkout.start(routine));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Não foi possível iniciar e salvar o treino. Tente novamente.',
            ),
          ),
        );
      }
      return;
    } finally {
      if (mounted) setState(() => saving = false);
    }
    if (!mounted) return;
    final draft = store.active!;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => WorkoutScreen(
          routine: draft.routine,
          draft: draft,
          previous: historyForRoutine(
            store.sessions,
            draft.routine,
          ).firstOrNull,
          onDraft: (draft) async {
            await store.save(active: draft);
            if (mounted) setState(() {});
          },
          onDiscard: () async {
            await store.save(clearActive: true);
            if (mounted) setState(() {});
          },
          onFinish: (session) async {
            await store.save(
              sessions: [...store.sessions, session],
              clearActive: true,
            );
            if (mounted) setState(() {});
          },
        ),
      ),
    );
  }

  void history([Routine? routine]) => Navigator.push<void>(
    context,
    MaterialPageRoute(
      builder: (_) => HistoryScreen(sessions: store.sessions, routine: routine),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: loading
          ? const Center(child: CircularProgressIndicator())
          : failed
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Não foi possível carregar seus dados.'),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: load,
                    child: const Text('Tentar novamente'),
                  ),
                ],
              ),
            )
          : tab == 1
          ? ProgressScreen(sessions: store.sessions)
          : home(),
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: tab,
      onDestinationSelected: (value) => setState(() => tab = value),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.grid_view_rounded),
          label: 'Rotinas',
        ),
        NavigationDestination(
          icon: Icon(Icons.insights_rounded),
          label: 'Evolução',
        ),
      ],
    ),
  );

  Widget home() => PageContent(
    children: [
      Row(
        children: [
          const Expanded(
            child: Text(
              'Minhas rotinas',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ),
          Text(
            '${store.routines.length}',
            style: const TextStyle(color: muted),
          ),
          IconButton(
            onPressed: () => history(),
            tooltip: 'Histórico de todos os treinos',
            icon: const Icon(Icons.history),
          ),
        ],
      ),
      const SizedBox(height: 16),
      if (saving) const LinearProgressIndicator(),
      if (store.active != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Em andamento: ${store.active!.routine.name}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Início: ${timestamp(store.active!.startedAt)}',
                  style: const TextStyle(color: muted),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: saving ? null : () => start(store.active!.routine),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Retomar treino'),
                ),
              ],
            ),
          ),
        ),
      if (store.routines.isEmpty)
        const Panel(
          child: Column(
            children: [
              Icon(Icons.add_task, size: 44, color: accent),
              SizedBox(height: 16),
              Text(
                'Nenhuma rotina criada',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Crie sua primeira rotina e adicione os exercícios do seu treino.',
                textAlign: TextAlign.center,
                style: TextStyle(color: muted, height: 1.5),
              ),
            ],
          ),
        ),
      ...store.routines.asMap().entries.map((entry) {
        final routine = entry.value;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'ROTINA ${(entry.key + 1).toString().padLeft(2, '0')}',
                      style: const TextStyle(
                        color: accent,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const Spacer(),
                    PopupMenuButton<String>(
                      enabled: !saving,
                      tooltip: 'Opções da rotina',
                      onSelected: (value) {
                        if (value == 'edit') {
                          edit(routine);
                        } else {
                          remove(routine);
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'edit',
                          child: Text('Editar rotina'),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text('Excluir rotina'),
                        ),
                      ],
                    ),
                  ],
                ),
                Text(
                  routine.name,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${routine.exercises.length} exercícios • ${routine.exercises.join(' · ')}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: muted, height: 1.5),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: saving || store.active != null
                        ? null
                        : () => start(routine),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Iniciar treino'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () => history(routine),
                    icon: const Icon(Icons.history),
                    label: const Text('Ver histórico'),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          side: const BorderSide(color: accent),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        onPressed: saving ? null : () => edit(),
        icon: const Icon(Icons.add),
        label: const Text('Criar nova rotina'),
      ),
    ],
  );
}
