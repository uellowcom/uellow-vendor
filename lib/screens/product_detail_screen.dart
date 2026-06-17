import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../api/api.dart';
import '../theme/theme.dart';

class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({super.key, required this.productId});
  final int productId;
  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  Future<ProductDetail>? _f;
  bool _canUpdateStock = true;
  bool _canRestock = true;
  @override
  void initState() {
    super.initState();
    _f = VendorApi.instance.productDetail(widget.productId);
    _checkCaps();
  }
  Future<void> _checkCaps() async {
    try {
      final caps = await VendorApi.instance.capabilities();
      final c = (caps['capabilities'] as Map?) ?? const {};
      if (mounted) setState(() {
        _canUpdateStock = c['update_stock'] != false;
        _canRestock = c['restock'] != false;
      });
    } catch (_) {}
  }
  Future<void> _refresh() async {
    setState(() => _f = VendorApi.instance.productDetail(widget.productId));
    await _f;
  }

  Future<void> _restore(ProductDetail p) async {
    final ar = VendorApi.instance.lang == 'ar';
    try {
      await VendorApi.instance.productRestore(p.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ar ? 'تم استرجاع المنتج' : 'Product restored')));
      _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  /// FBU / restock-only vendors can't set stock directly — they request it.
  Future<void> _requestRestock(ProductDetail p) async {
    final ar = VendorApi.instance.lang == 'ar';
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: Text(ar ? 'طلب تعبئة' : 'Request restock'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(p.name.t(ar ? 'ar' : 'en'), style: UT.body),
        const SizedBox(height: 10),
        TextField(controller: ctrl, keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: ar ? 'الكمية' : 'Quantity',
            border: const OutlineInputBorder())),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: Text(ar ? 'إلغاء' : 'Cancel')),
        FilledButton(onPressed: () => Navigator.pop(c, true),
          style: FilledButton.styleFrom(backgroundColor: UC.brown, foregroundColor: UC.yellow),
          child: Text(ar ? 'إرسال' : 'Submit')),
      ]));
    if (ok != true) return;
    final qty = int.tryParse(ctrl.text.trim()) ?? 0;
    if (qty <= 0) return;
    // restock endpoint targets a stockable variant (product.product id).
    final variantId = p.variants.isNotEmpty
      ? (p.variants.first['id'] as int? ?? p.id) : p.id;
    try {
      await VendorApi.instance.restockCreate(variantId, qty, '');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ar ? 'تم إرسال طلب التعبئة' : 'Restock request sent')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _stockSheet(ProductDetail p) async {
    final ar = VendorApi.instance.lang == 'ar';
    final ctrl = TextEditingController(text: p.qty.toStringAsFixed(0));
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: Text(ar ? 'تحديث المخزون' : 'Update stock'),
      content: TextField(controller: ctrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: ar ? 'الكمية' : 'Quantity')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(ar ? 'إلغاء' : 'Cancel')),
        ElevatedButton(onPressed: () => Navigator.pop(context, true), child: Text(ar ? 'حفظ' : 'Save')),
      ]));
    if (ok != true) return;
    try {
      await VendorApi.instance.productSetStock(p.id, double.tryParse(ctrl.text.trim()) ?? 0);
      _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _archive(ProductDetail p) async {
    final ar = VendorApi.instance.lang == 'ar';
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: Text(ar ? 'أرشفة المنتج' : 'Archive product'),
      content: Text(ar
        ? 'سيتم إخفاء المنتج من المتجر. لن يُحذف لأنه قد يكون مرتبط بطلبات سابقة.'
        : 'Product will be hidden from the store but kept for past orders.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(ar ? 'إلغاء' : 'Cancel')),
        ElevatedButton(onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(backgroundColor: UC.danger, foregroundColor: Colors.white),
          child: Text(ar ? 'أرشفة' : 'Archive')),
      ]));
    if (ok != true) return;
    try {
      await VendorApi.instance.productArchive(p.id);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ar = VendorApi.instance.lang == 'ar';
    final lang = ar ? 'ar' : 'en';
    return Scaffold(
      appBar: AppBar(title: Text(ar ? 'تفاصيل المنتج' : 'Product detail'),
        actions: [
          IconButton(icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              await Navigator.pushNamed(context, '/product-edit',
                arguments: {'id': widget.productId});
              _refresh();
            }),
        ]),
      body: FutureBuilder<ProductDetail>(future: _f, builder: (_, snap) {
        if (snap.connectionState != ConnectionState.done) return const Center(child: USpinner());
        if (snap.hasError) return Center(child: Padding(padding: const EdgeInsets.all(24),
          child: Text(snap.error.toString(), style: UT.body, textAlign: TextAlign.center)));
        final p = snap.data!;
        return ListView(padding: EdgeInsets.zero, children: [
          if (p.imageUrl != null) AspectRatio(aspectRatio: 1.4,
            child: CachedNetworkImage(
              imageUrl: '${VendorApi.instance.baseUrl}${p.imageUrl!}',
              fit: BoxFit.cover,
              errorWidget: (_,__,___) => Container(color: UC.yellowFaint,
                child: const Icon(Icons.image, size: 48, color: UC.brown))))
          else Container(color: UC.yellowFaint, height: 200,
            child: const Icon(Icons.image, size: 56, color: UC.brown)),
          Container(color: Colors.white, padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.name.t(lang), style: UT.h1),
              const SizedBox(height: 6),
              Row(children: [
                Text(p.listPrice.format(lang), style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w900, color: UC.brown)),
                const SizedBox(width: 8),
                UPill(text: p.approvalState.toUpperCase(),
                  bg: p.approvalState == 'approved' ? UC.successBg : UC.warnBg,
                  fg: p.approvalState == 'approved' ? UC.successDk : const Color(0xFF92400E)),
                if (!p.active) ...[
                  const SizedBox(width: 6),
                  UPill(text: ar ? 'مؤرشف' : 'ARCHIVED', bg: UC.dangerBg, fg: UC.dangerDk),
                ],
              ]),
              if (!p.active) Padding(padding: const EdgeInsets.only(top: 8),
                child: Container(width: double.infinity, padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: UC.bg, borderRadius: BorderRadius.circular(8)),
                  child: Text(ar
                    ? 'هذا المنتج مؤرشف — غير ظاهر للعملاء ولا يقبل طلبات. استرجعه لإعادته.'
                    : 'This product is archived — hidden from customers. Restore it to bring it back.',
                    style: UT.small))),
              if (p.underReview) Padding(padding: const EdgeInsets.only(top: 8),
                child: Container(width: double.infinity, padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: UC.warnBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFF0D49A))),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const Icon(Icons.hourglass_top, size: 16, color: Color(0xFF92400E)),
                      const SizedBox(width: 6),
                      Text(ar ? 'قيد المراجعة' : 'Under review',
                        style: const TextStyle(fontWeight: FontWeight.w900,
                          color: Color(0xFF92400E), fontSize: 13)),
                    ]),
                    const SizedBox(height: 4),
                    Text(ar
                      ? 'تعديلك بانتظار موافقة الأدمن — يعمل المنتج بالقيمة القديمة حتى الاعتماد.'
                      : 'Your edit awaits admin approval — the product keeps its old values until then.',
                      style: UT.small),
                    if (p.pendingChange.isNotEmpty) Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(p.pendingChange,
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF6b4516)))),
                  ]))),
              if (p.rejectionReason.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8),
                child: Container(padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: UC.dangerBg,
                    borderRadius: BorderRadius.circular(8)),
                  child: Text(p.rejectionReason, style: const TextStyle(
                    color: UC.dangerDk, fontSize: 12)))),
            ])),
          _section(ar ? 'المخزون والسعر' : 'Inventory & price', Column(children: [
            _kv(ar ? 'الكمية المتاحة' : 'Qty available', p.qty.toStringAsFixed(0)),
            _kv(ar ? 'سعر التكلفة' : 'Cost', p.standardPrice.format(lang)),
            _kv(ar ? 'سعر البيع' : 'Sale price', p.listPrice.format(lang)),
            _kv(ar ? 'هامش الربح' : 'Margin', _marginPct(p)),
            if (VendorApi.instance.vendorType == 'fbu'
                || VendorApi.instance.vendorType == 'consignment')
              _kv(ar ? 'عائدك (تخزين لدى يلو) = التكلفة' : 'Your payout (stored at Uellow) = cost',
                p.standardPrice.format(lang)),
            if (p.sku.isNotEmpty) _kv('SKU', p.sku),
            if (p.barcode.isNotEmpty) _kv('Barcode', p.barcode),
            if (p.weight > 0) _kv(ar ? 'الوزن (كجم)' : 'Weight (kg)', p.weight.toStringAsFixed(2)),
            const SizedBox(height: 8),
            if (p.active) Row(children: [
              Expanded(child: _canUpdateStock
                ? OutlinedButton.icon(onPressed: () => _stockSheet(p),
                    icon: const Icon(Icons.inventory_2, size: 16),
                    label: Text(ar ? 'تحديث المخزون' : 'Update stock'))
                : OutlinedButton.icon(
                    onPressed: _canRestock ? () => _requestRestock(p) : null,
                    icon: const Icon(Icons.add_box_outlined, size: 16),
                    label: Text(ar ? 'طلب تعبئة' : 'Request restock'))),
              const SizedBox(width: 6),
              Expanded(child: ElevatedButton.icon(
                onPressed: () async {
                  await VendorApi.instance.productUpdate(p.id,
                    {'is_published': !p.isPublished});
                  _refresh();
                },
                icon: Icon(p.isPublished ? Icons.visibility_off : Icons.visibility, size: 16),
                label: Text(p.isPublished
                  ? (ar ? 'إخفاء' : 'Unpublish')
                  : (ar ? 'نشر' : 'Publish')))),
            ]),
          ])),
          if (p.descriptionSale.isNotEmpty || p.description.isNotEmpty)
            _section(ar ? 'الوصف' : 'Description',
              Text(p.descriptionSale.isNotEmpty ? p.descriptionSale : p.description,
                style: UT.body)),
          if (p.variants.length > 1) _section(ar ? 'المتغيرات' : 'Variants',
            Column(children: p.variants.map((v) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                Expanded(child: Text((v['name'] ?? '').toString(),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5))),
                Text('${(v['qty'] ?? 0).toStringAsFixed(0)} pcs', style: UT.small),
                const SizedBox(width: 8),
                Text(((v['price'] as Map?)?['amount'] ?? '0').toString(),
                  style: const TextStyle(fontWeight: FontWeight.w900, color: UC.brown)),
              ]))).toList())),
          const SizedBox(height: 18),
          Padding(padding: const EdgeInsets.all(14),
            child: p.active
              ? OutlinedButton.icon(onPressed: () => _archive(p),
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: Text(ar ? 'أرشفة المنتج' : 'Archive product',
                    style: const TextStyle(color: UC.dangerDk, fontWeight: FontWeight.w800)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: UC.dangerBg, width: 1.5),
                    minimumSize: const Size(double.infinity, 46)))
              : ElevatedButton.icon(onPressed: () => _restore(p),
                  icon: const Icon(Icons.restore, size: 18),
                  label: Text(ar ? 'استرجاع المنتج' : 'Restore product'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: UC.yellow, foregroundColor: UC.brown,
                    minimumSize: const Size(double.infinity, 48)))),
          const SizedBox(height: 24),
        ]);
      }),
    );
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

  String _marginPct(ProductDetail p) {
    final sale = p.listPrice.amount, cost = p.standardPrice.amount;
    if (sale <= 0) return '—';
    return '${((sale - cost) / sale * 100).toStringAsFixed(1)}%';
  }

  Widget _kv(String k, String v) => Padding(padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(children: [
      Expanded(child: Text(k, style: UT.body)),
      Text(v, style: const TextStyle(fontWeight: FontWeight.w800, color: UC.brown)),
    ]));
}
