
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;


// Model สำหรับเก็บข้อมูล Pokemon แบบละเอียด
class PokemonDetail {
  final int id;
  final String name;
  final int height;
  final int weight;
  final List<String> types;
  final List<String> abilities;
  final Map<String, int> stats;
  final Map<String, String> sprites;
  final String description;

  const PokemonDetail({
    required this.id,
    required this.name,
    required this.height,
    required this.weight,
    required this.types,
    required this.abilities,
    required this.stats,
    required this.sprites,
    required this.description,
  });

  factory PokemonDetail.fromJson(Map<String, dynamic> json, String desc) {
    final List<dynamic> typesList = json['types'] ?? [];
    final List<dynamic> abilitiesList = json['abilities'] ?? [];
    final Map<String, dynamic> statsMap = {};
    
    if (json['stats'] != null) {
      for (var stat in json['stats']) {
        final String statName = stat['stat']['name'];
        final int baseStat = stat['base_stat'];
        statsMap[statName] = baseStat;
      }
    }

    final sprites = json['sprites'] ?? {};
    final other = sprites['other'] ?? {};
    final officialArtwork = other['official-artwork'] ?? {};
    final dreamWorld = other['dream_world'] ?? {};

    return PokemonDetail(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      height: json['height'] ?? 0,
      weight: json['weight'] ?? 0,
      types: typesList.map((t) => t['type']['name'].toString()).toList(),
      abilities: abilitiesList.map((a) => a['ability']['name'].toString()).toList(),
      stats: Map<String, int>.from(statsMap),
      sprites: {
        'front_default': sprites['front_default'] ?? '',
        'front_shiny': sprites['front_shiny'] ?? '',
        'official_artwork': officialArtwork['front_default'] ?? '',
        'dream_world': dreamWorld['front_default'] ?? '',
      },
      description: desc,
    );
  }
}

// Controller สำหรับจัดการข้อมูล Pokemon Detail
class PokemonDetailController extends GetxController {
  final RxBool isLoading = true.obs;
  final Rx<PokemonDetail?> pokemon = Rx<PokemonDetail?>(null);
  final RxString selectedSprite = 'official_artwork'.obs;
  final RxString error = ''.obs;

  Future<void> loadPokemonDetail(String name) async {
    try {
      isLoading.value = true;
      error.value = '';

      // Fetch Pokemon data
      final pokemonResponse = await http.get(
        Uri.parse('https://pokeapi.co/api/v2/pokemon/${name.toLowerCase()}')
      );

      if (pokemonResponse.statusCode != 200) {
        throw Exception('Failed to load Pokemon data');
      }

      final pokemonJson = jsonDecode(pokemonResponse.body);

      // Fetch Pokemon species for description
      final speciesResponse = await http.get(
        Uri.parse('https://pokeapi.co/api/v2/pokemon-species/${pokemonJson['id']}')
      );

      String description = 'No description available';
      if (speciesResponse.statusCode == 200) {
        final speciesJson = jsonDecode(speciesResponse.body);
        final flavorTexts = speciesJson['flavor_text_entries'] as List;
        
        // หาคำอธิบายภาษาอังกฤษ
        final englishEntry = flavorTexts.firstWhere(
          (entry) => entry['language']['name'] == 'en',
          orElse: () => null,
        );
        
        if (englishEntry != null) {
          description = englishEntry['flavor_text']
              .toString()
              .replaceAll('\n', ' ')
              .replaceAll('\f', ' ')
              .trim();
        }
      }

      pokemon.value = PokemonDetail.fromJson(pokemonJson, description);
      
      // เลือก sprite ที่มีภาพ
      final sprites = pokemon.value!.sprites;
      if (sprites['official_artwork']?.isNotEmpty == true) {
        selectedSprite.value = 'official_artwork';
      } else if (sprites['dream_world']?.isNotEmpty == true) {
        selectedSprite.value = 'dream_world';
      } else if (sprites['front_default']?.isNotEmpty == true) {
        selectedSprite.value = 'front_default';
      }

    } catch (e) {
      error.value = 'Error loading Pokemon: $e';
    } finally {
      isLoading.value = false;
    }
  }
}

// หน้า Pokemon Detail
class PokemonDetailPage extends StatefulWidget {
  final String pokemonName;
  final String? teamName;

  const PokemonDetailPage({
    super.key,
    required this.pokemonName,
    this.teamName,
  });

  @override
  State<PokemonDetailPage> createState() => _PokemonDetailPageState();
}

class _PokemonDetailPageState extends State<PokemonDetailPage> {
  late final PokemonDetailController controller;

  @override
  void initState() {
    super.initState();
    controller = Get.put(PokemonDetailController());
    controller.loadPokemonDetail(widget.pokemonName);
  }

  @override
  void dispose() {
    Get.delete<PokemonDetailController>();
    super.dispose();
  }

