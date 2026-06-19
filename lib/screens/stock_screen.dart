import 'package:flutter/material.dart';
import '../api/api.dart';
import '../theme/theme.dart';

/// Stock list + per-item restock request (mirrors /my/vendor/stock).
///
/// Loads the full vendor stock list once (filter:'all') then derives the
/// summary header + search + filter chips client-side, so the totals stay
/// correct regardless of the active chip. All existing api calls preserved.
class StockScreen extends StatefulWidget {
  const StockScreen({super.key});
  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  String _filter = 'all';
  String _query = '';
  bool _canRestock = true;
  final _searchCtrl = TextEditingController();
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
    _checkCaps();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkCaps() async {
    try {
      final caps = await VendorApi.instance.capabilities();
      if (mounted) setState(() => _canRestock = caps['capabilities']?['restock'] != false);
    } catch (_) {}
  }

  // Always load the complete list; chips + search filter in-memory so the
  // summary header reflects the true totals (same api call as before).
  Future<List<Map<String, dynamic>>> _load() =>
      VendorApi.instance.stock(filter: 'all');

  void _refresh() => setState(() => _future = _load());

  int _qtyOf(Map<String, dynamic> p) => ((p['qty'] ?? 0) as num).toInt();

  bool _matchesFilter(Map<String, dynamic> p) {
    switch (_filter) {
      case 'low':
        return p['low'] == true;
      case 'out':
        return p['out'] == true;
      default:
        return true;
    }
  }

  bool _matchesQuery(Map<String, dynamic> p) {
    if (_query.isEmpty) return true;
    final q = _query.toLowerCase();
    final name = (p['name'] ?? '').toString().toLowerCase();
    final sku = (p['sku'] ?? '').toString().toLowerCase();
    return name.contains(q) || sku.contains(q);
  }

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
              style: FilledButton.styleFrom(
                  backgroundColor: UC.brown, foregroundColor: UC.yellow),
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
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (c, s) {
          if (s.connectionState != ConnectionState.done) {
            return const USpinner();
          }
          if (s.hasError) {
            return Center(child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('${s.error}', textAlign: TextAlign.center, style: UT.body)));
          }
          final all = s.data ?? [];

          // ── Summary metrics (across the whole catalogue) ──
          final totalSkus = all.length;
          final lowCount = all.where((p) => p['low'] == true).length;
          final outCount = all.where((p) => p['out'] == true).length;
          final totalUnits = all.fold<int>(0, (sum, p) => sum + _qtyOf(p));

