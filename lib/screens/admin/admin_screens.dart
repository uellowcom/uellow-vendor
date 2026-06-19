import 'package:flutter/material.dart';
import '../../api/api.dart';
import '../../theme/theme.dart';
import '../reports_screen.dart' show downloadAndShare;

const Color _admin = Color(0xFF2563EB);
const Color _adminDk = Color(0xFF0F1F3A);
const Color _adminFaint = Color(0xFFEAF1FC);
const Color _approve = Color(0xFF1f9d55);

String _money(Map? m) {
  if (m == null) return '0';
  final a = (m['amount'] ?? 0);
  final s = (m['symbol'] ?? 'KD');
  return '$a $s';
}

// ════════════════════════ shared section header ════════════════════════
class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label, {this.icon, this.trailing});
  final String label;
  final IconData? icon;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 14, bottom: 8, left: 2, right: 2),
    child: Row(children: [
      if (icon != null) ...[Icon(icon, size: 16, color: UC.muted), const SizedBox(width: 6)],
      Expanded(child: Text(label.toUpperCase(),
        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900,
          color: UC.muted, letterSpacing: 0.6))),
      if (trailing != null) trailing!,
    ]),
  );
}

// ════════════════════════════ HOME ════════════════════════════
class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});
  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  late Future<Map<String, dynamic>> _f;
  @override
  void initState() { super.initState(); _f = VendorApi.instance.adminDashboard(); }

  @override
  Widget build(BuildContext context) {
    final ar = VendorApi.instance.lang == 'ar';
    return Scaffold(
      appBar: AppBar(backgroundColor: _admin, foregroundColor: Colors.white,
        title: Text(ar ? '🛡️ لوحة السوق' : '🛡️ Marketplace'),
        actions: [
          if (!VendorApi.instance.adminOnly)
            IconButton(tooltip: ar ? 'وضع التاجر' : 'Vendor mode',
              icon: const Icon(Icons.storefront),
              onPressed: () => Navigator.pushReplacementNamed(context, '/home')),
          IconButton(tooltip: ar ? 'خروج' : 'Logout', icon: const Icon(Icons.logout), onPressed: () async {
            await VendorApi.instance.logout();
            if (context.mounted) Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
          }),
        ]),
      body: FutureBuilder<Map<String, dynamic>>(future: _f, builder: (_, s) {
        if (s.connectionState != ConnectionState.done) return const USpinner();
        if (s.hasError) return Center(child: Padding(padding: const EdgeInsets.all(20), child: Text('${s.error}')));
        final d = s.data ?? const {};
        final gmv = (d['gmv'] as Map?) ?? const {};
        final ord = (d['orders'] as Map?) ?? const {};
        final ven = (d['vendors'] as Map?) ?? const {};
        final app = (d['approvals'] as Map?) ?? const {};
        final top = (d['top_vendors'] as List?) ?? const [];
        final byType = (d['by_type'] as List?) ?? const [];
        final pending = ((app['products'] ?? 0) as num).toInt() + ((app['edits'] ?? 0) as num).toInt();
        final newOrd = ((ord['new'] ?? 0) as num).toInt();
        return RefreshIndicator(
          color: _admin,
          onRefresh: () async => setState(() => _f = VendorApi.instance.adminDashboard()),
          child: ListView(padding: const EdgeInsets.fromLTRB(12, 12, 12, 28), children: [
            // ── hero GMV card ──
            Container(padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_adminDk, _admin],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [BoxShadow(color: _admin.withValues(alpha: 0.25),
                  blurRadius: 18, offset: const Offset(0, 8))]),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.trending_up, color: Colors.white70, size: 16),
                  const SizedBox(width: 6),
                  Expanded(child: Text(ar ? 'مبيعات السوق — هذا الشهر' : 'Marketplace GMV — this month',
                    style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700))),
                ]),
                const SizedBox(height: 6),
                Text(_money(gmv['month'] as Map?), style: const TextStyle(
                  color: Color(0xFFFFE066), fontSize: 30, fontWeight: FontWeight.w900, height: 1.05)),
                const SizedBox(height: 10),
                Row(children: [
                  _heroChip(Icons.today, ar ? 'اليوم' : 'Today', _money(gmv['today'] as Map?)),
                  const SizedBox(width: 8),
                  _heroChip(Icons.date_range, ar ? 'الأسبوع' : 'Week', _money(gmv['week'] as Map?)),
                ]),
              ])),
            const SizedBox(height: 12),
            // ── stat tiles ──
            GridView.count(crossAxisCount: 2, shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 2.5, mainAxisSpacing: 8, crossAxisSpacing: 8, children: [
              _stat('${ven['active'] ?? 0}', ar ? 'تاجر نشط' : 'Active vendors', Icons.storefront, _admin),
              _stat('$newOrd', ar ? 'طلبات جديدة' : 'New orders', Icons.fiber_new, UC.info),
              _stat('${ord['processing'] ?? 0}', ar ? 'قيد التجهيز' : 'Processing', Icons.local_shipping, UC.warn),
              _stat('$pending', ar ? 'بانتظار الموافقة' : 'Pending', Icons.fact_check, UC.danger),
            ]),

            // ── APPROVALS ──
            _SectionHeader(ar ? 'الموافقات' : 'Approvals', icon: Icons.fact_check),
            _actionCard(context, Icons.fact_check, _admin, _adminFaint,
              ar ? 'طابور الاعتماد' : 'Approvals queue',
              ar ? 'منتجات جديدة وتعديلات وأسعار' : 'New products, edits & prices',
              const AdminApprovalsScreen(), badge: pending),

            // ── VENDORS ──
            _SectionHeader(ar ? 'التُّجار' : 'Vendors', icon: Icons.store),
            _actionCard(context, Icons.storefront, const Color(0xFF7C3AED), const Color(0xFFF1EAFE),
              ar ? 'إدارة التُّجار' : 'Manage vendors',
              ar ? 'الأنواع، الصلاحيات، التسوية' : 'Types, capabilities, settlement',
              const AdminVendorsScreen(), badge: ((ven['active'] ?? 0) as num).toInt(), badgeColor: UC.muted),

            // ── ORDERS ──
            _SectionHeader(ar ? 'الطلبات' : 'Orders', icon: Icons.receipt_long),
            _actionCard(context, Icons.receipt_long, UC.info, UC.infoBg,
              ar ? 'كل الطلبات' : 'All orders',
              ar ? 'تتبّع وفلترة طلبات السوق' : 'Track & filter marketplace orders',
              const AdminOrdersScreen(), badge: newOrd, badgeColor: UC.info),

            // ── FINANCE / EXPORTS ──
            _SectionHeader(ar ? 'المالية والتصدير' : 'Finance & exports', icon: Icons.download),
            Row(children: [
              Expanded(child: _exportCard(context, Icons.table_view, ar ? 'تصدير الطلبات' : 'Export orders',
                ar ? 'ملف Excel للطلبات' : 'Orders Excel',
                '/api/vendor/v1/admin/export/orders.xlsx', 'marketplace_orders.xlsx')),
              const SizedBox(width: 8),
              Expanded(child: _exportCard(context, Icons.table_view, ar ? 'تصدير التُّجار' : 'Export vendors',
                ar ? 'ملف Excel للتُّجار' : 'Vendors Excel',
                '/api/vendor/v1/admin/export/vendors.xlsx', 'vendors.xlsx')),
            ]),

            // ── GMV by type ──
            if (byType.isNotEmpty) ...[
              _SectionHeader(ar ? 'المبيعات حسب نوع التاجر' : 'GMV by vendor type', icon: Icons.pie_chart),
              _breakdownCard([
                for (final b in byType)
                  _BreakdownRow(label: '${b['type'] ?? ''}', value: _money(b['gmv'] as Map?)),
              ]),
            ],

            // ── Top vendors ──
            if (top.isNotEmpty) ...[
              _SectionHeader(ar ? 'أفضل التُّجار (الشهر)' : 'Top vendors (month)', icon: Icons.emoji_events),
              _breakdownCard([
                for (var i = 0; i < top.length; i++)
                  _BreakdownRow(
                    rank: i + 1,
                    label: '${top[i]['name'] ?? ''}',
                    value: _money(top[i]['gmv'] as Map?)),
              ]),
            ],
          ]),
        );
      }),
    );
  }

  Widget _heroChip(IconData ic, String k, String v) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(10)),
    child: Row(children: [
      Icon(ic, size: 14, color: Colors.white70),
      const SizedBox(width: 6),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(k, style: const TextStyle(color: Colors.white60, fontSize: 9.5, fontWeight: FontWeight.w700)),
        Text(v, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w900),
          maxLines: 1, overflow: TextOverflow.ellipsis),
      ])),
    ]),
  ));

  Widget _stat(String v, String k, IconData ic, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
      border: Border.all(color: UC.border)),
    child: Row(children: [
      Container(width: 34, height: 34,
        decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(9)),
        child: Icon(ic, color: c, size: 18)),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(v, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 19, color: _adminDk, height: 1)),
        Text(k, style: UT.small, maxLines: 1, overflow: TextOverflow.ellipsis),
      ])),
    ]));

  Widget _actionCard(BuildContext c, IconData ic, Color accent, Color tint,
      String title, String desc, Widget screen, {int badge = 0, Color badgeColor = UC.dangerDk}) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Material(color: Colors.white, borderRadius: BorderRadius.circular(14),
      child: InkWell(borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => screen)),
        child: Container(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14),
            border: Border.all(color: UC.border)),
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Container(width: 44, height: 44,
              decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(12)),
              child: Icon(ic, color: accent, size: 22)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: UC.ink)),
              const SizedBox(height: 2),
              Text(desc, style: UT.small, maxLines: 1, overflow: TextOverflow.ellipsis),
            ])),
            if (badge > 0) ...[
              UPill(text: '$badge', bg: badgeColor.withValues(alpha: 0.12), fg: badgeColor),
              const SizedBox(width: 6),
            ],
            const Icon(Icons.chevron_right, color: UC.muted),
          ]),
        ))),
  );

  Widget _exportCard(BuildContext c, IconData ic, String title, String sub, String url, String fname) =>
    Material(color: Colors.white, borderRadius: BorderRadius.circular(14),
      child: InkWell(borderRadius: BorderRadius.circular(14),
        onTap: () => downloadAndShare(c, url, fname),
        child: Container(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14),
            border: Border.all(color: UC.border)),
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 36, height: 36,
              decoration: BoxDecoration(color: UC.successBg, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.table_view, color: UC.successDk, size: 19)),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5, color: UC.ink)),
            Text(sub, style: UT.tiny, maxLines: 1, overflow: TextOverflow.ellipsis),
          ]),
        )));

  Widget _breakdownCard(List<Widget> rows) => Container(
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
      border: Border.all(color: UC.border)),
    child: Column(children: [
      for (var i = 0; i < rows.length; i++) ...[
        if (i > 0) const Divider(height: 1, indent: 12, endIndent: 12),
        rows[i],
      ],
    ]));
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({required this.label, required this.value, this.rank});
  final String label, value;
  final int? rank;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
    child: Row(children: [
      if (rank != null) ...[
        Container(width: 22, height: 22, alignment: Alignment.center,
          decoration: BoxDecoration(
            color: rank! <= 3 ? UC.yellowFaint : UC.bg, borderRadius: BorderRadius.circular(7)),
          child: Text('$rank', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900,
            color: rank! <= 3 ? UC.brown : UC.muted))),
        const SizedBox(width: 10),
      ],
      Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        maxLines: 1, overflow: TextOverflow.ellipsis)),
      const SizedBox(width: 8),
      Text(value, style: const TextStyle(fontWeight: FontWeight.w900, color: _admin, fontSize: 13)),
    ]));
}

