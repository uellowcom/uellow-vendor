import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../api/api.dart';
import '../theme/theme.dart';

class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key});
  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  Future<Dashboard>? _f;
  @override
  void initState() { super.initState(); _f = VendorApi.instance.dashboard(); }
  Future<void> _refresh() async {
    setState(() => _f = VendorApi.instance.dashboard());
    await _f;
  }

  @override
  Widget build(BuildContext context) {
    final ar = VendorApi.instance.lang == 'ar';
    final lang = ar ? 'ar' : 'en';
    final v = VendorApi.instance.vendor;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 14,
        title: Row(children: [
          if (v?.logoUrl != null) CircleAvatar(radius: 16, backgroundColor: UC.yellowFaint,
            backgroundImage: CachedNetworkImageProvider('${VendorApi.instance.baseUrl}${v!.logoUrl!}'))
          else CircleAvatar(radius: 16, backgroundColor: UC.yellow,
            child: Text(v?.storeName.t(lang).substring(0, 1).toUpperCase() ?? 'U',
              style: const TextStyle(color: UC.brown, fontWeight: FontWeight.w900))),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min, children: [
            Text(v?.storeName.t(lang) ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
            Row(children: [
              const Icon(Icons.star, size: 11, color: UC.warn),
              Text(' ${v?.avgRating.toStringAsFixed(1) ?? "—"}  ·  ',
                style: const TextStyle(fontSize: 10.5, color: UC.muted, fontWeight: FontWeight.w700)),
              Text('${v?.followerCount ?? 0} ${ar ? "متابع" : "followers"}',
                style: const TextStyle(fontSize: 10.5, color: UC.muted, fontWeight: FontWeight.w700)),
            ]),
          ])),
        ]),
        actions: [
          IconButton(icon: const Icon(Icons.bar_chart),
            tooltip: ar ? 'تحليلات' : 'Analytics',
            onPressed: () => Navigator.pushNamed(context, '/analytics')),
          IconButton(icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.pushNamed(context, '/settings')),
        ],
      ),
      body: RefreshIndicator(onRefresh: _refresh,
        child: FutureBuilder<Dashboard>(future: _f, builder: (_, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: USpinner());
          if (snap.hasError) return Center(child: Padding(padding: const EdgeInsets.all(24),
            child: Text(snap.error.toString(), style: UT.body, textAlign: TextAlign.center)));
          final d = snap.data!;
          return ListView(padding: const EdgeInsets.only(bottom: 24), children: [
            // Vendor Score banner
            Container(margin: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(color: _scoreBg(d.scoreBand),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _scoreFg(d.scoreBand).withValues(alpha: .3))),
              child: Row(children: [
                Icon(Icons.verified, color: _scoreFg(d.scoreBand), size: 22),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(ar ? 'تقييم أداء المتجر' : 'Vendor score',
                    style: const TextStyle(fontSize: 11, color: UC.muted, fontWeight: FontWeight.w700)),
                  Text(_scoreLabel(d.scoreBand, ar),
                    style: TextStyle(fontSize: 13, color: _scoreFg(d.scoreBand), fontWeight: FontWeight.w900)),
                ])),
                Text('${d.score}', style: TextStyle(fontSize: 26, color: _scoreFg(d.scoreBand), fontWeight: FontWeight.w900)),
                Text(' /100', style: UT.small),
              ])),
            // Hero gradient with revenue
            Container(margin: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [UC.brown, UC.brownSoft]),
                borderRadius: BorderRadius.circular(18)),
              child: Stack(children: [
                Positioned(top: -30, right: -30, child: Container(width: 120, height: 120,
                  decoration: const BoxDecoration(
                    gradient: RadialGradient(colors: [Color(0x33F5C320), Colors.transparent]),
                    shape: BoxShape.circle))),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(ar ? 'إيرادات اليوم' : "TODAY'S REVENUE",
                    style: const TextStyle(color: Color(0xFFFFE066), fontSize: 11,
                      fontWeight: FontWeight.w800, letterSpacing: .4)),
                  const SizedBox(height: 4),
                  Text(d.revToday.format(lang),
                    style: const TextStyle(color: Colors.white, fontSize: 28,
                      fontWeight: FontWeight.w900, height: 1.1)),
                  const SizedBox(height: 14),
                  Row(children: [
                    _miniRev(ar ? 'هذا الأسبوع' : 'Week', d.revWeek.format(lang)),
                    _miniRev(ar ? 'هذا الشهر' : 'Month', d.revMonth.format(lang)),
                    _miniRev(ar ? 'إجمالي' : 'All time', d.revTotal.format(lang)),
                  ]),
                ]),
              ])),
            // Inventory value held at Yellow — FBU / consignment vendors only.
            if (d.invIsFbu) Padding(padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              child: Container(padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.white,
                  border: Border.all(color: UC.border), borderRadius: BorderRadius.circular(14)),
                child: Row(children: [
                  Container(width: 44, height: 44, alignment: Alignment.center,
                    decoration: BoxDecoration(color: UC.infoBg, borderRadius: BorderRadius.circular(11)),
                    child: const Icon(Icons.warehouse_outlined, color: UC.info, size: 21)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(ar ? 'قيمة مخزونك لدى يلو' : 'Inventory value at Yellow',
                      style: const TextStyle(fontSize: 11, color: UC.muted, fontWeight: FontWeight.w800)),
                    Text(d.invValue.format(lang),
                      style: const TextStyle(fontSize: 20, color: UC.brown, fontWeight: FontWeight.w900)),
                    Text('${d.invUnits} ${ar ? "وحدة بالتكلفة" : "units · at cost"}', style: UT.small),
                  ])),
                ]))),
            // Orders — tappable 2-col grid
            _sectionHeader(ar ? 'الطلبات' : 'Orders', Icons.shopping_bag_outlined),
            _grid([
              _orderTile(context, d.ordersNew, ar ? 'جديدة' : 'New', UC.info, UC.infoBg,
                Icons.fiber_new, 'orders_new', ar ? 'الطلبات الجديدة' : 'New orders'),
              _orderTile(context, d.ordersConfirmed, ar ? 'قيد التنفيذ' : 'Active', UC.warn, UC.warnBg,
                Icons.local_shipping_outlined, 'orders_active', ar ? 'الطلبات قيد التنفيذ' : 'Active orders'),
              _orderTile(context, d.ordersCompleted, ar ? 'مكتملة' : 'Done', UC.successDk, UC.successBg,
                Icons.task_alt, 'orders_done', ar ? 'الطلبات المكتملة' : 'Completed orders'),
              _orderTile(context, d.ordersCancelled, ar ? 'ملغاة' : 'Cancelled', UC.dangerDk, UC.dangerBg,
                Icons.cancel_outlined, 'orders_cancelled', ar ? 'الطلبات الملغاة' : 'Cancelled orders'),
            ]),
            // Performance KPIs — non-tappable, except Returns
            _sectionHeader(ar ? 'الأداء' : 'Performance', Icons.insights_outlined),
            _grid([
              _kpiTile(ar ? 'متوسط الطلب' : 'AOV',
                '${(d.kpis['aov'] is Map) ? (d.kpis['aov']['amount'] ?? 0) : 0} ${(d.kpis['aov'] is Map) ? (d.kpis['aov']['symbol'] ?? '') : ''}',
                Icons.payments_outlined),
              _kpiTile(ar ? 'مبيعات الشهر' : 'Units (mo)', '${d.kpis['units_month'] ?? 0}',
                Icons.inventory_2_outlined),
              _kpiTile(ar ? 'عملاء عائدون' : 'Repeat', '${d.kpis['repeat_pct'] ?? 0}%',
                Icons.repeat),
              _kpiTile(ar ? 'استرجاع مفتوح' : 'Returns', '${d.kpis['open_returns'] ?? 0}',
                Icons.assignment_return_outlined,
                metric: 'returns_open', title: ar ? 'المرتجعات المفتوحة' : 'Open returns'),
            ]),
            // Products — tappable 2-col grid
            _sectionHeader(ar ? 'المنتجات' : 'Products', Icons.category_outlined),
            _grid([
              _prodTile(context, d.productsActive, ar ? 'نشطة' : 'Active', Icons.check_circle_outline, UC.successDk,
                'products_active', ar ? 'المنتجات النشطة' : 'Active products'),
              _prodTile(context, d.productsPendingApproval, ar ? 'بانتظار الموافقة' : 'Pending', Icons.hourglass_bottom, UC.warn,
                'products_pending', ar ? 'بانتظار الموافقة' : 'Pending approval'),
              _prodTile(context, d.productsLowStock, ar ? 'مخزون منخفض' : 'Low stock', Icons.warning_amber, UC.dangerDk,
                'products_low', ar ? 'مخزون منخفض' : 'Low stock'),
            ]),
            // Wallet quick
            Padding(padding: const EdgeInsets.fromLTRB(14, 16, 14, 0),
              child: Material(color: Colors.white, borderRadius: BorderRadius.circular(13),
                child: InkWell(borderRadius: BorderRadius.circular(13),
                  onTap: () => Navigator.pushNamed(context, '/wallet'),
                  child: Container(padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                        colors: [UC.yellow, UC.yellowSoft]),
                      borderRadius: BorderRadius.circular(13)),
                    child: Row(children: [
                      Container(width: 44, height: 44, alignment: Alignment.center,
                        decoration: const BoxDecoration(color: UC.brown, shape: BoxShape.circle),
                        child: const Icon(Icons.account_balance_wallet,
                            color: UC.yellowSoft, size: 19)),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(ar ? 'رصيد المحفظة' : 'Wallet balance',
                          style: const TextStyle(color: UC.brownSoft, fontSize: 10.5,
                            fontWeight: FontWeight.w800, letterSpacing: .4)),
                        Text(d.walletBalance.format(lang),
                          style: const TextStyle(color: UC.brown, fontSize: 18,
                            fontWeight: FontWeight.w900)),
                      ])),
                      const Icon(Icons.chevron_right, color: UC.brown),
                    ])))),
              ),
            // Recent orders — title + inline "More" on the same line.
            if (d.recentOrders.isNotEmpty) Padding(padding: const EdgeInsets.fromLTRB(14, 20, 14, 6),
              child: Row(children: [
                const Icon(Icons.history, size: 16, color: UC.brown),
                const SizedBox(width: 6),
                Text(ar ? 'أحدث الطلبات' : 'Latest orders', style: UT.h3),
                const Spacer(),
                InkWell(
                  onTap: () => Navigator.pushNamed(context, '/order-hub'),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Row(children: [
                      Text(ar ? 'المزيد' : 'More',
                        style: const TextStyle(color: UC.brown, fontWeight: FontWeight.w900, fontSize: 12.5)),
                      const Icon(Icons.chevron_right, color: UC.brown, size: 18),
                    ]))),
              ])),
            for (final o in d.recentOrders) _recentRow(o, lang),
          ]);
        })),
    );
  }

  // Consistent section header with leading icon.
  Widget _sectionHeader(String title, IconData icon) => Padding(
    padding: const EdgeInsets.fromLTRB(14, 18, 14, 8),
    child: Row(children: [
      Icon(icon, size: 16, color: UC.brown),
      const SizedBox(width: 6),
      Text(title, style: UT.h3),
    ]));

  // Evenly-sized 2-column grid that keeps every tile aligned.
  Widget _grid(List<Widget> tiles) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14),
    child: GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 2.4,
      children: tiles,
    ));

  Widget _miniRev(String l, String v) => Expanded(child: Padding(
    padding: const EdgeInsets.symmetric(horizontal: 3),
    child: Container(padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(color: const Color(0x14FFFFFF),
        borderRadius: BorderRadius.circular(9)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l.toUpperCase(), style: const TextStyle(color: Color(0xCCFFE066),
          fontSize: 9, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(v, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white, fontSize: 12.5,
            fontWeight: FontWeight.w900)),
      ]))));

  Widget _tileShell({required Widget child, required Color bg, Color? border,
      VoidCallback? onTap}) {
    final box = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12),
        border: border != null ? Border.all(color: border) : null),
      child: child);
    if (onTap == null) return box;
    return Material(color: Colors.transparent, borderRadius: BorderRadius.circular(12),
      child: InkWell(borderRadius: BorderRadius.circular(12), onTap: onTap, child: box));
  }

  Widget _orderTile(BuildContext context, int v, String l, Color fg, Color bg,
      IconData ic, String metric, String title) => _tileShell(
    bg: bg,
    onTap: () => Navigator.pushNamed(context, '/records',
      arguments: {'metric': metric, 'title': title}),
    child: Row(children: [
      Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('$v', style: TextStyle(color: fg, fontSize: 22, fontWeight: FontWeight.w900, height: 1)),
        const SizedBox(height: 3),
        Text(l, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(color: fg, fontSize: 10.5, fontWeight: FontWeight.w800)),
      ])),
      Icon(ic, size: 22, color: fg.withValues(alpha: .55)),
    ]));

  Widget _prodTile(BuildContext context, int v, String l, IconData ic, Color c,
      String metric, String title) => _tileShell(
    bg: Colors.white, border: UC.border,
    onTap: () => Navigator.pushNamed(context, '/records',
      arguments: {'metric': metric, 'title': title}),
    child: Row(children: [
      Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('$v', style: TextStyle(color: c, fontSize: 22, fontWeight: FontWeight.w900, height: 1)),
        const SizedBox(height: 3),
        Text(l, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: UC.muted, fontSize: 10.5, fontWeight: FontWeight.w700)),
      ])),
      Icon(ic, size: 20, color: c.withValues(alpha: .6)),
    ]));

  Color _scoreBg(String b) => {
    'excellent': UC.successBg, 'good': UC.successBg,
    'fair': UC.warnBg, 'at_risk': UC.dangerBg}[b] ?? UC.warnBg;
  Color _scoreFg(String b) => {
    'excellent': UC.successDk, 'good': UC.successDk,
    'fair': const Color(0xFF92400E), 'at_risk': UC.dangerDk}[b] ?? const Color(0xFF92400E);
  String _scoreLabel(String b, bool ar) => {
    'excellent': ar ? 'ممتاز' : 'Excellent', 'good': ar ? 'جيد' : 'Good',
    'fair': ar ? 'مقبول' : 'Fair', 'at_risk': ar ? 'يحتاج تحسين' : 'Needs work'}[b] ?? b;

  Widget _kpiTile(String l, String v, IconData ic, {String? metric, String? title}) => _tileShell(
    bg: UC.yellowFaint, border: UC.border,
    onTap: (metric != null)
      ? () => Navigator.pushNamed(context, '/records',
          arguments: {'metric': metric, 'title': title ?? l})
      : null,
    child: Row(children: [
      Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(v, style: const TextStyle(color: UC.brown, fontSize: 17, fontWeight: FontWeight.w900, height: 1),
          maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 3),
        Text(l, style: const TextStyle(color: UC.muted, fontSize: 10, fontWeight: FontWeight.w700),
          maxLines: 1, overflow: TextOverflow.ellipsis),
      ])),
      Icon(ic, size: 20, color: UC.brown.withValues(alpha: .45)),
    ]));

  Widget _recentRow(RecentOrder o, String lang) => Padding(
    padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
    child: Material(color: Colors.white, borderRadius: BorderRadius.circular(11),
      child: InkWell(borderRadius: BorderRadius.circular(11),
        onTap: () => Navigator.pushNamed(context, '/order', arguments: {'id': o.id}),
        child: Container(padding: const EdgeInsets.all(11),
          child: Row(children: [
            Container(width: 36, height: 36, alignment: Alignment.center,
              decoration: BoxDecoration(color: UC.yellowFaint, borderRadius: BorderRadius.circular(9)),
              child: const Icon(Icons.receipt_long, color: UC.brown, size: 17)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(o.name, style: const TextStyle(fontFamily: 'monospace',
                  fontSize: 12, fontWeight: FontWeight.w900)),
                const SizedBox(width: 6),
                _statePill(o.state, lang),
              ]),
              const SizedBox(height: 2),
              Text(o.customer, style: UT.small, maxLines: 1, overflow: TextOverflow.ellipsis),
            ])),
            Text(o.amount.format(lang),
              style: const TextStyle(fontWeight: FontWeight.w900, color: UC.brown, fontSize: 13)),
          ])))),
  );

  Widget _statePill(String s, String lang) {
    final ar = lang == 'ar';
    final (String label, Color bg, Color fg) = switch (s) {
      'sale' => (ar ? 'مؤكد' : 'Confirmed', UC.successBg, UC.successDk),
      'done' => (ar ? 'مكتمل' : 'Done', UC.successBg, UC.successDk),
      'sent' => (ar ? 'عرض سعر' : 'Quote', UC.infoBg, const Color(0xFF1E40AF)),
      'draft' => (ar ? 'مسودة' : 'Draft', UC.warnBg, const Color(0xFF92400E)),
      'cancel' => (ar ? 'ملغي' : 'Cancelled', UC.dangerBg, UC.dangerDk),
      _ => (s, UC.bg, UC.muted),
    };
    return UPill(text: label, bg: bg, fg: fg);
  }
}
