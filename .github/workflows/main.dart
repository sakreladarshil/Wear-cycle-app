\
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const WearCycleApp());

class WearCycleApp extends StatelessWidget {
  const WearCycleApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'WearCycle',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF315C4B),
            brightness: Brightness.light,
          ),
          scaffoldBackgroundColor: const Color(0xFFF6F7F3),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFFF6F7F3),
            surfaceTintColor: Colors.transparent,
          ),
        ),
        home: const WardrobeScreen(),
      );
}

class Garment {
  Garment({
    required this.id,
    required this.name,
    required this.category,
    required this.limit,
    this.wears = 0,
    this.photoPath,
  });

  final String id;
  String name;
  String category;
  int limit;
  int wears;
  String? photoPath;

  bool get needsWash => wears >= limit;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'limit': limit,
        'wears': wears,
        'photoPath': photoPath,
      };

  factory Garment.fromJson(Map<String, dynamic> json) => Garment(
        id: json['id'] as String,
        name: json['name'] as String,
        category: json['category'] as String,
        limit: json['limit'] as int,
        wears: json['wears'] as int? ?? 0,
        photoPath: json['photoPath'] as String?,
      );
}

class WardrobeScreen extends StatefulWidget {
  const WardrobeScreen({super.key});

  @override
  State<WardrobeScreen> createState() => _WardrobeScreenState();
}

class _WardrobeScreenState extends State<WardrobeScreen> {
  final List<Garment> garments = [];
  final picker = ImagePicker();
  String filter = 'All';
  bool loading = true;

