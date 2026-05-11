import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/gait_data.dart';

class CsvExport {
  static Future<String?> exportToCsv(List<RecordEntry> records) async {
    if (records.isEmpty) return null;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'gait_data_$timestamp.csv';
      final file = File('${dir.path}/$fileName');
      final buffer = StringBuffer();
      buffer.writeln(RecordEntry.csvHeader.join(','));
      for (var record in records) {
        buffer.writeln(record.toCsvRow().join(','));
      }
      await file.writeAsString(buffer.toString());
      return file.path;
    } catch (e) {
      debugPrint('CSV export error: $e');
      return null;
    }
  }

  static void debugPrint(String msg) {
    print('[CsvExport] $msg');
  }
}
