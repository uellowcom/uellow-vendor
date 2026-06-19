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
        final fbu = VendorApi.instance.vendorType == 'fbu'
            || VendorApi.instance.vendorType == 'consignment';
        return ListView(padding: EdgeInsets.zero, children: [
          _gallery(p),
          Container(color: Colors.white, padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // status pills
              Wrap(spacing: 6, runSpacing: 6, children: [
                UPill(text: p.approvalState.toUpperCase(),
                  bg: p.approvalState == 'approved' ? UC.successBg : UC.warnBg,
                  fg: p.approvalState == 'approved' ? UC.successDk : const Color(0xFF92400E),
                  icon: p.approvalState == 'approved' ? Icons.verified : Icons.hourglass_top),
                UPill(
                  text: p.isPublished ? (ar ? 'منشور' : 'PUBLISHED') : (ar ? 'غير منشور' : 'DRAFT'),
                  bg: p.isPublished ? UC.infoBg : UC.bg,
                  fg: p.isPublished ? const Color(0xFF075985) : UC.muted,
                  icon: p.isPublished ? Icons.public : Icons.public_off),
                UPill(
                  text: (p.inStock || p.allowOos)
                    ? (ar ? 'متوفر' : 'IN STOCK')
                    : (ar ? 'نفد' : 'OUT OF STOCK'),
                  bg: (p.inStock || p.allowOos) ? UC.successBg : UC.dangerBg,
                  fg: (p.inStock || p.allowOos) ? UC.successDk : UC.dangerDk),
                if (!p.active)
                  UPill(text: ar ? 'مؤرشف' : 'ARCHIVED', bg: UC.dangerBg, fg: UC.dangerDk,
                    icon: Icons.inventory_2_outlined),
              ]),
              const SizedBox(height: 12),
              Text(p.name.t(lang), style: UT.h1),
              if (p.categoryName.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(p.categoryName, style: UT.small),
              ],
              const SizedBox(height: 14),
              // COST PRIMARY — vendor-facing
              _priceBlock(p, ar, lang, fbu),
              if (!p.active) Padding(padding: const EdgeInsets.only(top: 12),
                child: Container(width: double.infinity, padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: UC.bg, borderRadius: BorderRadius.circular(8)),
                  child: Text(ar
                    ? 'هذا المنتج مؤرشف — غير ظاهر للعملاء ولا يقبل طلبات. استرجعه لإعادته.'
                    : 'This product is archived — hidden from customers. Restore it to bring it back.',
                    style: UT.small))),
              if (p.underReview) Padding(padding: const EdgeInsets.only(top: 12),
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
              if (p.rejectionReason.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12),
                child: Container(padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: UC.dangerBg,
                    borderRadius: BorderRadius.circular(8)),
                  child: Text(p.rejectionReason, style: const TextStyle(
                    color: UC.dangerDk, fontSize: 12)))),
            ])),
          // ── STATISTICS STRIP ──
          _section(ar ? 'الإحصائيات' : 'Statistics', _statsGrid(p, ar, lang)),
          // ── DETAILS ──
          _section(ar ? 'تفاصيل المنتج' : 'Product details', Column(children: [
            if (p.sku.isNotEmpty) _kv('SKU', p.sku),
            if (p.barcode.isNotEmpty) _kv(ar ? 'الباركود' : 'Barcode', p.barcode),
            if (p.weight > 0) _kv(ar ? 'الوزن (كجم)' : 'Weight (kg)', p.weight.toStringAsFixed(2)),
            _kv(ar ? 'سعر التكلفة' : 'Cost price', p.standardPrice.format(lang)),
            _kv(ar ? 'سعر البيع' : 'Sale price', p.listPrice.format(lang)),
            _kv(ar ? 'هامش الربح' : 'Margin', _marginPct(p)),
          ])),
          // ── ACTIONS ──
          if (p.active) _section(ar ? 'الإجراءات' : 'Actions', Column(children: [
            Row(children: [
              Expanded(child: _canUpdateStock
                ? OutlinedButton.icon(onPressed: () => _stockSheet(p),
                    icon: const Icon(Icons.inventory_2, size: 16),
                    label: Text(ar ? 'تحديث المخزون' : 'Update stock'),
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 46)))
                : OutlinedButton.icon(
                    onPressed: _canRestock ? () => _requestRestock(p) : null,
                    icon: const Icon(Icons.add_box_outlined, size: 16),
                    label: Text(ar ? 'طلب تعبئة' : 'Request restock'),
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 46)))),
              const SizedBox(width: 8),
              Expanded(child: ElevatedButton.icon(
                onPressed: () async {
                  await VendorApi.instance.productUpdate(p.id,
                    {'is_published': !p.isPublished});
                  _refresh();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: p.isPublished ? UC.bg : UC.yellow,
                  foregroundColor: UC.brown, elevation: 0,
                  minimumSize: const Size(0, 46)),
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
          const SizedBox(height: 10),
          Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: p.active
              ? OutlinedButton.icon(onPressed: () => _archive(p),
                  icon: const Icon(Icons.delete_outline, size: 16, color: UC.dangerDk),
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

  // ── Image gallery ──
  Widget _gallery(ProductDetail p) {
    final base = VendorApi.instance.baseUrl;
    final urls = <String>[
      if (p.imageUrl != null) p.imageUrl!,
      ...p.gallery.where((g) => g != p.imageUrl),
    ];
    if (urls.isEmpty) {
      return Container(color: UC.yellowFaint, height: 220,
        child: const Icon(Icons.image_outlined, size: 56, color: UC.brown));
    }
    final controller = PageController();
    final main = AspectRatio(aspectRatio: 1.2,
      child: PageView.builder(
        controller: controller,
        itemCount: urls.length,
        itemBuilder: (_, i) => CachedNetworkImage(
          imageUrl: '$base${urls[i]}',
          fit: BoxFit.contain,
          placeholder: (_, __) => const USpinner(),
          errorWidget: (_, __, ___) => Container(color: UC.yellowFaint,
            child: const Icon(Icons.broken_image_outlined, size: 48, color: UC.brown)))));
    final thumbs = Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: SizedBox(height: 56,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: urls.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) => GestureDetector(
            onTap: () => controller.animateToPage(i,
              duration: const Duration(milliseconds: 250), curve: Curves.easeOut),
            child: ClipRRect(borderRadius: BorderRadius.circular(8),
              child: Container(width: 56, height: 56, color: UC.bg,
                child: CachedNetworkImage(imageUrl: '$base${urls[i]}',
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => const Icon(Icons.image, size: 20, color: UC.brown))))))));
    return Container(color: Colors.white,
      child: Column(children: [
        main,
        if (urls.length > 1) thumbs else const SizedBox(height: 4),
      ]));
  }

  // ── COST-PRIMARY price block (vendor-facing) ──
  Widget _priceBlock(ProductDetail p, bool ar, String lang, bool fbu) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: UC.yellowFaint, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: UC.yellow.withValues(alpha: .5))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text((ar ? 'تكلفتك' : 'Your cost').toUpperCase(), style: const TextStyle(
          fontSize: 10.5, fontWeight: FontWeight.w900, color: UC.brownSoft, letterSpacing: .5)),
        const SizedBox(height: 3),
        Text(p.standardPrice.format(lang), style: const TextStyle(
          fontSize: 28, fontWeight: FontWeight.w900, color: UC.brown, height: 1.1)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _miniPrice(
            ar ? 'سعر البيع' : 'Sale price', p.listPrice.format(lang))),
          Container(width: 1, height: 28, color: UC.yellow.withValues(alpha: .5)),
          Expanded(child: _miniPrice(ar ? 'الهامش' : 'Margin', _marginPct(p))),
        ]),
        if (fbu) Padding(padding: const EdgeInsets.only(top: 10),
          child: Row(children: [
            const Icon(Icons.info_outline, size: 14, color: UC.brownSoft),
            const SizedBox(width: 6),
            Expanded(child: Text(
              ar ? 'عائدك (تخزين لدى يلو) = التكلفة' : 'Your payout (stored at Uellow) = cost',
              style: const TextStyle(fontSize: 11.5, color: UC.brownSoft,
                fontWeight: FontWeight.w700))),
          ])),
      ]));
  }

  Widget _miniPrice(String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 10),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(k, style: UT.tiny),
      const SizedBox(height: 2),
      Text(v, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: UC.brown)),
    ]));

  // ── Statistics grid ──
  Widget _statsGrid(ProductDetail p, bool ar, String lang) {
    final inStock = p.inStock || p.allowOos;
    final tiles = <Widget>[
      _statTile(Icons.shopping_bag_outlined, ar ? 'مبيعات' : 'Units sold',
        p.salesCount.toStringAsFixed(0), UC.info, UC.infoBg),
      _statTile(Icons.inventory_2_outlined, ar ? 'المخزون' : 'Stock',
        inStock && p.qty <= 0 && p.allowOos
          ? (ar ? 'مفتوح' : 'Open')
          : p.qty.toStringAsFixed(0),
        inStock ? UC.success : UC.danger,
        inStock ? UC.successBg : UC.dangerBg),
      _statTile(Icons.percent, ar ? 'الهامش' : 'Margin', _marginPct(p),
        UC.brown, UC.yellowFaint),
      _statTile(Icons.sell_outlined, ar ? 'سعر البيع' : 'Sale price',
        p.listPrice.format(lang), UC.brown, UC.bg),
    ];
    return LayoutBuilder(builder: (_, c) {
      final w = (c.maxWidth - 10) / 2;
      return Wrap(spacing: 10, runSpacing: 10,
        children: tiles.map((t) => SizedBox(width: w, child: t)).toList());
    });
  }

  Widget _statTile(IconData icon, String label, String value, Color fg, Color bg) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
    child: Row(children: [
      Container(width: 34, height: 34,
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .65),
          borderRadius: BorderRadius.circular(9)),
        child: Icon(icon, size: 18, color: fg)),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: UT.tiny, maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: fg),
          maxLines: 1, overflow: TextOverflow.ellipsis),
      ])),
    ]));

  Widget _section(String title, Widget child) => Container(
    margin: const EdgeInsets.only(top: 8), color: Colors.white,
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title.toUpperCase(), style: const TextStyle(fontSize: 10.5,
        fontWeight: FontWeight.w900, color: UC.muted, letterSpacing: .5)),
      const SizedBox(height: 12),
      child,
    ]));

  String _marginPct(ProductDetail p) {
    if (p.marginPct != 0) return '${p.marginPct.toStringAsFixed(1)}%';
    final sale = p.listPrice.amount, cost = p.standardPrice.amount;
    if (sale <= 0) return '—';
    return '${((sale - cost) / sale * 100).toStringAsFixed(1)}%';
  }

  Widget _kv(String k, String v) => Padding(padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(children: [
      Expanded(child: Text(k, style: UT.body)),
      Text(v, style: const TextStyle(fontWeight: FontWeight.w800, color: UC.brown)),
    ]));
}
