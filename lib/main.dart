import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as excel;
import 'package:confetti/confetti.dart';

void main() => runApp(const LuckyDrawApp());

class LuckyDrawApp extends StatelessWidget {
  const LuckyDrawApp({super.key});
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: ExcelUploadPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class ExcelUploadPage extends StatefulWidget {
  const ExcelUploadPage({super.key});
  @override
  _ExcelUploadPageState createState() => _ExcelUploadPageState();
}

class _ExcelUploadPageState extends State<ExcelUploadPage> {
  List<Map<String, dynamic>> participants = [];
  List<Map<String, dynamic>> filteredParticipants = [];
  final List<String> winnerHistory = [];
  int currentPage = 0;
  int rowsPerPage = 10;
  final TextEditingController searchController = TextEditingController();
  String selectedMode = 'Single Winner Mode';
  int consolationPrizesCount = 0;
  bool isDrawing = false;
  String? winner;
  Map<String, String> multiWinners = {};

  List<Map<String, dynamic>> getCurrentPage() {
    int start = currentPage * rowsPerPage;
    int end = min(start + rowsPerPage, filteredParticipants.length);
    return filteredParticipants.sublist(start, end);
  }

  void prevPage() => setState(() => currentPage = max(0, currentPage - 1));
  void nextPage() {
    if ((currentPage + 1) * rowsPerPage < filteredParticipants.length) {
      setState(() => currentPage++);
    }
  }

  void searchParticipants(String q) {
    setState(() {
      filteredParticipants = participants
          .where((p) =>
              p['name'].toString().toLowerCase().contains(q.toLowerCase()))
          .toList();
      currentPage = 0;
    });
  }

  void _showWinnerHistoryDialog() {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('🏅 Past Winners'),
      content: SizedBox(
        width: double.maxFinite,
        child: winnerHistory.isEmpty
            ? const Text('No winners yet.')
            : ListView.separated(
                shrinkWrap: true,
                itemCount: winnerHistory.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (_, i) => Text(winnerHistory[i]),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        )
      ],
    ),
  );
}

Widget _buildWinnerRow(String label, String? idStr) {
  final id = int.tryParse(idStr ?? '') ?? -1;
return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Fixed-width label
        SizedBox(
          width: 150,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
            textAlign: TextAlign.right,
          ),
        ),
        const SizedBox(width: 12),
        _buildWinnerItem(id),
      ],
    ),
  );
}

Widget _buildWinnerItem(int id) {
 if (id == -1) return const Text('None');

  final name = _getNameById(id);
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(
          color: Colors.green,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        margin: const EdgeInsets.only(right: 8),
        child: Text(
          id.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      SizedBox(
        width: 160, // Keep this width consistent for alignment
        child: Text(
          name,
          style: const TextStyle(fontSize: 16),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ],
  );
}


  Future<void> pickExcelFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );
    final bytes = result?.files.single.bytes;
    if (bytes != null) {
      final excelFile = excel.Excel.decodeBytes(bytes);
      final loaded = <Map<String, dynamic>>[];
      int idCounter = 1;
      for (var table in excelFile.tables.values) {
        int? nameCol, entriesCol;
        for (int i = 0; i < table.rows.length; i++) {
          final row = table.rows[i];
          if (i == 0) {
            for (int j = 0; j < row.length; j++) {
              final val = row[j]?.value.toString().toLowerCase();
              if (val == 'name') nameCol = j;
              if (val == 'entries') entriesCol = j;
            }
            if (nameCol == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('❌ "Name" column not found.')),
              );
              return;
            }
          } else {
            if (nameCol! < row.length) {
              final name = row[nameCol]?.value.toString() ?? '';
              int entries = 1;
              if (entriesCol != null && entriesCol < row.length) {
                entries = int.tryParse(row[entriesCol]?.value.toString() ?? '1') ?? 1;
              }
              if (name.trim().isNotEmpty) {
                loaded.add({
                  'id': idCounter++,
                  'name': name,
                  'entries': max(1, entries)
                });
              }
            }
          }
        }
        break;
      }
      setState(() {
        participants = loaded;
        filteredParticipants = List.from(loaded);
        currentPage = 0;
        winner = null;
        multiWinners.clear();
      });
    }
  }

  Future<void> startLuckyDraw() async {
    if (participants.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('No participants')));
      return;
    }
    if (selectedMode == 'Single Winner Mode') {
      await singleWinnerDrawWithBox();
    } else {
      await multiTierDraw();
    }
  }

