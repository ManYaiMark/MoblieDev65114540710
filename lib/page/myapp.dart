import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:myapp/page/playerselection.dart';


class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple)),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  /// load teams from storage
  Future<List<SavedTeam>> _loadTeams() async {
    final box = GetStorage();
    final raw = (box.read<List>('teams') ?? []);
    return raw.map((e) => SavedTeam.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  /// rename a team
  Future<void> _renameTeam(SavedTeam team) async {
    final ctl = TextEditingController(text: team.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rename team'),
        content: TextField(
          controller: ctl,
          decoration: const InputDecoration(labelText: 'Team name'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, ''), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, ctl.text.trim()), child: const Text('Save')),
        ],
      ),
    );

    if (newName == null || newName.isEmpty || newName == team.name) return;

    final box = GetStorage();
    final raw = (box.read<List>('teams') ?? []);
    final list = raw.map((e) => SavedTeam.fromJson(Map<String, dynamic>.from(e))).toList();

    final idx = list.indexWhere((t) => t.name == team.name);
    if (idx >= 0) {
      list[idx] = SavedTeam(name: newName, members: team.members, imgs: team.imgs);
      await box.write('teams', list.map((e) => e.toJson()).toList());
      setState(() {});
    }
  }

  /// delete a team
  Future<void> _deleteTeam(SavedTeam team) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Team'),
        content: Text('Are you sure you want to delete "${team.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true) return;

    final box = GetStorage();
    final raw = (box.read<List>('teams') ?? []);
    final list = raw.map((e) => SavedTeam.fromJson(Map<String, dynamic>.from(e))).toList();
    list.removeWhere((t) => t.name == team.name);
    await box.write('teams', list.map((e) => e.toJson()).toList());
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: FutureBuilder<List<SavedTeam>>(
        future: _loadTeams(),
        builder: (context, snap) {
          final teams = snap.data ?? [];
          if (teams.isEmpty) {
            return const Center(child: Text('No teams yet. Tap the button to create one.'));
          }
          return GridView.count(
            crossAxisCount: 2,
            childAspectRatio: 2.8,
            padding: const EdgeInsets.all(16),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            children: teams.map((t) {
              return InkWell(
                onTap: () {
                  Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => Playerselection(initialTeam: t)))
                      .then((_) => setState(() {}));
                },
                child: Card(
                  elevation: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // header: team name + actions
                        Row(
                          children: [
                            Expanded(
                              child: Hero(
                                tag: 'teamname-${t.name}',
                                child: Text(
                                  t.name,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit, size: 20),
                              tooltip: 'Rename Team',
                              onPressed: () => _renameTeam(t),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                              tooltip: 'Delete Team',
                              onPressed: () => _deleteTeam(t),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // members preview (centered)
                        Expanded(
                          child: Center(
                            child: Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              alignment: WrapAlignment.center,
                              children: t.members.map((m) {
                                final img = t.imgs[m];
                                final tag = 'poke-${t.name}-$m';
                                return Hero(
                                  tag: tag,
                                  child: CircleAvatar(
                                    radius: 86,
                                    backgroundImage: (img == null || img.isEmpty) ? null : NetworkImage(img),
                                    child: (img == null || img.isEmpty)
                                        ? const Icon(Icons.catching_pokemon)
                                        : null,
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const Playerselection()))
              .then((_) => setState(() {}));
        },
        label: const Text('Create Team'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}