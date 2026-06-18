import 'package:flutter/material.dart';
import '../api/api.dart';
import '../theme/theme.dart';

/// Fulfillment hub — orders grouped into actionable buckets with SLA aging
/// and bulk confirm/ship.
class OrderHubScreen extends StatefulWidget {
  const OrderHubScreen({super.key});
  @override
  State<OrderHubScreen> createState() => _OrderHubScreenState();
}

class _OrderHubScreenState extends State<OrderHubScreen> {
  bool _loading = true;
  String? _error;
  OrderHub? _hub;
  String _bucket = 'to_confirm';
  final Set<int> _selected = {};
  bool _busy = false;

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
      final h = await VendorApi.instance.orderHub();
      if (!mounted) return;
      setState(() {
        _hub = h;
        _loading = false;
        _selected.clear();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  String _bucketLabel(String k) {
    switch (k) {
      case 'to_confirm':
        return _ar ? 'للتأكيد' : 'To confirm';
      case 'to_ship':
        return _ar ? 'للشحن' : 'To ship';
      case 'shipped':
        return _ar ? 'مشحون' : 'Shipped';
      default:
        return _ar ? 'مكتمل' : 'Completed';
    }
  }

  Color _slaColor(String s) {
    switch (s) {
      case 'overdue':
        return UC.danger;
      case 'due_soon':
        return UC.warn;
      case 'done':
        return UC.success;
      default:
        return UC.muted;
    }
  }

  String _slaLabel(String s) {
    switch (s) {
      case 'overdue':
        return _ar ? 'متأخر' : 'Overdue';
      case 'due_soon':
        return _ar ? 'قريب الاستحقاق' : 'Due soon';
      case 'on_time':
        return _ar ? 'في الوقت' : 'On time';
      case 'done':
        return _ar ? 'تم' : 'Done';
      default:
        return '';
    }
  }

  // bulk action allowed only on actionable buckets
  bool get _canBulk => _bucket == 'to_confirm' || _bucket == 'to_ship';
  String get _bulkAction => _bucket == 'to_confirm' ? 'confirm' : 'ship';

  Future<void> _runBulk() async {
    if (_selected.isEmpty) return;
    setState(() => _busy = true);
    try {
      final res = await VendorApi.instance.ordersBulk(_selected.toList(), _bulkAction);
      if (!mounted) return;
      final done = res['done'] ?? 0;
      final failed = res['failed'] ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_ar
            ? 'تم: $done · فشل: $failed'
            : 'Done: $done · Failed: $failed'),
      ));
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hub = _hub;
    final orders = hub?.buckets[_bucket] ?? const [];
    return Scaffold(
      appBar: AppBar(title: Text(_ar ? 'مركز الطلبات' : 'Order hub')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center)))
              : Column(children: [
                  // SLA banner
                  if (hub != null && (hub.overdue > 0 || hub.dueSoon > 0))
                    Container(
                      width: double.infinity,
                      color: hub.overdue > 0 ? UC.dangerBg : UC.warnBg,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      child: Text(
                        _ar
                            ? '${hub.overdue} متأخر · ${hub.dueSoon} قريب الاستحقاق'
                            : '${hub.overdue} overdue · ${hub.dueSoon} due soon',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: hub.overdue > 0 ? UC.dangerDk : UC.warn),
                      ),
                    ),
                  // bucket chips
                  SizedBox(
                    height: 52,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      children: [
                        for (final k in ['to_confirm', 'to_ship', 'shipped', 'completed'])
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text('${_bucketLabel(k)} (${hub?.counts[k] ?? 0})'),
                              selected: _bucket == k,
                              onSelected: (_) => setState(() {
                                _bucket = k;
                                _selected.clear();
                              }),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _load,
                      child: orders.isEmpty
                          ? ListView(children: [
                              Padding(
                                padding: const EdgeInsets.all(40),
                                child: Center(child: Text(_ar ? 'لا توجد طلبات' : 'No orders', style: UT.small)),
                              )
                            ])
                          : ListView.builder(
                              padding: const EdgeInsets.all(10),
                              itemCount: orders.length,
                              itemBuilder: (_, i) {
                                final o = orders[i];
                                final selectable = _canBulk;
                                return Card(
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: const BorderSide(color: UC.border)),
                                  child: ListTile(
                                    leading: selectable
                                        ? Checkbox(
                                            value: _selected.contains(o.id),
                                            onChanged: (v) => setState(() {
                                              if (v == true) {
                                                _selected.add(o.id);
                                              } else {
                                                _selected.remove(o.id);
                                              }
                                            }),
                                          )
                                        : null,
                                    title: Text(o.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                                    subtitle: Text(
                                        '${o.customer['name'] ?? ''} · ${o.itemCount} ${_ar ? 'صنف' : 'items'} · ${o.amount.format(_ar ? 'ar' : 'en')}',
                                        style: UT.small),
                                    trailing: o.slaState.isEmpty || o.slaState == 'na'
                                        ? null
                                        : Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: _slaColor(o.slaState).withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(_slaLabel(o.slaState),
                                                style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w800,
                                                    color: _slaColor(o.slaState))),
                                          ),
                                    onTap: () => Navigator.pushNamed(context, '/order', arguments: {'id': o.id}),
                                  ),
                                );
                              },
                            ),
                    ),
                  ),
                ]),
      bottomNavigationBar: (_canBulk && _selected.isNotEmpty)
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _busy ? null : _runBulk,
                    icon: _busy
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: UC.brown))
                        : Icon(_bulkAction == 'confirm' ? Icons.check_circle : Icons.local_shipping),
                    label: Text(
                      _bulkAction == 'confirm'
                          ? (_ar ? 'تأكيد المحدد (${_selected.length})' : 'Confirm selected (${_selected.length})')
                          : (_ar ? 'شحن المحدد (${_selected.length})' : 'Ship selected (${_selected.length})'),
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }
}
