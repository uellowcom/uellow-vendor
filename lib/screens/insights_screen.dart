import 'package:flutter/material.dart';
import '../api/api.dart';
import '../theme/theme.dart';

/// Vendor KPIs — products, profit/margin, sales, customers, categories,
/// top sellers and storefront views.
class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});
  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  Future<Map<String, dynamic>>? _f;
  bool get _ar => VendorApi.instance.lang == 'ar';

  @override
  void initState() { super.initState(); _f = VendorApi.instance.kpis(); }
  Future<void> _refresh() async { setState(() => _f = VendorApi.instance.kpis()); await _f; }

  String _money(dynamic m) => m is Map
    ? '${(m['amount'] ?? 0)} ${m['symbol'] ?? ''}' : '${m ?? ''}';
  String _bl(dynamic v) => v is Map
    ? (_ar ? (v['ar'] ?? v['en']) : (v['en'] ?? v['ar']) ?? '').toString() : '${v ?? ''}';

  @override
  Widget build(BuildContext context) {
    final ar = _ar;
    return Scaffold(
      backgroundColor: UC.bg,
      appBar: AppBar(title: Text(ar ? 'مؤشرات الأداء' : 'Insights / KPIs')),
      body: RefreshIndicator(onRefresh: _refresh,
        child: FutureBuilder<Map<String, dynamic>>(future: _f, builder: (_, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: USpinner());
          if (snap.hasError) return ListView(children: [Padding(padding: const EdgeInsets.all(24),
            child: Text(snap.error.toString(), textAlign: TextAlign.center, style: UT.body))]);
          final d = snap.data ?? const {};
          final pr = (d['products'] as Map?) ?? const {};
          final pf = (d['profit'] as Map?) ?? const {};
          final sl = (d['sales'] as Map?) ?? const {};
          final cu = (d['customers'] as Map?) ?? const {};
          final cats = (d['categories'] as List?) ?? const [];
          final sellers = (d['top_sellers'] as List?) ?? const [];
          return ListView(padding: const EdgeInsets.all(14), children: [
            // Profit hero
            Container(padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [UC.brown, UC.brownSoft],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(18)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(ar ? 'إجمالي الربح' : 'GROSS PROFIT',
                  style: const TextStyle(color: Color(0xFFFFE066), fontSize: 11, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(_money(pf['gross_profit']),
                  style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                Row(children: [
                  _heroBit(ar ? 'الإيراد' : 'Revenue', _money(pf['revenue'])),
                  _heroBit(ar ? 'التكلفة' : 'Cost', _money(pf['cost'])),
                  _heroBit(ar ? 'الهامش' : 'Margin', '${pf['margin_pct'] ?? 0}%'),
                ]),
              ])),
            const SizedBox(height: 14),
            _h(ar ? 'المنتجات' : 'Products'),
            GridView.count(crossAxisCount: 3, shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.15, children: [
                _tile('${pr['total'] ?? 0}', ar ? 'الكل' : 'Total', Icons.inventory_2, UC.brown),
                _tile('${pr['published'] ?? 0}', ar ? 'منشورة' : 'Live', Icons.check_circle, UC.successDk),
                _tile('${pr['pending'] ?? 0}', ar ? 'بانتظار' : 'Pending', Icons.hourglass_bottom, UC.warn),
                _tile('${pr['out_of_stock'] ?? 0}', ar ? 'نفد' : 'Out', Icons.remove_shopping_cart, UC.dangerDk),
                _tile('${pr['low_stock'] ?? 0}', ar ? 'منخفض' : 'Low', Icons.warning_amber, UC.warn),
                _tile('${pr['total_views'] ?? 0}', ar ? 'الزيارات' : 'Views', Icons.visibility, UC.info),
              ]),
            const SizedBox(height: 14),
            _h(ar ? 'المبيعات والعملاء' : 'Sales & customers'),
            GridView.count(crossAxisCount: 2, shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 2.5, children: [
                _wide(ar ? 'مبيعات الشهر' : 'Sales (month)', _money(sl['gmv_month']), Icons.trending_up),
                _wide(ar ? 'طلبات الشهر' : 'Orders (month)', '${sl['orders_month'] ?? 0}', Icons.receipt_long),
                _wide(ar ? 'متوسط الطلب' : 'Avg order', _money(sl['aov']), Icons.shopping_basket),
                _wide(ar ? 'وحدات مُباعة' : 'Units sold', '${sl['units_all'] ?? 0}', Icons.sell),
                _wide(ar ? 'عملاء' : 'Customers', '${cu['distinct'] ?? 0}', Icons.people),
                _wide(ar ? 'عائدون' : 'Repeat', '${cu['repeat_pct'] ?? 0}%', Icons.repeat),
              ]),
            if (cats.isNotEmpty) ...[
              const SizedBox(height: 14),
              _h(ar ? 'أعلى الأقسام' : 'Top categories'),
              for (final c in cats) _rowItem(_bl((c as Map)['name']),
                '${_money(c['revenue'])} · ${c['units']} ${ar ? 'وحدة' : 'units'}', Icons.category),
            ],
            if (sellers.isNotEmpty) ...[
              const SizedBox(height: 14),
              _h(ar ? 'الأكثر مبيعاً' : 'Top sellers'),
              for (final s in sellers) _rowItem(_bl((s as Map)['name']),
                '${s['units']} ${ar ? 'مُباع' : 'sold'} · ${s['views']} ${ar ? 'زيارة' : 'views'}',
                Icons.star, img: s['image_url'] as String?),
            ],
            const SizedBox(height: 24),
          ]);
        })),
    );
  }

  Widget _heroBit(String l, String v) => Expanded(child: Container(
    margin: const EdgeInsets.only(right: 6), padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(color: const Color(0x14FFFFFF), borderRadius: BorderRadius.circular(9)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(l.toUpperCase(), style: const TextStyle(color: Color(0xCCFFE066), fontSize: 8.5, fontWeight: FontWeight.w800)),
      Text(v, maxLines: 1, overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900)),
    ])));

  Widget _h(String t) => Padding(padding: const EdgeInsets.only(bottom: 8),
    child: Text(t, style: UT.h3));

  Widget _tile(String v, String l, IconData ic, Color c) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(13),
      border: Border.all(color: UC.border)),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(ic, size: 16, color: c),
      const Spacer(),
      Text(v, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: c)),
      Text(l, style: const TextStyle(fontSize: 10, color: UC.muted, fontWeight: FontWeight.w700)),
    ]));

  Widget _wide(String l, String v, IconData ic) => Container(
    padding: const EdgeInsets.all(11),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(13),
      border: Border.all(color: UC.border)),
    child: Row(children: [
      Container(width: 34, height: 34, alignment: Alignment.center,
        decoration: BoxDecoration(color: UC.yellowFaint, borderRadius: BorderRadius.circular(9)),
        child: Icon(ic, size: 16, color: UC.brown)),
      const SizedBox(width: 8),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(v, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: UC.ink)),
        Text(l, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 9.5, color: UC.muted, fontWeight: FontWeight.w700)),
      ])),
    ]));

  Widget _rowItem(String title, String sub, IconData ic, {String? img}) => Container(
    margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
      border: Border.all(color: UC.border)),
    child: Row(children: [
      Container(width: 38, height: 38, alignment: Alignment.center,
        decoration: BoxDecoration(color: UC.yellowFaint, borderRadius: BorderRadius.circular(10)),
        child: img != null
          ? ClipRRect(borderRadius: BorderRadius.circular(10),
              child: Image.network('${VendorApi.instance.baseUrl}$img', fit: BoxFit.cover,
                width: 38, height: 38, errorBuilder: (_,__,___) => Icon(ic, size: 16, color: UC.brown)))
          : Icon(ic, size: 16, color: UC.brown)),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
        Text(sub, style: UT.small),
      ])),
    ]));
}