Future<void> singleWinnerDrawWithBox() async {
  setState(() => isDrawing = true);
  final weighted = <int>[];
  for (var p in participants) {
    weighted.addAll(List.filled(p['entries'], p['id'] as int));
  }
  final selId = weighted[Random().nextInt(weighted.length)];
  final sel = participants.firstWhere((p) => p['id'] == selId);

  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      bool unlocked = false;

      return StatefulBuilder(builder: (_, setDialog) {
        return AlertDialog(
          title: const Text('Drag the icon to unlock the chest'),
          content: SizedBox(
            height: 320,
            width: 400,
            child: Stack(alignment: Alignment.center, children: [
              // 3D Treasure Chest Box
              AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                height: unlocked ? 140 : 180,
                width: unlocked ? 240 : 220,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: unlocked
                      ? [Colors.teal.shade400, Colors.green.shade700]
                      : [Colors.brown.shade600, Colors.brown.shade900],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(color: Colors.black45, blurRadius: 8, offset: Offset(6, 6)),
                  ],
                  border: Border.all(color: Colors.brown.shade900, width: 4),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      unlocked ? Icons.lock_open : Icons.diamond,
                      color: unlocked ? Colors.green : Colors.blueAccent,
                      size: 32,
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),

              // Drag Target Area
              Positioned(
                bottom: 60,
                child: DragTarget<String>(
                  builder: (context, candidateData, rejectedData) => AnimatedOpacity(
                    opacity: unlocked ? 0 : 1,
                    duration: const Duration(milliseconds: 300),
                    child: Container(
                      height: 50,
                      width: 50,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.brown[700],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.yellow.shade700, width: 2),
                      ),
                      child: const Text('🔓'),
                    ),
                  ),
                  onAccept: (_) {
                    setDialog(() => unlocked = true);
                    Future.delayed(const Duration(seconds: 1), () {
                      Navigator.of(ctx).pop();
                      winner = sel['id'].toString();
                      winnerHistory.add('Single Winner\n(${sel['id']}) ${sel['name']}');
                      _showResultDialog(
                        '🎉 Winner',
                            Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircleAvatar(
                                    radius: 40,
                                    backgroundColor: Colors.green,
                                    child: Text(
                                      sel['id'].toString(),
                                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    sel['name'],
                                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                      );
                      setState(() => isDrawing = false);
                    });
                  },
                ),
              ),

              // Draggable Key
              if (!unlocked)
                Positioned(
                  top: 20,
                  child: Draggable<String>(
                    data: 'unlock',
                    feedback: Material(
                      color: Colors.transparent,
                      child: Image.asset(
                        'assets/images/key.png',
                        height: 40,
                        width: 40,
                      ),
                    ),
                    childWhenDragging: const SizedBox.shrink(),
                    child: Image.asset(
                      'assets/images/key.png',
                      height: 40,
                      width: 40,
                    ),
                  ),
                ),
            ]),
          ),

              actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  setState(() => isDrawing = false);
                },
                child: const Text('Close'),
              ),
            ],
        );
      });
    },
  );
}

  Future<void> multiTierDraw() async {
    if (consolationPrizesCount < 0 || consolationPrizesCount > participants.length - 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid consolation prize count')),
      );
      return;
    }
    setState(() => isDrawing = true);

    final weighted = <int>[];
    for (var p in participants) {
      weighted.addAll(List.filled(p['entries'], p['id'] as int));
    }
    weighted.shuffle(Random());
    final used = <int>{};
    int idx = 0;

    int pickUnique() {
      while (idx < weighted.length && used.contains(weighted[idx])) idx++;
      if (idx >= weighted.length) return -1;
      final id = weighted[idx++];
      used.add(id);
      return id;
    }

    final gp = pickUnique();
    final fp = pickUnique();
    final sp = pickUnique();
    multiWinners['Grand Prize'] = gp == -1 ? 'None' : gp.toString();
    multiWinners['First Prize'] = fp == -1 ? 'None' : fp.toString();
    multiWinners['Second Prize'] = sp == -1 ? 'None' : sp.toString();

    final cons = <String>[];
    for (int i = 0; i < consolationPrizesCount; i++) {
      final c = pickUnique();
      if (c == -1) break;
      cons.add(c.toString());
    }
    multiWinners['Consolation Prizes'] = cons.isEmpty ? 'None' : cons.join(', ');

    await Future.delayed(const Duration(milliseconds: 500));
    setState(() => isDrawing = false);

    final historyEntry = StringBuffer('Multi Winner\n');

