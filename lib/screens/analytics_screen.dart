import 'package:cached_network_image/cached_network_image.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../api/api.dart';
import '../theme/theme.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});
  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  int _days = 30;
  Future<SalesTimeseries>? _ts;
  Future<List<TopProduct>>? _tp;
  Future<List<TopCustomer>>? _tc;
  @override
  void initState() { super.initState(); _load(); }
  void _load() {
    setState(() {
      _ts = VendorApi.instance.salesTimeseries(days: _days);
      _tp = VendorApi.instance.topProducts();
      _tc = VendorApi.instance.topCustomers();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ar = VendorApi.instance.lang == 'ar';
    final lang = ar ? 'ar' : 'en';
    return Scaffold(
      appBar: AppBar(title: Text(ar ? 'التحليلات' : 'Analytics')),
      body: ListView(padding: EdgeInsets.zero, children: [
        // Range picker
        Padding(padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
          child: Wrap(spacing: 6, children: [
            for (final d in const [7, 14, 30, 60, 90])
              ChoiceChip(
                label: Text('$d ${ar ? "يوم" : "days"}'),
                selected: _days == d,
                onSelected: (_) { _days = d; _load(); },
                selectedColor: UC.yellow,
                labelStyle: TextStyle(
                  fontWeight: FontWeight.w900, fontSize: 11,
                  color: _days == d ? UC.brown : UC.text),
              ),
          ])),
        // Sales chart
        FutureBuilder<SalesTimeseries>(future: _ts, builder: (_, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const SizedBox(height: 240, child: Center(child: USpinner()));
          }
          final d = snap.data;
          if (d == null) return const SizedBox.shrink();
          return Container(margin: const EdgeInsets.all(14),
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            decoration: BoxDecoration(color: Colors.white,
              border: Border.all(color: UC.border), borderRadius: BorderRadius.circular(13)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(ar ? 'الإيرادات اليومية' : 'Daily revenue',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
              Text(ar ? 'إجمالي ${d.totalRevenue.toStringAsFixed(3)} KD · ${d.totalOrders} طلب'
                      : 'Total ${d.totalRevenue.toStringAsFixed(3)} KD · ${d.totalOrders} orders',
                style: UT.small),
              const SizedBox(height: 10),
              SizedBox(height: 180, child: LineChart(LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineBarsData: [LineChartBarData(
                  spots: [for (var i = 0; i < d.days.length; i++)
                    FlSpot(i.toDouble(), d.days[i].revenue)],
                  isCurved: true, color: UC.brown, barWidth: 3,
                  belowBarData: BarAreaData(show: true,
                    gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [UC.yellow.withValues(alpha: .5), UC.yellow.withValues(alpha: 0)])),
                  dotData: const FlDotData(show: false),
                )]))),
            ]));
        }),
        // Top products
        Padding(padding: const EdgeInsets.fromLTRB(14, 4, 14, 6),
          child: Text(ar ? 'أعلى المنتجات مبيعاً' : 'Top products', style: UT.h3)),
        FutureBuilder<List<TopProduct>>(future: _tp, builder: (_, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const SizedBox(height: 100, child: Center(child: USpinner()));
          }
          final rows = snap.data ?? const <TopProduct>[];
          if (rows.isEmpty) return Padding(padding: const EdgeInsets.all(20),
            child: Center(child: Text(ar ? 'لا توجد بيانات' : 'No data', style: UT.small)));
          return Container(margin: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(color: Colors.white,
              border: Border.all(color: UC.border), borderRadius: BorderRadius.circular(13)),
            child: Column(children: rows.take(8).map((p) => Padding(
              padding: const EdgeInsets.all(10),
              child: Row(children: [
                ClipRRect(borderRadius: BorderRadius.circular(8),
                  child: p.imageUrl != null
                    ? CachedNetworkImage(imageUrl: '${VendorApi.instance.baseUrl}${p.imageUrl!}',
                        width: 38, height: 38, fit: BoxFit.cover,
                        errorWidget: (_,__,___) => Container(width: 38, height: 38,
                          color: UC.bg, child: const Icon(Icons.image, color: UC.muted, size: 16)))
                    : Container(width: 38, height: 38, color: UC.yellowFaint)),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p.name.t(lang), maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
                  Text('${p.qty.toStringAsFixed(0)} ${ar ? "قطعة" : "units"}', style: UT.small),
                ])),
                Text(p.revenue.format(lang), style: const TextStyle(
                  fontFamily: 'monospace', fontWeight: FontWeight.w900,
                  color: UC.brown, fontSize: 12.5)),
              ])
            )).toList()));
        }),
        Padding(padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
          child: Text(ar ? 'أفضل العملاء' : 'Top customers', style: UT.h3)),
        FutureBuilder<List<TopCustomer>>(future: _tc, builder: (_, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const SizedBox(height: 100, child: Center(child: USpinner()));
          }
          final rows = snap.data ?? const <TopCustomer>[];
          if (rows.isEmpty) return Padding(padding: const EdgeInsets.all(20),
            child: Center(child: Text(ar ? 'لا توجد بيانات' : 'No data', style: UT.small)));
          return Container(margin: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(color: Colors.white,
              border: Border.all(color: UC.border), borderRadius: BorderRadius.circular(13)),
            child: Column(children: rows.take(8).map((c) => Padding(
              padding: const EdgeInsets.all(10),
              child: Row(children: [
                CircleAvatar(radius: 18, backgroundColor: UC.yellowFaint,
                  backgroundImage: c.avatarUrl != null
                    ? CachedNetworkImageProvider('${VendorApi.instance.baseUrl}${c.avatarUrl!}')
                    : null,
                  child: c.avatarUrl == null
                    ? Text(c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                        style: const TextStyle(color: UC.brown,
                          fontWeight: FontWeight.w900, fontSize: 13)) : null),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
                  Text('${c.orders} ${ar ? "طلب" : "orders"}', style: UT.small),
                ])),
                Text(c.spent.format(lang), style: const TextStyle(
                  fontFamily: 'monospace', fontWeight: FontWeight.w900,
                  color: UC.brown, fontSize: 12.5)),
              ])
            )).toList()));
        }),
        const SizedBox(height: 24),
      ]),
    );
  }
}