// ════════════════════════════ ORDERS ════════════════════════════
class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({super.key});
  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> {
  String _state = '';
  String _query = '';
  late Future<Map<String, dynamic>> _f;
  @override
  void initState() { super.initState(); _f = VendorApi.instance.adminOrders(); }
  void _reload() => setState(() => _f = VendorApi.instance.adminOrders(state: _state));

  ({Color bg, Color fg, String label}) _stateStyle(String? raw, bool ar) {
    final s = (raw ?? '').toLowerCase();
    if (s.contains('cancel')) return (bg: UC.dangerBg, fg: UC.dangerDk, label: ar ? 'ملغي' : 'Cancelled');
    if (s.contains('done') || s.contains('complete') || s.contains('sale')) {
      return (bg: UC.successBg, fg: UC.successDk, label: ar ? 'مكتمل' : 'Done');
    }
    if (s.contains('process')) return (bg: UC.warnBg, fg: UC.warn, label: ar ? 'تجهيز' : 'Processing');
    if (s.contains('new') || s.contains('draft')) return (bg: UC.infoBg, fg: UC.info, label: ar ? 'جديد' : 'New');
    return (bg: UC.bg, fg: UC.muted, label: raw ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final ar = VendorApi.instance.lang == 'ar';
    final filters = {'': ar ? 'الكل' : 'All', 'new': ar ? 'جديد' : 'New',
      'processing': ar ? 'تجهيز' : 'Processing', 'completed': ar ? 'مكتمل' : 'Done',
      'cancelled': ar ? 'ملغي' : 'Cancelled'};
    return Scaffold(
      appBar: AppBar(backgroundColor: _admin, foregroundColor: Colors.white,
        title: Text(ar ? 'كل الطلبات' : 'All orders')),
      body: Column(children: [
        // search
        Padding(padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          child: TextField(
            onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            decoration: InputDecoration(
              hintText: ar ? 'بحث بالرقم أو التاجر أو العميل' : 'Search order / vendor / customer',
              prefixIcon: const Icon(Icons.search, size: 20),
              contentPadding: const EdgeInsets.symmetric(vertical: 0)))),
        // filter chips
        SingleChildScrollView(scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(children: filters.entries.map((e) => Padding(
            padding: const EdgeInsetsDirectional.only(end: 6),
            child: ChoiceChip(label: Text(e.value), selected: _state == e.key,
              selectedColor: _adminFaint,
              labelStyle: TextStyle(fontWeight: FontWeight.w800,
                color: _state == e.key ? _admin : UC.text, fontSize: 12),
              side: BorderSide(color: _state == e.key ? _admin : UC.border),
              onSelected: (_) { setState(() => _state = e.key); _reload(); }))).toList())),
        Expanded(child: FutureBuilder<Map<String, dynamic>>(future: _f, builder: (_, s) {
          if (s.connectionState != ConnectionState.done) return const USpinner();
          if (s.hasError) return Center(child: Text('${s.error}'));
          final allRows = (s.data?['data'] as List?) ?? const [];
          final total = (s.data?['meta'] as Map?)?['total'] ?? allRows.length;
          final rows = _query.isEmpty ? allRows : allRows.where((o) {
            final hay = '${o['name'] ?? ''} ${o['vendor'] ?? ''} ${o['customer'] ?? ''}'.toLowerCase();
            return hay.contains(_query);
          }).toList();
          if (allRows.isEmpty) {
            return _emptyState(Icons.receipt_long, ar ? 'لا طلبات' : 'No orders',
              ar ? 'لم يتم العثور على طلبات بهذا الفلتر' : 'No orders match this filter');
          }
          if (rows.isEmpty) {
            return _emptyState(Icons.search_off, ar ? 'لا نتائج' : 'No results',
              ar ? 'جرّب كلمة بحث أخرى' : 'Try a different search');
          }
          return RefreshIndicator(color: _admin, onRefresh: () async => _reload(),
            child: ListView.builder(padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
              itemCount: rows.length + 1,
              itemBuilder: (_, i) {
                if (i == 0) {
                  return Padding(padding: const EdgeInsets.only(bottom: 8, left: 2),
                    child: Text('${ar ? "الإجمالي" : "Total"}: $total'
                      '${_query.isNotEmpty ? "  ·  ${ar ? "ظاهر" : "showing"} ${rows.length}" : ""}',
                      style: UT.small));
                }
                final o = rows[i - 1];
                final st = _stateStyle(o['state'] as String?, ar);
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: UC.border)),
                  padding: const EdgeInsets.all(12),
                  child: Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Flexible(child: Text('${o['name'] ?? ''}',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: UC.ink),
                          maxLines: 1, overflow: TextOverflow.ellipsis)),
                        if (st.label.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          UPill(text: st.label, bg: st.bg, fg: st.fg),
                        ],
                      ]),
                      const SizedBox(height: 3),
                      Text('${o['vendor'] ?? ''}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: UC.text),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text('${o['customer'] ?? ''} · ${o['when']?.toString().split('T').first ?? ''}',
                        style: UT.small, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ])),
                    const SizedBox(width: 8),
                    Text(_money(o['amount'] as Map?),
                      style: const TextStyle(fontWeight: FontWeight.w900, color: _adminDk, fontSize: 14)),
                  ]),
                );
              }));
        })),
      ]),
    );
  }
}

