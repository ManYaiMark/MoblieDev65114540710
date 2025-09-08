import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'PokemonDetailPage.dart';

/// Data Model
class SavedTeam {
  final String name;
  final List<String> members;
  final Map<String, String> imgs;
  const SavedTeam({required this.name, required this.members, required this.imgs});

  Map<String, dynamic> toJson() => {'name': name, 'members': members, 'imgs': imgs};

  factory SavedTeam.fromJson(Map<String, dynamic> j) => SavedTeam(
        name: j['name'] as String,
        members: List<String>.from(j['members'] ?? const []),
        imgs: Map<String, String>.from(j['imgs'] ?? const {}),
      );
}


/// Controller เลื่อนนทีม

class TeamController extends GetxController {
  // storage
  final box = GetStorage();

  // search
  final TextEditingController searchCtl = TextEditingController();
  final RxString query = ''.obs;

  // team name
  final RxString teamName = 'My Team'.obs;

  // all candidates
  final RxList<String> allNames = <String>[
    'Venusaur','Charizard','Blastoise','Beedrill',
    'Pidgeot','Raticate','Fearow','Arbok',
    'Pikachu','Sandslash','Nidoking','Nidoqueen',
    'Ninetales','Wigglytuff','Arcanine','Alakazam',
    'Machamp','Tentacruel','Golem','Rapidash',
  ].obs;

  // selection state
  final RxSet<String> selected = <String>{}.obs;
  final RxList<String> selectedOrder = <String>[].obs;

  // image cache: name -> url
  final RxMap<String, String> imageByName = <String, String>{}.obs;

  // filtered list by query
  List<String> get filteredNames {
    final q = query.value.trim().toLowerCase();
    if (q.isEmpty) return allNames;
    return allNames.where((e) => e.toLowerCase().contains(q)).toList();
  }

  @override
  void onInit() {
    super.onInit();

    // load last snapshot (if any)
    final snap = box.read('current_team_snapshot');
    if (snap is Map) {
      teamName.value = (snap['name'] as String?) ?? 'My Team';
      final members = List<String>.from(snap['members'] ?? const []);
      selected.addAll(members);
      selectedOrder.addAll(members);
      imageByName.addAll(Map<String, String>.from(snap['imgs'] ?? const {}));
    }

    _prefetchImages(allNames);
  }

  /// persist current working snapshot
  Future<void> saveSnapshot() async {
    await box.write('current_team_snapshot', {
      'name': teamName.value,
      'members': selectedOrder.toList(),
      'imgs': imageByName.map((k, v) => MapEntry(k, v)),
    });
  }

  /// fetch images from PokeAPI and cache them
  Future<void> _prefetchImages(List<String> names) async {
    for (final n in names) {
      if (imageByName.containsKey(n)) continue;
      try {
        final res = await http.get(Uri.parse('https://pokeapi.co/api/v2/pokemon/${n.toLowerCase()}'));
        if (res.statusCode == 200) {
          final j = jsonDecode(res.body);
          final img = (j['sprites']?['other']?['official-artwork']?['front_default'])?.toString();
          if (img != null) imageByName[n] = img;
        }
      } catch (_) {}
    }
    await saveSnapshot();
  }

  /// toggle select/deselect member
  void toggle(String name) {
    if (selected.contains(name)) {
      selected.remove(name);
      selectedOrder.remove(name);
    } else {
      if (selected.length >= 3) {
        Get.showSnackbar(const GetSnackBar(message: 'เลือกได้สูงสุด 3 คน', duration: Duration(seconds: 2)));
        return;
      }
      selected.add(name);
      selectedOrder.add(name);
      if (!imageByName.containsKey(name)) {
        _prefetchImages([name]);
      }
    }
    saveSnapshot();
  }

  /// clear team members
  void clearTeam() {
    selected.clear();
    selectedOrder.clear();
    saveSnapshot();
  }

  /// reorder selected members
  void reorder(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    final item = selectedOrder.removeAt(oldIndex);
    selectedOrder.insert(newIndex, item);
    saveSnapshot();
  }
}

/// หน้าเลือกผู้เล่น
class Playerselection extends StatefulWidget {
  const Playerselection({super.key, this.initialTeam});
  final SavedTeam? initialTeam;

