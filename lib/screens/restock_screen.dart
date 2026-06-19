import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api/api.dart';
import '../theme/theme.dart';

/// Restock requests — list + openable detail (PO, prices, dates, receipt,
/// handover note). Creation happens from the product detail screen.
class RestockScreen extends StatefulWidget {
  const RestockScreen({super.key});
  @override
  State<RestockScreen> createState() => _RestockScreenState();
}

class _RestockScreenState extends State<RestockScreen> {
  late Future<List<Map<String, dynamic>>> _future;
  bool get _ar => VendorApi.instance.lang == 'ar';

  @override
  void initState() { super.initState(); _future = VendorApi.instance.restockList(); }
  void _reload() => setState(() => _future = VendorApi.instance.restockList());

  String _bl(dynamic v) => v is Map ? (_ar ? (v['ar'] ?? v['en']) : (v['en'] ?? v['ar']) ?? '').toString() : '${v ?? ''}';
  Color _stateColor(String s) => {
    'received': UC.successDk, 'rejected': UC.dangerDk, 'cancelled': UC.muted,
    'approved': UC.warn, 'submitted': UC.info}[s] ?? UC.muted;

  @override
  Widget build(BuildContext context) {
    final ar = _ar;
    return Scaffold(
      backgroundColor: UC.bg,
      appBar: AppBar(title: Text(ar ? 'طلبات التعبئة' : 'Restock requests')),
      body: RefreshIndicator(onRefresh: () async => _reload(),
        child: FutureBuilder<List<Map<String, dynamic>>>(future: _future, builder: (c, s) {
          if (s.connectionState != ConnectionState.done) return const Center(child: USpinner());
          if (s.hasError) return ListView(children: [Padding(padding: const EdgeInsets.all(24), child: Text('${s.error}', textAlign: TextAlign.center))]);
          final items = s.data ?? [];
          if (items.isEmpty) {
            return ListView(children: [Padding(padding: const EdgeInsets.all(40),
              child: Column(children: [
                const Icon(Icons.inventory_outlined, size: 44, color: UC.muted),
                const SizedBox(height: 10),
                Text(ar ? 'لا طلبات تعبئة بعد' : 'No restock requests yet', style: UT.body),
              ]))]);
          }
          return ListView(padding: const EdgeInsets.fromLTRB(12, 12, 12, 24), children: [
            for (final r in items) _card(r, ar),
          ]);
        })),
    );
  }

  Widget _card(Map<String, dynamic> r, bool ar) {
    final st = '${r['state']}';
    final lines = (r['lines'] as List?) ?? const [];
    return Container(margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: UC.border)),
      child: InkWell(borderRadius: BorderRadius.circular(12),
        onTap: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => RestockDetailScreen(id: r['id'] as int)));
          _reload();
        },
        child: Padding(padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('${r['name'] ?? r['id']}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
              const Spacer(),
              UPill(text: _bl(r['state_label']).isNotEmpty ? _bl(r['state_label']) : st,
                bg: _stateColor(st).withValues(alpha: .14), fg: _stateColor(st)),
            ]),
            const SizedBox(height: 6),
            Row(children: [
              if ((r['po_name'] ?? '').toString().isNotEmpty)
                UPill(text: '${ar ? "أمر شراء" : "PO"} ${r['po_name']}', bg: UC.yellowFaint, fg: UC.brown),
              if (r['po_total'] is Map) ...[
                const SizedBox(width: 6),
                UPill(text: '${(r['po_total'] as Map)['amount']} ${(r['po_total'] as Map)['symbol']}', bg: UC.bg, fg: UC.muted),
              ],
            ]),
            const SizedBox(height: 6),
            if (r['expected_date'] != null && r['expected_date'] != false)
              Text('${ar ? "التسليم المتوقع" : "Expected"}: ${r['expected_date']}', style: UT.small),
            const SizedBox(height: 4),
            for (final l in lines.take(3))
              Text('• ${l['product']}  ×${l['qty']}', style: UT.small, maxLines: 1, overflow: TextOverflow.ellipsis),
            if (lines.length > 3) Text('+${lines.length - 3} ${ar ? "أخرى" : "more"}', style: UT.tiny),
            const Align(alignment: AlignmentDirectional.centerEnd, child: Icon(Icons.chevron_right, color: UC.muted, size: 18)),
          ]))));
  }
}

// ─────────────── Restock detail ───────────────
class RestockDetailScreen extends StatefulWidget {
  final int id;
  const RestockDetailScreen({super.key, required this.id});
  @override
  State<RestockDetailScreen> createState() => _RestockDetailScreenState();
}

