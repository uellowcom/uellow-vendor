import 'package:flutter/material.dart';
import '../api/api.dart';
import '../theme/theme.dart';

/// Order issues / disputes — vendor flags an order problem to Uellow.
class DisputesScreen extends StatefulWidget {
  const DisputesScreen({super.key});
  @override
  State<DisputesScreen> createState() => _DisputesScreenState();
}

class _DisputesScreenState extends State<DisputesScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _disputes = [];
  List<Map<String, dynamic>> _reasons = [];

  bool get _ar => VendorApi.instance.lang == 'ar';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final d = await VendorApi.instance.disputes();
      if (!mounted) return;
      setState(() {
        _disputes = ((d['disputes'] as List?) ?? const []).cast<Map>().map((e) => e.cast<String, dynamic>()).toList();
        _reasons = ((d['reasons'] as List?) ?? const []).cast<Map>().map((e) => e.cast<String, dynamic>()).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  String _reasonLabel(String code) {
    final r = _reasons.firstWhere((e) => e['code'] == code, orElse: () => {});
    return r.isEmpty ? code : (_ar ? (r['ar'] ?? r['en']) : r['en']);
  }

  Color _stateColor(String s) {
    switch (s) {
      case 'open':
        return UC.warn;
      case 'in_review':
        return UC.info;
      case 'resolved':
        return UC.success;
      default:
        return UC.muted;
    }
  }

  Future<void> _create() async {
    List<OrderSummary> orders;
    try {
      orders = await VendorApi.instance.orders();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      return;
    }
    if (!mounted) return;
    if (orders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_ar ? 'لا توجد طلبات' : 'No orders')));
      return;
    }
    OrderSummary? order = orders.first;
    String reason = _reasons.isNotEmpty ? (_reasons.first['code'] as String) : 'other';
    String desc = '';

    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => AlertDialog(
        title: Text(_ar ? 'الإبلاغ عن مشكلة' : 'Report an issue'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            DropdownButton<OrderSummary>(
              isExpanded: true,
              value: order,
              items: [for (final o in orders) DropdownMenuItem(value: o, child: Text('${o.name} · ${o.customer['name'] ?? ''}', overflow: TextOverflow.ellipsis))],
              onChanged: (o) => setS(() => order = o),
            ),
            const SizedBox(height: 8),
            DropdownButton<String>(
              isExpanded: true,
              value: reason,
              items: [for (final r in _reasons) DropdownMenuItem(value: r['code'] as String, child: Text(_ar ? (r['ar'] ?? r['en']) : r['en']))],
              onChanged: (r) => setS(() => reason = r ?? 'other'),
            ),
            const SizedBox(height: 8),
            TextField(
              decoration: InputDecoration(labelText: _ar ? 'التفاصيل' : 'Details'),
              maxLines: 3,
              onChanged: (v) => desc = v,
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(_ar ? 'إلغاء' : 'Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(_ar ? 'إرسال' : 'Submit')),
        ],
      )),
    );
    if (go != true || order == null) return;
    try {
      final created = await VendorApi.instance.disputeCreate(order!.id, reason, desc);
      _load();
      if (mounted && created['id'] != null) {
        await Navigator.push(context, MaterialPageRoute(
          builder: (_) => DisputeDetailScreen(id: created['id'] as int)));
        _load();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_ar ? 'مشاكل الطلبات' : 'Order issues')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.report_problem_outlined),
        label: Text(_ar ? 'إبلاغ' : 'Report'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center)))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _disputes.isEmpty
                      ? ListView(children: [Padding(padding: const EdgeInsets.all(40), child: Center(child: Text(_ar ? 'لا توجد بلاغات' : 'No issues', style: UT.small)))])
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _disputes.length,
                          itemBuilder: (_, i) {
                            final d = _disputes[i];
                            return Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: UC.border)),
                              child: ListTile(
                                onTap: () async {
                                  await Navigator.push(context, MaterialPageRoute(
                                    builder: (_) => DisputeDetailScreen(id: d['id'] as int? ?? 0)));
                                  _load();
                                },
                                title: Text('${d['name']} · ${d['order']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                                subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(_reasonLabel('${d['reason']}'), style: UT.small),
                                  if ('${d['description'] ?? ''}'.isNotEmpty) Text('${d['description']}', style: UT.tiny, maxLines: 2, overflow: TextOverflow.ellipsis),
                                ]),
                                trailing: Column(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(color: _stateColor('${d['state']}').withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                                    child: Text(_ar ? ((d['state_label'] as Map?)?['ar'] ?? d['state']).toString() : ((d['state_label'] as Map?)?['en'] ?? d['state']).toString(),
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _stateColor('${d['state']}'))),
                                  ),
                                  const SizedBox(height: 4),
                                  const Icon(Icons.chevron_right, color: UC.muted, size: 18),
                                ]),
                              ),
                            );
                          },
                        ),
                ),
    );
  }
}

// ─────────────── Dispute detail ───────────────
class DisputeDetailScreen extends StatefulWidget {
  final int id;
  const DisputeDetailScreen({super.key, required this.id});
  @override
  State<DisputeDetailScreen> createState() => _DisputeDetailScreenState();
}