  @override
  State<Playerselection> createState() => _PlayerselectionState();
}

class _PlayerselectionState extends State<Playerselection> {
  // controller
  late final TeamController c;

  // initial team name for hero tags
  late String _teamNameForHero;

  @override
  void initState() {
    super.initState();
    c = Get.put(TeamController(), permanent: true);

    // load team to edit or start fresh
    if (widget.initialTeam != null) {
      final t = widget.initialTeam!;
      c.teamName.value = t.name;
      c.selected..clear()..addAll(t.members);
      c.selectedOrder..clear()..addAll(t.members);
      c.imageByName.addAll(t.imgs);
      c.saveSnapshot();
    } else {
      c.teamName.value = 'My Team';
      c.selected.clear();
      c.selectedOrder.clear();
    }

    _teamNameForHero = widget.initialTeam?.name ?? c.teamName.value;
  }

  /// save team 
  Future<void> _saveAndClose() async {
    var name = c.teamName.value.trim();
    if (name.isEmpty) {
      final ctl = TextEditingController();
      name = await showDialog<String>(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Team name is required'),
              content: TextField(
                controller: ctl,
                decoration: const InputDecoration(labelText: 'Team name'),
                autofocus: true,
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, ''), child: const Text('Cancel')),
                TextButton(onPressed: () => Navigator.pop(context, ctl.text.trim()), child: const Text('OK')),
              ],
            ),
          ) ??
          '';
      if (name.isEmpty) return;
      c.teamName.value = name;
    }

    final box = GetStorage();
    final list = (box.read<List>('teams') ?? [])
        .map((e) => SavedTeam.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    // ensure unique name when creating
    if (widget.initialTeam == null) {
      final base = c.teamName.value;
      var candidate = base;
      var i = 2;
      while (list.any((t) => t.name == candidate)) {
        candidate = '$base ($i)';
        i++;
      }
      c.teamName.value = candidate;
    }

    final data = SavedTeam(
      name: c.teamName.value,
      members: c.selectedOrder.toList(),
      imgs: c.imageByName.map((k, v) => MapEntry(k, v)),
    );

    if (widget.initialTeam != null) {
      final idx = list.indexWhere((t) => t.name == widget.initialTeam!.name);
      if (idx >= 0) {
        list[idx] = data;
      } else {
        list.add(data);
      }
    } else {
      list.add(data);
    }

    await box.write('teams', list.map((e) => e.toJson()).toList());
    await c.saveSnapshot();

    if (mounted) {
      Navigator.pop(context, data);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Obx(
          () => Hero(
            tag: 'teamname-$_teamNameForHero',
            child: Text(
              c.teamName.value,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        actions: [
          Obx(
            () => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Center(child: Text('${c.selected.length}/3')),
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              // selected bar
              Container(
                height: 240,
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Obx(
                  () => c.selected.isEmpty
                      ? const Center(child: Text('เลือกผู้เล่นได้สูงสุด 3 คน'))
                      : Row(
                          children: [
                            Expanded(
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  const itemWidth = 280.0;
                                  const gap = 12.0;
                                  final total = c.selectedOrder.length * itemWidth +
                                      (c.selectedOrder.length - 1) * gap;
                                  final pad = total < constraints.maxWidth
                                      ? (constraints.maxWidth - total) / 2
                                      : 0.0;

                                  return ReorderableListView.builder(
                                    key: const PageStorageKey('selected-top-bar'),
                                    scrollDirection: Axis.horizontal,
                                    padding: EdgeInsets.symmetric(horizontal: pad),
                                    buildDefaultDragHandles: false,
                                    itemCount: c.selectedOrder.length,
                                    onReorder: c.reorder,
                                    itemBuilder: (context, i) {
                                      final name = c.selectedOrder[i];
                                      final img = c.imageByName[name];
                                      return Container(
                                        key: ValueKey(name),
                                        width: itemWidth,
                                        margin: EdgeInsets.only(
                                          right: i == c.selectedOrder.length - 1 ? 0 : gap,
                                        ),
                                        alignment: Alignment.center,
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            ReorderableDragStartListener(
                                              index: i,
                                              child: GestureDetector(  // เพิ่ม GestureDetector ครอบ Stack
                                                onTap: () {
                                                  // เมื่อคลิกจะไปหน้าใหม่
                                                  Get.to(() => PokemonDetailPage(pokemonName: name));
                                                  
                                                  // หรือถ้าต้องการส่งข้อมูลไปด้วย
                                                  // Get.to(() => PokemonDetailPage(), arguments: {
                                                  //   'name': name,
                                                  //   'image': img,
                                                  //   'teamName': c.teamName.value
                                                  // });
                                                },
                                                child: Stack(
                                                  children: [
                                                    Hero(
                                                      tag: 'poke-$_teamNameForHero-$name',
                                                      child: ClipRRect(
                                                        borderRadius: BorderRadius.circular(12),
                                                        child: img == null 
                                                          ? const SizedBox(
                                                              width: 260, 
                                                              height: 150,
                                                              child: Center(child: CircularProgressIndicator()),
                                                            )
                                                          : Image.network(
                                                              img,
                                                              width: 260,
                                                              height: 150,
                                                              fit: BoxFit.contain,
                                                            ),
                                                      ),
                                                    ),
                                                    Positioned(
                                                      top: 6,
                                                      right: 6,
                                                      child: InkWell(
                                                        onTap: () => c.toggle(name), // ปุ่ม X ยังคงทำงานเหมือนเดิม
                                                        child: Container(
                                                          padding: const EdgeInsets.all(4),
                                                          decoration: const BoxDecoration(
                                                            shape: BoxShape.circle,
                                                            color: Colors.black54,
                                                          ),
                                                          child: const Icon(
                                                            Icons.close,
                                                            size: 16,
                                                            color: Colors.white,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                                const SizedBox(height: 4),
                                            Text("CP ${1000 + i * 200}",  // ตัวอย่าง mock CP
                                                style: const TextStyle(fontSize: 12, color: Colors.black54)),

                                            const SizedBox(height: 4),
                                            SizedBox(
                                              width: 200,
                                              child: LinearProgressIndicator(
                                                value: 0.6, // mock ค่า 60% HP
                                                backgroundColor: Colors.red.shade100,
                                                valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text("HP 90/150", // mock ค่า HP
                                                style: const TextStyle(fontSize: 12, color: Colors.black54)),
                                          ],
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
                            TextButton(
                              onPressed: c.clearTeam,
                              child: const Text('Clear All'),
                            ),
                          ],
                        ),
                ),
              ),

              // toolbar under selected bar
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                child: Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _saveAndClose,
                      icon: const Icon(Icons.check),
                      label: const Text('Save Team'),
                    ),
                    const SizedBox(width: 8),
                    const Spacer(),
                    SizedBox(
                      width: 280,
                      child: TextField(
                        controller: c.searchCtl,
                        decoration: const InputDecoration(
                          hintText: 'Search Pokémon',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (v) => c.query.value = v,
                      ),
                    ),
                  ],
                ),
              ),

              // grid
              Expanded(
                child: Obx(() {
                  final names = c.filteredNames;
                  return GridView.count(
                    crossAxisCount: 4,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    padding: const EdgeInsets.all(10),
                    children: List.generate(names.length, (i) {
                      final name = names[i];
                      final img = c.imageByName[name];
                      final isSelected = c.selected.contains(name);

                      return GestureDetector(
                        onTap: () => c.toggle(name),
                        child: AnimatedScale(
                          duration: const Duration(milliseconds: 140),
                          scale: isSelected ? 0.97 : 1.0,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOut,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.blue.shade200 : Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? Colors.blue : Colors.blue.shade100,
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (img == null)
                                  const SizedBox(
                                    width: 90,
                                    height: 90,
                                    child: Center(child: CircularProgressIndicator()),
                                  )
                                else
                                  AnimatedOpacity(
                                    duration: const Duration(milliseconds: 150),
                                    opacity: isSelected ? 1 : 0.95,
                                    child: Image.network(img, width: 120, height: 120),
                                  ),
                                const SizedBox(height: 8),
                                Text(
                                  name,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected ? Colors.white : Colors.black87,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}