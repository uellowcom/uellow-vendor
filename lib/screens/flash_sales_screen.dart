import 'dart:async';
import 'package:flutter/material.dart';
import '../api/api.dart';
import '../theme/theme.dart';

// ─────────────── shared helpers ───────────────
String _pickName(dynamic name, bool ar) {
  if (name is Map) {
    final en = (name['en'] ?? '').toString();
    final a = (name['ar'] ?? '').toString();
    if (ar) return a.isNotEmpty ? a : en;
    return en.isNotEmpty ? en : a;
  }
  return name?.toString() ?? '';
}

String _money(dynamic m) {
  if (m is Map) {
    final amount = m['amount'];
    final symbol = (m['symbol'] ?? '').toString();
    if (amount == null) return '';
    return '$amount $symbol'.trim();
  }
  return m?.toString() ?? '';
}

String _countdown(int seconds, bool ar) {
  if (seconds <= 0) return ar ? 'انتهى' : 'Ended';
  final d = seconds ~/ 86400;
  final h = (seconds % 86400) ~/ 3600;
  final mi = (seconds % 3600) ~/ 60;
  if (d > 0) return ar ? '${d}ي ${h}س متبقّية' : '${d}d ${h}h left';
  if (h > 0) return ar ? '${h}س ${mi}د متبقّية' : '${h}h ${mi}m left';
  final s = seconds % 60;
  return ar ? '${mi}د ${s}ث متبقّية' : '${mi}m ${s}s left';
}

String _stateLabel(String s, bool ar) {
  switch (s) {
    case 'active': return ar ? 'نشط' : 'Active';
    case 'draft': return ar ? 'مسودة' : 'Draft';
    case 'done':
    case 'ended':
    case 'closed': return ar ? 'منتهٍ' : 'Ended';
    case 'cancel':
    case 'cancelled': return ar ? 'ملغى' : 'Cancelled';
    default: return s;
  }
}

Color _stateBg(String s) {
  switch (s) {
    case 'active': return UC.successBg;
    case 'draft': return UC.warnBg;
    default: return UC.bg;
  }
}

Color _stateFg(String s) {
  switch (s) {
    case 'active': return UC.successDk;
    case 'draft': return UC.warn;
    default: return UC.muted;
  }
}

String _fmtIso(String? iso, bool ar) {
  if (iso == null || iso.isEmpty) return '—';
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  final l = d.toLocal();
  String p(int n) => n.toString().padLeft(2, '0');
  return '${l.year}-${p(l.month)}-${p(l.day)} ${p(l.hour)}:${p(l.minute)}';
}

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
    final newId = await Navigator.push<int>(context,
      MaterialPageRoute(builder: (_) => const PromotionCreateScreen()));
    if (newId != null && newId > 0 && mounted) {
      await Navigator.push(context,
        MaterialPageRoute(builder: (_) => PromotionDetailScreen(id: newId)));
    }
    if (mounted) _refresh();
  }

  Future<void> _open(int id) async {
    await Navigator.push(context,
      MaterialPageRoute(builder: (_) => PromotionDetailScreen(id: id)));
    if (mounted) _refresh();
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
                final name = _pickName(f['name'], ar);
                final remaining = (f['remaining_seconds'] is num)
                    ? (f['remaining_seconds'] as num).toInt() : 0;
                final units = (f['units_sold'] is num) ? (f['units_sold'] as num).toInt() : 0;
                final revenue = _money(f['revenue']);
                final dateLine = st == 'active'
                    ? _countdown(remaining, ar)
                    : '${_fmtIso(f['start']?.toString(), ar)} → ${_fmtIso(f['end']?.toString(), ar)}';
                return InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => _open(f['id'] as int),
                  child: Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: UC.border)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        const Icon(Icons.bolt, color: UC.yellow, size: 18),
                        const SizedBox(width: 4),
                        Expanded(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14.5))),
                        UPill(text: _stateLabel(st, ar), bg: _stateBg(st), fg: _stateFg(st),
                            live: st == 'active'),
                      ]),
                      const SizedBox(height: 9),
                      Wrap(spacing: 6, runSpacing: 6, children: [
                        UPill(text: '-${(f['discount_pct'] ?? 0)}%', bg: UC.dangerBg,
                            fg: UC.dangerDk, icon: Icons.percent),
                        UPill(text: '${f['product_count'] ?? 0} ${ar ? "منتج" : "items"}',
                            icon: Icons.shopping_bag_outlined),
                        if (units != 0)
                          UPill(text: '$units ${ar ? "مبيع" : "sold"}', icon: Icons.shopping_cart_outlined),
                        if (revenue.isNotEmpty && revenue != '0')
                          UPill(text: revenue, bg: UC.successBg, fg: UC.successDk,
                              icon: Icons.payments_outlined),
                      ]),
                      const SizedBox(height: 9),
                      Row(children: [
                        Icon(st == 'active' ? Icons.timer_outlined : Icons.event_outlined,
                            size: 13, color: UC.muted),
                        const SizedBox(width: 5),
                        Expanded(child: Text(dateLine, style: UT.small,
                            maxLines: 1, overflow: TextOverflow.ellipsis)),
                        const Icon(Icons.chevron_right, size: 18, color: UC.muted),
                      ]),
                      if (st == 'active' && _canFlash)
                        Align(alignment: AlignmentDirectional.centerEnd,
                          child: TextButton.icon(
                            onPressed: () => _end(f['id'] as int),
                            icon: const Icon(Icons.stop_circle_outlined, size: 18, color: UC.dangerDk),
                            label: Text(ar ? 'إنهاء العرض' : 'End promotion',
                                style: const TextStyle(color: UC.dangerDk)))),
                    ]),
                  ),
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
      final newId = await VendorApi.instance.flashCreate(body);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ar ? 'تم إنشاء العرض' : 'Promotion created')));
      Navigator.pop(context, newId);
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

