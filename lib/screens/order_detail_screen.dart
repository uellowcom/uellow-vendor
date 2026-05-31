import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api/api.dart';
import '../theme/theme.dart';

class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({super.key, required this.orderId});
  final int orderId;
  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  Future<OrderDetail>? _f;
  bool _busy = false;
  @override
  void initState() { super.initState(); _f = VendorApi.instance.orderDetail(widget.orderId); }
  Future<void> _refresh() async {
    setState(() => _f = VendorApi.instance.orderDetail(widget.orderId));
    await _f;
  }

  Future<void> _do(Future<void> Function() fn, String okMsg) async {
    setState(() => _busy = true);
    try {
      await fn();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(okMsg)));
      _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _cancel() async {
    final ar = VendorApi.instance.lang == 'ar';
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: Text(ar ? 'إلغاء الطلب' : 'Cancel order'),
      content: TextField(controller: ctrl, decoration: InputDecoration(
        labelText: ar ? 'سبب الإلغاء' : 'Cancellation reason')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(ar ? 'تراجع' : 'Back')),
        ElevatedButton(onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(backgroundColor: UC.danger, foregroundColor: Colors.white),
          child: Text(ar ? 'تأكيد الإلغاء' : 'Confirm')),
      ]));
    if (ok != true) return;
    _do(() async => VendorApi.instance.orderCancel(widget.orderId,
        ctrl.text.trim().isEmpty ? 'Vendor cancelled' : ctrl.text.trim()),
      ar ? 'تم الإلغاء' : 'Cancelled');
  }

  @override
  Widget build(BuildContext context) {
    final ar = VendorApi.instance.lang == 'ar';
    final lang = ar ? 'ar' : 'en';
    return Scaffold(
      appBar: AppBar(title: Text('#${widget.orderId}'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh),
        ]),
      body: FutureBuilder<OrderDetail>(future: _f, builder: (_, snap) {
        if (snap.connectionState != ConnectionState.done) return const Center(child: USpinner());
        if (snap.hasError) return Center(child: Padding(padding: const EdgeInsets.all(24),
          child: Text(snap.error.toString(), style: UT.body, textAlign: TextAlign.center)));
        final o = snap.data!;
        final addr = o.shippingAddress;
        return RefreshIndicator(onRefresh: _refresh,
          child: ListView(padding: EdgeInsets.zero, children: [
            Container(padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
              color: Colors.white, width: double.infinity,
              child: Row(children: [
                UPill(text: o.stateLabel.t(lang),
                  bg: UC.successBg, fg: UC.successDk, live: o.state == 'sale'),
                const Spacer(),
                Text(o.name, style: const TextStyle(
                  fontFamily: 'monospace', fontWeight: FontWeight.w900,
                  color: UC.muted, fontSize: 12)),
              ])),
            _section(ar ? 'العميل' : 'Customer', Column(children: [
              _row(Icons.person_outline,
                (o.customer['name'] ?? '').toString(),
                (o.customer['phone'] ?? '').toString()),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: OutlinedButton.icon(
                  onPressed: () => launchUrl(Uri.parse('tel:${o.customer['phone'] ?? ''}'),
                      mode: LaunchMode.externalApplication),
                  icon: const Icon(Icons.phone, size: 16),
                  label: Text(ar ? 'اتصال' : 'Call'))),
                const SizedBox(width: 6),
                Expanded(child: OutlinedButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/chat',
                    arguments: {'id': o.id, 'title': o.customer['name']}),
                  icon: const Icon(Icons.chat_bubble_outline, size: 16),
                  label: Text(ar ? 'محادثة' : 'Chat'))),
              ]),
            ])),
            _section(ar ? 'عنوان الشحن' : 'Shipping address', _row(
              Icons.location_on_outlined,
              '${addr['city'] ?? ''}${(addr['city'] ?? '').toString().isNotEmpty ? ", " : ""}'
              '${addr['street'] ?? ''}',
              [addr['street2'], addr['country']]
                  .where((x) => x != null && x.toString().isNotEmpty)
                  .join(' · '))),
            if (o.items.isNotEmpty) _section(
              ar ? 'العناصر (${o.items.length})' : 'Items (${o.items.length})',
              Column(children: [
                for (final it in o.items) Container(padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: UC.bg))),
                  child: Row(children: [
                    ClipRRect(borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: '${VendorApi.instance.baseUrl}${it.imageUrl}',
                        width: 46, height: 46, fit: BoxFit.cover,
                        errorWidget: (_,__,___) => Container(width: 46, height: 46,
                          color: UC.bg, child: const Icon(Icons.image, color: UC.muted)))),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(it.name.t(lang), maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
                      Text(it.subtotal.format(lang), style: UT.small),
                    ])),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: UC.yellowFaint,
                        borderRadius: BorderRadius.circular(7)),
                      child: Text('×${it.qty.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900,
                          color: UC.brown))),
                  ])),
              ])),
            // Totals
            _section(ar ? 'الإجمالي' : 'Totals', Column(children: [
              _kv(ar ? 'الإجمالي قبل الشحن' : 'Subtotal', o.subtotal.format(lang)),
              _kv(ar ? 'الشحن' : 'Shipping', o.shipping.format(lang)),
              const Divider(),
              _kv(ar ? 'الإجمالي' : 'Total', o.amount.format(lang), bold: true),
            ])),
            const SizedBox(height: 120),
          ]));
      }),
      bottomNavigationBar: FutureBuilder<OrderDetail>(future: _f, builder: (_, snap) {
        if (snap.data == null) return const SizedBox.shrink();
        final o = snap.data!;
        return SafeArea(top: false, child: Container(
          padding: const EdgeInsets.all(14),
          decoration: const BoxDecoration(color: Colors.white,
            border: Border(top: BorderSide(color: UC.border))),
          child: _ctaFor(o, ar),
        ));
      }),
    );
  }

  Widget _ctaFor(OrderDetail o, bool ar) {
    if (_busy) return const Center(child: USpinner());
    switch (o.state) {
      case 'draft':
      case 'sent':
        return Row(children: [
          Expanded(child: OutlinedButton(onPressed: _cancel,
            child: Text(ar ? 'رفض' : 'Reject',
              style: const TextStyle(color: UC.dangerDk, fontWeight: FontWeight.w900)))),
          const SizedBox(width: 8),
          Expanded(flex: 2, child: ElevatedButton.icon(
            onPressed: () => _do(() async => VendorApi.instance.orderConfirm(o.id),
              ar ? 'تم القبول' : 'Confirmed'),
            icon: const Icon(Icons.check, size: 16),
            label: Text(ar ? 'قبول الطلب' : 'Accept order',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)))),
        ]);
      case 'sale':
        return Row(children: [
          Expanded(child: OutlinedButton(onPressed: _cancel,
            child: Text(ar ? 'إلغاء' : 'Cancel',
              style: const TextStyle(color: UC.dangerDk, fontWeight: FontWeight.w900)))),
          const SizedBox(width: 8),
          Expanded(flex: 2, child: ElevatedButton.icon(
            onPressed: () => _do(() async => VendorApi.instance.orderShip(o.id),
              ar ? 'تم التسليم للتوصيل' : 'Marked shipped'),
            style: ElevatedButton.styleFrom(
              backgroundColor: UC.success, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14)),
            icon: const Icon(Icons.local_shipping, size: 16),
            label: Text(ar ? 'جاهز للشحن' : 'Mark shipped',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)))),
        ]);
      default:
        return Container(padding: const EdgeInsets.all(12), alignment: Alignment.center,
          decoration: BoxDecoration(color: UC.bg, borderRadius: BorderRadius.circular(11)),
          child: Text(o.stateLabel.t(ar ? 'ar' : 'en'),
            style: const TextStyle(fontWeight: FontWeight.w900)));
    }
  }

  Widget _section(String title, Widget child) => Container(
    margin: const EdgeInsets.only(top: 8), color: Colors.white,
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title.toUpperCase(), style: const TextStyle(fontSize: 10.5,
        fontWeight: FontWeight.w800, color: UC.muted, letterSpacing: .4)),
      const SizedBox(height: 8),
      child,
    ]));

  Widget _row(IconData ic, String a, String b) => Row(children: [
    Container(width: 32, height: 32, alignment: Alignment.center,
      decoration: BoxDecoration(color: UC.yellowFaint, borderRadius: BorderRadius.circular(9)),
      child: Icon(ic, color: UC.brown, size: 16)),
    const SizedBox(width: 10),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(a, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
      Text(b, style: UT.small),
    ])),
  ]);

  Widget _kv(String k, String v, {bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(children: [
      Expanded(child: Text(k, style: TextStyle(fontSize: 12.5,
        fontWeight: bold ? FontWeight.w900 : FontWeight.w600,
        color: bold ? UC.ink : UC.text))),
      Text(v, style: TextStyle(fontSize: bold ? 14 : 12.5,
        fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
        color: bold ? UC.brown : UC.text, fontFamily: 'monospace')),
    ]));
}
