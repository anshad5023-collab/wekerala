import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';

class BulkImportScreen extends ConsumerStatefulWidget {
  const BulkImportScreen({super.key});
  @override
  ConsumerState<BulkImportScreen> createState() => _BulkImportScreenState();
}

class _BulkImportScreenState extends ConsumerState<BulkImportScreen> {
  String? _shopId;
  List<Map<String, dynamic>> _parsed = [];
  bool _loading = false;
  int _imported = 0;

  @override
  void initState() {
    super.initState();
    _loadShopId();
  }

  Future<void> _loadShopId() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final snap = await FirebaseFirestore.instance.collection('shops').where('ownerId', isEqualTo: uid).limit(1).get();
    if (snap.docs.isNotEmpty) setState(() => _shopId = snap.docs.first.id);
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom, allowedExtensions: ['csv'], withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final bytes = result.files.first.bytes;
    if (bytes == null) return;
    final content = String.fromCharCodes(bytes);
    final lines = content.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) return;
    final headers = lines[0].split(',').map((h) => h.trim().toLowerCase()).toList();
    final nameIdx = headers.indexOf('name');
    final priceIdx = headers.indexOf('price');
    final unitIdx = headers.indexOf('unit');
    final catIdx = headers.indexOf('category');
    final stockIdx = headers.indexOf('stock');
    final descIdx = headers.indexOf('description');

    final parsed = <Map<String, dynamic>>[];
    for (int i = 1; i < lines.length; i++) {
      final cells = lines[i].split(',');
      final name = nameIdx >= 0 && nameIdx < cells.length ? cells[nameIdx].trim() : '';
      if (name.isEmpty) continue;
      final price = priceIdx >= 0 ? double.tryParse(cells[priceIdx].trim()) ?? 0.0 : 0.0;
      final stock = stockIdx >= 0 ? int.tryParse(cells[stockIdx].trim()) ?? 0 : 0;
      parsed.add({
        'name': name,
        'price': price,
        'unit': unitIdx >= 0 && unitIdx < cells.length ? cells[unitIdx].trim() : 'unit',
        'category': catIdx >= 0 && catIdx < cells.length ? cells[catIdx].trim() : 'General',
        'stock': stock,
        'description': descIdx >= 0 && descIdx < cells.length ? cells[descIdx].trim() : '',
        'isValid': name.isNotEmpty && price > 0,
      });
    }
    setState(() => _parsed = parsed);
  }

  Future<void> _import() async {
    if (_shopId == null || _parsed.isEmpty) return;
    setState(() { _loading = true; _imported = 0; });
    final valid = _parsed.where((p) => p['isValid'] == true).toList();
    final ref = FirebaseFirestore.instance.collection('shops').doc(_shopId).collection('products');
    for (int i = 0; i < valid.length; i += 50) {
      final batch = FirebaseFirestore.instance.batch();
      final chunk = valid.skip(i).take(50).toList();
      for (final p in chunk) {
        batch.set(ref.doc(), {
          'name': p['name'], 'price': p['price'], 'unit': p['unit'],
          'category': p['category'], 'stock': p['stock'], 'description': p['description'],
          'isActive': true, 'createdAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
      setState(() => _imported = i + chunk.length);
    }
    setState(() => _loading = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ $_imported products imported!')));
    setState(() => _parsed = []);
  }

  @override
  Widget build(BuildContext context) {
    final valid = _parsed.where((p) => p['isValid'] == true).length;
    final invalid = _parsed.length - valid;
    return Scaffold(
      appBar: AppBar(title: const Text('Bulk Import'), backgroundColor: const Color(0xFF2D6A4F), foregroundColor: Colors.white),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('CSV Format', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                  child: const Text('name,price,unit,category,stock,description\nTomato,40,kg,Vegetables,100,Fresh tomatoes', style: TextStyle(fontFamily: 'monospace', fontSize: 12)),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _pickFile,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 40),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF2D6A4F), width: 2, style: BorderStyle.solid),
                borderRadius: BorderRadius.circular(12),
                color: const Color(0xFFF0F7F4),
              ),
              child: Column(children: [
                const Icon(Icons.upload_file, size: 48, color: Color(0xFF2D6A4F)),
                const SizedBox(height: 8),
                Text(_parsed.isEmpty ? 'Tap to select CSV file' : '${_parsed.length} rows found', style: const TextStyle(fontSize: 16, color: Color(0xFF2D6A4F), fontWeight: FontWeight.bold)),
              ]),
            ),
          ),
          if (_parsed.isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(children: [
              Chip(label: Text('$valid ready'), backgroundColor: Colors.green[100]),
              const SizedBox(width: 8),
              if (invalid > 0) Chip(label: Text('$invalid errors'), backgroundColor: Colors.red[100]),
            ]),
            const SizedBox(height: 8),
            ...(_parsed.take(5).map((p) => ListTile(
              leading: Icon(p['isValid'] == true ? Icons.check_circle : Icons.error, color: p['isValid'] == true ? Colors.green : Colors.red),
              title: Text(p['name']),
              subtitle: Text('₹${p['price']} • ${p['category']}'),
            ))),
            if (_parsed.length > 5) Text('...and ${_parsed.length - 5} more', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            if (_loading) Column(children: [
              LinearProgressIndicator(value: _imported / valid.clamp(1, 999999), color: const Color(0xFF2D6A4F)),
              const SizedBox(height: 8),
              Text('Importing $_imported / $valid...'),
            ]) else SizedBox(width: double.infinity, child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2D6A4F), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
              onPressed: valid > 0 ? _import : null,
              child: Text('Import $valid Products', style: const TextStyle(fontSize: 16)),
            )),
          ],
        ]),
      ),
    );
  }
}