historyEntry.writeln('🏆 Grand: (${gp}) ${_getNameById(gp)}');
historyEntry.writeln('🥈 First: (${fp}) ${_getNameById(fp)}');
historyEntry.writeln('🥉 Second: (${sp}) ${_getNameById(sp)}');

if (multiWinners['Consolation Prizes'] != 'None') {
  final consNames = multiWinners['Consolation Prizes']!
    .split(',')
    .map((idStr) {
      final id = int.tryParse(idStr.trim()) ?? -1;
      final name = _getNameById(id);
      return '(${id}) $name';
    })
    .join(', ');
historyEntry.writeln('🎉 Consolation: $consNames');
}

winnerHistory.add(historyEntry.toString().trim());

    _showResultDialog(
'🏆 Winners',
  SingleChildScrollView(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildWinnerRow('🏆 Grand Prize', multiWinners['Grand Prize']),
        const SizedBox(height: 8),
        _buildWinnerRow('🥈 First Prize', multiWinners['First Prize']),
        const SizedBox(height: 8),
        _buildWinnerRow('🥉 Second Prize', multiWinners['Second Prize']),
        const SizedBox(height: 12),

            // Add a divider here
    const Divider(
      thickness: 2,
      color: Colors.grey,
      height: 32,
    ),

        if (multiWinners['Consolation Prizes'] != 'None') ...[
          const Text('🎉 Consolation Prizes:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: multiWinners['Consolation Prizes']!
                .split(',')
                .map((idStr) {
                  final id = int.tryParse(idStr.trim()) ?? -1;
                  return _buildWinnerItem(id);
                })
                .toList(),
          ),
        ],
      ],
    ),
  ),
    );
  }

  String _getNameById(int id) => participants.firstWhere((p) => p['id'] == id)['name'] ?? 'Unknown';

  Future<void> _showResultDialog(String title, Widget content) async {
    final ctl = ConfettiController(duration: const Duration(seconds: 3));
    ctl.play();
    await showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
child: ConstrainedBox(
  constraints: BoxConstraints(
    maxWidth: MediaQuery.of(context).size.width * 0.9,
    maxHeight: MediaQuery.of(context).size.height * 0.85,
  ),
  child: Stack(
    alignment: Alignment.center,
    children: [
      ConfettiWidget(
        confettiController: ctl,
        blastDirectionality: BlastDirectionality.explosive,
        emissionFrequency: 0.05,
        numberOfParticles: 30,
        gravity: 0.2,
        colors: const [Colors.red, Colors.blue, Colors.green, Colors.orange, Colors.purple],
      ),
      SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            content, // Your generated content for winners
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                ctl.stop();
                ctl.dispose();
                Navigator.of(context).pop();
              },
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    ],
  ),
),
      ),
    );
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const contentMaxWidth = 600.0;
    final pageItems = getCurrentPage();
    return Scaffold(
      appBar: AppBar(title: const Text('🎲 Lucky Draw'),   actions: [
    IconButton(
      icon: const Icon(Icons.emoji_events), // Trophy Icon
      tooltip: 'Past Winners',
      onPressed: () => _showWinnerHistoryDialog(),
    ),
  ],),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: contentMaxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton(
                  onPressed: isDrawing ? null : pickExcelFile,
                  child: const Text('📁 Import Excel'),
                ),
                const SizedBox(height: 16),
                if (participants.isNotEmpty)
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Expanded(
                      child: Row(children: [
                        const Text('Mode:'), const SizedBox(width: 10),
                        DropdownButton<String>(
                          value: selectedMode,
                          items: const [
                            DropdownMenuItem(value: 'Single Winner Mode', child: Text('Single Winner')),
                            DropdownMenuItem(value: 'Multi-Tier Mode', child: Text('Multi-Tier')),
                          ],
                          onChanged: isDrawing
                              ? null
                              : (v) => setState(() {
                                    selectedMode = v!;
                                    winner = null;
                                    multiWinners.clear();
                                    consolationPrizesCount = 0;
                                    currentPage = 0;
                                  }),
                        ),
                        const SizedBox(width: 20),
                        if (selectedMode == 'Multi-Tier Mode')
                            Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Number of Consolation Prizes',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 6),
                                  SizedBox(
                                    width: 200,
                                    child: TextField(
                                      enabled: !isDrawing,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        hintText: 'e.g. 5',
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                                      ),
                                      onChanged: (v) => setState(() => consolationPrizesCount = int.tryParse(v) ?? 0),
                                    ),
                                  ),
                                ],
                              ),
                      ]),
                    ),
                    ElevatedButton(
                      onPressed: isDrawing ? null : startLuckyDraw,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                      child: const Text('🎉 Start Lucky Draw'),
                    ),
                  ]),
                const SizedBox(height: 16),
                TextField(
                  controller: searchController,
                  enabled: !isDrawing,
                  decoration: InputDecoration(
                    labelText: 'Search Participants',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              searchController.clear();
                              searchParticipants('');
                            },
                          )
                        : null,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: searchParticipants,
                ),
                const SizedBox(height: 10),