// ════════════════════════════ VENDORS ════════════════════════════
class AdminVendorsScreen extends StatefulWidget {
  const AdminVendorsScreen({super.key});
  @override
  State<AdminVendorsScreen> createState() => _AdminVendorsScreenState();
}

class _AdminVendorsScreenState extends State<AdminVendorsScreen> {
  late Future<List<Map<String, dynamic>>> _f;
  String _query = '';
  @override
  void initState() { super.initState(); _f = VendorApi.instance.adminVendors(); }

  @override
  Widget build(BuildContext context) {
    final ar = VendorApi.instance.lang == 'ar';
    return Scaffold(
      appBar: AppBar(backgroundColor: _admin, foregroundColor: Colors.white,
        title: Text(ar ? 'إدارة التُّجار' : 'Vendors')),
      body: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: TextField(
            onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            decoration: InputDecoration(
              hintText: ar ? 'بحث عن تاجر' : 'Search vendor',
              prefixIcon: const Icon(Icons.search, size: 20),
              contentPadding: const EdgeInsets.symmetric(vertical: 0)))),
        Expanded(child: FutureBuilder<List<Map<String, dynamic>>>(future: _f, builder: (_, s) {
          if (s.connectionState != ConnectionState.done) return const USpinner();
          if (s.hasError) return Center(child: Text('${s.error}'));
          final all = s.data ?? [];
          final rows = _query.isEmpty ? all : all.where((v) =>
            '${v['display_name'] ?? ''}'.toLowerCase().contains(_query)).toList();
          if (all.isEmpty) {
            return _emptyState(Icons.storefront, ar ? 'لا تُّجار' : 'No vendors',
              ar ? 'لم يُسجَّل أي تاجر بعد' : 'No vendors registered yet');
          }
          if (rows.isEmpty) {
            return _emptyState(Icons.search_off, ar ? 'لا نتائج' : 'No results',
              ar ? 'جرّب اسماً آخر' : 'Try a different name');
          }
          return RefreshIndicator(color: _admin,
            onRefresh: () async => setState(() => _f = VendorApi.instance.adminVendors()),
            child: ListView.builder(padding: const EdgeInsets.fromLTRB(12, 2, 12, 20),
              itemCount: rows.length,
              itemBuilder: (c, i) {
                final v = rows[i];
                final active = '${v['state']}'.toLowerCase().contains('active') ||
                  '${v['state']}'.toLowerCase().contains('approved');
                final score = (v['score'] ?? 0);
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: UC.border)),
                  child: Material(color: Colors.transparent,
                    child: InkWell(borderRadius: BorderRadius.circular(12),
                      onTap: () => Navigator.push(c, MaterialPageRoute(
                        builder: (_) => AdminVendorSettingsScreen(vendorId: v['id'] as int,
                          name: '${v['display_name'] ?? ''}'))),
                      child: Padding(padding: const EdgeInsets.all(12),
                        child: Row(children: [
                          CircleAvatar(radius: 20, backgroundColor: _adminFaint,
                            child: Text(
                              '${v['display_name'] ?? '?'}'.trim().isEmpty ? '?'
                                : '${v['display_name']}'.trim()[0].toUpperCase(),
                              style: const TextStyle(color: _admin, fontWeight: FontWeight.w900))),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('${v['display_name'] ?? ''}',
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5, color: UC.ink),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 5),
                            Wrap(spacing: 5, runSpacing: 5, children: [
                              UPill(text: '${v['vendor_type'] ?? ''}', bg: _adminFaint, fg: _admin),
                              UPill(
                                text: active ? (ar ? 'نشط' : 'Active') : '${v['state'] ?? ''}',
                                bg: active ? UC.successBg : UC.bg,
                                fg: active ? UC.successDk : UC.muted,
                                live: active),
                              UPill(icon: Icons.inventory_2_outlined,
                                text: '${v['product_total'] ?? 0}', bg: UC.bg, fg: UC.muted),
                              UPill(icon: Icons.star, text: '$score', bg: UC.warnBg, fg: UC.warn),
                            ]),
                          ])),
                          const Icon(Icons.tune, color: _admin, size: 20),
                        ]),
                      ))),
                );
              }));
        })),
      ]),
    );
  }
}

