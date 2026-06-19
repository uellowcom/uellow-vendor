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

  Future<void> _create() async {
    final created = await Navigator.push<bool>(context,
      MaterialPageRoute(builder: (_) => const PromotionCreateScreen()));
    if (created == true) _refresh();
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

// ─────────────── Promotion create (full page) ───────────────
class _PLine {
  final ProductSummary product;
  final TextEditingController disc;
  _PLine(this.product) : disc = TextEditingController();
}

class PromotionCreateScreen extends StatefulWidget {
  const PromotionCreateScreen({super.key});
  @override
  State<PromotionCreateScreen> createState() => _PromotionCreateScreenState();
}

class _PromotionCreateScreenState extends State<PromotionCreateScreen> {
  final _name = TextEditingController();
  final _general = TextEditingController(text: '15');
  bool _perProduct = false;
  bool _busy = false, _loading = true;
  List<ProductSummary> _all = [];
  final Map<int, _PLine> _selected = {};
  Duration _dur = const Duration(days: 1);

  bool get _ar => VendorApi.instance.lang == 'ar';
  String get _lang => _ar ? 'ar' : 'en';

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      var p = await VendorApi.instance.products(state: 'live');
      if (p.isEmpty) p = await VendorApi.instance.products(state: 'published');
      if (!mounted) return;
      setState(() { _all = p; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  void dispose() {
    _name.dispose(); _general.dispose();
    for (final l in _selected.values) { l.disc.dispose(); }
    super.dispose();
  }

  String _fmt(DateTime d) {
    String p(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${p(d.month)}-${p(d.day)} ${p(d.hour)}:${p(d.minute)}:${p(d.second)}';
  }

  Future<void> _pick() async {
    final picked = await showModalBottomSheet<ProductSummary>(
      context: context, isScrollControlled: true, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _PromoProductPicker(products: _all.where((p) => !_selected.containsKey(p.id)).toList(),
        lang: _lang, ar: _ar));
    if (picked != null) setState(() => _selected[picked.id] = _PLine(picked));
  }

  Future<void> _submit() async {
    final ar = _ar;
    if (_selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ar ? 'اختر منتجاً واحداً على الأقل' : 'Select at least one product')));
      return;
    }
    final general = double.tryParse(_general.text.trim()) ?? 0;
    if (!_perProduct && general <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ar ? 'أدخل نسبة خصم صحيحة' : 'Enter a valid discount')));
      return;
    }
    setState(() => _busy = true);
    final start = DateTime.now().toUtc();
    final end = start.add(_dur);
    final name = _name.text.trim().isEmpty ? (ar ? 'عرض داخلي' : 'Internal promotion') : _name.text.trim();
    final body = <String, dynamic>{
      'name_en': name, 'name_ar': name,
      'discount_pct': general,
      'start': _fmt(start), 'end': _fmt(end),
    };
    if (_perProduct) {
      body['lines'] = [for (final l in _selected.values)
        {'product_id': l.product.id, 'discount_pct': double.tryParse(l.disc.text.trim()) ?? 0}];
    } else {
      body['product_ids'] = _selected.keys.toList();
    }
    try {
      await VendorApi.instance.flashCreate(body);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ar ? 'تم إنشاء العرض' : 'Promotion created')));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ar = _ar;
    final durs = <String, Duration>{
      (ar ? '٦ س' : '6h'): const Duration(hours: 6),
      (ar ? '١٢ س' : '12h'): const Duration(hours: 12),
      (ar ? 'يوم' : '24h'): const Duration(days: 1),
      (ar ? '٣ أيام' : '3d'): const Duration(days: 3),
      (ar ? 'أسبوع' : '7d'): const Duration(days: 7),
    };
    return Scaffold(
      backgroundColor: UC.bg,
      appBar: AppBar(title: Text(ar ? 'عرض داخلي جديد' : 'New promotion')),
      body: _loading ? const Center(child: USpinner()) : ListView(padding: const EdgeInsets.all(14), children: [
        _card(ar ? 'التفاصيل' : 'Details', Icons.bolt, [
          TextField(controller: _name, decoration: InputDecoration(labelText: ar ? 'اسم العرض' : 'Promotion name')),
          const SizedBox(height: 12),
          Text((ar ? 'المدة' : 'Duration').toUpperCase(), style: UT.tiny),
          const SizedBox(height: 6),
          Wrap(spacing: 6, children: [
            for (final e in durs.entries)
              ChoiceChip(label: Text(e.key), selected: _dur == e.value,
                selectedColor: UC.yellowFaint,
                onSelected: (_) => setState(() => _dur = e.value)),
          ]),
        ]),
        _card(ar ? 'نوع الخصم' : 'Discount type', Icons.percent, [
          SwitchListTile(contentPadding: EdgeInsets.zero,
            activeColor: UC.brown,
            title: Text(ar ? 'خصم مختلف لكل منتج' : 'Per-product discount',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
            subtitle: Text(ar ? 'أطفئه لخصم عام موحّد' : 'Off = one general discount',
              style: UT.small),
            value: _perProduct, onChanged: (v) => setState(() => _perProduct = v)),
          if (!_perProduct) ...[
            const SizedBox(height: 6),
            TextField(controller: _general, keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: ar ? 'الخصم العام %' : 'General discount %',
                suffixText: '%')),
          ],
        ]),
        _card('${ar ? 'المنتجات' : 'Products'} (${_selected.length})', Icons.shopping_bag_outlined, [
          for (final l in _selected.values) _lineRow(l),
          if (_selected.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(ar ? 'لم تُضف منتجات' : 'No products yet', style: UT.small)),
          const SizedBox(height: 6),
          OutlinedButton.icon(onPressed: _pick, icon: const Icon(Icons.add, size: 18),
            label: Text(ar ? 'إضافة منتج (بحث)' : 'Add product (search)')),
        ]),
        const SizedBox(height: 6),
        SizedBox(width: double.infinity, child: ElevatedButton.icon(
          onPressed: _busy ? null : _submit,
          icon: _busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: UC.brown))
            : const Icon(Icons.bolt, size: 18),
          label: Text(ar ? 'إنشاء العرض' : 'Create promotion',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15)))),
        const SizedBox(height: 24),
      ]),
    );
  }

  Widget _lineRow(_PLine l) {
    return Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: UC.bg, borderRadius: BorderRadius.circular(11)),
      child: Row(children: [
        ClipRRect(borderRadius: BorderRadius.circular(8),
          child: l.product.imageUrl != null
            ? Image.network('${VendorApi.instance.baseUrl}${l.product.imageUrl}',
                width: 42, height: 42, fit: BoxFit.cover,
                errorBuilder: (_,__,___) => Container(width: 42, height: 42, color: UC.border, child: const Icon(Icons.image, size: 18, color: UC.muted)))
            : Container(width: 42, height: 42, color: UC.border, child: const Icon(Icons.image, size: 18, color: UC.muted))),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l.product.name.t(_lang), maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
          Text(l.product.listPrice.format(_lang), style: UT.small),
        ])),
        if (_perProduct) SizedBox(width: 66, child: TextField(controller: l.disc,
          keyboardType: TextInputType.number, textAlign: TextAlign.center,
          decoration: const InputDecoration(isDense: true, hintText: '%', suffixText: '%',
            contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 6)))),
        IconButton(icon: const Icon(Icons.close, size: 18, color: UC.dangerDk),
          onPressed: () => setState(() { l.disc.dispose(); _selected.remove(l.product.id); })),
      ]));
  }

  Widget _card(String title, IconData ic, List<Widget> children) => Container(
    margin: const EdgeInsets.only(bottom: 14), padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
      border: Border.all(color: UC.border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Icon(ic, size: 17, color: UC.brown), const SizedBox(width: 7), Text(title, style: UT.h3)]),
      const SizedBox(height: 10), ...children,
    ]));
}

