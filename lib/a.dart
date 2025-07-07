import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as excel;
import 'package:flutter_fortune_wheel/flutter_fortune_wheel.dart';
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
  List<String> participants = [];
  List<String> filteredParticipants = [];
  int currentPage = 0;
  int rowsPerPage = 10;
  final TextEditingController searchController = TextEditingController();
  String selectedMode = 'Single Winner Mode';
  int consolationPrizesCount = 0;
  bool isDrawing = false;
  String? winner;
  Map<String, String> multiWinners = {};
  StreamController<int>? _wheelController;

  List<String> getCurrentPage() {
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
          .where((n) => n.toLowerCase().contains(q.toLowerCase()))
          .toList();
      currentPage = 0;
    });
  }

  Future<void> pickExcelFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );
    if (result?.files.single.bytes != null) {
      final bytes = result!.files.single.bytes!;
      final excelFile = excel.Excel.decodeBytes(bytes);
      final names = <String>[];
      for (var t in excelFile.tables.values) {
        for (var row in t.rows) {
          if (row.isNotEmpty && row[0] != null) {
            names.add(row[0]!.value.toString());
          }
        }
        break;
      }
      setState(() {
        participants = names;
        filteredParticipants = List.from(names);
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
      await singleWinnerDrawWithWheel();
    } else {
      await multiTierDraw();
    }
  }

  Future<void> singleWinnerDrawWithWheel() async {
    setState(() => isDrawing = true);
    _wheelController?.close();
    _wheelController = StreamController<int>();
    final sel = Random().nextInt(participants.length);

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        bool spinning = true;
        return StatefulBuilder(builder: (_, setStateDialog) {
          if (spinning) _wheelController!.add(sel);
          return AlertDialog(
            title: const Text('🎡 Spinning the Wheel...'),
            content: SizedBox(
              height: 300,
              width: 300,
              child: FortuneWheel(
                selected: _wheelController!.stream,
                items: [
                  for (var p in participants)
                    FortuneItem(
                      child: Text(p, style: const TextStyle(fontSize: 14)),
                    ),
                ],
                onAnimationEnd: () {
                  spinning = false;
                  winner = participants[sel];
                  setStateDialog(() {});
                  Future.delayed(const Duration(milliseconds: 500), () {
                    Navigator.of(ctx).pop();
                    _showResultDialog(
                      '🎉 Winner',
                      Text(
                        winner!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    );
                    setState(() => isDrawing = false);
                  });
                },
              ),
            ),
          );
        });
      },
    );
  }

  Future<void> multiTierDraw() async {
    if (consolationPrizesCount < 0 ||
        consolationPrizesCount > participants.length - 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid consolation prize count')),
      );
      return;
    }
    setState(() => isDrawing = true);
    final shuffled = List<String>.from(participants)..shuffle();
    multiWinners['Grand Prize'] = shuffled[0];
    multiWinners['First Prize'] = shuffled[1];
    multiWinners['Second Prize'] = shuffled[2];
    multiWinners['Consolation Prizes'] = consolationPrizesCount > 0
        ? shuffled.sublist(3, 3 + consolationPrizesCount).join(', ')
        : 'None';

    await Future.delayed(const Duration(seconds: 2));
    setState(() => isDrawing = false);

    _showResultDialog(
      '🏆 Winners',
      Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('🏆 Grand Prize: ${multiWinners['Grand Prize']}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          Text('🥈 First Prize: ${multiWinners['First Prize']}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18)),
          Text('🥉 Second Prize: ${multiWinners['Second Prize']}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 8),
          Text('🎉 Consolation: ${multiWinners['Consolation Prizes']}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }

  Future<void> _showResultDialog(String title, Widget content) async {
    final confettiController =
        ConfettiController(duration: const Duration(seconds: 3));
    confettiController.play();

    await showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: SizedBox(
          width: 300,
          height: 300,
          child: Stack(
            alignment: Alignment.center,
            children: [
              ConfettiWidget(
                confettiController: confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                shouldLoop: false,
                emissionFrequency: 0.05,
                numberOfParticles: 25,
                gravity: 0.2,
                colors: const [
                  Colors.red,
                  Colors.blue,
                  Colors.green,
                  Colors.orange,
                  Colors.purple
                ],
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  content,
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      confettiController.stop();
                      confettiController.dispose();
                      Navigator.of(context).pop();
                    },
                    child: const Text('Close'),
                  ),
                ],
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
    _wheelController?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pageItems = getCurrentPage();

    return Scaffold(
      appBar: AppBar(title: const Text('🎲 Lucky Draw')),
      body: LayoutBuilder(
        builder: (ctx, constraints) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton(
                    onPressed: isDrawing ? null : pickExcelFile,
                    child: const Text('📁 Import Excel'),
                  ),
                  const SizedBox(height: 10),

                  if (participants.isNotEmpty)
                    ElevatedButton(
                      onPressed: isDrawing ? null : startLuckyDraw,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('🎉 Start Lucky Draw'),
                    ),
                  const SizedBox(height: 16),

                  Row(children: [
                    const Text('Mode:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 10),
                    DropdownButton<String>(
                      value: selectedMode,
                      items: const [
                        DropdownMenuItem(
                            value: 'Single Winner Mode',
                            child: Text('Single Winner')),
                        DropdownMenuItem(
                            value: 'Multi-Tier Mode',
                            child: Text('Multi-Tier')),
                      ],
                      onChanged: isDrawing
                          ? null
                          : (v) => setState(() {
                                selectedMode = v!;
                                winner = null;
                                multiWinners.clear();
                              }),
                    ),
                    const SizedBox(width: 20),
                    if (selectedMode == 'Multi-Tier Mode')
                      SizedBox(
                        width: 100,
                        child: TextField(
                          enabled: !isDrawing,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Consolation',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (v) => setState(() =>
                              consolationPrizesCount = int.tryParse(v) ?? 0),
                        ),
                      ),
                  ]),

                  const SizedBox(height: 10),

                  TextField(
                    controller: searchController,
                    decoration: const InputDecoration(
                      labelText: 'Search',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: searchParticipants,
                  ),

                  const SizedBox(height: 10),

                  Flexible(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: participants.isEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(32.0),
                                child: Text('No data',
                                    style: TextStyle(fontSize: 18)),
                              ),
                            )
                          : SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                    minWidth: constraints.maxWidth - 32),
                                child: DataTable(
                                  columnSpacing: 32,
                                  columns: const [
                                    DataColumn(label: Text('No')),
                                    DataColumn(label: Text('Name')),
                                  ],
                                  rows: [
                                    for (var name in pageItems)
                                      DataRow(cells: [
                                        DataCell(Text(
                                            '${participants.indexOf(name) + 1}')),
                                        DataCell(Text(name)),
                                      ])
                                  ],
                                ),
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 10),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    ElevatedButton(onPressed: prevPage, child: const Text('Previous')),
                    const SizedBox(width: 20),
                    ElevatedButton(onPressed: nextPage, child: const Text('Next')),
                  ]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