// ════════════════════════ VENDOR SETTINGS ════════════════════════
class AdminVendorSettingsScreen extends StatefulWidget {
  const AdminVendorSettingsScreen({super.key, required this.vendorId, required this.name});
  final int vendorId;
  final String name;
  @override
  State<AdminVendorSettingsScreen> createState() => _AdminVendorSettingsScreenState();
}

class _AdminVendorSettingsScreenState extends State<AdminVendorSettingsScreen> {
  Map<String, dynamic>? _settings;
  bool _loading = true, _saving = false;
  final _capKeys = const ['add_products','edit_products','archive_products','update_stock',
    'publish_products','manage_price','flash_sale','bundles','join_promotions',
    'import_products','manage_orders','cancel_orders','restock','edit_store','request_payout'];
  final _types = const ['fbu','seller','dropshipper','hybrid','consignment'];
  final _settle = const ['wallet','per_order','none'];

  static const _capIcons = <String, IconData>{
    'add_products': Icons.add_box, 'edit_products': Icons.edit,
    'archive_products': Icons.archive, 'update_stock': Icons.inventory,
    'publish_products': Icons.publish, 'manage_price': Icons.sell,
    'flash_sale': Icons.bolt, 'bundles': Icons.widgets,
    'join_promotions': Icons.campaign, 'import_products': Icons.upload_file,
    'manage_orders': Icons.receipt_long, 'cancel_orders': Icons.cancel,
    'restock': Icons.refresh, 'edit_store': Icons.storefront,
    'request_payout': Icons.payments,
  };

  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try {
      final d = await VendorApi.instance.adminVendor(widget.vendorId);
      setState(() { _settings = (d['settings'] as Map).cast<String, dynamic>(); _loading = false; });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final s = _settings!;
    try {
      await VendorApi.instance.adminSaveVendorSettings(widget.vendorId, {
        'vendor_type': s['vendor_type'],
        'settlement_mode': s['settlement_mode'],
        'hide_financials': s['hide_financials'],
        'vendor_sees_customer': s['vendor_sees_customer'],
        'caps': s['caps'],
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(VendorApi.instance.lang == 'ar' ? 'تم الحفظ' : 'Saved')));
      Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally { if (mounted) setState(() => _saving = false); }
  }

  Future<void> _applyPreset() async {
    setState(() => _saving = true);
    try {
      final d = await VendorApi.instance.adminSaveVendorSettings(widget.vendorId,
        {'vendor_type': _settings!['vendor_type'], 'apply_preset': true});
      setState(() {
        _settings!['caps'] = (d['caps'] as Map).cast<String, dynamic>();
        _settings!['settlement_mode'] = d['settlement_mode'];
        _settings!['hide_financials'] = d['hide_financials'];
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(VendorApi.instance.lang == 'ar' ? 'تم تطبيق إعدادات النوع' : 'Type preset applied')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally { if (mounted) setState(() => _saving = false); }
  }

  Widget _block({required String title, IconData? icon, required List<Widget> children}) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
      border: Border.all(color: UC.border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
        child: Row(children: [
          if (icon != null) ...[Icon(icon, size: 16, color: _admin), const SizedBox(width: 6)],
          Text(title, style: UT.h3),
        ])),
      ...children,
      const SizedBox(height: 6),
    ]));

  @override
  Widget build(BuildContext context) {
    final ar = VendorApi.instance.lang == 'ar';
    final capsEnabled = _settings == null ? 0
      : _capKeys.where((c) => (_settings!['caps'] as Map)[c] == true).length;
    return Scaffold(
      appBar: AppBar(backgroundColor: _admin, foregroundColor: Colors.white,
        title: Text(widget.name, overflow: TextOverflow.ellipsis)),
      body: _loading ? const USpinner()
        : _settings == null
          ? _emptyState(Icons.error_outline, ar ? 'تعذّر التحميل' : 'Failed to load',
              ar ? 'حاول مرة أخرى' : 'Please try again')
          : ListView(padding: const EdgeInsets.all(12), children: [
              _block(title: ar ? 'النوع والتسوية' : 'Type & settlement', icon: Icons.category, children: [
                Padding(padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(ar ? 'نوع التاجر' : 'Vendor type', style: UT.small),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      value: _types.contains(_settings!['vendor_type']) ? _settings!['vendor_type'] : 'seller',
                      items: _types.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                      onChanged: (v) => setState(() => _settings!['vendor_type'] = v)),
                    Align(alignment: AlignmentDirectional.centerEnd, child: TextButton.icon(
                      style: TextButton.styleFrom(foregroundColor: _admin),
                      onPressed: _saving ? null : _applyPreset,
                      icon: const Icon(Icons.auto_fix_high, size: 16),
                      label: Text(ar ? 'تطبيق إعدادات النوع' : 'Apply type preset'))),
                    Text(ar ? 'وضع التسوية' : 'Settlement', style: UT.small),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      value: _settle.contains(_settings!['settlement_mode']) ? _settings!['settlement_mode'] : 'wallet',
                      items: _settle.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                      onChanged: (v) => setState(() => _settings!['settlement_mode'] = v)),
                  ])),
              ]),
              _block(title: ar ? 'الخصوصية' : 'Privacy', icon: Icons.visibility, children: [
                SwitchListTile(dense: true, activeColor: _admin,
                  secondary: const Icon(Icons.visibility_off, color: UC.muted),
                  title: Text(ar ? 'إخفاء البيانات المالية' : 'Hide financials',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  value: _settings!['hide_financials'] == true,
                  onChanged: (v) => setState(() => _settings!['hide_financials'] = v)),
                SwitchListTile(dense: true, activeColor: _admin,
                  secondary: const Icon(Icons.person_outline, color: UC.muted),
                  title: Text(ar ? 'يرى بيانات العميل' : 'Sees customer data',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  value: _settings!['vendor_sees_customer'] == true,
                  onChanged: (v) => setState(() => _settings!['vendor_sees_customer'] = v)),
              ]),
              _block(title: ar ? 'الصلاحيات' : 'Capabilities', icon: Icons.lock_open, children: [
                Padding(padding: const EdgeInsets.only(left: 14, bottom: 4),
                  child: UPill(text: '$capsEnabled / ${_capKeys.length} ${ar ? "مُفعّل" : "enabled"}',
                    bg: _adminFaint, fg: _admin)),
                for (final c in _capKeys)
                  SwitchListTile(dense: true, activeColor: _admin,
                    secondary: Icon(_capIcons[c] ?? Icons.toggle_on, color: UC.muted, size: 20),
                    title: Text(c.replaceAll('_', ' '),
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    value: (_settings!['caps'] as Map)[c] == true,
                    onChanged: (v) => setState(() => (_settings!['caps'] as Map)[c] = v)),
              ]),
              const SizedBox(height: 4),
              FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: _admin,
                  minimumSize: const Size.fromHeight(48)),
                onPressed: _saving ? null : _save,
                icon: _saving
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.save, size: 18),
                label: Text(_saving ? (ar ? 'جارٍ الحفظ...' : 'Saving...') : (ar ? 'حفظ التغييرات' : 'Save changes'))),
              const SizedBox(height: 24),
            ]),
    );
  }
}

