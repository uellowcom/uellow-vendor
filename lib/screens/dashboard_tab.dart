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
          return ListView(padding: EdgeInsets.zero, children: [
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
                  const SizedBox(height: 12),
                  Row(children: [
                    _miniRev(ar ? 'هذا الأسبوع' : 'Week', d.revWeek.format(lang)),
                    _miniRev(ar ? 'هذا الشهر' : 'Month', d.revMonth.format(lang)),
                    _miniRev(ar ? 'إجمالي' : 'All time', d.revTotal.format(lang)),
                  ]),
                ]),
              ])),
            // Order cards
            Padding(padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
              child: Row(children: [Text(ar ? 'الطلبات' : 'Orders', style: UT.h3)])),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(children: [
                _orderTile(d.ordersNew, ar ? 'جديدة' : 'New', UC.info, UC.infoBg),
                const SizedBox(width: 6),
                _orderTile(d.ordersConfirmed, ar ? 'قيد التنفيذ' : 'Active', UC.warn, UC.warnBg),
                const SizedBox(width: 6),
                _orderTile(d.ordersCompleted, ar ? 'مكتملة' : 'Done', UC.successDk, UC.successBg),
                const SizedBox(width: 6),
                _orderTile(d.ordersCancelled, ar ? 'ملغاة' : 'Cancelled', UC.dangerDk, UC.dangerBg),
              ])),
            // Product cards
            Padding(padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
              child: Row(children: [Text(ar ? 'المنتجات' : 'Products', style: UT.h3)])),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(children: [
                _prodTile(d.productsActive, ar ? 'نشطة' : 'Active', Icons.check_circle_outline, UC.successDk),
                const SizedBox(width: 6),
                _prodTile(d.productsPendingApproval, ar ? 'بانتظار الموافقة' : 'Pending', Icons.hourglass_bottom, UC.warn),
                const SizedBox(width: 6),
                _prodTile(d.productsLowStock, ar ? 'مخزون منخفض' : 'Low stock', Icons.warning_amber, UC.dangerDk),
              ])),
            // Wallet quick
            Padding(padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
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
            // Recent orders
            if (d.recentOrders.isNotEmpty) Padding(padding: const EdgeInsets.fromLTRB(14, 18, 14, 4),
              child: Row(children: [
                Text(ar ? 'أحدث الطلبات' : 'Latest orders', style: UT.h3),
              ])),
            for (final o in d.recentOrders) _recentRow(o, lang),
            const SizedBox(height: 24),
          ]);
        })),
    );
  }

  Widget _miniRev(String l, String v) => Expanded(child: Padding(
    padding: const EdgeInsets.symmetric(horizontal: 3),
    child: Container(padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: const Color(0x14FFFFFF),
        borderRadius: BorderRadius.circular(9)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l.toUpperCase(), style: const TextStyle(color: Color(0xCCFFE066),
          fontSize: 9, fontWeight: FontWeight.w800)),
        Text(v, style: const TextStyle(color: Colors.white, fontSize: 12.5,
          fontWeight: FontWeight.w900)),
      ]))));

  Widget _orderTile(int v, String l, Color fg, Color bg) => Expanded(child: Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(11)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('$v', style: TextStyle(color: fg, fontSize: 20, fontWeight: FontWeight.w900)),
      const SizedBox(height: 2),
      Text(l, style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.w800)),
    ])));

  Widget _prodTile(int v, String l, IconData ic, Color c) => Expanded(child: Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: Colors.white, border: Border.all(color: UC.border),
      borderRadius: BorderRadius.circular(11)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(ic, size: 13, color: c),
        const SizedBox(width: 4),
        Text('$v', style: TextStyle(color: c, fontSize: 20, fontWeight: FontWeight.w900)),
      ]),
      Text(l, style: const TextStyle(color: UC.muted, fontSize: 10, fontWeight: FontWeight.w700)),
    ])));

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
              Text(o.name, style: const TextStyle(fontFamily: 'monospace',
                fontSize: 12, fontWeight: FontWeight.w900)),
              Text(o.customer, style: UT.small, maxLines: 1, overflow: TextOverflow.ellipsis),
            ])),
            Text(o.amount.format(lang),
              style: const TextStyle(fontWeight: FontWeight.w900, color: UC.brown, fontSize: 13)),
          ])))),
  );
}
