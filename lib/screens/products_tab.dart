import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../api/api.dart';
import '../theme/theme.dart';

const int _kPerPage = 20;

class ProductsTab extends StatefulWidget {
  const ProductsTab({super.key});
  @override
  State<ProductsTab> createState() => _ProductsTabState();
}

class _ProductsTabState extends State<ProductsTab> {
  String _state = '';
  String _search = '';
  final _q = TextEditingController();
  final _scroll = ScrollController();

  final List<ProductSummary> _items = [];
  int _page = 1;
  bool _loading = false;
  bool _hasMore = true;
  bool _firstDone = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _reload();
  }

  @override
  void dispose() { _q.dispose(); _scroll.dispose(); super.dispose(); }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 400) _loadMore();
  }

  Future<void> _reload() async {
    setState(() {
      _items.clear(); _page = 1; _hasMore = true; _firstDone = false; _error = null;
    });
    await _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    setState(() => _loading = true);
    try {
      final rows = await VendorApi.instance.products(
        state: _state, search: _search, page: _page);
      setState(() {
        _items.addAll(rows);
        _hasMore = rows.length >= _kPerPage;
        _page += 1;
        _error = null;
      });
    } catch (e) {
      setState(() => _error = e);
    } finally {
      if (mounted) setState(() { _loading = false; _firstDone = true; });
    }
  }

  Color _apprBg(String s) => switch (s) {
    'approved' => UC.successBg,
    'pending' || 'draft' => UC.warnBg,
    'rejected' => UC.dangerBg,
    _ => UC.bg,
  };
  Color _apprFg(String s) => switch (s) {
    'approved' => UC.successDk,
    'pending' || 'draft' => const Color(0xFF92400E),
    'rejected' => UC.dangerDk,
    _ => UC.muted,
  };

  @override
  Widget build(BuildContext context) {
    final ar = VendorApi.instance.lang == 'ar';
    final lang = ar ? 'ar' : 'en';
    return Scaffold(
      appBar: AppBar(title: Text(ar ? 'المنتجات' : 'Products'),
        bottom: PreferredSize(preferredSize: const Size.fromHeight(98),
          child: Column(children: [
            Padding(padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              child: TextField(controller: _q,
                onChanged: (v) { _search = v; _reload(); },
                decoration: InputDecoration(
                  hintText: ar ? 'بحث المنتجات…' : 'Search products…',
                  prefixIcon: const Icon(Icons.search, size: 18)))),
            SizedBox(height: 44, child: ListView(scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              children: [
                _tab('',          ar ? 'الكل' : 'All'),
                _tab('live',      ar ? 'منشورة' : 'Live'),
                _tab('pending',   ar ? 'قيد المراجعة' : 'Pending'),
                _tab('rejected',  ar ? 'مرفوضة' : 'Rejected'),
                _tab('low_stock', ar ? 'مخزون منخفض' : 'Low stock'),
                _tab('unpublished', ar ? 'غير منشورة' : 'Unpublished'),
              ])),
          ])),
      ),
      // Smaller, more professional new-product action.
      floatingActionButton: FloatingActionButton.small(
        onPressed: () async {
          await Navigator.pushNamed(context, '/product-edit');
          _reload();
        },
        backgroundColor: UC.brown, foregroundColor: UC.yellowSoft,
        tooltip: ar ? 'منتج جديد' : 'New product',
        child: const Icon(Icons.add, size: 22)),
      body: RefreshIndicator(onRefresh: _reload, child: _body(lang, ar)),
    );
  }

  Widget _body(String lang, bool ar) {
    if (!_firstDone && _items.isEmpty) return const Center(child: USpinner());
    if (_error != null && _items.isEmpty) {
      return ListView(children: [Padding(padding: const EdgeInsets.all(24),
        child: Text(_error.toString(), style: UT.body, textAlign: TextAlign.center))]);
    }
    if (_items.isEmpty) {
      return ListView(children: [Padding(padding: const EdgeInsets.all(40),
        child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.shopping_bag_outlined, size: 48, color: UC.muted),
          const SizedBox(height: 12),
          Text(ar ? 'لا توجد منتجات هنا' : 'No products here', style: UT.body),
        ])))]);
    }
    return ListView.separated(controller: _scroll,
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 90),
      itemCount: _items.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        if (i == _items.length) {
          return Padding(padding: const EdgeInsets.all(16),
            child: Center(child: _hasMore
              ? const USpinner()
              : Text('— ${ar ? "النهاية" : "end"} —', style: UT.small)));
        }
        return _card(_items[i], lang);
      });
  }

  Widget _tab(String key, String label) {
    final on = _state == key;
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: GestureDetector(onTap: () { _state = key; _reload(); },
        child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: on ? UC.yellow : Colors.white,
            border: Border.all(color: on ? UC.yellow : UC.border, width: 1.5),
            borderRadius: BorderRadius.circular(999)),
          child: Text(label, style: TextStyle(
            color: on ? UC.brown : UC.text, fontWeight: FontWeight.w900, fontSize: 12.5)))));
  }

  /// Stock pill that respects continue-selling / non-storable products.
  Widget _stockPill(ProductSummary p, bool ar) {
    if (!p.inStock) {
      return UPill(text: ar ? 'نفد المخزون' : 'Out of stock',
        bg: UC.dangerBg, fg: UC.dangerDk, icon: Icons.error_outline);
    }
    if (p.allowOos && p.qty <= 0) {
      return UPill(text: ar ? 'متاح (حسب الطلب)' : 'Available',
        bg: UC.successBg, fg: UC.successDk, icon: Icons.all_inclusive);
    }
    final low = p.qty <= 5;
    return UPill(
      text: '${p.qty.toStringAsFixed(0)} ${ar ? "بالمخزون" : "in stock"}',
      bg: low ? UC.warnBg : UC.successBg,
      fg: low ? const Color(0xFF92400E) : UC.successDk,
      icon: low ? Icons.warning_amber : null);
  }

  Widget _card(ProductSummary p, String lang) {
    final ar = lang == 'ar';
    return Material(color: Colors.white, borderRadius: BorderRadius.circular(13),
      child: InkWell(borderRadius: BorderRadius.circular(13),
        onTap: () => Navigator.pushNamed(context, '/product', arguments: {'id': p.id}),
        child: Container(padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(border: Border.all(color: UC.border),
            borderRadius: BorderRadius.circular(13)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ClipRRect(borderRadius: BorderRadius.circular(10),
              child: p.imageUrl != null
                ? CachedNetworkImage(
                    imageUrl: '${VendorApi.instance.baseUrl}${p.imageUrl!}',
                    width: 70, height: 70, fit: BoxFit.cover,
                    errorWidget: (_,__,___) => Container(width: 70, height: 70,
                      color: UC.bg, child: const Icon(Icons.image, color: UC.muted)))
                : Container(width: 70, height: 70, color: UC.yellowFaint,
                    child: const Icon(Icons.image, color: UC.brown))),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.name.t(lang), maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
              const SizedBox(height: 4),
              // Cost is what the vendor deals with → show it primary.
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(p.standardPrice.format(lang),
                  style: const TextStyle(fontWeight: FontWeight.w900,
                    color: UC.brown, fontSize: 14.5)),
                const SizedBox(width: 6),
                Text(ar ? 'التكلفة' : 'cost', style: UT.tiny),
                const Spacer(),
                UPill(text: p.approvalState.toUpperCase(),
                  bg: _apprBg(p.approvalState), fg: _apprFg(p.approvalState)),
              ]),
              const SizedBox(height: 2),
              Text('${ar ? "البيع" : "Sells at"} ${p.listPrice.format(lang)}'
                  '${p.marginPct != 0 ? "  ·  ${p.marginPct.toStringAsFixed(0)}% ${ar ? "هامش" : "margin"}" : ""}',
                style: UT.small),
              const SizedBox(height: 5),
              Wrap(spacing: 6, runSpacing: 4, children: [
                _stockPill(p, ar),
                if (!p.isPublished) UPill(text: ar ? 'غير منشور' : 'Unpublished',
                  bg: UC.warnBg, fg: const Color(0xFF92400E)),
                if (p.salesCount > 0) UPill(text: ar
                    ? '${p.salesCount.toStringAsFixed(0)} مبيعات'
                    : '${p.salesCount.toStringAsFixed(0)} sold',
                  bg: UC.infoBg, fg: const Color(0xFF1E40AF)),
              ]),
            ])),
          ]))));
  }
}
