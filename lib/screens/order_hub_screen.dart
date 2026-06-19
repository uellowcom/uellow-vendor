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

  IconData _slaIcon(String s) {
    switch (s) {
      case 'overdue':
        return Icons.error_outline;
      case 'due_soon':
        return Icons.schedule;
      case 'done':
        return Icons.check_circle_outline;
      default:
        return Icons.fiber_manual_record;
    }
  }

  // visual identity per bucket
  Color _bucketColor(String k) {
    switch (k) {
      case 'to_confirm':
        return UC.warn;
      case 'to_ship':
        return UC.info;
      case 'shipped':
        return UC.yellow;
      default:
        return UC.success;
    }
  }

  IconData _bucketIcon(String k) {
    switch (k) {
      case 'to_confirm':
        return Icons.task_alt;
      case 'to_ship':
        return Icons.inventory_2_outlined;
      case 'shipped':
        return Icons.local_shipping_outlined;
      default:
        return Icons.done_all;
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
          ? const USpinner()
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center)))
              : Column(children: [
                  // explainer + bucket chips + SLA summary
                  _buildHeader(hub),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _load,
                      child: orders.isEmpty
                          ? ListView(children: [_buildEmpty()])
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(12, 6, 12, 24),
                              itemCount: orders.length,
                              itemBuilder: (_, i) => _buildOrderCard(orders[i]),
                            ),
                    ),
                  ),
                ]),
      bottomNavigationBar: (_canBulk && _selected.isNotEmpty) ? _buildBulkBar() : null,
    );
  }

  // ── Header: explainer banner + caption + bucket chips + SLA summary ──
  Widget _buildHeader(OrderHub? hub) {
    return Container(
      color: UC.card,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // info banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: UC.infoBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: UC.info.withValues(alpha: 0.25)),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.lightbulb_outline, size: 18, color: UC.info),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  _ar ? 'مساحة عمل تنفيذ الطلبات' : 'Your fulfilment workspace',
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: UC.ink),
                ),
                const SizedBox(height: 2),
                Text(
                  _ar
                      ? 'تتدفق الطلبات عبر مراحل: للتأكيد ← للشحن ← مشحون ← مكتمل. أكّد أو اشحن دفعة واحدة، وراقب مهل التسليم (SLA).'
                      : 'Orders flow through stages: To confirm → To ship → Shipped → Completed. Confirm or ship in bulk and watch SLA aging.',
                  style: const TextStyle(fontSize: 11, height: 1.35, color: UC.text),
                ),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 10),
        // one-line caption under title
        Text(
          _ar ? 'اختر مرحلة لمتابعة طلباتها' : 'Pick a stage to work its orders',
          style: UT.small,
        ),
        const SizedBox(height: 8),
        // bucket chips with counts + color coding
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final k in ['to_confirm', 'to_ship', 'shipped', 'completed'])
              _bucketChip(k, hub?.counts[k] ?? 0),
          ]),
        ),
        // SLA summary
        if (hub != null && (hub.overdue > 0 || hub.dueSoon > 0)) ...[
          const SizedBox(height: 10),
          Row(children: [
            if (hub.overdue > 0)
              _slaSummaryTile(
                  Icons.error_outline, UC.danger, UC.dangerBg, UC.dangerDk,
                  hub.overdue, _ar ? 'متأخر' : 'Overdue'),
            if (hub.overdue > 0 && hub.dueSoon > 0) const SizedBox(width: 8),
            if (hub.dueSoon > 0)
              _slaSummaryTile(
                  Icons.schedule, UC.warn, UC.warnBg, UC.warn,
                  hub.dueSoon, _ar ? 'قريب الاستحقاق' : 'Due soon'),
          ]),
        ],
      ]),
    );
  }

  Widget _bucketChip(String k, int count) {
    final selected = _bucket == k;
    final c = _bucketColor(k);
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: GestureDetector(
        onTap: () => setState(() {
          _bucket = k;
          _selected.clear();
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? c.withValues(alpha: 0.14) : UC.bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? c : UC.border, width: selected ? 1.5 : 1),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(_bucketIcon(k), size: 15, color: selected ? c : UC.muted),
            const SizedBox(width: 6),
            Text(_bucketLabel(k),
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: selected ? UC.ink : UC.text)),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
              decoration: BoxDecoration(
                color: selected ? c : UC.border,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text('$count',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: selected ? Colors.white : UC.text)),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _slaSummaryTile(IconData icon, Color fg, Color bg, Color textC, int n, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: fg.withValues(alpha: 0.3)),
        ),
        child: Row(children: [
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: 8),
          Text('$n',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: textC)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(label,
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: textC),
                overflow: TextOverflow.ellipsis),
          ),
        ]),
      ),
    );
  }

  Widget _buildEmpty() {
    return Padding(
      padding: const EdgeInsets.all(48),
      child: Center(
        child: Column(children: [
          Icon(_bucketIcon(_bucket), size: 40, color: UC.border),
          const SizedBox(height: 12),
          Text(_ar ? 'لا توجد طلبات في هذه المرحلة' : 'No orders in this stage',
              style: UT.small, textAlign: TextAlign.center),
        ]),
      ),
    );
  }

  // ── Order card ──
  Widget _buildOrderCard(OrderSummary o) {
    final selectable = _canBulk;
    final checked = _selected.contains(o.id);
    final hasSla = o.slaState.isNotEmpty && o.slaState != 'na';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: UC.card,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.pushNamed(context, '/order', arguments: {'id': o.id}),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: checked ? _bucketColor(_bucket) : UC.border, width: checked ? 1.5 : 1),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (selectable)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 4),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: Checkbox(
                      value: checked,
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onChanged: (v) => setState(() {
                        if (v == true) {
                          _selected.add(o.id);
                        } else {
                          _selected.remove(o.id);
                        }
                      }),
                    ),
                  ),
                ),
              if (selectable) const SizedBox(width: 8),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(
                      child: Text(o.name,
                          style: UT.h3, overflow: TextOverflow.ellipsis),
                    ),
                    if (hasSla)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _slaColor(o.slaState).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(_slaIcon(o.slaState), size: 11, color: _slaColor(o.slaState)),
                          const SizedBox(width: 3),
                          Text(_slaLabel(o.slaState),
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: _slaColor(o.slaState))),
                        ]),
                      ),
                  ]),
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.person_outline, size: 13, color: UC.muted),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text('${o.customer['name'] ?? ''}',
                          style: UT.body, overflow: TextOverflow.ellipsis),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    UPill(
                      text: '${o.itemCount} ${_ar ? 'صنف' : 'items'}',
                      icon: Icons.shopping_bag_outlined,
                      bg: UC.bg,
                      fg: UC.muted,
                    ),
                    const SizedBox(width: 8),
                    Text(o.amount.format(_ar ? 'ar' : 'en'),
                        style: const TextStyle(
                            fontSize: 13.5, fontWeight: FontWeight.w900, color: UC.brown)),
                  ]),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  // ── Bulk action bar ──
  Widget _buildBulkBar() {
    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(
          color: UC.card,
          border: Border(top: BorderSide(color: UC.border)),
        ),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _bucketColor(_bucket).withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              _ar ? '${_selected.length} محدد' : '${_selected.length} selected',
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w900, color: _bucketColor(_bucket)),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: _busy ? null : () => setState(() => _selected.clear()),
            child: Text(_ar ? 'إلغاء' : 'Clear',
                style: const TextStyle(fontWeight: FontWeight.w800, color: UC.muted)),
          ),
          const Spacer(),
          SizedBox(
            height: 46,
            child: ElevatedButton.icon(
              onPressed: _busy ? null : _runBulk,
              icon: _busy
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: UC.brown))
                  : Icon(_bulkAction == 'confirm' ? Icons.check_circle : Icons.local_shipping, size: 18),
              label: Text(
                _bulkAction == 'confirm'
                    ? (_ar ? 'تأكيد (${_selected.length})' : 'Confirm (${_selected.length})')
                    : (_ar ? 'شحن (${_selected.length})' : 'Ship (${_selected.length})'),
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
