import 'package:flutter/material.dart';
import '../api/api.dart';
import '../theme/theme.dart';

/// Internal Promotions (vendor-run timed discounts; backend model
/// uellow.flash.sale) — list + create + end.
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
    try {
      await VendorApi.instance.flashEnd(id);
      _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  // Naive UTC timestamp 'YYYY-MM-DD HH:MM:SS' (Odoo stores naive UTC).
  String _fmt(DateTime d) {
    String p(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${p(d.month)}-${p(d.day)} ${p(d.hour)}:${p(d.minute)}:${p(d.second)}';
  }

  Future<void> _create() async {
    final ar = VendorApi.instance.lang == 'ar';
    final lang = ar ? 'ar' : 'en';
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
        content: Text(ar ? 'لا منتجات منشورة لإنشاء عرض' : 'No live products to promote')));
      return;
    }
    final nameCtrl = TextEditingController();
    final discCtrl = TextEditingController(text: '15');
    final selected = <int>{};
    final durations = <String, Duration>{
      (ar ? '6 ساعات' : '6h'): const Duration(hours: 6),
      (ar ? '12 ساعة' : '12h'): const Duration(hours: 12),
      (ar ? 'يوم' : '24h'): const Duration(days: 1),
      (ar ? '3 أيام' : '3d'): const Duration(days: 3),
      (ar ? 'أسبوع' : '7d'): const Duration(days: 7),
    };
    String durKey = durations.keys.elementAt(2); // default 24h

    final submitted = await showModalBottomSheet<bool>(
      context: context, isScrollControlled: true, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (c) => StatefulBuilder(builder: (c, setM) => Padding(
        padding: EdgeInsets.only(
          left: 14, right: 14, top: 14,
          bottom: MediaQuery.of(c).viewInsets.bottom + 14),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(ar ? 'إنشاء عرض داخلي' : 'Create internal promotion', style: UT.h2),
            const SizedBox(height: 10),
            TextField(controller: nameCtrl,
              decoration: InputDecoration(
                labelText: ar ? 'اسم العرض' : 'Promotion name',
                border: const OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: discCtrl, keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: ar ? 'نسبة الخصم %' : 'Discount %',
                border: const OutlineInputBorder())),
            const SizedBox(height: 10),
            Text(ar ? 'المدة' : 'Duration', style: UT.small),
            Wrap(spacing: 6, children: [
              for (final k in durations.keys)
                ChoiceChip(label: Text(k), selected: durKey == k,
                  selectedColor: UC.yellowFaint,
                  onSelected: (_) => setM(() => durKey = k)),
            ]),
            const SizedBox(height: 8),
            Text(ar ? 'المنتجات' : 'Products', style: UT.small),
            Flexible(child: ListView(shrinkWrap: true, children: [
              for (final p in prods)
                CheckboxListTile(
                  dense: true, activeColor: UC.brown,
                  value: selected.contains(p.id),
                  title: Text(p.name.t(lang), maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  subtitle: Text(p.listPrice.format(lang), style: UT.small),
                  onChanged: (v) => setM(() {
                    if (v == true) { selected.add(p.id); } else { selected.remove(p.id); }
                  }),
                ),
            ])),
            const SizedBox(height: 10),
            SizedBox(width: double.infinity, child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: UC.yellow, foregroundColor: UC.brown),
              onPressed: selected.isEmpty ? null : () => Navigator.pop(c, true),
              icon: const Icon(Icons.bolt, size: 18),
              label: Text(ar ? 'تفعيل العرض' : 'Activate promotion'))),
            const SizedBox(height: 4),
          ])),
      ),
    );
    if (submitted != true) return;
    final disc = double.tryParse(discCtrl.text.trim()) ?? 0;
    if (disc <= 0) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ar ? 'أدخل نسبة خصم صحيحة' : 'Enter a valid discount')));
      return;
    }
    final start = DateTime.now().toUtc();
    final end = start.add(durations[durKey]!);
    final name = nameCtrl.text.trim().isEmpty
      ? (ar ? 'عرض داخلي' : 'Internal promotion') : nameCtrl.text.trim();
    try {
      await VendorApi.instance.flashCreate({
        'name_en': name, 'name_ar': name,
        'discount_pct': disc,
        'start': _fmt(start), 'end': _fmt(end),
        'product_ids': selected.toList(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ar ? 'تم إنشاء العرض' : 'Promotion created')));
      _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
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
      appBar: AppBar(
        title: Text(ar ? 'العروض الداخلية' : 'Internal Promotion'),
        actions: [
          if (_canFlash)
            IconButton(icon: const Icon(Icons.add), tooltip: ar ? 'إنشاء' : 'Create',
              onPressed: _create),
        ]),
      floatingActionButton: _canFlash
        ? FloatingActionButton.extended(
            backgroundColor: UC.yellow, foregroundColor: UC.brown,
            onPressed: _create,
            icon: const Icon(Icons.add),
            label: Text(ar ? 'عرض داخلي' : 'New promotion'))
        : null,
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (c, s) {
          if (s.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (s.hasError) return Center(child: Text('${s.error}'));
          final items = s.data ?? [];
          if (items.isEmpty) {
            return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(ar ? 'لا عروض داخلية بعد' : 'No internal promotions yet', style: UT.body),
              const SizedBox(height: 10),
              if (_canFlash) FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: UC.yellow, foregroundColor: UC.brown),
                onPressed: _create,
                icon: const Icon(Icons.add, size: 18),
                label: Text(ar ? 'إنشاء عرض داخلي' : 'Create internal promotion')),
            ]));
          }
          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
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
