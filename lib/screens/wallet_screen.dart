import 'package:flutter/material.dart';
import '../api/api.dart';
import '../theme/theme.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});
  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  Future<WalletData>? _f;
  @override
  void initState() { super.initState(); _f = VendorApi.instance.wallet(); }
  Future<void> _refresh() async {
    setState(() => _f = VendorApi.instance.wallet()); await _f;
  }

  @override
  Widget build(BuildContext context) {
    final ar = VendorApi.instance.lang == 'ar';
    final lang = ar ? 'ar' : 'en';
    return Scaffold(
      appBar: AppBar(title: Text(ar ? 'المحفظة' : 'Wallet')),
      body: RefreshIndicator(onRefresh: _refresh,
        child: FutureBuilder<WalletData>(future: _f, builder: (_, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: USpinner());
          if (snap.hasError) return Center(child: Padding(padding: const EdgeInsets.all(24),
            child: Text(snap.error.toString(), style: UT.body, textAlign: TextAlign.center)));
          final d = snap.data!;
          return ListView(padding: EdgeInsets.zero, children: [
            Container(margin: const EdgeInsets.all(14),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [UC.brown, UC.brownSoft]),
                borderRadius: BorderRadius.circular(18)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(ar ? 'الرصيد المتاح' : 'AVAILABLE BALANCE',
                  style: const TextStyle(color: Color(0xFFFFE066), fontSize: 11,
                    fontWeight: FontWeight.w800, letterSpacing: .4)),
                const SizedBox(height: 4),
                Text(d.balance.format(lang),
                  style: const TextStyle(color: Colors.white, fontSize: 28,
                    fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(ar ? 'قيد التحرير: ${d.pending.format(lang)}'
                        : 'Pending: ${d.pending.format(lang)}',
                  style: const TextStyle(color: Color(0xCCFFE066), fontSize: 12)),
              ])),
            if (d.transactions.isNotEmpty) Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
              child: Row(children: [
                Text(ar ? 'سجل المعاملات' : 'Transactions', style: UT.h3),
              ])),
            for (final tx in d.transactions) _txRow(tx, lang),
            if (d.transactions.isEmpty) Padding(padding: const EdgeInsets.all(40),
              child: Center(child: Text(ar ? 'لا توجد معاملات بعد' : 'No transactions yet',
                style: UT.body))),
          ]);
        })),
    );
  }

  Widget _txRow(WalletTx tx, String lang) {
    final isIn = tx.amount.amount > 0;
    return Container(color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: UC.bg))),
      child: Row(children: [
        Container(width: 36, height: 36, alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isIn ? UC.successBg : UC.dangerBg,
            borderRadius: BorderRadius.circular(10)),
          child: Icon(isIn ? Icons.arrow_downward : Icons.arrow_upward,
            color: isIn ? UC.successDk : UC.dangerDk, size: 18)),
        const SizedBox(width: 11),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tx.description.isNotEmpty ? tx.description : tx.type,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
          Text(tx.when.split('T').first, style: UT.small),
        ])),
        Text('${isIn ? "+" : ""}${tx.amount.amount.toStringAsFixed(tx.amount.digits)}',
          style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w900,
            color: isIn ? UC.successDk : UC.dangerDk, fontSize: 14)),
      ]));
  }
}