// ════════════════════════════ APPROVALS ════════════════════════════
class AdminApprovalsScreen extends StatefulWidget {
  const AdminApprovalsScreen({super.key});
  @override
  State<AdminApprovalsScreen> createState() => _AdminApprovalsScreenState();
}

class _AdminApprovalsScreenState extends State<AdminApprovalsScreen> {
  late Future<Map<String, dynamic>> _f;
  @override
  void initState() { super.initState(); _f = VendorApi.instance.adminApprovals(); }
  void _reload() => setState(() => _f = VendorApi.instance.adminApprovals());

  Future<void> _decideChange(int id, String d) async {
    try { await VendorApi.instance.adminDecideChange(id, d); _reload(); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
  }
  Future<void> _decideProduct(int id, String d) async {
    try { await VendorApi.instance.adminDecideProduct(id, d); _reload(); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
  }
  Future<void> _decidePriceLine(int id, String d) async {
    try { await VendorApi.instance.adminPriceLineDecide(id, d); _reload(); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
  }
  Future<void> _approveAllPrices(int reqId) async {
    try { await VendorApi.instance.adminPriceApproveAll(reqId); _reload(); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
  }

  @override
  Widget build(BuildContext context) {
    final ar = VendorApi.instance.lang == 'ar';
    return Scaffold(
      appBar: AppBar(backgroundColor: _admin, foregroundColor: Colors.white,
        title: Text(ar ? 'طابور الاعتماد' : 'Approvals')),
      body: FutureBuilder<Map<String, dynamic>>(future: _f, builder: (_, s) {
        if (s.connectionState != ConnectionState.done) return const USpinner();
        if (s.hasError) return Center(child: Text('${s.error}'));
        final d = s.data ?? const {};
        final changes = (d['changes'] as List?) ?? const [];
        final newp = (d['new_products'] as List?) ?? const [];
        final prices = (d['price_requests'] as List?) ?? const [];
        if (changes.isEmpty && newp.isEmpty && prices.isEmpty) {
          return RefreshIndicator(color: _admin, onRefresh: () async => _reload(),
            child: ListView(children: [
              SizedBox(height: MediaQuery.of(context).size.height * 0.25),
              _emptyState(Icons.task_alt, ar ? 'لا شيء بانتظار الموافقة' : 'All caught up',
                ar ? 'لا توجد عناصر تنتظر مراجعتك' : 'Nothing is pending review'),
            ]));
        }
        return RefreshIndicator(color: _admin, onRefresh: () async => _reload(),
          child: ListView(padding: const EdgeInsets.fromLTRB(12, 4, 12, 24), children: [
            if (prices.isNotEmpty)
              _queueHeader(ar ? 'أسعار بانتظار الاعتماد' : 'Price approvals', Icons.sell, prices.length, UC.warn),
            for (final r in prices) _priceCard(r as Map<String, dynamic>, ar),
            if (changes.isNotEmpty)
              _queueHeader(ar ? 'تعديلات' : 'Edits', Icons.edit_note, changes.length, _admin),
            for (final c in changes) _card(
              icon: Icons.edit_note, accent: _admin,
              title: '${c['product']}', subtitle: '${c['vendor']}',
              body: '${c['summary'] ?? ''}',
              onApprove: () => _decideChange(c['id'] as int, 'approve'),
              onReject: () => _decideChange(c['id'] as int, 'reject')),
            if (newp.isNotEmpty)
              _queueHeader(ar ? 'منتجات جديدة' : 'New products', Icons.add_box, newp.length, _approve),
            for (final p in newp) _card(
              icon: Icons.add_box, accent: _approve,
              title: '${(p['name'] is Map) ? (ar ? p['name']['ar'] : p['name']['en']) : p['name']}',
              subtitle: '${p['vendor']}',
              body: _money(p['list_price'] as Map?),
              onApprove: () => _decideProduct(p['id'] as int, 'approve'),
              onReject: () => _decideProduct(p['id'] as int, 'reject')),
          ]));
      }),
    );
  }

  Widget _queueHeader(String label, IconData icon, int count, Color c) => Padding(
    padding: const EdgeInsets.only(top: 10, bottom: 8),
    child: Row(children: [
      Icon(icon, size: 17, color: c),
      const SizedBox(width: 7),
      Text(label, style: UT.h2),
      const SizedBox(width: 8),
      UPill(text: '$count', bg: c.withValues(alpha: 0.12), fg: c),
    ]));

  Widget _priceCard(Map<String, dynamic> r, bool ar) {
    final lines = (r['lines'] as List?) ?? const [];
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: UC.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Row(children: [
            Container(width: 36, height: 36,
              decoration: BoxDecoration(color: UC.warnBg, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.sell, color: UC.warn, size: 19)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${r['name'] ?? ''}',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: UC.ink),
                maxLines: 1, overflow: TextOverflow.ellipsis),
              Text('${r['vendor'] ?? ''} · ${lines.length} ${ar ? "بند" : "lines"}',
                style: UT.small, maxLines: 1, overflow: TextOverflow.ellipsis),
            ])),
            FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: _approve,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
              onPressed: () => _approveAllPrices(r['id'] as int),
              icon: const Icon(Icons.done_all, size: 16),
              label: Text(ar ? 'اعتماد الكل' : 'Apply all',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900))),
          ])),
        Padding(padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          child: Column(children: [
            for (final l in lines) Container(
              margin: const EdgeInsets.only(bottom: 6), padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: UC.bg, borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${(l as Map)['product']}', maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: UC.ink)),
                  const SizedBox(height: 3),
                  Row(children: [
                    Text('${l['current_price']} → ${l['new_price']}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: UC.text)),
                    const SizedBox(width: 6),
                    UPill(text: '${l['delta_pct']}%',
                      bg: ((l['delta_pct'] ?? 0) as num) < 0 ? UC.dangerBg : UC.infoBg,
                      fg: ((l['delta_pct'] ?? 0) as num) < 0 ? UC.dangerDk : UC.info),
                    const SizedBox(width: 4),
                    UPill(text: '${ar ? "هامش" : "m"} ${l['margin_after']}%',
                      bg: ((l['margin_after'] ?? 0) as num) < 0 ? UC.dangerBg : UC.successBg,
                      fg: ((l['margin_after'] ?? 0) as num) < 0 ? UC.dangerDk : UC.successDk),
                  ]),
                ])),
                IconButton(visualDensity: VisualDensity.compact,
                  tooltip: ar ? 'اعتماد' : 'Approve',
                  icon: const Icon(Icons.check_circle, color: _approve, size: 24),
                  onPressed: () => _decidePriceLine(l['id'] as int, 'approve')),
                IconButton(visualDensity: VisualDensity.compact,
                  tooltip: ar ? 'رفض' : 'Reject',
                  icon: const Icon(Icons.cancel, color: UC.dangerDk, size: 24),
                  onPressed: () => _decidePriceLine(l['id'] as int, 'reject')),
              ])),
          ])),
      ]));
  }

  Widget _card({required IconData icon, required Color accent, required String title,
      required String subtitle, required String body,
      required VoidCallback onApprove, required VoidCallback onReject}) {
    final ar = VendorApi.instance.lang == 'ar';
    return Container(
      margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: UC.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 36, height: 36,
            decoration: BoxDecoration(color: accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: accent, size: 19)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: UC.ink),
              maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(subtitle, style: UT.small, maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
        ]),
        if (body.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(width: double.infinity, padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: UC.bg, borderRadius: BorderRadius.circular(8)),
            child: Text(body, style: UT.body)),
        ],
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: _approve),
            onPressed: onApprove, icon: const Icon(Icons.check, size: 16),
            label: Text(ar ? 'اعتماد' : 'Approve'))),
          const SizedBox(width: 8),
          Expanded(child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: UC.dangerDk,
              side: const BorderSide(color: UC.dangerBg, width: 1.5)),
            onPressed: onReject, icon: const Icon(Icons.close, size: 16),
            label: Text(ar ? 'رفض' : 'Reject'))),
        ]),
      ]));
  }
}

// ════════════════════════════ shared empty state ════════════════════════════
Widget _emptyState(IconData icon, String title, String sub) => Center(
  child: Padding(padding: const EdgeInsets.all(28),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 64, height: 64,
        decoration: BoxDecoration(color: UC.bg, shape: BoxShape.circle),
        child: Icon(icon, size: 30, color: UC.muted)),
      const SizedBox(height: 14),
      Text(title, style: UT.h2, textAlign: TextAlign.center),
      const SizedBox(height: 4),
      Text(sub, style: UT.small, textAlign: TextAlign.center),
    ])));
