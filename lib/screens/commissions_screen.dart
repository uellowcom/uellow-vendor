import 'package:flutter/material.dart';
import '../api/api.dart';
import '../theme/theme.dart';

class CommissionsScreen extends StatefulWidget {
  const CommissionsScreen({super.key});
  @override
  State<CommissionsScreen> createState() => _CommissionsScreenState();
}

class _CommissionsScreenState extends State<CommissionsScreen> {
  String _state = '';
  Future<CommissionList>? _f;
  @override
  void initState() { super.initState(); _reload(); }
  void _reload() {
    setState(() => _f = VendorApi.instance.commissions(state: _state));
  }

  Color _bg(String s) => switch (s) {
    'released' => UC.successBg, 'paid_out' => UC.infoBg, 'pending' => UC.warnBg,
    _ => UC.bg,
  };
  Color _fg(String s) => switch (s) {
    'released' => UC.successDk, 'paid_out' => const Color(0xFF1E40AF),
    'pending' => const Color(0xFF92400E), _ => UC.muted,
  };

  @override
  Widget build(BuildContext context) {
    final ar = VendorApi.instance.lang == 'ar';
    final lang = ar ? 'ar' : 'en';
    return Scaffold(
      appBar: AppBar(title: Text(ar ? 'العمولات' : 'Commissions'),
        bottom: PreferredSize(preferredSize: const Size.fromHeight(44),
          child: SizedBox(height: 44, child: ListView(scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            children: [
              _tab('',         ar ? 'الكل' : 'All'),
              _tab('pending',  ar ? 'قيد الانتظار' : 'Pending'),
              _tab('released', ar ? 'مُفرَجة' : 'Released'),
              _tab('paid_out', ar ? 'مدفوعة' : 'Paid out'),
            ]))),
      ),
      body: FutureBuilder<CommissionList>(future: _f, builder: (_, snap) {
        if (snap.connectionState != ConnectionState.done) return const Center(child: USpinner());
        if (snap.hasError) return Center(child: Padding(padding: const EdgeInsets.all(24),
          child: Text(snap.error.toString(), style: UT.body, textAlign: TextAlign.center)));
        final d = snap.data!;
        return Column(children: [
          Container(margin: const EdgeInsets.all(14),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white,
              border: Border.all(color: UC.border), borderRadius: BorderRadius.circular(13)),
            child: Row(children: [
              _stat(ar ? 'قيد الانتظار' : 'Pending', d.pending.format(lang), UC.warn),
              _stat(ar ? 'مفرجة' : 'Released', d.released.format(lang), UC.successDk),
              _stat(ar ? 'مدفوعة' : 'Paid out', d.paidOut.format(lang), UC.info),
            ])),
          Expanded(child: ListView.separated(itemCount: d.items.length,
            separatorBuilder: (_, __) => const Divider(height: 1, color: UC.bg),
            itemBuilder: (_, i) {
              final c = d.items[i];
              return Container(color: Colors.white,
                padding: const EdgeInsets.all(13),
                child: Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(c.orderName, style: const TextStyle(fontFamily: 'monospace',
                      fontWeight: FontWeight.w900, fontSize: 12.5)),
                    Row(children: [
                      Text(c.orderDate.split('T').first, style: UT.small),
                      const SizedBox(width: 6),
                      UPill(text: c.state.toUpperCase(),
                        bg: _bg(c.state), fg: _fg(c.state)),
                    ]),
                    const SizedBox(height: 4),
                    Text(ar
                      ? 'مبلغ الطلب ${c.orderAmount.format(lang)} · عمولة ${c.commissionRate.toStringAsFixed(1)}%'
                      : 'Order ${c.orderAmount.format(lang)} · ${c.commissionRate.toStringAsFixed(1)}% commission',
                      style: UT.small),
                  ])),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('+${c.netAmount.format(lang)}',
                      style: const TextStyle(fontFamily: 'monospace',
                        fontWeight: FontWeight.w900, color: UC.successDk, fontSize: 14)),
                    Text('-${c.commissionAmount.format(lang)}', style: UT.small),
                  ]),
                ]));
            })),
        ]);
      }),
    );
  }

  Widget _tab(String key, String label) {
    final on = _state == key;
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: GestureDetector(onTap: () { _state = key; _reload(); },
        child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: on ? UC.yellow : Colors.white,
            border: Border.all(color: on ? UC.yellow : UC.border, width: 1.5),
            borderRadius: BorderRadius.circular(999)),
          child: Text(label, style: TextStyle(
            color: on ? UC.brown : UC.text, fontWeight: FontWeight.w900, fontSize: 12.5)))));
  }
  Widget _stat(String l, String v, Color c) => Expanded(child: Column(children: [
    Text(v, style: TextStyle(color: c, fontSize: 15, fontWeight: FontWeight.w900, fontFamily: 'monospace')),
    Text(l, style: const TextStyle(fontSize: 10, color: UC.muted, fontWeight: FontWeight.w800)),
  ]));
}
