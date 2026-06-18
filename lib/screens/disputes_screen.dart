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
      await VendorApi.instance.disputeCreate(order!.id, reason, desc);
      _load();
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
                                title: Text('${d['name']} · ${d['order']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                                subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(_reasonLabel('${d['reason']}'), style: UT.small),
                                  if ('${d['description'] ?? ''}'.isNotEmpty) Text('${d['description']}', style: UT.tiny, maxLines: 2, overflow: TextOverflow.ellipsis),
                                  if ('${d['resolution'] ?? ''}'.isNotEmpty) Text('${_ar ? 'الحل: ' : 'Resolution: '}${d['resolution']}', style: const TextStyle(fontSize: 11, color: UC.successDk)),
                                ]),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(color: _stateColor('${d['state']}').withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                                  child: Text('${d['state']}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _stateColor('${d['state']}'))),
                                ),
                              ),
                            );
                          },
                        ),
                ),
    );
  }
}
