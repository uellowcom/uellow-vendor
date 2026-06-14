import 'package:flutter/material.dart';
import '../api/api.dart';
import '../theme/theme.dart';

/// Stock list + per-item restock request (mirrors /my/vendor/stock).
class StockScreen extends StatefulWidget {
  const StockScreen({super.key});
  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  String _filter = 'all';
  bool _canRestock = true;
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
    _checkCaps();
  }

  Future<void> _checkCaps() async {
    try {
      final caps = await VendorApi.instance.capabilities();
      if (mounted) setState(() => _canRestock = caps['capabilities']?['restock'] != false);
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> _load() =>
      VendorApi.instance.stock(filter: _filter);

  void _refresh() => setState(() => _future = _load());

  Future<void> _restock(Map<String, dynamic> p) async {
    final ar = VendorApi.instance.lang == 'ar';
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(ar ? 'طلب تعبئة' : 'Request restock'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(p['name'] ?? '', style: UT.body),
          const SizedBox(height: 10),
          TextField(controller: ctrl, keyboardType: TextInputType.number,
              decoration: InputDecoration(
                  labelText: ar ? 'الكمية' : 'Quantity',
                  border: const OutlineInputBorder())),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false),
              child: Text(ar ? 'إلغاء' : 'Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true),
              style: FilledButton.styleFrom(backgroundColor: UC.brown),
              child: Text(ar ? 'إرسال' : 'Submit')),
        ],
      ),
    );
    if (ok != true) return;
    final qty = int.tryParse(ctrl.text.trim()) ?? 0;
    if (qty <= 0) return;
    try {
      await VendorApi.instance.restockCreate(p['id'] as int, qty, '');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(ar ? 'تم إرسال الطلب' : 'Request sent')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ar = VendorApi.instance.lang == 'ar';
    return Scaffold(
      appBar: AppBar(title: Text(ar ? 'المخزون' : 'Stock')),
      body: Column(children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.all(10),
          child: Row(children: [
            _chip('all', ar ? 'الكل' : 'All'),
            _chip('low', ar ? 'منخفض' : 'Low'),
            _chip('out', ar ? 'نفد' : 'Out'),
          ]),
        ),
        Expanded(child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (c, s) {
            if (s.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (s.hasError) return Center(child: Text('${s.error}'));
            final items = s.data ?? [];
            if (items.isEmpty) {
              return Center(child: Text(ar ? 'لا منتجات' : 'No products', style: UT.body));
            }
            return RefreshIndicator(
              onRefresh: () async => _refresh(),
              child: ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, __) => const Divider(height: 1, color: UC.bg),
                itemBuilder: (c, i) {
                  final p = items[i];
                  final qty = (p['qty'] ?? 0);
                  final out = p['out'] == true, low = p['low'] == true;
                  return ListTile(
                    title: Text(p['name'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    subtitle: Text(p['sku']?.toString() ?? '', style: UT.small),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      UPill(text: '$qty',
                          bg: out ? UC.dangerBg : (low ? UC.warnBg : UC.yellowFaint),
                          fg: out ? UC.dangerDk : UC.brown),
                      if (_canRestock) ...[
                        const SizedBox(width: 6),
                        IconButton(
                          icon: const Icon(Icons.add_box_outlined, color: UC.brown),
                          tooltip: ar ? 'طلب تعبئة' : 'Restock',
                          onPressed: () => _restock(p)),
                      ],
                    ]),
                  );
                },
              ),
            );
          },
        )),
      ]),
    );
  }

  Widget _chip(String val, String label) => Padding(
    padding: const EdgeInsets.only(right: 6),
    child: ChoiceChip(
      label: Text(label),
      selected: _filter == val,
      selectedColor: UC.yellowFaint,
      onSelected: (_) { setState(() => _filter = val); _refresh(); },
    ),
  );
}
