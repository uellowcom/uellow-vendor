import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../api/api.dart';
import '../theme/theme.dart';

class ProductsTab extends StatefulWidget {
  const ProductsTab({super.key});
  @override
  State<ProductsTab> createState() => _ProductsTabState();
}

class _ProductsTabState extends State<ProductsTab> {
  String _state = '';
  String _search = '';
  Future<List<ProductSummary>>? _f;
  final _q = TextEditingController();
  @override
  void initState() { super.initState(); _reload(); }
  @override
  void dispose() { _q.dispose(); super.dispose(); }
  void _reload() {
    setState(() => _f = VendorApi.instance.products(state: _state, search: _search));
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.pushNamed(context, '/product-edit');
          _reload();
        },
        backgroundColor: UC.brown, foregroundColor: UC.yellowSoft,
        icon: const Icon(Icons.add),
        label: Text(ar ? 'منتج جديد' : 'New product',
          style: const TextStyle(fontWeight: FontWeight.w900))),
      body: RefreshIndicator(onRefresh: () async { _reload(); await _f; },
        child: FutureBuilder<List<ProductSummary>>(future: _f, builder: (_, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: USpinner());
          if (snap.hasError) return Center(child: Padding(padding: const EdgeInsets.all(24),
            child: Text(snap.error.toString(), style: UT.body, textAlign: TextAlign.center)));
          final rows = snap.data ?? const <ProductSummary>[];
          if (rows.isEmpty) return Padding(padding: const EdgeInsets.all(40),
            child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.shopping_bag_outlined, size: 48, color: UC.muted),
              const SizedBox(height: 12),
              Text(ar ? 'لا توجد منتجات هنا' : 'No products here', style: UT.body),
            ])));
          return ListView.separated(padding: const EdgeInsets.fromLTRB(10, 0, 10, 80),
            itemCount: rows.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _card(rows[i], lang));
        })),
    );
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
              Row(children: [
                Text(p.listPrice.format(lang),
                  style: const TextStyle(fontWeight: FontWeight.w900,
                    color: UC.brown, fontSize: 13.5)),
                const SizedBox(width: 8),
                UPill(text: p.approvalState.toUpperCase(),
                  bg: _apprBg(p.approvalState), fg: _apprFg(p.approvalState)),
              ]),
              const SizedBox(height: 4),
              Wrap(spacing: 6, runSpacing: 4, children: [
                UPill(text: '${p.qty.toStringAsFixed(0)} ${ar ? "بالمخزون" : "in stock"}',
                  bg: p.qty <= 5 ? UC.dangerBg : UC.bg,
                  fg: p.qty <= 5 ? UC.dangerDk : UC.muted,
                  icon: p.qty <= 5 ? Icons.warning_amber : null),
                if (!p.isPublished) UPill(text: ar ? 'غير منشور' : 'Unpublished',
                  bg: UC.warnBg, fg: const Color(0xFF92400E)),
                if (p.salesCount > 0) UPill(text: ar
                    ? '${p.salesCount.toStringAsFixed(0)} مبيعات'
                    : '${p.salesCount.toStringAsFixed(0)} sold',
                  bg: UC.successBg, fg: UC.successDk),
              ]),
            ])),
          ]))));
  }
}