class _PromoProductPicker extends StatefulWidget {
  final List<ProductSummary> products;
  final String lang;
  final bool ar;
  const _PromoProductPicker({required this.products, required this.lang, required this.ar});
  @override
  State<_PromoProductPicker> createState() => _PromoProductPickerState();
}

class _PromoProductPickerState extends State<_PromoProductPicker> {
  String _q = '';
  @override
  Widget build(BuildContext context) {
    final q = _q.trim().toLowerCase();
    final list = widget.products.where((p) => q.isEmpty
      || p.name.en.toLowerCase().contains(q) || p.name.ar.toLowerCase().contains(q)).toList();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(height: MediaQuery.of(context).size.height * .75, child: Column(children: [
        const SizedBox(height: 10),
        Container(width: 40, height: 4, decoration: BoxDecoration(color: UC.border, borderRadius: BorderRadius.circular(2))),
        Padding(padding: const EdgeInsets.all(14),
          child: TextField(autofocus: true,
            decoration: InputDecoration(hintText: widget.ar ? 'ابحث عن منتج' : 'Search products',
              prefixIcon: const Icon(Icons.search)),
            onChanged: (s) => setState(() => _q = s))),
        Expanded(child: ListView.builder(itemCount: list.length, itemBuilder: (c, i) {
          final p = list[i];
          return ListTile(
            leading: ClipRRect(borderRadius: BorderRadius.circular(8),
              child: p.imageUrl != null
                ? Image.network('${VendorApi.instance.baseUrl}${p.imageUrl}', width: 44, height: 44, fit: BoxFit.cover,
                    errorBuilder: (_,__,___) => Container(width: 44, height: 44, color: UC.border, child: const Icon(Icons.image, color: UC.muted)))
                : Container(width: 44, height: 44, color: UC.border, child: const Icon(Icons.image, color: UC.muted))),
            title: Text(p.name.t(widget.lang), maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(p.listPrice.format(widget.lang), style: UT.small),
            trailing: const Icon(Icons.add_circle, color: UC.brown),
            onTap: () => Navigator.pop(context, p));
        })),
      ])));
  }
}
