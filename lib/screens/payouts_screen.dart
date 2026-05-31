import 'package:flutter/material.dart';
import '../api/api.dart';
import '../theme/theme.dart';

class PayoutsScreen extends StatefulWidget {
  const PayoutsScreen({super.key});
  @override
  State<PayoutsScreen> createState() => _PayoutsScreenState();
}

class _PayoutsScreenState extends State<PayoutsScreen> {
  Future<List<PayoutSummary>>? _f;
  bool _busy = false;
  @override
  void initState() { super.initState(); _f = VendorApi.instance.payouts(); }
  Future<void> _refresh() async {
    setState(() => _f = VendorApi.instance.payouts()); await _f;
  }

  Future<void> _request() async {
    final ar = VendorApi.instance.lang == 'ar';
    setState(() => _busy = true);
    try {
      await VendorApi.instance.requestPayout();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ar ? 'تم إرسال طلب الدفع' : 'Payout request submitted')));
      _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally { if (mounted) setState(() => _busy = false); }
  }

  Color _bg(String s) => switch (s) {
    'paid' => UC.successBg, 'approved' => UC.infoBg, 'draft' => UC.warnBg,
    _ => UC.bg,
  };
  Color _fg(String s) => switch (s) {
    'paid' => UC.successDk, 'approved' => const Color(0xFF1E40AF),
    'draft' => const Color(0xFF92400E), _ => UC.muted,
  };

  @override
  Widget build(BuildContext context) {
    final ar = VendorApi.instance.lang == 'ar';
    final lang = ar ? 'ar' : 'en';
    return Scaffold(
      appBar: AppBar(title: Text(ar ? 'الدفعات' : 'Payouts')),
      body: RefreshIndicator(onRefresh: _refresh,
        child: FutureBuilder<List<PayoutSummary>>(future: _f, builder: (_, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: USpinner());
          if (snap.hasError) return Center(child: Padding(padding: const EdgeInsets.all(24),
            child: Text(snap.error.toString(), style: UT.body, textAlign: TextAlign.center)));
          final rows = snap.data ?? const <PayoutSummary>[];
          return ListView.separated(itemCount: rows.length + 1,
            separatorBuilder: (_, __) => const Divider(height: 1, color: UC.bg),
            itemBuilder: (_, i) {
              if (i == 0) return Container(color: Colors.white,
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(ar ? 'سجل الدفعات' : 'Payout history', style: UT.h3),
                  if (rows.isEmpty) Padding(padding: const EdgeInsets.all(20),
                    child: Center(child: Text(ar ? 'لا توجد دفعات بعد' : 'No payouts yet',
                      style: UT.body))),
                ]));
              final p = rows[i - 1];
              return Container(color: Colors.white,
                padding: const EdgeInsets.all(13),
                child: Row(children: [
                  Container(width: 38, height: 38, alignment: Alignment.center,
                    decoration: BoxDecoration(color: UC.yellowFaint,
                      borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.payments, color: UC.brown, size: 18)),
                  const SizedBox(width: 11),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(p.name, style: const TextStyle(fontFamily: 'monospace',
                      fontWeight: FontWeight.w900, fontSize: 12.5)),
                    Row(children: [
                      Text(p.when.split('T').first, style: UT.small),
                      const SizedBox(width: 8),
                      UPill(text: p.stateLabel.t(lang), bg: _bg(p.state), fg: _fg(p.state)),
                    ]),
                  ])),
                  Text(p.amount.format(lang),
                    style: const TextStyle(fontFamily: 'monospace',
                      fontSize: 14, fontWeight: FontWeight.w900, color: UC.brown)),
                ]));
            });
        })),
      bottomNavigationBar: SafeArea(top: false, child: Container(
        padding: const EdgeInsets.all(14),
        decoration: const BoxDecoration(color: Colors.white,
          border: Border(top: BorderSide(color: UC.border))),
        child: ElevatedButton.icon(onPressed: _busy ? null : _request,
          icon: _busy ? const SizedBox(width: 16, height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: UC.brown))
            : const Icon(Icons.send, size: 18),
          label: Text(VendorApi.instance.lang == 'ar' ? 'طلب دفعة جديدة' : 'Request new payout',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14.5)),
          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14))))),
    );
  }
}
