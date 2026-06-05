import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/billing_provider.dart';
import '../../../providers/products_provider.dart';
import '../../../providers/shop_provider.dart';
import '../../../models/product_model.dart';

// ─── Models ───────────────────────────────────────────────────────────────────

class _KotItem {
  final String name;
  int qty = 1;
  String notes = '';
  _KotItem({required this.name, this.notes = ''});
}

class _KotOrder {
  final String id;
  final String table;
  final List<_KotItem> items;
  final DateTime createdAt;
  String status = 'pending'; // 'pending' | 'preparing' | 'ready' | 'served'

  _KotOrder({
    required this.id,
    required this.table,
    required this.items,
    required this.createdAt,
  });
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class KotScreen extends ConsumerStatefulWidget {
  const KotScreen({super.key});

  @override
  ConsumerState<KotScreen> createState() => _KotScreenState();
}

class _KotScreenState extends ConsumerState<KotScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<_KotOrder> _orders = [];
  final String _selectedTable = 'Table 1';

  static const _tables = [
    'Table 1', 'Table 2', 'Table 3', 'Table 4',
    'Table 5', 'Table 6', 'Takeaway', 'Delivery',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadFromFirestore());
  }

  Future<void> _loadFromFirestore() async {
    final shopId = ref.read(activeShopIdProvider).valueOrNull ?? '';
    if (shopId.isEmpty) return;
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final snap = await FirebaseFirestore.instance
          .collection('shops')
          .doc(shopId)
          .collection('kots')
          .where('status', whereNotIn: ['served'])
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .get();
      if (!mounted) return;
      setState(() {
        for (final doc in snap.docs) {
          final d = doc.data();
          final id = d['id'] as String? ?? doc.id;
          if (_orders.any((o) => o.id == id)) continue;
          final rawItems = (d['items'] as List?)?.cast<Map>() ?? [];
          final items = rawItems.map((i) {
            final item = _KotItem(
              name: i['name'] as String? ?? '',
              notes: i['notes'] as String? ?? '',
            );
            item.qty = (i['qty'] as int?) ?? 1;
            return item;
          }).toList();
          final order = _KotOrder(
            id: id,
            table: d['table'] as String? ?? '',
            items: items,
            createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          );
          order.status = d['status'] as String? ?? 'pending';
          _orders.add(order);
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not load kitchen orders: $e'),
            action: SnackBarAction(label: 'Retry', onPressed: _loadFromFirestore),
            duration: const Duration(seconds: 6),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openNewKot() async {
    final result = await showModalBottomSheet<({String table, List<_KotItem> items})>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NewKotSheet(
        tables: _tables,
        initialTable: _selectedTable,
        ref: ref,
      ),
    );
    if (result == null || result.items.isEmpty) return;
    setState(() {
      _orders.insert(
        0,
        _KotOrder(
          id: 'KOT-${DateTime.now().millisecondsSinceEpoch}',
          table: result.table,
          items: result.items,
          createdAt: DateTime.now(),
        ),
      );
    });
    _syncToFirestore(_orders.first);
  }

  Future<void> _syncToFirestore(_KotOrder order) async {
    final shopAsync = ref.read(activeShopIdProvider);
    final shopId = shopAsync.valueOrNull ?? '';
    if (shopId.isEmpty) return;

    await FirebaseFirestore.instance
        .collection('shops')
        .doc(shopId)
        .collection('kots')
        .doc(order.id)
        .set({
      'id': order.id,
      'table': order.table,
      'status': order.status,
      'createdAt': Timestamp.fromDate(order.createdAt),
      'items': order.items.map((i) => {
            'name': i.name,
            'qty': i.qty,
            'notes': i.notes,
          }).toList(),
    });
  }

  void _updateStatus(_KotOrder order, String status) {
    setState(() => order.status = status);
    _syncToFirestore(order);
  }

  Future<void> _clearServed() async {
    final served = _servedOrders;
    if (served.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear Served Orders?'),
        content: Text('Remove ${served.length} served order${served.length == 1 ? '' : 's'} from this view. They remain saved in history.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _orders.removeWhere((o) => o.status == 'served'));
  }

  List<_KotOrder> get _activeOrders =>
      _orders.where((o) => o.status != 'served').toList();
  List<_KotOrder> get _servedOrders =>
      _orders.where((o) => o.status == 'served').toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Kitchen Orders (KOT)'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          AnimatedBuilder(
            animation: _tabController,
            builder: (_, __) => _tabController.index == 1 && _servedOrders.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.delete_sweep_outlined),
                    tooltip: 'Clear served orders',
                    onPressed: _clearServed,
                  )
                : const SizedBox.shrink(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: [
            Tab(text: 'Active (${_activeOrders.length})'),
            Tab(text: 'Served (${_servedOrders.length})'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openNewKot,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New KOT'),
      ),
      body: Builder(builder: (ctx) {
        final shopId = ref.watch(activeShopIdProvider).valueOrNull ?? '';
        return TabBarView(
          controller: _tabController,
          children: [
            _OrderList(
              orders: _activeOrders,
              onStatusChange: _updateStatus,
              shopId: shopId,
            ),
            _OrderList(
              orders: _servedOrders,
              onStatusChange: _updateStatus,
              readOnly: true,
              shopId: shopId,
            ),
          ],
        );
      }),
    );
  }
}

// ─── Order List ───────────────────────────────────────────────────────────────

class _OrderList extends ConsumerWidget {
  final List<_KotOrder> orders;
  final void Function(_KotOrder, String) onStatusChange;
  final bool readOnly;
  final String shopId;

  const _OrderList({
    required this.orders,
    required this.onStatusChange,
    required this.shopId,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined, size: 56, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              readOnly ? 'No served orders yet' : 'No active orders',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 15),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: orders.length,
      itemBuilder: (_, i) => _KotCard(
        order: orders[i],
        onStatusChange: onStatusChange,
        readOnly: readOnly,
        shopId: shopId,
      ),
    );
  }
}

// ─── KOT Card ─────────────────────────────────────────────────────────────────

class _KotCard extends ConsumerWidget {
  final _KotOrder order;
  final void Function(_KotOrder, String) onStatusChange;
  final bool readOnly;
  final String shopId;

  const _KotCard({
    required this.order,
    required this.onStatusChange,
    required this.shopId,
    this.readOnly = false,
  });

  static const _statusColors = {
    'pending':   Color(0xFFF57C00),
    'preparing': Color(0xFF1976D2),
    'ready':     Color(0xFF388E3C),
    'served':    Color(0xFF757575),
  };

  static const _nextStatus = {
    'pending':   'preparing',
    'preparing': 'ready',
    'ready':     'served',
  };

  static const _nextLabel = {
    'pending':   'Start Preparing',
    'preparing': 'Mark Ready',
    'ready':     'Mark Served',
  };

  String _elapsed(DateTime from) {
    final diff = DateTime.now().difference(from);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ${diff.inMinutes % 60}m ago';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = _statusColors[order.status] ?? Colors.grey;
    final next = _nextStatus[order.status];
    final nextLbl = _nextLabel[order.status];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                Icon(Icons.table_restaurant_outlined, size: 16, color: color),
                const SizedBox(width: 6),
                Text(order.table,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: color)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    order.status.toUpperCase(),
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _elapsed(order.createdAt),
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),

          // ── Items ────────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...order.items.map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Center(
                              child: Text('${item.qty}',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(item.name,
                                style: const TextStyle(fontSize: 13)),
                          ),
                          if (item.notes.isNotEmpty)
                            Text(item.notes,
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                    fontStyle: FontStyle.italic)),
                        ],
                      ),
                    )),
              ],
            ),
          ),

          // ── Action buttons ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Column(
              children: [
                if (!readOnly && next != null && nextLbl != null) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => onStatusChange(order, next),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: Text(nextLbl, style: const TextStyle(fontSize: 13)),
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
                // Bill This Table — available when ready or served
                if (order.status == 'ready' || order.status == 'served')
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.point_of_sale_outlined, size: 16),
                      label: Text('Bill Table ${order.table}'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.success,
                        side: const BorderSide(color: AppColors.success),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      onPressed: () {
                        // Pre-load KOT items into billing cart then navigate
                        final notifier = ref.read(billingProvider.notifier);
                        notifier.clearCart();
                        // Set table number as pre-note on the bill
                        notifier.setPreNote('Table: ${order.table}');
                        final products =
                            ref.read(productsStreamProvider(shopId)).valueOrNull ?? [];
                        for (final item in order.items) {
                          final match = products.firstWhere(
                            (p) => p.nameEn.toLowerCase() == item.name.toLowerCase(),
                            orElse: () => ProductModel(
                              productId: 'kot_${item.name}',
                              nameEn: item.name,
                              category: '',
                              price: 0,
                              createdAt: DateTime.now(),
                              updatedAt: DateTime.now(),
                            ),
                          );
                          for (var i = 0; i < item.qty; i++) {
                            notifier.addItem(match);
                          }
                        }
                        context.push('/billing');
                      },
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── New KOT Sheet ────────────────────────────────────────────────────────────

class _NewKotSheet extends ConsumerStatefulWidget {
  final List<String> tables;
  final String initialTable;
  final WidgetRef ref;

  const _NewKotSheet({
    required this.tables,
    required this.initialTable,
    required this.ref,
  });

  @override
  ConsumerState<_NewKotSheet> createState() => _NewKotSheetState();
}

class _NewKotSheetState extends ConsumerState<_NewKotSheet> {
  late String _table;
  final List<_KotItem> _items = [];
  final _searchCtrl = TextEditingController();
  String _search = '';

  @override
  void initState() {
    super.initState();
    _table = widget.initialTable; // mutable — updated by dropdown selection
    _searchCtrl.addListener(() => setState(() => _search = _searchCtrl.text.trim().toLowerCase()));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _addItem(String name) {
    setState(() {
      final existing = _items.where((i) => i.name == name).firstOrNull;
      if (existing != null) {
        existing.qty++;
      } else {
        _items.add(_KotItem(name: name));
      }
    });
  }

  void _removeItem(_KotItem item) {
    setState(() {
      if (item.qty > 1) {
        item.qty--;
      } else {
        _items.remove(item);
      }
    });
  }

  Future<void> _editItemNotes(_KotItem item) async {
    final ctrl = TextEditingController(text: item.notes);
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Notes for ${item.name}'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 80,
          decoration: const InputDecoration(
            hintText: 'e.g. no onion, extra spicy...',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    ctrl.dispose();
    if (result == null || !mounted) return;
    setState(() => item.notes = result);
  }

  @override
  Widget build(BuildContext context) {
    final shopAsync = ref.watch(activeShopIdProvider);
    final shopId = shopAsync.valueOrNull ?? '';

    final productsAsync = shopId.isNotEmpty
        ? ref.watch(productsStreamProvider(shopId))
        : const AsyncValue<List<dynamic>>.loading();

    final allProducts = productsAsync.valueOrNull ?? [];
    final filtered = _search.isEmpty
        ? allProducts
        : allProducts.where((p) {
            final name = (p.nameEn as String? ?? '').toLowerCase();
            return name.contains(_search);
          }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // ── Handle ──────────────────────────────────────────────────────────
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Table selector ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Text('Table:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _table,
                      isExpanded: true,
                      items: widget.tables.map((t) => DropdownMenuItem(
                        value: t,
                        child: Text(t, style: const TextStyle(fontSize: 14)),
                      )).toList(),
                      onChanged: (v) => setState(() => _table = v ?? _table),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Current items ────────────────────────────────────────────────────
          if (_items.isNotEmpty) ...[
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Order', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.textSecondary)),
                  const SizedBox(height: 6),
                  ..._items.map((item) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () => _removeItem(item),
                                child: const Icon(Icons.remove_circle_outline, size: 18, color: AppColors.error),
                              ),
                              const SizedBox(width: 6),
                              Text('${item.qty}×', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              const SizedBox(width: 4),
                              Expanded(child: Text(item.name, style: const TextStyle(fontSize: 13))),
                              GestureDetector(
                                onTap: () => _editItemNotes(item),
                                child: Icon(
                                  Icons.note_alt_outlined,
                                  size: 16,
                                  color: item.notes.isNotEmpty ? AppColors.primary : Colors.grey.shade400,
                                ),
                              ),
                              const SizedBox(width: 4),
                              GestureDetector(
                                onTap: () => _addItem(item.name),
                                child: const Icon(Icons.add_circle_outline, size: 18, color: AppColors.primary),
                              ),
                            ],
                          ),
                          if (item.notes.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(left: 28, bottom: 2),
                              child: Text(
                                item.notes,
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontStyle: FontStyle.italic),
                              ),
                            ),
                        ],
                      )),
                ],
              ),
            ),
          ],

          // ── Search ──────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search menu items...',
                prefixIcon: const Icon(Icons.search, size: 20),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ),

          // ── Product list ─────────────────────────────────────────────────────
          Expanded(
            child: productsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
              data: (_) => ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: filtered.length,
                itemBuilder: (_, i) {
                  final p = filtered[i];
                  final name = p.nameEn as String? ?? '';
                  final inOrder = _items.where((it) => it.name == name).firstOrNull;
                  return ListTile(
                    dense: true,
                    title: Text(name, style: const TextStyle(fontSize: 13)),
                    subtitle: Text('₹${p.price}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    trailing: inOrder != null
                        ? Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text('${inOrder.qty}',
                                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                            ),
                          )
                        : GestureDetector(
                            onTap: () => _addItem(name),
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.add, size: 18, color: AppColors.primary),
                            ),
                          ),
                    onTap: () => _addItem(name),
                  );
                },
              ),
            ),
          ),

          // ── Send KOT button ──────────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(
                16, 8, 16, MediaQuery.of(context).viewInsets.bottom + 16),
            child: ElevatedButton(
              onPressed: _items.isEmpty
                  ? null
                  : () => Navigator.of(context).pop((table: _table, items: _items)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text('Send KOT (${_items.length} items)',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}
