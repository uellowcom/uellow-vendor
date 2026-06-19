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

  Future<void> _openDoc(Future<String> Function() get, String failMsg) async {
    setState(() => _busy = true);
    try {
      final url = await get();
      if (url.isEmpty) throw Exception(failMsg);
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _cancel() async {
    final ar = VendorApi.instance.lang == 'ar';
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: Text(ar ? 'رفض / إلغاء الطلب' : 'Reject / cancel order'),
      content: TextField(controller: ctrl, decoration: InputDecoration(
        labelText: ar ? 'السبب' : 'Reason')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(ar ? 'تراجع' : 'Back')),
        ElevatedButton(onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(backgroundColor: UC.danger, foregroundColor: Colors.white),
          child: Text(ar ? 'تأكيد' : 'Confirm')),
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

            // ── Tracking timeline (everyone, incl. FBU) ──
            if (o.tracking.steps.isNotEmpty)
              _section(ar ? 'تتبّع الطلب' : 'Order tracking', _tracking(o, ar)),

            // ── FBU notice (no controls) ──
            if (o.minimal) Container(
              margin: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: UC.infoBg, borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                const Icon(Icons.verified_user_outlined, color: UC.info, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(
                  ar ? 'يلو تتولّى تجهيز وتوصيل هذا الطلب بالكامل. تابع الحالة من شريط التتبّع.'
                     : 'Uellow fulfils & delivers this order. Track its status above.',
                  style: const TextStyle(color: UC.info, fontSize: 12, fontWeight: FontWeight.w600))),
              ])),

            _section(ar ? 'العميل' : 'Customer', Column(children: [
              _row(Icons.person_outline,
                (o.customer['name'] ?? '').toString(),
                [o.customer['city'], o.customer['country']]
                    .where((x) => x != null && x.toString().isNotEmpty).join(' · ')),
              if (!o.minimal) ...[
                const SizedBox(height: 8),
                Row(children: [
                  if ((o.customer['phone'] ?? '').toString().isNotEmpty)
                    Expanded(child: OutlinedButton.icon(
                      onPressed: () => launchUrl(Uri.parse('tel:${o.customer['phone'] ?? ''}'),
                          mode: LaunchMode.externalApplication),
                      icon: const Icon(Icons.phone, size: 16),
                      label: Text(ar ? 'اتصال' : 'Call'))),
                  if ((o.customer['phone'] ?? '').toString().isNotEmpty) const SizedBox(width: 6),
                  Expanded(child: OutlinedButton.icon(
                    onPressed: () => Navigator.pushNamed(context, '/chat',
                      arguments: {'id': o.id, 'title': o.customer['name']}),
                    icon: const Icon(Icons.chat_bubble_outline, size: 16),
                    label: Text(ar ? 'محادثة' : 'Chat'))),
                ]),
              ],
            ])),

            // ── Shipping address (full only for non-FBU) ──
            _section(ar ? 'عنوان الشحن' : 'Shipping address', _row(
              Icons.location_on_outlined,
              '${addr['city'] ?? ''}${(addr['city'] ?? '').toString().isNotEmpty && (addr['street'] ?? '').toString().isNotEmpty ? ", " : ""}'
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

            _section(ar ? 'الإجمالي' : 'Totals', Column(children: [
              _kv(ar ? 'الإجمالي قبل الشحن' : 'Subtotal', o.subtotal.format(lang)),
              _kv(ar ? 'الشحن' : 'Shipping', o.shipping.format(lang)),
              const Divider(),
              _kv(ar ? 'الإجمالي' : 'Total', o.amount.format(lang), bold: true),
            ])),
            const SizedBox(height: 130),
          ]));
      }),
      bottomNavigationBar: FutureBuilder<OrderDetail>(future: _f, builder: (_, snap) {
        if (snap.data == null) return const SizedBox.shrink();
        final o = snap.data!;
        final bar = _ctaFor(o, ar);
        if (bar == null) return const SizedBox.shrink();
        return SafeArea(top: false, child: Container(
          padding: const EdgeInsets.all(14),
          decoration: const BoxDecoration(color: Colors.white,
            border: Border(top: BorderSide(color: UC.border))),
          child: bar,
        ));
      }),
    );
  }

  // ── Tracking timeline widget ──
  Widget _tracking(OrderDetail o, bool ar) {
    final tr = o.tracking;
    final lang = ar ? 'ar' : 'en';
    if (tr.cancelled) {
      return Row(children: [
        const Icon(Icons.cancel, color: UC.dangerDk, size: 20),
        const SizedBox(width: 8),
        Text(ar ? 'تم إلغاء الطلب' : 'Order cancelled',
          style: const TextStyle(color: UC.dangerDk, fontWeight: FontWeight.w900)),
      ]);
    }
    return Column(children: [
      Row(children: [
        for (int i = 0; i < tr.steps.length; i++) ...[
          _dot(tr.steps[i]),
          if (i < tr.steps.length - 1)
            Expanded(child: Container(height: 3,
              color: tr.steps[i + 1].done ? UC.success : UC.border)),
        ],
      ]),
      const SizedBox(height: 6),
      Row(children: [
        for (final s in tr.steps) Expanded(child: Text(s.t(lang),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 9.5,
            fontWeight: s.current ? FontWeight.w900 : FontWeight.w600,
            color: s.done ? UC.successDk : UC.muted))),
      ]),
      if (tr.failed) Padding(padding: const EdgeInsets.only(top: 8),
        child: Text(ar ? '⚠ فشل التسليم' : '⚠ Delivery failed',
          style: const TextStyle(color: UC.dangerDk, fontWeight: FontWeight.w800, fontSize: 12))),
      if (tr.driver.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8),
        child: Row(children: [
          const Icon(Icons.delivery_dining, size: 16, color: UC.brown),
          const SizedBox(width: 6),
          Text('${ar ? "السائق" : "Driver"}: ${tr.driver}', style: UT.small),
        ])),
    ]);
  }

  Widget _dot(TrackStep s) => Container(
    width: 24, height: 24, alignment: Alignment.center,
    decoration: BoxDecoration(shape: BoxShape.circle,
      color: s.done ? UC.success : Colors.white,
      border: Border.all(color: s.done ? UC.success : UC.border, width: 2)),
    child: s.done
      ? const Icon(Icons.check, size: 13, color: Colors.white)
      : Container(width: 7, height: 7, decoration: const BoxDecoration(
          shape: BoxShape.circle, color: UC.muted)));

  // ── Bottom CTA bar (null = no bar, e.g. FBU) ──
  Widget? _ctaFor(OrderDetail o, bool ar) {
    if (_busy) return const Center(child: USpinner());
    if (o.minimal) return null; // FBU: no controls
    final buttons = <Widget>[];

    // Accept / Reject for incoming
    if (o.act('can_accept')) {
      buttons.add(Expanded(flex: 2, child: ElevatedButton.icon(
        onPressed: () => _do(() async => VendorApi.instance.orderConfirm(o.id),
          ar ? 'تم القبول' : 'Accepted'),
        icon: const Icon(Icons.check, size: 16),
        label: Text(ar ? 'قبول الطلب' : 'Accept', style: _bs))));
    }
    // Prepare → ready for pickup
    if (o.act('can_prepare')) {
      buttons.add(Expanded(flex: 2, child: ElevatedButton.icon(
        onPressed: () => _do(() async => VendorApi.instance.orderPrepare(o.id),
          ar ? 'جاهز للاستلام' : 'Ready for pickup'),
        style: ElevatedButton.styleFrom(backgroundColor: UC.success, foregroundColor: Colors.white),
        icon: const Icon(Icons.inventory_2, size: 16),
        label: Text(ar ? 'تجهيز للاستلام' : 'Mark ready', style: _bs))));
    } else if (o.act('ready_for_pickup')) {
      buttons.add(Expanded(flex: 2, child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13), alignment: Alignment.center,
        decoration: BoxDecoration(color: UC.successBg, borderRadius: BorderRadius.circular(11)),
        child: Text(ar ? '✓ جاهز للاستلام' : '✓ Ready for pickup',
          style: const TextStyle(color: UC.successDk, fontWeight: FontWeight.w900)))));
    }
    if (o.act('can_reject')) {
      buttons.insert(0, Expanded(child: OutlinedButton(onPressed: _cancel,
        child: Text(ar ? 'رفض' : 'Reject',
          style: const TextStyle(color: UC.dangerDk, fontWeight: FontWeight.w900)))));
    }

    final docRow = <Widget>[];
    if (o.act('can_print_label')) {
      docRow.add(Expanded(child: OutlinedButton.icon(
        onPressed: () => _openDoc(() => VendorApi.instance.orderLabelUrl(o.id),
          ar ? 'تعذّر إنشاء الملصق' : 'Could not create label'),
        icon: const Icon(Icons.local_shipping_outlined, size: 16),
        label: Text(ar ? 'طباعة ليبل' : 'Print label'))));
    }
    if (o.act('can_print_invoice')) {
      if (docRow.isNotEmpty) docRow.add(const SizedBox(width: 8));
      docRow.add(Expanded(child: OutlinedButton.icon(
        onPressed: () => _openDoc(() => VendorApi.instance.orderInvoiceUrl(o.id),
          ar ? 'تعذّر إنشاء الفاتورة' : 'Could not create invoice'),
        icon: const Icon(Icons.receipt_long_outlined, size: 16),
        label: Text(ar ? 'طباعة فاتورة' : 'Print invoice'))));
    }

    if (buttons.isEmpty && docRow.isEmpty) return null;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      if (docRow.isNotEmpty) Row(children: docRow),
      if (docRow.isNotEmpty && buttons.isNotEmpty) const SizedBox(height: 8),
      if (buttons.isNotEmpty)
        Row(children: [
          for (int i = 0; i < buttons.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            buttons[i],
          ],
        ]),
    ]);
  }

  static const _bs = TextStyle(fontWeight: FontWeight.w900, fontSize: 14);

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
      if (b.isNotEmpty) Text(b, style: UT.small),
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
