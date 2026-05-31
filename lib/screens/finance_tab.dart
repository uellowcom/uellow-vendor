import 'package:flutter/material.dart';
import '../api/api.dart';
import '../theme/theme.dart';

class FinanceTab extends StatelessWidget {
  const FinanceTab({super.key});
  @override
  Widget build(BuildContext context) {
    final ar = VendorApi.instance.lang == 'ar';
    final v = VendorApi.instance.vendor;
    return Scaffold(
      appBar: AppBar(title: Text(ar ? 'المالية' : 'Finance')),
      body: ListView(padding: const EdgeInsets.all(14), children: [
        // Hero balance
        Container(padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [UC.brown, UC.brownSoft]),
            borderRadius: BorderRadius.circular(18)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(ar ? 'رصيد المحفظة' : 'Wallet balance',
              style: const TextStyle(color: Color(0xFFFFE066), fontSize: 11,
                fontWeight: FontWeight.w800, letterSpacing: .4)),
            const SizedBox(height: 4),
            Text('${(v?.walletBalance ?? 0).toStringAsFixed(3)} ${v?.currencySymbol ?? "KD"}',
              style: const TextStyle(color: Colors.white, fontSize: 28,
                fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(ar ? 'الإيرادات الإجمالية: ${(v?.totalSales ?? 0).toStringAsFixed(3)} ${v?.currencySymbol ?? "KD"}'
                    : 'Total revenue: ${(v?.totalSales ?? 0).toStringAsFixed(3)} ${v?.currencySymbol ?? "KD"}',
              style: const TextStyle(color: Color(0xCCFFE066), fontSize: 12)),
          ])),
        const SizedBox(height: 12),
        _row(context, Icons.account_balance_wallet_outlined,
          ar ? 'تفاصيل المحفظة' : 'Wallet details',
          ar ? 'الرصيد + سجل المعاملات' : 'Balance + transactions',
          '/wallet'),
        _row(context, Icons.receipt_long_outlined,
          ar ? 'العمولات' : 'Commissions',
          ar ? 'كل عمولة على طلباتي' : 'Per-order commissions',
          '/commissions'),
        _row(context, Icons.payments_outlined,
          ar ? 'الدفعات' : 'Payouts',
          ar ? 'دفعاتي السابقة + طلب دفعة' : 'Past payouts + request payout',
          '/payouts'),
        _row(context, Icons.bar_chart_outlined,
          ar ? 'التحليلات' : 'Analytics',
          ar ? 'مبيعات يومية + أعلى المنتجات + أفضل العملاء' : 'Daily sales + top products + top customers',
          '/analytics'),
      ]),
    );
  }
  Widget _row(BuildContext c, IconData ic, String title, String sub, String route) =>
    Material(color: Colors.white, borderRadius: BorderRadius.circular(13),
      child: InkWell(borderRadius: BorderRadius.circular(13),
        onTap: () => Navigator.pushNamed(c, route),
        child: Container(margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(border: Border.all(color: UC.border),
            borderRadius: BorderRadius.circular(13)),
          child: Row(children: [
            Container(width: 44, height: 44, alignment: Alignment.center,
              decoration: BoxDecoration(color: UC.yellowFaint,
                borderRadius: BorderRadius.circular(12)),
              child: Icon(ic, color: UC.brown, size: 19)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5)),
              Text(sub, style: UT.small),
            ])),
            const Icon(Icons.chevron_right, color: UC.muted),
          ]))));
}