class _DisputeDetailScreenState extends State<DisputeDetailScreen> {
  Map<String, dynamic>? _d;
  bool _loading = true, _busy = false;
  String? _err;
  final _comment = TextEditingController();

  bool get _ar => VendorApi.instance.lang == 'ar';

  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { _comment.dispose(); super.dispose(); }

  Future<void> _load() async {
    try {
      final d = await VendorApi.instance.disputeDetail(widget.id);
      if (!mounted) return;
      setState(() { _d = d; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _err = '$e'; _loading = false; });
    }
  }

  Color _stateColor(String s) => {
    'open': UC.warn, 'in_review': UC.info, 'resolved': UC.success, 'rejected': UC.dangerDk}[s] ?? UC.muted;

  Future<void> _send() async {
    final t = _comment.text.trim();
    if (t.isEmpty) return;
    setState(() => _busy = true);
    try {
      await VendorApi.instance.disputeComment(widget.id, t);
      _comment.clear();
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally { if (mounted) setState(() => _busy = false); }
  }

  String _bl(dynamic v) => v is Map ? (_ar ? (v['ar'] ?? v['en']) : (v['en'] ?? v['ar']) ?? '').toString() : '${v ?? ''}';

  @override
  Widget build(BuildContext context) {
    final d = _d;
    final state = (d?['state'] ?? '').toString();
    final open = state == 'open' || state == 'in_review';
    return Scaffold(
      backgroundColor: UC.bg,
      appBar: AppBar(title: Text(d?['name']?.toString() ?? (_ar ? 'المشكلة' : 'Issue'))),
      body: _loading
        ? const Center(child: USpinner())
        : d == null
          ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_err ?? 'Error')))
          : ListView(padding: const EdgeInsets.all(14), children: [
              // Header
              Container(padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.white,
                  borderRadius: BorderRadius.circular(16), border: Border.all(color: UC.border)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(_bl(d['reason_label']),
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15))),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: _stateColor(state).withValues(alpha: .15),
                        borderRadius: BorderRadius.circular(999)),
                      child: Text(_bl(d['state_label']),
                        style: TextStyle(color: _stateColor(state), fontSize: 11, fontWeight: FontWeight.w900))),
                  ]),
                  const SizedBox(height: 8),
                  if ('${d['description'] ?? ''}'.isNotEmpty)
                    Text('${d['description']}', style: UT.body),
                ])),
              const SizedBox(height: 12),
              // Order card
              if (d['order_detail'] is Map) Container(padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.white,
                  borderRadius: BorderRadius.circular(16), border: Border.all(color: UC.border)),
                child: Row(children: [
                  Container(width: 38, height: 38, alignment: Alignment.center,
                    decoration: BoxDecoration(color: UC.yellowFaint, borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.receipt_long, color: UC.brown, size: 18)),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${(d['order_detail'] as Map)['name']}',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontFamily: 'monospace')),
                    Text('${d['customer'] ?? ''}', style: UT.small),
                  ])),
                  Text('${((d['order_detail'] as Map)['amount'] as Map?)?['amount'] ?? ''} ${((d['order_detail'] as Map)['amount'] as Map?)?['symbol'] ?? ''}',
                    style: const TextStyle(fontWeight: FontWeight.w900, color: UC.brown)),
                ])),
              if ('${d['resolution'] ?? ''}'.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: UC.successBg, borderRadius: BorderRadius.circular(12)),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.verified, color: UC.successDk, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text('${_ar ? "الحل: " : "Resolution: "}${d['resolution']}',
                      style: const TextStyle(color: UC.successDk, fontWeight: FontWeight.w600))),
                  ])),
              ],
              const SizedBox(height: 16),
              Text(_ar ? 'السجل' : 'Timeline', style: UT.h3),
              const SizedBox(height: 8),
              for (final m in ((d['timeline'] as List?) ?? const []))
                _timelineItem((m as Map).cast<String, dynamic>()),
              if (((d['timeline'] as List?) ?? const []).isEmpty)
                Text(_ar ? 'لا توجد تحديثات بعد' : 'No updates yet', style: UT.small),
              const SizedBox(height: 90),
            ]),
      bottomNavigationBar: (d != null && open) ? SafeArea(top: false, child: Container(
        padding: const EdgeInsets.all(10),
        decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: UC.border))),
        child: Row(children: [
          Expanded(child: TextField(controller: _comment,
            decoration: InputDecoration(hintText: _ar ? 'أضف تعليقاً' : 'Add a comment', isDense: true))),
          const SizedBox(width: 8),
          IconButton(onPressed: _busy ? null : _send,
            icon: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.send, color: UC.brown)),
        ]))) : null,
    );
  }

  Widget _timelineItem(Map<String, dynamic> m) {
    final body = (m['body'] ?? '').toString()
      .replaceAll(RegExp(r'<[^>]*>'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    return Container(margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(color: Colors.white,
        borderRadius: BorderRadius.circular(12), border: Border.all(color: UC.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.circle, size: 8, color: UC.brown),
          const SizedBox(width: 6),
          Text('${m['author'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
          const Spacer(),
          Text((m['when'] ?? '').toString().split('T').first, style: UT.tiny),
        ]),
        if (body.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4, left: 14),
          child: Text(body, style: UT.body)),
      ]));
  }
}