Container(
  decoration: BoxDecoration(
    border: Border.all(color: Colors.lightGreen.shade100),
    borderRadius: BorderRadius.circular(8),
  ),
child: participants.isEmpty
    ? const Padding(
        padding: EdgeInsets.all(16),
        child: Text('No participants loaded.'),
      )
    : Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left column: first 5 participants
            Expanded(
              child: Column(
                children: pageItems.take(5).map((p) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            p['id'].toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: SizedBox(
                            height: 60,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p['name'],
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Entries: ${p['entries']}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(width: 24),

            // Right column: next 5 participants
            Expanded(
              child: Column(
                children: pageItems.skip(5).take(5).map((p) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            p['id'].toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: SizedBox(
                            height: 60,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p['name'],
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Entries: ${p['entries']}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
),

if (participants.isNotEmpty)
  Padding(
    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Page ${currentPage + 1} of ${((filteredParticipants.length - 1) / rowsPerPage + 1).floor()}',
        ),
        Row(
          children: [
            IconButton(
              onPressed: currentPage == 0 ? null : prevPage,
              icon: const Icon(Icons.arrow_back),
            ),
            IconButton(
              onPressed: (currentPage + 1) * rowsPerPage >= filteredParticipants.length
                  ? null
                  : nextPage,
              icon: const Icon(Icons.arrow_forward),
            ),
          ],
        ),
      ],
    ),
  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