class _RestockDetailScreenState extends State<RestockDetailScreen> {
  Map<String, dynamic>? _r;
  bool _loading = true, _busy = false;
  bool get _ar => VendorApi.instance.lang == 'ar';
  String _bl(dynamic v) => v is Map ? (_ar ? (v['ar'] ?? v['en']) : (v['en'] ?? v['ar']) ?? '').toString() : '${v ?? ''}';

  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try {
      final r = await VendorApi.instance.restockDetail(widget.id);
      if (!mounted) return;
      setState(() { _r = r; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _handover() async {
    setState(() => _busy = true);
    try {
      final url = await VendorApi.instance.restockHandoverUrl(widget.id);
      if (url.isEmpty) throw Exception(_ar ? 'غير متاح' : 'Not available');
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally { if (mounted) setState(() => _busy = false); }
  }

  @override
  Widget build(BuildContext context) {
    final ar = _ar;
    final r = _r;
    final lines = ((r?['lines'] as List?) ?? const []).cast<Map>().map((e) => e.cast<String, dynamic>()).toList();
    final received = r?['state'] == 'received';
    return Scaffold(
      backgroundColor: UC.bg,
      appBar: AppBar(title: Text(r?['name']?.toString() ?? (ar ? 'طلب تعبئة' : 'Restock'))),
      body: _loading ? const Center(child: USpinner()) : r == null
        ? Center(child: Text(ar ? 'غير موجود' : 'Not found'))
        : ListView(padding: const EdgeInsets.all(14), children: [
            Container(padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: UC.border)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(_bl(r['state_label']), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15))),
                  if ((r['po_name'] ?? '').toString().isNotEmpty)
                    UPill(text: '${ar ? "أمر شراء" : "PO"} ${r['po_name']}', bg: UC.yellowFaint, fg: UC.brown),
                ]),
                const SizedBox(height: 8),
                _kv(ar ? 'موقع الاستلام' : 'Receiving location', '${r['location'] ?? '-'}'),
                _kv(ar ? 'التسليم المتوقع' : 'Expected delivery', '${r['expected_date'] ?? '-'}'),
                if ((r['confirmed_date'] ?? false) != false)
                  _kv(ar ? 'تاريخ الاستلام المؤكد' : 'Confirmed receipt', '${r['confirmed_date']}'),
                if (r['po_total'] is Map)
                  _kv(ar ? 'إجمالي أمر الشراء' : 'PO total',
                    '${(r['po_total'] as Map)['amount']} ${(r['po_total'] as Map)['symbol']}', bold: true),
              ])),
            const SizedBox(height: 12),
            Text(ar ? 'الأصناف' : 'Items', style: UT.h3),
            const SizedBox(height: 6),
            for (final l in lines) Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: UC.border)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${l['product']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                const SizedBox(height: 4),
                Row(children: [
                  _chip('${ar ? "مطلوب" : "Req"}: ${l['qty']}', UC.brown),
                  const SizedBox(width: 6),
                  if (received) _chip('${ar ? "استُلم" : "Recv"}: ${l['qty_received']}', UC.successDk),
                  if (received && (l['qty_damaged'] ?? 0) != 0) ...[
                    const SizedBox(width: 6), _chip('${ar ? "تالف" : "Dmg"}: ${l['qty_damaged']}', UC.dangerDk)],
                  const Spacer(),
                  if (l['price'] is Map) Text('${(l['price'] as Map)['amount']} ${(l['price'] as Map)['symbol']}',
                    style: const TextStyle(fontWeight: FontWeight.w900, color: UC.brown)),
                ]),
              ])),
            if (received) Container(margin: const EdgeInsets.only(top: 4), padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: UC.successBg, borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                const Icon(Icons.verified_user, color: UC.successDk, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(ar
                  ? 'تم استلام وفحص بضاعتك وإدخالها للمخزون عبر أمر الشراء — مستنداتك أدناه.'
                  : 'Your goods were received, inspected and booked into stock via the PO — documents below.',
                  style: const TextStyle(color: UC.successDk, fontWeight: FontWeight.w600, fontSize: 12))),
              ])),
            const SizedBox(height: 16),
            Text(ar ? 'السجل' : 'Timeline', style: UT.h3),
            const SizedBox(height: 8),
            for (final m in ((r['timeline'] as List?) ?? const []))
              Padding(padding: const EdgeInsets.only(bottom: 8),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Padding(padding: EdgeInsets.only(top: 4), child: Icon(Icons.circle, size: 8, color: UC.brown)),
                  const SizedBox(width: 8),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text((m as Map)['body'].toString().replaceAll(RegExp(r'<[^>]*>'), ' ').trim(), style: UT.body),
                    Text('${m['author']} · ${(m['when'] ?? '').toString().split('T').first}', style: UT.tiny),
                  ])),
                ])),
            const SizedBox(height: 100),
          ]),
      bottomNavigationBar: (r != null && r['has_handover'] == true) ? SafeArea(top: false, child: Padding(
        padding: const EdgeInsets.all(12),
        child: ElevatedButton.icon(
          onPressed: _busy ? null : _handover,
          icon: _busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: UC.brown))
            : const Icon(Icons.print_outlined, size: 18),
          label: Text(ar ? 'طباعة إذن التسليم/الاستلام' : 'Print handover / delivery note',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
          style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50))))) : null,
    );
  }

  Widget _chip(String t, Color c) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: c.withValues(alpha: .12), borderRadius: BorderRadius.circular(8)),
    child: Text(t, style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w800)));

  Widget _kv(String k, String v, {bool bold = false}) => Padding(padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(children: [
      Expanded(child: Text(k, style: const TextStyle(fontSize: 12.5, color: UC.muted, fontWeight: FontWeight.w600))),
      Text(v, style: TextStyle(fontSize: bold ? 14 : 12.5, fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
        color: bold ? UC.brown : UC.ink)),
    ]));
}