  static const defaults = <String, int>{
    'T-shirt': 2,
    'Lower': 3,
    'Towel': 4,
    'Shirt': 2,
    'Pants': 3,
    'White coat': 4,
    'Handkerchief': 1,
    'Socks': 2,
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('garments');
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw) as List<dynamic>;
        garments.addAll(decoded.map((e) =>
            Garment.fromJson(Map<String, dynamic>.from(e as Map))));
      } catch (_) {
        // Ignore a damaged local save rather than preventing the app opening.
      }
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'garments', jsonEncode(garments.map((g) => g.toJson()).toList()));
  }

  Future<void> _addGarment() async {
    final nameController = TextEditingController();
    String category = defaults.keys.first;
    int limit = defaults[category]!;
    String? photo;

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Add clothing item',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 14),
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(
                    labelText: 'Name (e.g. Blue graphic tee)',
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: category,
                decoration: const InputDecoration(
                    labelText: 'Type', border: OutlineInputBorder()),
                items: defaults.keys
                    .map((k) => DropdownMenuItem(value: k, child: Text(k)))
                    .toList(),
                onChanged: (v) => setSheetState(() {
                  category = v!;
                  limit = defaults[category]!;
                }),
              ),
              const SizedBox(height: 12),
              Row(children: [
                const Text('Wash after'),
                const SizedBox(width: 12),
                IconButton(
                    onPressed: limit > 1
                        ? () => setSheetState(() => limit--)
                        : null,
                    icon: const Icon(Icons.remove_circle_outline)),
                Text('$limit uses',
                    style: Theme.of(context).textTheme.titleMedium),
                IconButton(
                    onPressed: () => setSheetState(() => limit++),
                    icon: const Icon(Icons.add_circle_outline)),
              ]),
              OutlinedButton.icon(
                onPressed: () async {
                  final image =
                      await picker.pickImage(source: ImageSource.gallery);
                  if (image != null) setSheetState(() => photo = image.path);
                },
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(photo == null ? 'Choose photo (optional)' : 'Photo selected'),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () {
                  if (nameController.text.trim().isEmpty) return;
                  Navigator.pop(context, true);
                },
                child: const Text('Add to wardrobe'),
              ),
            ],
          ),
        ),
      ),
    );

    if (result == true) {
      setState(() {
        garments.add(Garment(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          name: nameController.text.trim(),
          category: category,
          limit: limit,
          photoPath: photo,
        ));
      });
      await _save();
    }
    nameController.dispose();
  }

  Future<void> _wear(Garment g) async {
    setState(() => g.wears++);
    await _save();
  }

  Future<void> _washed(Garment g) async {
    setState(() => g.wears = 0);
    await _save();
  }

  Future<void> _delete(Garment g) async {
    setState(() => garments.removeWhere((x) => x.id == g.id));
    await _save();
  }

  @override
  Widget build(BuildContext context) {
    final visible = garments.where((g) {
      if (filter == 'Needs washing') return g.needsWash;
      if (filter == 'Clean') return g.wears == 0;
      if (filter == 'Worn') return g.wears > 0 && !g.needsWash;
      return true;
    }).toList();
    final dirtyCount = garments.where((g) => g.needsWash).length;

    return Scaffold(
      appBar: AppBar(
        title: const Row(children: [
          Icon(Icons.checkroom, color: Color(0xFF315C4B)),
          SizedBox(width: 9),
          Text('WearCycle', style: TextStyle(fontWeight: FontWeight.w800)),
        ]),
        actions: [
          IconButton(
            tooltip: 'About',
            onPressed: () => showAboutDialog(
              context: context,
              applicationName: 'WearCycle',
              applicationVersion: '1.0.0',
              children: const [
                Text('A private, on-device tracker for clothing wear and laundry.'),
              ],
            ),
            icon: const Icon(Icons.info_outline),
          )
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addGarment,
        icon: const Icon(Icons.add),
        label: const Text('Add item'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 88),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5EEE8),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('YOUR WARDROBE',
                            style: TextStyle(
                                letterSpacing: 1.2,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF315C4B))),
                        const SizedBox(height: 8),
                        Text('${garments.length} items',
                            style: Theme.of(context).textTheme.headlineMedium),
                        const SizedBox(height: 4),
                        Text('$dirtyCount need${dirtyCount == 1 ? 's' : ''} washing',
                            style: const TextStyle(color: Color(0xFF315C4B))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['All', 'Needs washing', 'Worn', 'Clean']
                          .map((f) => Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(f),
                                  selected: filter == f,
                                  onSelected: (_) => setState(() => filter = f),
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: visible.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.checkroom_outlined,
                                    size: 48, color: Colors.black38),
                                const SizedBox(height: 10),
                                Text(garments.isEmpty
                                    ? 'Your wardrobe is empty'
                                    : 'Nothing in this section'),
                                const SizedBox(height: 4),
                                const Text('Add an item to start tracking.',
                                    style: TextStyle(color: Colors.black54)),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: visible.length,
                            itemBuilder: (context, index) {
                              final g = visible[index];
                              final progress =
                                  (g.wears / g.limit).clamp(0.0, 1.0);
                              return Card(
                                margin: const EdgeInsets.only(bottom: 10),
                                elevation: 0,
                                color: Colors.white,
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: SizedBox(
                                          width: 64,
                                          height: 72,
                                          child: g.photoPath != null &&
                                                  File(g.photoPath!).existsSync()
                                              ? Image.file(File(g.photoPath!),
                                                  fit: BoxFit.cover)
                                              : Container(
                                                  color: const Color(0xFFEAF0EC),
                                                  child: const Icon(
                                                      Icons.checkroom,
                                                      color: Color(0xFF527563),
                                                      size: 30),
                                                ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(g.name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 16)),
                                            Text('${g.category} · ${g.wears}/${g.limit} uses',
                                                style: const TextStyle(
                                                    color: Colors.black54,
                                                    fontSize: 12)),
                                            const SizedBox(height: 8),
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child: LinearProgressIndicator(
                                                value: progress,
                                                minHeight: 6,
                                                backgroundColor:
                                                    const Color(0xFFE9ECE8),
                                                color: g.needsWash
                                                    ? Colors.red.shade400
                                                    : const Color(0xFF527563),
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              g.needsWash
                                                  ? 'Needs washing'
                                                  : g.wears == 0
                                                      ? 'Clean'
                                                      : 'Ready to wear',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: g.needsWash
                                                    ? Colors.red.shade700
                                                    : const Color(0xFF527563),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      PopupMenuButton<String>(
                                        onSelected: (v) {
                                          if (v == 'wear') _wear(g);
                                          if (v == 'wash') _washed(g);
                                          if (v == 'delete') _delete(g);
                                        },
                                        itemBuilder: (_) => const [
                                          PopupMenuItem(
                                              value: 'wear',
                                              child: Text('Record a wear/use')),
                                          PopupMenuItem(
                                              value: 'wash',
                                              child: Text('Mark as washed')),
                                          PopupMenuItem(
                                              value: 'delete',
                                              child: Text('Delete item')),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
