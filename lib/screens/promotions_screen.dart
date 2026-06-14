import 'package:flutter/material.dart';
import '../api/api.dart';
import '../theme/theme.dart';

/// Marketplace promotions — available campaigns + the vendor's joined lines
/// (mirrors /my/vendor/promotions).
class PromotionsScreen extends StatefulWidget {
  const PromotionsScreen({super.key});
  @override
  State<PromotionsScreen> createState() => _PromotionsScreenState();
}

class _PromotionsScreenState extends State<PromotionsScreen> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = VendorApi.instance.promotions();
  }

  Color _lineColor(String s) {
    switch (s) {
      case 'approved': return UC.successBg;
      case 'rejected': return UC.dangerBg;
      default: return UC.warnBg;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ar = VendorApi.instance.lang == 'ar';
    return Scaffold(
      appBar: AppBar(title: Text(ar ? 'الحملات الترويجية' : 'Promotions')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (c, s) {
          if (s.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (s.hasError) return Center(child: Text('${s.error}'));
          final d = s.data ?? const {};
          final avail = (d['available'] as List?) ?? const [];
          final mine = (d['mine'] as List?) ?? const [];
          return RefreshIndicator(
            onRefresh: () async => setState(() => _future = VendorApi.instance.promotions()),
            child: ListView(padding: const EdgeInsets.all(12), children: [
              Text(ar ? 'حملات متاحة للانضمام' : 'Open campaigns', style: UT.h2),
              const SizedBox(height: 8),
              if (avail.isEmpty)
                Text(ar ? 'لا حملات متاحة حالياً' : 'No open campaigns', style: UT.small),
              for (final p in avail) _availCard(p, ar),
              const SizedBox(height: 18),
              Text(ar ? 'مشاركاتي' : 'My entries', style: UT.h2),
              const SizedBox(height: 8),
              if (mine.isEmpty)
                Text(ar ? 'لم تنضم لأي حملة بعد' : 'You have not joined any campaign yet',
                    style: UT.small),
              for (final l in mine) _mineRow(l, ar),
            ]),
          );
        },
      ),
    );
  }

  Widget _availCard(Map p, bool ar) {
    final name = (p['name'] is Map)
        ? (ar ? (p['name']['ar'] ?? p['name']['en']) : p['name']['en'])
        : p['name'];
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.circular(12), border: Border.all(color: UC.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.local_offer_outlined, color: UC.brown, size: 18),
          const SizedBox(width: 6),
          Expanded(child: Text('$name',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14))),
        ]),
        const SizedBox(height: 6),
        Text('${ar ? "الخصم المسموح" : "Allowed discount"}: '
            '${p['min_discount_pct'] ?? 0}%–${p['max_discount_pct'] ?? 0}%', style: UT.small),
        if (p['date_to'] != null)
          Text('${ar ? "ينتهي" : "Ends"}: ${p['date_to']}', style: UT.small),
        const SizedBox(height: 4),
        Text(ar
            ? 'للانضمام بمنتجاتك استخدم بوابة الويب أو حدّث التطبيق لاحقاً.'
            : 'Join with your products from the web portal.',
            style: const TextStyle(fontSize: 10, color: UC.muted, fontStyle: FontStyle.italic)),
      ]),
    );
  }

  Widget _mineRow(Map l, bool ar) => Container(
    margin: const EdgeInsets.only(bottom: 6),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: Colors.white,
        borderRadius: BorderRadius.circular(10), border: Border.all(color: UC.border)),
    child: Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${l['product'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
        Text('${l['promotion'] ?? ''} · -${l['discount_pct'] ?? 0}%', style: UT.small),
      ])),
      UPill(text: (l['state'] ?? '').toString(),
          bg: _lineColor((l['state'] ?? '').toString()), fg: UC.brown),
    ]),
  );
}
