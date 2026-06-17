import 'package:flutter/material.dart';
import '../../api/api.dart';
import '../../theme/theme.dart';
import '../reports_screen.dart' show downloadAndShare;

const Color _admin = Color(0xFF2563EB);
const Color _adminDk = Color(0xFF0F1F3A);

String _money(Map? m) {
  if (m == null) return '0';
  final a = (m['amount'] ?? 0);
  final s = (m['symbol'] ?? 'KD');
  return '$a $s';
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
          IconButton(icon: const Icon(Icons.logout), onPressed: () async {
            await VendorApi.instance.logout();
            if (context.mounted) Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
          }),
        ]),
      body: FutureBuilder<Map<String, dynamic>>(future: _f, builder: (_, s) {
        if (s.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (s.hasError) return Center(child: Padding(padding: const EdgeInsets.all(20), child: Text('${s.error}')));
        final d = s.data ?? const {};
        final gmv = (d['gmv'] as Map?) ?? const {};
        final ord = (d['orders'] as Map?) ?? const {};
        final ven = (d['vendors'] as Map?) ?? const {};
        final app = (d['approvals'] as Map?) ?? const {};
        final top = (d['top_vendors'] as List?) ?? const [];
        final byType = (d['by_type'] as List?) ?? const [];
        return RefreshIndicator(
          onRefresh: () async => setState(() => _f = VendorApi.instance.adminDashboard()),
          child: ListView(padding: const EdgeInsets.all(12), children: [
            Container(padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(gradient: const LinearGradient(colors: [_adminDk, _admin]),
                borderRadius: BorderRadius.circular(16)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(ar ? 'مبيعات السوق — الشهر' : 'Marketplace GMV — month',
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
                Text(_money(gmv['month'] as Map?), style: const TextStyle(
                  color: Color(0xFFFFE066), fontSize: 26, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text('${ar ? "اليوم" : "Today"}: ${_money(gmv['today'] as Map?)}  ·  '
                     '${ar ? "الأسبوع" : "Week"}: ${_money(gmv['week'] as Map?)}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ])),
            const SizedBox(height: 10),
            GridView.count(crossAxisCount: 2, shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 2.4, mainAxisSpacing: 8, crossAxisSpacing: 8, children: [
              _stat('${ven['active'] ?? 0}', ar ? 'تاجر نشط' : 'Active vendors'),
              _stat('${ord['new'] ?? 0}', ar ? 'طلبات جديدة' : 'New orders'),
              _stat('${ord['processing'] ?? 0}', ar ? 'قيد التجهيز' : 'Processing'),
              _stat('${(app['products'] ?? 0) + (app['edits'] ?? 0)}', ar ? 'بانتظار الموافقة' : 'Pending approvals'),
            ]),
            const SizedBox(height: 6),
            _navTile(context, Icons.receipt_long, ar ? 'كل الطلبات' : 'All orders', const AdminOrdersScreen()),
            _navTile(context, Icons.storefront, ar ? 'إدارة التُّجار' : 'Vendors', const AdminVendorsScreen()),
            _navTile(context, Icons.fact_check, ar ? 'طابور الاعتماد' : 'Approvals', const AdminApprovalsScreen(),
              badge: (app['products'] ?? 0) + (app['edits'] ?? 0)),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(child: OutlinedButton.icon(
                onPressed: () => downloadAndShare(context,
                  '/api/vendor/v1/admin/export/orders.xlsx', 'marketplace_orders.xlsx'),
                icon: const Icon(Icons.table_view, size: 16),
                label: Text(ar ? 'تصدير الطلبات' : 'Export orders'))),
              const SizedBox(width: 6),
              Expanded(child: OutlinedButton.icon(
                onPressed: () => downloadAndShare(context,
                  '/api/vendor/v1/admin/export/vendors.xlsx', 'vendors.xlsx'),
                icon: const Icon(Icons.table_view, size: 16),
                label: Text(ar ? 'تصدير التُّجار' : 'Export vendors'))),
            ]),
            const SizedBox(height: 10),
            if (byType.isNotEmpty) ...[
              Text(ar ? 'المبيعات حسب نوع التاجر (الشهر)' : 'GMV by vendor type (month)', style: UT.h2),
              const SizedBox(height: 6),
              for (final b in byType) Container(
                margin: const EdgeInsets.only(bottom: 6), padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: UC.border)),
                child: Row(children: [
                  Expanded(child: Text('${b['type'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700))),
                  Text(_money(b['gmv'] as Map?), style: const TextStyle(fontWeight: FontWeight.w900, color: _admin)),
                ])),
              const SizedBox(height: 10),
            ],
            if (top.isNotEmpty) ...[
              Text(ar ? 'أفضل التُّجار (الشهر)' : 'Top vendors (month)', style: UT.h2),
              const SizedBox(height: 6),
              for (final t in top) Container(
                margin: const EdgeInsets.only(bottom: 6), padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: UC.border)),
                child: Row(children: [
                  Expanded(child: Text('${t['name'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700))),
                  Text(_money(t['gmv'] as Map?), style: const TextStyle(fontWeight: FontWeight.w900, color: _admin)),
                ])),
            ],
          ]),
        );
      }),
    );
  }

  Widget _stat(String v, String k) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
      border: Border.all(color: UC.border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center,
      children: [Text(v, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: _adminDk)),
        Text(k, style: UT.small, maxLines: 1, overflow: TextOverflow.ellipsis)]));

  Widget _navTile(BuildContext c, IconData ic, String t, Widget screen, {int badge = 0}) => Card(
    elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12),
      side: const BorderSide(color: UC.border)),
    child: ListTile(
      leading: CircleAvatar(backgroundColor: const Color(0xFFEAF1FC),
        child: Icon(ic, color: _admin, size: 20)),
      title: Text(t, style: const TextStyle(fontWeight: FontWeight.w800)),
      trailing: badge > 0
        ? CircleAvatar(radius: 12, backgroundColor: UC.dangerDk,
            child: Text('$badge', style: const TextStyle(color: Colors.white, fontSize: 11)))
        : const Icon(Icons.chevron_right),
      onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => screen)),
    ));
}