          // ── Apply chip + search client-side ──
          final items = all.where(_matchesFilter).where(_matchesQuery).toList();

          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                _summaryHeader(ar, totalSkus, lowCount, outCount, totalUnits),
                _searchField(ar),
                _chipsRow(ar, totalSkus, lowCount, outCount),
                const SizedBox(height: 4),
                if (all.isEmpty)
                  _emptyState(ar, ar ? 'لا توجد منتجات' : 'No products')
                else if (items.isEmpty)
                  _emptyState(ar, ar ? 'لا توجد نتائج' : 'No matching items')
                else
                  ...items.map((p) => _stockCard(ar, p)),
              ],
            ),
          );
        },
      ),
    );
  }

  // ───────────────────────── Summary header ─────────────────────────
  Widget _summaryHeader(bool ar, int skus, int low, int out, int units) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [UC.brown, UC.brownSoft],
          begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.inventory_2_outlined, color: UC.yellow, size: 18),
          const SizedBox(width: 7),
          Text(ar ? 'نظرة عامة على المخزون' : 'Inventory overview',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          _metric(ar ? 'المنتجات' : 'SKUs', '$skus', UC.yellow),
          _metricDivider(),
          _metric(ar ? 'إجمالي الوحدات' : 'Units', '$units', Colors.white),
          _metricDivider(),
          _metric(ar ? 'منخفض' : 'Low', '$low', UC.warn),
          _metricDivider(),
          _metric(ar ? 'نفد' : 'Out', '$out', UC.danger),
        ]),
      ]),
    );
  }

  Widget _metric(String label, String value, Color color) => Expanded(
    child: Column(children: [
      Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 19)),
      const SizedBox(height: 2),
      Text(label, textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w700)),
    ]),
  );

  Widget _metricDivider() => Container(
      width: 1, height: 30, color: Colors.white24);

  // ───────────────────────── Search ─────────────────────────
  Widget _searchField(bool ar) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
    child: TextField(
      controller: _searchCtrl,
      onChanged: (v) => setState(() => _query = v.trim()),
      decoration: InputDecoration(
        hintText: ar ? 'ابحث بالاسم أو الرمز' : 'Search by name or SKU',
        prefixIcon: const Icon(Icons.search, color: UC.muted, size: 20),
        suffixIcon: _query.isEmpty ? null : IconButton(
          icon: const Icon(Icons.close, size: 18, color: UC.muted),
          onPressed: () { _searchCtrl.clear(); setState(() => _query = ''); }),
      ),
    ),
  );

  // ───────────────────────── Filter chips ─────────────────────────
  Widget _chipsRow(bool ar, int skus, int low, int out) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    child: Row(children: [
      _chip('all', ar ? 'الكل' : 'All', skus),
      _chip('low', ar ? 'منخفض' : 'Low', low),
      _chip('out', ar ? 'نفد' : 'Out', out),
    ]),
  );

  Widget _chip(String val, String label, int count) {
    final selected = _filter == val;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: ChoiceChip(
        label: Text('$label ($count)',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12,
                color: selected ? UC.brown : UC.text)),
        selected: selected,
        showCheckmark: false,
        backgroundColor: UC.card,
        selectedColor: UC.yellowFaint,
        side: BorderSide(color: selected ? UC.yellow : UC.border, width: 1.3),
        onSelected: (_) => setState(() => _filter = val),
      ),
    );
  }

  // ───────────────────────── Stock card ─────────────────────────
  Widget _stockCard(bool ar, Map<String, dynamic> p) {
    final qty = _qtyOf(p);
    final out = p['out'] == true, low = p['low'] == true;
    final name = (p['name'] ?? '').toString();
    final sku = (p['sku'] ?? '').toString();
    final price = (p['price'] ?? '').toString();
    final image = (p['image'] ?? '').toString();

    final badgeBg = out ? UC.dangerBg : (low ? UC.warnBg : UC.successBg);
    final badgeFg = out ? UC.dangerDk : (low ? UC.warn : UC.successDk);
    final badgeLabel = out
        ? (ar ? 'نفد' : 'Out')
        : (low ? (ar ? 'منخفض' : 'Low') : (ar ? 'متوفر' : 'In stock'));

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: UC.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: UC.border),
      ),
      child: Row(children: [
        // Thumbnail
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 52, height: 52, color: UC.bg,
            child: image.isEmpty
                ? const Icon(Icons.image_outlined, color: UC.muted, size: 22)
                : Image.network(image, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.image_outlined, color: UC.muted, size: 22)),
          ),
        ),
        const SizedBox(width: 12),
        // Name + sku + price
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: UT.h3),
            const SizedBox(height: 3),
            Row(children: [
              if (sku.isNotEmpty) ...[
                Flexible(child: Text(sku, maxLines: 1, overflow: TextOverflow.ellipsis, style: UT.small)),
                const SizedBox(width: 8),
              ],
              if (price.isNotEmpty)
                Text(price, style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w900, color: UC.brown)),
            ]),
            const SizedBox(height: 6),
            Row(children: [
              UPill(text: badgeLabel, bg: badgeBg, fg: badgeFg),
              const SizedBox(width: 6),
              UPill(
                text: ar ? '$qty وحدة' : '$qty units',
                bg: UC.bg, fg: UC.text, icon: Icons.layers_outlined),
            ]),
          ]),
        ),
        // Restock action
        if (_canRestock) ...[
          const SizedBox(width: 6),
          IconButton(
            icon: const Icon(Icons.add_box_outlined, color: UC.brown),
            tooltip: ar ? 'طلب تعبئة' : 'Restock',
            onPressed: () => _restock(p)),
        ],
      ]),
    );
  }

  Widget _emptyState(bool ar, String msg) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 60),
    child: Column(children: [
      const Icon(Icons.inventory_2_outlined, size: 44, color: UC.muted),
      const SizedBox(height: 12),
      Text(msg, style: UT.body),
    ]),
  );
}