// ─────────────── Promotion detail (full record) ───────────────
class PromotionDetailScreen extends StatefulWidget {
  final int id;
  const PromotionDetailScreen({super.key, required this.id});
  @override
  State<PromotionDetailScreen> createState() => _PromotionDetailScreenState();
}

class _PromotionDetailScreenState extends State<PromotionDetailScreen> {
  late Future<Map<String, dynamic>> _future;
  Map<String, dynamic>? _data;
  int _remaining = 0;
  bool _ending = false;
  Timer? _ticker;

  bool get _ar => VendorApi.instance.lang == 'ar';

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = VendorApi.instance.flashDetail(widget.id).then((d) {
      if (mounted) {
        setState(() {
          _data = d;
          _remaining = (d['remaining_seconds'] is num)
              ? (d['remaining_seconds'] as num).toInt() : 0;
        });
        _startTicker(d);
      }
      return d;
    });
  }

  void _startTicker(Map<String, dynamic> d) {
    _ticker?.cancel();
    if ((d['state'] ?? '').toString() == 'active' && _remaining > 0) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) { return; }
        setState(() => _remaining = _remaining > 0 ? _remaining - 1 : 0);
        if (_remaining <= 0) _ticker?.cancel();
      });
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _end() async {
    final ar = _ar;
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: Text(ar ? 'إنهاء العرض؟' : 'End promotion?'),
      content: Text(ar
        ? 'سيتم إيقاف العرض فوراً ولا يمكن التراجع.'
        : 'This will stop the promotion immediately and cannot be undone.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false),
          child: Text(ar ? 'إلغاء' : 'Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: UC.danger, foregroundColor: Colors.white),
          onPressed: () => Navigator.pop(context, true),
          child: Text(ar ? 'إنهاء' : 'End')),
      ]));
    if (ok != true) return;
    setState(() => _ending = true);
    try {
      await VendorApi.instance.flashEnd(widget.id);
      if (!mounted) return;
      _ticker?.cancel();
      _load();
      setState(() => _ending = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ar ? 'تم إنهاء العرض' : 'Promotion ended')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _ending = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ar = _ar;
    return Scaffold(
      backgroundColor: UC.bg,
      appBar: AppBar(title: Text(ar ? 'تفاصيل العرض' : 'Promotion details')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (c, s) {
          if (s.connectionState != ConnectionState.done && _data == null) {
            return const USpinner();
          }
          if (s.hasError && _data == null) {
            return Center(child: Padding(padding: const EdgeInsets.all(24),
              child: Text('${s.error}', style: UT.body, textAlign: TextAlign.center)));
          }
          final d = _data ?? s.data ?? {};
          return RefreshIndicator(
            onRefresh: () async => _load(),
            child: ListView(padding: const EdgeInsets.fromLTRB(14, 14, 14, 30),
              children: _body(d, ar)),
          );
        },
      ),
    );
  }

  List<Widget> _body(Map<String, dynamic> d, bool ar) {
    final st = (d['state'] ?? '').toString();
    final name = _pickName(d['name'], ar);
    final discount = d['discount_pct'] ?? 0;
    final units = (d['units_sold'] is num) ? (d['units_sold'] as num).toInt() : 0;
    final productCount = d['product_count'] ?? 0;
    final extraComm = d['extra_commission'] ?? 0;
    final revenue = _money(d['revenue']);
    final products = (d['products'] is List) ? (d['products'] as List) : const [];

    return [
      // header
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.circular(16), border: Border.all(color: UC.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 40, height: 40,
              decoration: BoxDecoration(color: UC.yellowFaint, borderRadius: BorderRadius.circular(11)),
              child: const Icon(Icons.bolt, color: UC.yellow, size: 22)),
            const SizedBox(width: 11),
            Expanded(child: Text(name, style: UT.h1, maxLines: 2, overflow: TextOverflow.ellipsis)),
            UPill(text: _stateLabel(st, ar), bg: _stateBg(st), fg: _stateFg(st), live: st == 'active'),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Icon(st == 'active' ? Icons.timer_outlined : Icons.event_outlined,
              size: 15, color: st == 'active' ? UC.successDk : UC.muted),
            const SizedBox(width: 6),
            Text(st == 'active' ? _countdown(_remaining, ar) : _stateLabel(st, ar),
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900,
                color: st == 'active' ? UC.successDk : UC.muted)),
          ]),
        ]),
      ),
      const SizedBox(height: 14),

      // stat tiles
      GridView.count(
        crossAxisCount: 2, shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 2.5,
        children: [
          _stat(Icons.percent, ar ? 'الخصم' : 'Discount', '-$discount%', UC.dangerDk),
          _stat(Icons.shopping_bag_outlined, ar ? 'المنتجات' : 'Products', '$productCount', UC.brown),
          _stat(Icons.shopping_cart_outlined, ar ? 'الوحدات المباعة' : 'Units sold', '$units', UC.info),
          _stat(Icons.payments_outlined, ar ? 'الإيرادات' : 'Revenue',
            revenue.isEmpty ? '—' : revenue, UC.successDk),
          if ((extraComm is num ? extraComm.toDouble() : 0) != 0)
            _stat(Icons.workspace_premium_outlined, ar ? 'عمولة إضافية' : 'Extra commission',
              '$extraComm%', UC.warn),
        ],
      ),
      const SizedBox(height: 14),

      // dates
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.circular(16), border: Border.all(color: UC.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [const Icon(Icons.calendar_today_outlined, size: 16, color: UC.brown),
            const SizedBox(width: 7), Text(ar ? 'الفترة' : 'Schedule', style: UT.h3)]),
          const SizedBox(height: 10),
          _dateRow(ar ? 'يبدأ' : 'Start', _fmtIso(d['start']?.toString(), ar)),
          const SizedBox(height: 6),
          _dateRow(ar ? 'ينتهي' : 'End', _fmtIso(d['end']?.toString(), ar)),
        ]),
      ),
      const SizedBox(height: 14),

      // products
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.circular(16), border: Border.all(color: UC.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [const Icon(Icons.inventory_2_outlined, size: 16, color: UC.brown),
            const SizedBox(width: 7),
            Text('${ar ? 'المنتجات' : 'Products'} (${products.length})', style: UT.h3)]),
          const SizedBox(height: 4),
          if (products.isEmpty)
            Padding(padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(ar ? 'لا منتجات' : 'No products', style: UT.small)),
          for (final p in products) _productRow(p as Map<String, dynamic>, ar),
        ]),
      ),
      const SizedBox(height: 16),

      if (st == 'active')
        SizedBox(width: double.infinity, child: ElevatedButton.icon(
          onPressed: _ending ? null : _end,
          icon: _ending
            ? const SizedBox(width: 16, height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.stop_circle_outlined, size: 18),
          label: Text(ar ? 'إنهاء العرض' : 'End promotion',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
          style: ElevatedButton.styleFrom(
            backgroundColor: UC.danger, foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14)))),
    ];
  }

  Widget _stat(IconData ic, String label, String value, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(color: Colors.white,
      borderRadius: BorderRadius.circular(14), border: Border.all(color: UC.border)),
    child: Row(children: [
      Icon(ic, size: 20, color: color),
      const SizedBox(width: 9),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(label.toUpperCase(), style: UT.tiny, maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 2),
        Text(value, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: color)),
      ])),
    ]));

  Widget _dateRow(String label, String value) => Row(children: [
    Expanded(child: Text(label, style: UT.small)),
    Text(value, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: UC.ink)),
  ]);

  Widget _productRow(Map<String, dynamic> p, bool ar) {
    final name = _pickName(p['name'], ar);
    final img = p['image_url']?.toString();
    final listPrice = _money(p['list_price']);
    final salePrice = _money(p['sale_price']);
    final disc = p['discount_pct'] ?? 0;
    return Container(
      margin: const EdgeInsets.only(top: 8), padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: UC.bg, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        ClipRRect(borderRadius: BorderRadius.circular(9),
          child: (img != null && img.isNotEmpty)
            ? Image.network('${VendorApi.instance.baseUrl}$img',
                width: 48, height: 48, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(width: 48, height: 48, color: UC.border,
                  child: const Icon(Icons.image, size: 18, color: UC.muted)))
            : Container(width: 48, height: 48, color: UC.border,
                child: const Icon(Icons.image, size: 18, color: UC.muted))),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, maxLines: 2, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
          const SizedBox(height: 4),
          Row(children: [
            if (listPrice.isNotEmpty)
              Text(listPrice, style: const TextStyle(fontSize: 11, color: UC.muted,
                decoration: TextDecoration.lineThrough)),
            if (listPrice.isNotEmpty) const SizedBox(width: 6),
            if (salePrice.isNotEmpty)
              Text(salePrice, style: const TextStyle(fontSize: 12.5,
                fontWeight: FontWeight.w900, color: UC.successDk)),
          ]),
        ])),
        const SizedBox(width: 6),
        UPill(text: '-$disc%', bg: UC.dangerBg, fg: UC.dangerDk),
      ]),
    );
  }
}
