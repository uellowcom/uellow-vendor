import 'package:flutter/material.dart';
import '../api/api.dart';
import '../theme/theme.dart';

class OrdersTab extends StatefulWidget {
  const OrdersTab({super.key});
  @override
  State<OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<OrdersTab> {
  String _state = '';
  String _search = '';
  Future<List<OrderSummary>>? _f;
  final _q = TextEditingController();
  @override
  void initState() { super.initState(); _reload(); }
  @override
  void dispose() { _q.dispose(); super.dispose(); }
  void _reload() {
    setState(() => _f = VendorApi.instance.orders(state: _state, search: _search));
  }

  Color _stBg(String s) => switch (s) {
    'completed' || 'sale' => UC.successBg,
    'cancelled' || 'cancel' => UC.dangerBg,
    'pending' || 'draft' => UC.warnBg,
    _ => UC.infoBg,
  };
  Color _stFg(String s) => switch (s) {
    'completed' || 'sale' => UC.successDk,
    'cancelled' || 'cancel' => UC.dangerDk,
    'pending' || 'draft' => const Color(0xFF92400E),
    _ => const Color(0xFF1E40AF),
  };

  @override
  Widget build(BuildContext context) {
    final ar = VendorApi.instance.lang == 'ar';
    final lang = ar ? 'ar' : 'en';
    return Scaffold(
      appBar: AppBar(title: Text(ar ? 'الطلبات' : 'Orders'),
        bottom: PreferredSize(preferredSize: const Size.fromHeight(98),
          child: Column(children: [
            Padding(padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              child: TextField(controller: _q,
                onChanged: (v) { _search = v; _reload(); },
                decoration: InputDecoration(
                  hintText: ar ? 'بحث برقم الطلب أو العميل…' : 'Search by # or customer…',
                  prefixIcon: const Icon(Icons.search, size: 18)))),
            SizedBox(height: 44, child: ListView(scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              children: [
                _tab('',         ar ? 'الكل' : 'All'),
                _tab('new',      ar ? 'جديدة' : 'New'),
                _tab('active',   ar ? 'قيد التنفيذ' : 'Active'),
                _tab('completed', ar ? 'مكتملة' : 'Completed'),
                _tab('cancelled', ar ? 'ملغاة' : 'Cancelled'),
              ])),
          ])),
      ),
      body: RefreshIndicator(onRefresh: () async { _reload(); await _f; },
        child: FutureBuilder<List<OrderSummary>>(future: _f, builder: (_, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: USpinner());
          if (snap.hasError) return Center(child: Padding(padding: const EdgeInsets.all(24),
            child: Text(snap.error.toString(), style: UT.body, textAlign: TextAlign.center)));
          final rows = snap.data ?? const <OrderSummary>[];
          if (rows.isEmpty) return Padding(padding: const EdgeInsets.all(40),
            child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.inventory_2_outlined, size: 48, color: UC.muted),
              const SizedBox(height: 12),
              Text(ar ? 'لا توجد طلبات' : 'No orders here', style: UT.body),
            ])));
          return ListView.separated(padding: const EdgeInsets.all(10),
            itemCount: rows.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _card(rows[i], lang));
        })),
    );
  }

  Widget _tab(String key, String label) {
    final on = _state == key;
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: GestureDetector(onTap: () { _state = key; _reload(); },
        child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: on ? UC.yellow : Colors.white,
            border: Border.all(color: on ? UC.yellow : UC.border, width: 1.5),
            borderRadius: BorderRadius.circular(999)),
          child: Text(label, style: TextStyle(
            color: on ? UC.brown : UC.text, fontWeight: FontWeight.w900, fontSize: 12.5)))));
  }

  Widget _card(OrderSummary o, String lang) => Material(color: Colors.white,
    borderRadius: BorderRadius.circular(14),
    child: InkWell(borderRadius: BorderRadius.circular(14),
      onTap: () => Navigator.pushNamed(context, '/order', arguments: {'id': o.id}),
      child: Container(padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(border: Border.all(color: UC.border),
          borderRadius: BorderRadius.circular(14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(o.name, style: const TextStyle(fontFamily: 'monospace',
              fontSize: 12.5, fontWeight: FontWeight.w900)),
            const Spacer(),
            UPill(text: o.stateLabel.t(lang), bg: _stBg(o.state), fg: _stFg(o.state)),
          ]),
          const SizedBox(height: 6),
          Text((o.customer['name'] ?? '').toString(),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
          if ((o.customer['phone'] ?? '').toString().isNotEmpty)
            Text((o.customer['phone'] ?? '').toString(),
              style: const TextStyle(fontSize: 11.5, color: UC.muted)),
          const SizedBox(height: 8),
          Row(children: [
            Text(o.amount.format(lang), style: const TextStyle(fontSize: 14.5,
              fontWeight: FontWeight.w900, color: UC.brown)),
            const SizedBox(width: 8),
            UPill(text: '${o.itemCount} ${VendorApi.instance.lang == "ar" ? "عناصر" : "items"}'),
            const Spacer(),
            Text(o.when.split('T').first, style: UT.small),
          ]),
        ]))));
}