  Color getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'fire': return Colors.red.shade400;
      case 'water': return Colors.blue.shade400;
      case 'grass': return Colors.green.shade400;
      case 'electric': return Colors.yellow.shade600;
      case 'psychic': return Colors.pink.shade400;
      case 'ice': return Colors.lightBlue.shade300;
      case 'dragon': return Colors.indigo.shade400;
      case 'dark': return Colors.brown.shade400;
      case 'fairy': return Colors.pink.shade200;
      case 'normal': return Colors.grey.shade400;
      case 'fighting': return Colors.red.shade700;
      case 'poison': return Colors.purple.shade400;
      case 'ground': return Colors.orange.shade300;
      case 'flying': return Colors.indigo.shade200;
      case 'bug': return Colors.green.shade300;
      case 'rock': return Colors.grey.shade600;
      case 'ghost': return Colors.purple.shade300;
      case 'steel': return Colors.blueGrey.shade400;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        if (controller.error.value.isNotEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
                const SizedBox(height: 16),
                Text(controller.error.value, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => controller.loadPokemonDetail(widget.pokemonName),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final pokemon = controller.pokemon.value;
        if (pokemon == null) {
          return const Center(child: Text('No data available'));
        }

        return CustomScrollView(
          slivers: [
            // App Bar with Hero Image
            SliverAppBar(
              expandedHeight: 300,
              pinned: true,
              backgroundColor: pokemon.types.isNotEmpty 
                  ? getTypeColor(pokemon.types.first).withOpacity(0.8)
                  : Colors.blue,
              flexibleSpace: FlexibleSpaceBar(
                title: Text(
                  pokemon.name.capitalize ?? pokemon.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(offset: Offset(1, 1), blurRadius: 3, color: Colors.black45)
                    ],
                  ),
                ),
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        if (pokemon.types.isNotEmpty) ...[
                          getTypeColor(pokemon.types.first),
                          if (pokemon.types.length > 1)
                            getTypeColor(pokemon.types[1])
                          else
                            getTypeColor(pokemon.types.first).withOpacity(0.7),
                        ] else ...[
                          Colors.blue,
                          Colors.blue.shade300,
                        ]
                      ],
                    ),
                  ),
                  child: Center(
                    child: Hero(
                      tag: 'pokemon-${widget.pokemonName}',
                      child: Obx(() {
                        final spriteUrl = pokemon.sprites[controller.selectedSprite.value] ?? '';
                        return spriteUrl.isEmpty
                            ? const Icon(Icons.catching_pokemon, size: 120, color: Colors.white70)
                            : Image.network(
                                spriteUrl,
                                width: 200,
                                height: 200,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(Icons.catching_pokemon, size: 120, color: Colors.white70),
                              );
                      }),
                    ),
                  ),
                ),
              ),
            ),

            // Content
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Basic Info Card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  '#${pokemon.id.toString().padLeft(3, '0')}',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '${(pokemon.height / 10).toStringAsFixed(1)} m',
                                  style: const TextStyle(fontSize: 16),
                                ),
                                const SizedBox(width: 16),
                                Text(
                                  '${(pokemon.weight / 10).toStringAsFixed(1)} kg',
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            
                            // Types
                            const Text('Type:', style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              children: pokemon.types.map((type) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: getTypeColor(type),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    type.capitalize ?? type,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Description Card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Description',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              pokemon.description,
                              style: const TextStyle(fontSize: 14, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Stats Card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Base Stats',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),
                            ...pokemon.stats.entries.map((stat) {
                              final statName = stat.key.replaceAll('-', ' ').capitalize ?? stat.key;
                              final statValue = stat.value;
                              final progress = statValue / 150; // สูงสุดประมาณ 150
                              
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 80,
                                      child: Text(
                                        statName,
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 40,
                                      child: Text(
                                        statValue.toString(),
                                        textAlign: TextAlign.right,
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: LinearProgressIndicator(
                                        value: progress.clamp(0.0, 1.0),
                                        backgroundColor: Colors.grey.shade300,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          progress > 0.7 ? Colors.green :
                                          progress > 0.4 ? Colors.orange : Colors.red,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Abilities Card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Abilities',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: pokemon.abilities.map((ability) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    border: Border.all(color: Colors.blue.shade200),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    ability.replaceAll('-', ' ').capitalize ?? ability,
                                    style: TextStyle(color: Colors.blue.shade700),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Sprite Gallery Card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Gallery',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 100,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                children: pokemon.sprites.entries
                                    .where((entry) => entry.value.isNotEmpty)
                                    .map((entry) {
                                  final isSelected = controller.selectedSprite.value == entry.key;
                                  return GestureDetector(
                                    onTap: () => controller.selectedSprite.value = entry.key,
                                    child: Container(
                                      width: 100,
                                      margin: const EdgeInsets.only(right: 8),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: isSelected ? Colors.blue : Colors.grey.shade300,
                                          width: 2,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Image.network(
                                        entry.value,
                                        fit: BoxFit.contain,
                                        errorBuilder: (context, error, stackTrace) =>
                                            const Icon(Icons.image_not_supported),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}