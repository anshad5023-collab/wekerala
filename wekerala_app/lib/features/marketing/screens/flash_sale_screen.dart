import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FlashSaleScreen extends ConsumerStatefulWidget {
  const FlashSaleScreen({super.key});
  @override
  ConsumerState<FlashSaleScreen> createState() => _FlashSaleScreenState();
}

class _FlashSaleScreenState extends ConsumerState<FlashSaleScreen> {
  String? _shopId;

  @override
  void initState() {
    super.initState();
    _loadShopId();
  }

  Future<void> _loadShopId() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final snap = await FirebaseFirestore.instance
        .collection('shops').where('ownerId', isEqualTo: uid).limit(1).get();
    if (snap.docs.isNotEmpty) setState(() => _shopId = snap.docs.first.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Flash Sales'),
        backgroundColor: const Color(0xFFFC8019),
        foregroundColor: Colors.white,
      ),
      body: _shopId == null
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('shops').doc(_shopId).collection('flashSales')
                  .orderBy('createdAt', descending: true).limit(10).snapshots(),
              builder: (ctx, snap) {
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                final sales = snap.data!.docs;
                if (sales.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.local_fire_department, size: 64, color: Color(0xFFFC8019)),
                        const SizedBox(height: 16),
                        const Text('No flash sales yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        const Text('Create a flash sale to boost orders!', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: sales.length,
                  itemBuilder: (ctx, i) {
                    final d = sales[i].data() as Map<String, dynamic>;
                    final isExpired = d['expired'] == true;
                    final endTime = (d['endTime'] as Timestamp?)?.toDate();
                    final isActive = !isExpired && endTime != null && endTime.isAfter(DateTime.now());
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isActive ? const Color(0xFFFC8019) : Colors.grey,
                          child: Icon(Icons.local_fire_department, color: Colors.white),
                        ),
                        title: Text(d['name'] ?? 'Sale', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${d['discountPercent'] ?? 0}% OFF${(d['applicableCategory'] as String?)?.isNotEmpty == true ? " on ${d['applicableCategory']}" : ""} • ${isActive ? "LIVE 🔥" : isExpired ? "Ended" : "Scheduled"}'),
                        trailing: isActive
                            ? TextButton(
                                onPressed: () async {
                                  final ok = await showDialog<bool>(
                                    context: ctx,
                                    builder: (_) => AlertDialog(
                                      title: const Text('End Flash Sale?'),
                                      content: Text('End "${d['name'] ?? 'this sale'}" immediately? Normal prices will apply at once.'),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('End Sale', style: TextStyle(color: Colors.red))),
                                      ],
                                    ),
                                  );
                                  if (ok == true) {
                                    await sales[i].reference.update({'expired': true});
                                  }
                                },
                                child: const Text('End', style: TextStyle(color: Colors.red)),
                              )
                            : null,
                      ),
                    );
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFFFC8019),
        icon: const Icon(Icons.add),
        label: const Text('New Sale'),
        onPressed: _shopId == null ? null : () async => _showCreateSheet(context),
      ),
    );
  }

  Future<List<String>> _getCategories() async {
    if (_shopId == null) return [];
    final snap = await FirebaseFirestore.instance
        .collection('shops')
        .doc(_shopId)
        .get();
    return List<String>.from(snap.data()?['categories'] ?? []);
  }

  Future<void> _showCreateSheet(BuildContext context) async {
    final nameCtrl = TextEditingController();
    double discount = 20;
    DateTime startTime = DateTime.now();
    DateTime endTime = DateTime.now().add(const Duration(hours: 24));
    String? selectedCategory; // null = all products

    // Pre-load categories so the dropdown is populated when the sheet opens
    final List<String> categories = await _getCategories();

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(left: 16, right: 16, top: 24, bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Create Flash Sale', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Sale Name (e.g. Weekend Special)', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Apply to',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All Products')),
                  ...categories.map((c) => DropdownMenuItem(value: c, child: Text(c))),
                ],
                onChanged: (v) => setS(() => selectedCategory = v),
              ),
              const SizedBox(height: 16),
              Text('Discount: ${discount.round()}%', style: const TextStyle(fontWeight: FontWeight.bold)),
              Slider(value: discount, min: 5, max: 80, divisions: 15, activeColor: const Color(0xFFFC8019),
                onChanged: (v) => setS(() => discount = v)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: OutlinedButton.icon(
                  icon: const Icon(Icons.play_arrow_outlined),
                  label: Text('Starts: ${startTime.day}/${startTime.month} ${startTime.hour}:${startTime.minute.toString().padLeft(2,'0')}'),
                  onPressed: () async {
                    final d = await showDatePicker(context: ctx, initialDate: startTime, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 30)));
                    if (d == null || !ctx.mounted) return;
                    final t = await showTimePicker(context: ctx, initialTime: TimeOfDay.fromDateTime(startTime));
                    if (t != null) setS(() => startTime = DateTime(d.year, d.month, d.day, t.hour, t.minute));
                  },
                )),
                const SizedBox(width: 8),
                Expanded(child: OutlinedButton.icon(
                  icon: const Icon(Icons.schedule),
                  label: Text('Ends: ${endTime.day}/${endTime.month} ${endTime.hour}:${endTime.minute.toString().padLeft(2,'0')}'),
                  onPressed: () async {
                    final d = await showDatePicker(context: ctx, initialDate: endTime, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 30)));
                    if (d == null || !ctx.mounted) return;
                    final t = await showTimePicker(context: ctx, initialTime: TimeOfDay.fromDateTime(endTime));
                    if (t != null) setS(() => endTime = DateTime(d.year, d.month, d.day, t.hour, t.minute));
                  },
                )),
              ]),
              const SizedBox(height: 16),
              SizedBox(width: double.infinity, child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFC8019), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                onPressed: () async {
                  if (nameCtrl.text.trim().isEmpty) return;
                  if (!endTime.isAfter(startTime)) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('End time must be after start time')),
                    );
                    return;
                  }
                  await FirebaseFirestore.instance.collection('shops').doc(_shopId).collection('flashSales').add({
                    'name': nameCtrl.text.trim(),
                    'discountPercent': discount.round(),
                    'applicableCategory': selectedCategory ?? '',
                    'startTime': Timestamp.fromDate(startTime),
                    'endTime': Timestamp.fromDate(endTime),
                    'broadcastSent': false,
                    'expired': false,
                    'createdAt': FieldValue.serverTimestamp(),
                  });
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Flash sale created! 🔥')));
                },
                child: const Text('Create Sale', style: TextStyle(fontSize: 16)),
              )),
            ],
          ),
        ),
      ),
    );
  }
}
