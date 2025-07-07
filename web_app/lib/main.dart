import 'dart:typed_data';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart';

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
  String? winner;

  Future<void> pickExcelFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );

    if (result != null && result.files.single.bytes != null) {
      Uint8List fileBytes = result.files.single.bytes!;
      var excel = Excel.decodeBytes(fileBytes);

      List<String> names = [];

      for (var table in excel.tables.keys) {
        for (var row in excel.tables[table]!.rows) {
          if (row.isNotEmpty && row[0] != null) {
            names.add(row[0]!.value.toString());
          }
        }
        break; // Only read first sheet
      }

      setState(() {
        participants = names;
        winner = null;
      });
    }
  }

  void pickRandomWinner() {
    if (participants.isEmpty) return;

    final random = Random();
    final selected = participants[random.nextInt(participants.length)];

    setState(() {
      winner = selected;
    });

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('🎉 We Have a Winner!'),
        content: Text(
          selected,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('🎲 Lucky Draw Importer')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            ElevatedButton.icon(
              onPressed: pickExcelFile,
              icon: const Icon(Icons.upload_file),
              label: const Text("Import Excel (.xlsx)"),
            ),
            const SizedBox(height: 20),
            if (participants.isNotEmpty)
              ElevatedButton.icon(
                onPressed: pickRandomWinner,
                icon: const Icon(Icons.casino),
                label: const Text("Pick a Winner"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            const SizedBox(height: 20),
            Text(
              "Participants (${participants.length}):",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: participants.isEmpty
                  ? const Text("No data yet.")
                  : ListView.builder(
                      itemCount: participants.length,
                      itemBuilder: (context, index) {
                        return ListTile(
                          title: Text(participants[index]),
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
