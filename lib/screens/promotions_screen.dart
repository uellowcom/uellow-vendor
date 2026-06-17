import 'package:flutter/material.dart';
import '../api/api.dart';
import '../theme/theme.dart';

/// Marketplace promotions — available campaigns the vendor can JOIN with their
/// products (calls /promotions/join) + the vendor's joined lines.
class PromotionsScreen extends StatefulWidget {
  const PromotionsScreen({super.key});
  @override
  State<PromotionsScreen> createState() => _PromotionsScreenState();
}

class _PromotionsScreenState extends State<PromotionsScreen> {
  late Future<Map<String, dynamic>> _future;
  bool _canJoin = true;

  @override
  void initState() {
    super.initState();
    _future = VendorApi.instance.promotions();
    _checkCaps();
  }

  Future<void> _checkCaps() async {
    try {
      final caps = await VendorApi.instance.capabilities();
      if (mounted) {
        setState(() => _canJoin = (caps['capabilities'] as Map?)?['join_promotions'] != false);
      }
    } catch (_) {}
  }

  void _reload() => setState(() => _future = VendorApi.instance.promotions());

  Color _lineColor(String s) {
    switch (s) {
      case 'approved': return UC.successBg;
      case 'rejected': return UC.dangerBg;
      default: return UC.warnBg;
    }
  }

  Future<void> _join(Map promo) async {
    final ar = VendorApi.instance.lang == 'ar';
    final lang = ar ? 'ar' : 'en';
    final minD = ((promo['min_discount_pct'] ?? 0) as num).toDouble();
    final maxD = ((promo['max_discount_pct'] ?? 100) as num).toDouble();
    List<ProductSummary> prods;
    try {
      prods = await VendorApi.instance.products(state: 'live');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      return;
    }
    if (!mounted) return;
    if (prods.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ar ? 'لا منتجات منشورة للانضمام' : 'No live products to join')));
      return;
    }
    final selected = <int>{};
    final discCtrl = TextEditingController(text: minD.toStringAsFixed(0));
    final submitted = await showModalBottomSheet<bool>(
      context: context, isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (c) => StatefulBuilder(builder: (c, setM) => Padding(
        padding: EdgeInsets.only(
          left: 14, right: 14, top: 14,
          bottom: MediaQuery.of(c).viewInsets.bottom + 14),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(ar ? 'الانضمام بمنتجاتك' : 'Join with your products', style: UT.h2),
            const SizedBox(height: 4),
            Text('${ar ? "الخصم المسموح" : "Allowed"}: ${minD.toStringAsFixed(0)}%–${maxD.toStringAsFixed(0)}%',
              style: UT.small),
            const SizedBox(height: 10),
            TextField(controller: discCtrl, keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: ar ? 'نسبة الخصم %' : 'Discount %',
                border: const OutlineInputBorder())),
            const SizedBox(height: 10),
            Flexible(child: ListView(shrinkWrap: true, children: [
              for (final p in prods)
                CheckboxListTile(
                  dense: true,
                  value: selected.contains(p.id),
                  activeColor: UC.brown,
                  title: Text(p.name.t(lang), maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  subtitle: Text(p.listPrice.format(lang), style: UT.small),
                  onChanged: (v) => setM(() {
                    if (v == true) { selected.add(p.id); } else { selected.remove(p.id); }
                  }),
                ),
            ])),
            const SizedBox(height: 10),
            SizedBox(width: double.infinity, child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: UC.yellow, foregroundColor: UC.brown),
              onPressed: selected.isEmpty ? null : () => Navigator.pop(c, true),
              child: Text(ar ? 'إرسال طلب الانضمام' : 'Submit join request'))),
            const SizedBox(height: 4),
          ])),
      ),
    );
    if (submitted != true) return;
    var disc = double.tryParse(discCtrl.text.trim()) ?? minD;
    if (disc < minD) disc = minD;
    if (disc > maxD) disc = maxD;
    final items = selected.map((id) => {'product_id': id, 'discount_pct': disc}).toList();
    try {
      await VendorApi.instance.promotionJoin(promo['id'] as int, items);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ar ? 'تم إرسال طلب الانضمام للمراجعة' : 'Join request submitted for review')));
      _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
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
            onRefresh: () async => _reload(),
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
        const SizedBox(height: 8),
        SizedBox(width: double.infinity, child: FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: UC.yellow, foregroundColor: UC.brown),
          onPressed: _canJoin ? () => _join(p) : null,
          icon: const Icon(Icons.add, size: 18),
          label: Text(ar ? 'انضمام بمنتجاتي' : 'Join with my products'))),
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
