import 'package:flutter/material.dart';
import '../api/api.dart';
import '../theme/theme.dart';

/// Restock requests history (mirrors /my/vendor/restock-requests).
class RestockScreen extends StatefulWidget {
  const RestockScreen({super.key});
  @override
  State<RestockScreen> createState() => _RestockScreenState();
}

class _RestockScreenState extends State<RestockScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = VendorApi.instance.restockList();
  }

  Color _stateColor(String s) {
    switch (s) {
      case 'received': return UC.successBg;
      case 'rejected': return UC.dangerBg;
      case 'shipped':
      case 'approved': return UC.warnBg;
      default: return UC.yellowFaint;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ar = VendorApi.instance.lang == 'ar';
    return Scaffold(
      appBar: AppBar(title: Text(ar ? 'طلبات التعبئة' : 'Restock requests')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (c, s) {
          if (s.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (s.hasError) return Center(child: Text('${s.error}'));
          final items = s.data ?? [];
          if (items.isEmpty) {
            return Center(child: Text(ar ? 'لا طلبات' : 'No requests', style: UT.body));
          }
          return RefreshIndicator(
            onRefresh: () async => setState(() => _future = VendorApi.instance.restockList()),
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (c, i) {
                final r = items[i];
                final lines = (r['lines'] as List?) ?? const [];
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: UC.border)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Text('#${r['id']}', style: const TextStyle(fontWeight: FontWeight.w900)),
                      const Spacer(),
                      UPill(text: (r['state'] ?? '').toString(),
                          bg: _stateColor((r['state'] ?? '').toString()), fg: UC.brown),
                    ]),
                    if (r['expected_date'] != null)
                      Text('${ar ? "متوقع" : "Expected"}: ${r['expected_date']}', style: UT.small),
                    const SizedBox(height: 6),
                    for (final l in lines)
                      Text('• ${l['product']}  ×${l['qty']}', style: UT.body),
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