// ════════════════════════════ ORDERS ════════════════════════════
class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({super.key});
  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> {
  String _state = '';
  late Future<Map<String, dynamic>> _f;
  @override
  void initState() { super.initState(); _f = VendorApi.instance.adminOrders(); }
  void _reload() => setState(() => _f = VendorApi.instance.adminOrders(state: _state));

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
        SingleChildScrollView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.all(8),
          child: Row(children: filters.entries.map((e) => Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(label: Text(e.value), selected: _state == e.key,
              selectedColor: const Color(0xFFEAF1FC),
              onSelected: (_) { setState(() => _state = e.key); _reload(); }))).toList())),
        Expanded(child: FutureBuilder<Map<String, dynamic>>(future: _f, builder: (_, s) {
          if (s.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (s.hasError) return Center(child: Text('${s.error}'));
          final rows = (s.data?['data'] as List?) ?? const [];
          final total = (s.data?['meta'] as Map?)?['total'] ?? rows.length;
          if (rows.isEmpty) return Center(child: Text(ar ? 'لا طلبات' : 'No orders'));
          return RefreshIndicator(onRefresh: () async => _reload(), child: ListView(children: [
            Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Text('${ar ? "الإجمالي" : "Total"}: $total', style: UT.small)),
            for (final o in rows) ListTile(
              title: Text('${o['name']} · ${o['vendor']}',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              subtitle: Text('${o['customer'] ?? ''} · ${o['when']?.toString().split('T').first ?? ''}',
                style: UT.small),
              trailing: Text(_money(o['amount'] as Map?),
                style: const TextStyle(fontWeight: FontWeight.w900, color: _adminDk)),
            ),
          ]));
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
  @override
  void initState() { super.initState(); _f = VendorApi.instance.adminVendors(); }

  @override
  Widget build(BuildContext context) {
    final ar = VendorApi.instance.lang == 'ar';
    return Scaffold(
      appBar: AppBar(backgroundColor: _admin, foregroundColor: Colors.white,
        title: Text(ar ? 'إدارة التُّجار' : 'Vendors')),
      body: FutureBuilder<List<Map<String, dynamic>>>(future: _f, builder: (_, s) {
        if (s.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (s.hasError) return Center(child: Text('${s.error}'));
        final rows = s.data ?? [];
        return RefreshIndicator(onRefresh: () async => setState(() => _f = VendorApi.instance.adminVendors()),
          child: ListView.separated(itemCount: rows.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (c, i) {
              final v = rows[i];
              return ListTile(
                title: Text('${v['display_name'] ?? ''}',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                subtitle: Text('${v['vendor_type']} · ${v['state']} · ${v['product_total']} ${ar ? "منتج" : "products"} · ⭐${v['score'] ?? 0}',
                  style: UT.small),
                trailing: const Icon(Icons.tune, color: _admin),
                onTap: () => Navigator.push(c, MaterialPageRoute(
                  builder: (_) => AdminVendorSettingsScreen(vendorId: v['id'] as int,
                    name: '${v['display_name'] ?? ''}'))),
              );
            }));
      }),
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
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally { if (mounted) setState(() => _saving = false); }
  }

  @override
  Widget build(BuildContext context) {
    final ar = VendorApi.instance.lang == 'ar';
    return Scaffold(
      appBar: AppBar(backgroundColor: _admin, foregroundColor: Colors.white,
        title: Text(widget.name, overflow: TextOverflow.ellipsis)),
      body: _loading ? const Center(child: CircularProgressIndicator())
        : _settings == null ? Center(child: Text(ar ? 'تعذّر التحميل' : 'Failed to load'))
        : ListView(padding: const EdgeInsets.all(12), children: [
            Text(ar ? 'نوع التاجر' : 'Vendor type', style: UT.small),
            DropdownButtonFormField<String>(
              value: _types.contains(_settings!['vendor_type']) ? _settings!['vendor_type'] : 'seller',
              items: _types.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
              onChanged: (v) => setState(() => _settings!['vendor_type'] = v)),
            Align(alignment: AlignmentDirectional.centerEnd, child: TextButton.icon(
              onPressed: _saving ? null : _applyPreset, icon: const Icon(Icons.auto_fix_high, size: 16),
              label: Text(ar ? 'تطبيق إعدادات النوع' : 'Apply type preset'))),
            const SizedBox(height: 6),
            Text(ar ? 'وضع التسوية' : 'Settlement', style: UT.small),
            DropdownButtonFormField<String>(
              value: _settle.contains(_settings!['settlement_mode']) ? _settings!['settlement_mode'] : 'wallet',
              items: _settle.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
              onChanged: (v) => setState(() => _settings!['settlement_mode'] = v)),
            SwitchListTile(dense: true, activeColor: _admin,
              title: Text(ar ? 'إخفاء البيانات المالية' : 'Hide financials'),
              value: _settings!['hide_financials'] == true,
              onChanged: (v) => setState(() => _settings!['hide_financials'] = v)),
            SwitchListTile(dense: true, activeColor: _admin,
              title: Text(ar ? 'يرى بيانات العميل' : 'Sees customer data'),
              value: _settings!['vendor_sees_customer'] == true,
              onChanged: (v) => setState(() => _settings!['vendor_sees_customer'] = v)),
            const Divider(),
            Text(ar ? 'الصلاحيات' : 'Capabilities', style: UT.h2),
            for (final c in _capKeys)
              SwitchListTile(dense: true, activeColor: _admin,
                title: Text(c.replaceAll('_', ' ')),
                value: (_settings!['caps'] as Map)[c] == true,
                onChanged: (v) => setState(() => (_settings!['caps'] as Map)[c] = v)),
            const SizedBox(height: 12),
            FilledButton(style: FilledButton.styleFrom(backgroundColor: _admin),
              onPressed: _saving ? null : _save,
              child: Text(_saving ? '...' : (ar ? 'حفظ' : 'Save'))),
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

  @override
  Widget build(BuildContext context) {
    final ar = VendorApi.instance.lang == 'ar';
    return Scaffold(
      appBar: AppBar(backgroundColor: _admin, foregroundColor: Colors.white,
        title: Text(ar ? 'طابور الاعتماد' : 'Approvals')),
      body: FutureBuilder<Map<String, dynamic>>(future: _f, builder: (_, s) {
        if (s.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (s.hasError) return Center(child: Text('${s.error}'));
        final d = s.data ?? const {};
        final changes = (d['changes'] as List?) ?? const [];
        final newp = (d['new_products'] as List?) ?? const [];
        if (changes.isEmpty && newp.isEmpty) {
          return Center(child: Text(ar ? 'لا شيء بانتظار الموافقة' : 'Nothing pending'));
        }
        return RefreshIndicator(onRefresh: () async => _reload(),
          child: ListView(padding: const EdgeInsets.all(12), children: [
            if (changes.isNotEmpty) Text(ar ? 'تعديلات' : 'Edits', style: UT.h2),
            for (final c in changes) _card(
              title: '${c['product']} · ${c['vendor']}',
              body: '${c['summary'] ?? ''}',
              onApprove: () => _decideChange(c['id'] as int, 'approve'),
              onReject: () => _decideChange(c['id'] as int, 'reject')),
            if (newp.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10),
              child: Text(ar ? 'منتجات جديدة' : 'New products', style: UT.h2)),
            for (final p in newp) _card(
              title: '${(p['name'] is Map) ? (ar ? p['name']['ar'] : p['name']['en']) : p['name']} · ${p['vendor']}',
              body: _money(p['list_price'] as Map?),
              onApprove: () => _decideProduct(p['id'] as int, 'approve'),
              onReject: () => _decideProduct(p['id'] as int, 'reject')),
          ]));
      }),
    );
  }

  Widget _card({required String title, required String body,
      required VoidCallback onApprove, required VoidCallback onReject}) => Container(
    margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
      border: Border.all(color: UC.border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
      const SizedBox(height: 4),
      Text(body, style: UT.small),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: FilledButton(style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1f9d55)),
          onPressed: onApprove, child: Text(VendorApi.instance.lang == 'ar' ? 'اعتماد' : 'Approve'))),
        const SizedBox(width: 6),
        Expanded(child: OutlinedButton(
          style: OutlinedButton.styleFrom(foregroundColor: UC.dangerDk),
          onPressed: onReject, child: Text(VendorApi.instance.lang == 'ar' ? 'رفض' : 'Reject'))),
      ]),
    ]));
}
