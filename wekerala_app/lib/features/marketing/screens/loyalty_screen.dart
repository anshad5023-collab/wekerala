import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoyaltyScreen extends ConsumerStatefulWidget {
  const LoyaltyScreen({super.key});
  @override
  ConsumerState<LoyaltyScreen> createState() => _LoyaltyScreenState();
}

class _LoyaltyScreenState extends ConsumerState<LoyaltyScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  String? _shopId;
  bool _enabled = false;
  int _pointsPer100 = 10;
  int _minRedeem = 100;
  double _valuePerPoint = 0.5;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final snap = await FirebaseFirestore.instance.collection('shops').where('ownerId', isEqualTo: uid).limit(1).get();
    if (snap.docs.isEmpty) return;
    final doc = snap.docs.first;
    final settings = Map<String, dynamic>.from(doc.data()['loyaltySettings'] as Map? ?? {});
    setState(() {
      _shopId = doc.id;
      _enabled = settings['enabled'] == true;
      _pointsPer100 = settings['pointsPerHundred'] ?? 10;
      _minRedeem = settings['minRedeem'] ?? 100;
      _valuePerPoint = (settings['valuePerPoint'] ?? 0.5).toDouble();
    });
  }

  Future<void> _save() async {
    if (_shopId == null) return;
    await FirebaseFirestore.instance.collection('shops').doc(_shopId).update({
      'loyaltySettings': {
        'enabled': _enabled,
        'pointsPerHundred': _pointsPer100,
        'minRedeem': _minRedeem,
        'valuePerPoint': _valuePerPoint,
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Loyalty settings saved!')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Loyalty Program'),
        backgroundColor: const Color(0xFFFF9900),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabs,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [Tab(text: 'Settings'), Tab(text: 'Leaderboard')],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          // Settings tab
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      const Text('Enable Loyalty Program', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Switch(value: _enabled, activeColor: const Color(0xFFFF9900), onChanged: (v) => setState(() => _enabled = v)),
                    ]),
                    const Divider(),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      const Text('Points per ₹100 spent'),
                      Row(children: [
                        IconButton(icon: const Icon(Icons.remove_circle_outline), onPressed: () => setState(() { if (_pointsPer100 > 1) _pointsPer100--; })),
                        Text('$_pointsPer100', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: () => setState(() => _pointsPer100++)),
                      ]),
                    ]),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      const Text('₹ value per point'),
                      Row(children: [
                        IconButton(icon: const Icon(Icons.remove_circle_outline), onPressed: () => setState(() { if (_valuePerPoint > 0.1) _valuePerPoint = (_valuePerPoint - 0.1).clamp(0.1, 10); })),
                        Text('₹${_valuePerPoint.toStringAsFixed(1)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: () => setState(() => _valuePerPoint = (_valuePerPoint + 0.1).clamp(0.1, 10))),
                      ]),
                    ]),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(8)),
                      child: Text('Customer spending ₹500 earns ${(5 * _pointsPer100)} points worth ₹${(5 * _pointsPer100 * _valuePerPoint).toStringAsFixed(0)}', style: const TextStyle(color: Color(0xFFFF9900))),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(width: double.infinity, child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF9900), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                onPressed: _save,
                child: const Text('Save Settings', style: TextStyle(fontSize: 16)),
              )),
            ]),
          ),
          // Leaderboard tab
          _shopId == null ? const Center(child: CircularProgressIndicator()) :
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('shops').doc(_shopId).collection('customers')
                .orderBy('loyaltyPoints', descending: true).limit(50).snapshots(),
            builder: (ctx, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final customers = snap.data!.docs;
              if (customers.isEmpty) return const Center(child: Text('No customers yet'));
              return ListView.builder(
                itemCount: customers.length,
                itemBuilder: (ctx, i) {
                  final d = customers[i].data() as Map<String, dynamic>;
                  final phone = d['phone'] as String? ?? '';
                  final maskedPhone = phone.length > 4 ? '••••${phone.substring(phone.length - 4)}' : phone;
                  final points = d['loyaltyPoints'] as int? ?? 0;
                  final medals = ['👑', '🥈', '🥉'];
                  return ListTile(
                    leading: CircleAvatar(backgroundColor: const Color(0xFFFF9900), child: Text(i < 3 ? medals[i] : '${i+1}')),
                    title: Text(d['name'] ?? maskedPhone, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('$points points • ₹${(d['totalSpent'] as num?)?.toStringAsFixed(0) ?? 0} spent'),
                    trailing: IconButton(
                      icon: const Icon(Icons.message, color: Color(0xFF25D366)),
                      onPressed: () {},
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
