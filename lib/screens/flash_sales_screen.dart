import 'package:flutter/material.dart';
import '../api/api.dart';
import '../theme/theme.dart';

/// Flash sales list + end action (mirrors /my/vendor/flash-sale).
class FlashSalesScreen extends StatefulWidget {
  const FlashSalesScreen({super.key});
  @override
  State<FlashSalesScreen> createState() => _FlashSalesScreenState();
}

class _FlashSalesScreenState extends State<FlashSalesScreen> {
  bool _canFlash = true;
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = VendorApi.instance.flashSales();
    _checkCaps();
  }

  Future<void> _checkCaps() async {
    try {
      final caps = await VendorApi.instance.capabilities();
      if (mounted) setState(() => _canFlash = caps['capabilities']?['flash_sale'] != false);
    } catch (_) {}
  }

  void _refresh() => setState(() => _future = VendorApi.instance.flashSales());

  Future<void> _end(int id) async {
    final ar = VendorApi.instance.lang == 'ar';
    try {
      await VendorApi.instance.flashEnd(id);
      _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
    if (mounted && ar) {} // keep ar referenced
  }

  Color _stateColor(String s) {
    switch (s) {
      case 'active': return UC.successBg;
      case 'draft': return UC.warnBg;
      default: return UC.bg;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ar = VendorApi.instance.lang == 'ar';
    return Scaffold(
      appBar: AppBar(title: Text(ar ? 'عروض الفلاش' : 'Flash sales')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (c, s) {
          if (s.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (s.hasError) return Center(child: Text('${s.error}'));
          final items = s.data ?? [];
          if (items.isEmpty) {
            return Center(child: Text(ar ? 'لا عروض' : 'No flash sales', style: UT.body));
          }
          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (c, i) {
                final f = items[i];
                final st = (f['state'] ?? '').toString();
                final name = (f['name'] is Map)
                    ? (ar ? (f['name']['ar'] ?? f['name']['en']) : f['name']['en'])
                    : f['name'];
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: UC.border)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const Icon(Icons.bolt, color: UC.yellow, size: 18),
                      const SizedBox(width: 4),
                      Expanded(child: Text('$name',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14))),
                      UPill(text: st, bg: _stateColor(st), fg: UC.brown),
                    ]),
                    const SizedBox(height: 6),
                    Row(children: [
                      UPill(text: '-${(f['discount_pct'] ?? 0)}%', bg: UC.dangerBg, fg: UC.dangerDk),
                      const SizedBox(width: 6),
                      UPill(text: '${f['product_count'] ?? 0} ${ar ? "منتج" : "items"}'),
                      const SizedBox(width: 6),
                      if ((f['units_sold'] ?? 0) != 0)
                        UPill(text: '${f['units_sold']} ${ar ? "مبيع" : "sold"}'),
                    ]),
                    if (st == 'active' && _canFlash)
                      Align(alignment: AlignmentDirectional.centerEnd,
                        child: TextButton.icon(
                          onPressed: () => _end(f['id'] as int),
                          icon: const Icon(Icons.stop_circle_outlined, size: 18, color: UC.dangerDk),
                          label: Text(ar ? 'إنهاء' : 'End',
                              style: const TextStyle(color: UC.dangerDk)))),
                  ]),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
