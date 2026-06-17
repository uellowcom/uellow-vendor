import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../api/api.dart';
import '../theme/theme.dart';

class ProductEditScreen extends StatefulWidget {
  const ProductEditScreen({super.key, this.productId});
  final int? productId;
  @override
  State<ProductEditScreen> createState() => _ProductEditScreenState();
}

class _ProductEditScreenState extends State<ProductEditScreen> {
  final _nameEn = TextEditingController();
  final _nameAr = TextEditingController();
  final _price = TextEditingController();
  final _cost = TextEditingController();
  final _sku = TextEditingController();
  final _barcode = TextEditingController();
  final _weight = TextEditingController();
  final _desc = TextEditingController();
  Uint8List? _image;
  final List<Uint8List> _gallery = [];
  List<Map<String, dynamic>> _cats = [];
  int? _categoryId;
  bool _busy = false, _loading = true;
  ProductDetail? _existing;
  String? _err;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try { _cats = await VendorApi.instance.categories(); } catch (_) {}
    if (widget.productId != null) {
      try {
        final p = await VendorApi.instance.productDetail(widget.productId!);
        _existing = p;
        _nameEn.text = p.nameEn.isNotEmpty ? p.nameEn : p.name.en;
        _nameAr.text = p.nameAr.isNotEmpty ? p.nameAr : p.name.ar;
        _price.text = p.listPrice.amount.toStringAsFixed(p.listPrice.digits);
        _cost.text = p.standardPrice.amount > 0
          ? p.standardPrice.amount.toStringAsFixed(p.standardPrice.digits) : '';
        _sku.text = p.sku;
        _barcode.text = p.barcode;
        _weight.text = p.weight > 0 ? p.weight.toString() : '';
        _desc.text = p.descriptionSale;
        if (p.categoryId > 0) _categoryId = p.categoryId;
      } catch (_) {}
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _nameEn.dispose(); _nameAr.dispose(); _price.dispose(); _cost.dispose();
    _sku.dispose(); _barcode.dispose(); _weight.dispose(); _desc.dispose();
    super.dispose();
  }

  Future<void> _pickMain(ImageSource src) async {
    final p = await ImagePicker().pickImage(source: src, maxWidth: 1280, imageQuality: 85);
    if (p == null) return;
    final b = await File(p.path).readAsBytes();
    setState(() => _image = b);
  }

  Future<void> _addGallery() async {
    final imgs = await ImagePicker().pickMultiImage(maxWidth: 1280, imageQuality: 85);
    for (final x in imgs) {
      _gallery.add(await File(x.path).readAsBytes());
    }
    if (mounted) setState(() {});
  }

  void _photoSheet() {
    final ar = VendorApi.instance.lang == 'ar';
    showModalBottomSheet(context: context, builder: (sheet) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: const Icon(Icons.camera_alt_outlined),
          title: Text(ar ? 'التقط صورة' : 'Take photo'),
          onTap: () { Navigator.pop(sheet); _pickMain(ImageSource.camera); }),
        ListTile(leading: const Icon(Icons.photo_library_outlined),
          title: Text(ar ? 'من المعرض' : 'From gallery'),
          onTap: () { Navigator.pop(sheet); _pickMain(ImageSource.gallery); }),
      ])));
  }

  Future<void> _save() async {
    final ar = VendorApi.instance.lang == 'ar';
    if (_nameEn.text.trim().isEmpty && _nameAr.text.trim().isEmpty) {
      setState(() => _err = ar ? 'الاسم مطلوب (عربي أو إنجليزي)' : 'Name required (AR or EN)');
      return;
    }
    final price = double.tryParse(_price.text.trim()) ?? 0;
    final cost = double.tryParse(_cost.text.trim());
    final weight = double.tryParse(_weight.text.trim());
    setState(() { _busy = true; _err = null; });
    try {
      if (widget.productId == null) {
        await VendorApi.instance.productCreate(
          name: _nameEn.text.trim().isNotEmpty ? _nameEn.text.trim() : _nameAr.text.trim(),
          nameAr: _nameAr.text.trim(),
          price: price, cost: cost, weight: weight,
          description: _desc.text.trim(), sku: _sku.text.trim(),
          barcode: _barcode.text.trim(), categoryId: _categoryId,
          image: _image, gallery: _gallery);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ar ? 'تم إرسال المنتج للمراجعة' : 'Product sent for review')));
        Navigator.pop(context, true);
      } else {
        final body = <String, dynamic>{
          'name': _nameEn.text.trim(),
          'name_ar': _nameAr.text.trim(),
          'list_price': price,
          if (cost != null) 'standard_price': cost,
          if (weight != null) 'weight': weight,
          'default_code': _sku.text.trim(),
          'barcode': _barcode.text.trim(),
          'description_sale': _desc.text.trim(),
          if (_categoryId != null) 'category_id': _categoryId,
          if (_image != null) 'image_base64': base64Encode(_image!),
          if (_gallery.isNotEmpty) 'gallery': _gallery.map((g) => base64Encode(g)).toList(),
        };
        await VendorApi.instance.productUpdate(widget.productId!, body);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ar ? 'أُرسل التعديل للمراجعة' : 'Edit sent for review')));
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() { _busy = false; _err = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ar = VendorApi.instance.lang == 'ar';
    if (_loading) return const Scaffold(body: Center(child: USpinner()));
    final isNew = widget.productId == null;
    return Scaffold(
      appBar: AppBar(title: Text(isNew
        ? (ar ? 'منتج جديد' : 'New product')
        : (ar ? 'تعديل المنتج' : 'Edit product'))),
      body: ListView(padding: const EdgeInsets.all(14), children: [
        // Main image
        Center(child: GestureDetector(onTap: _photoSheet,
          child: Container(width: 120, height: 120,
            decoration: BoxDecoration(color: UC.yellowFaint,
              border: Border.all(color: UC.yellow, width: 2),
              borderRadius: BorderRadius.circular(16)),
            child: _image != null
              ? ClipRRect(borderRadius: BorderRadius.circular(14),
                  child: Image.memory(_image!, fit: BoxFit.cover))
              : (_existing?.imageUrl != null
                  ? ClipRRect(borderRadius: BorderRadius.circular(14),
                      child: Image.network('${VendorApi.instance.baseUrl}${_existing!.imageUrl!}',
                        fit: BoxFit.cover))
                  : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.add_a_photo, size: 32, color: UC.brown),
                      Text(ar ? 'الصورة الرئيسية' : 'Main photo',
                        style: const TextStyle(color: UC.brown, fontWeight: FontWeight.w800, fontSize: 11)),
                    ])),
          ))),
        const SizedBox(height: 12),
        // Gallery
        _lbl(ar ? 'معرض الصور' : 'Gallery'),
        SizedBox(height: 64, child: ListView(scrollDirection: Axis.horizontal, children: [
          for (int i = 0; i < _gallery.length; i++) Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Stack(children: [
              ClipRRect(borderRadius: BorderRadius.circular(10),
                child: Image.memory(_gallery[i], width: 60, height: 60, fit: BoxFit.cover)),
              Positioned(right: 0, top: 0, child: GestureDetector(
                onTap: () => setState(() => _gallery.removeAt(i)),
                child: Container(decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                  child: const Icon(Icons.close, size: 14, color: Colors.white)))),
            ])),
          GestureDetector(onTap: _addGallery, child: Container(width: 60, height: 60,
            decoration: BoxDecoration(color: UC.yellowFaint, borderRadius: BorderRadius.circular(10),
              border: Border.all(color: UC.yellow)),
            child: const Icon(Icons.add, color: UC.brown))),
        ])),
        const SizedBox(height: 12),
        _lbl(ar ? 'الاسم (عربي)' : 'Name (Arabic)'),
        TextField(controller: _nameAr, textDirection: TextDirection.rtl,
          decoration: InputDecoration(hintText: ar ? 'مثل: ساعة ذكية' : 'بالعربية')),
        const SizedBox(height: 12),
        _lbl(ar ? 'الاسم (إنجليزي)' : 'Name (English)'),
        TextField(controller: _nameEn, textDirection: TextDirection.ltr,
          decoration: const InputDecoration(hintText: 'e.g. Smart Watch')),
        const SizedBox(height: 12),
        _lbl(ar ? 'القسم' : 'Category'),
        DropdownButtonFormField<int>(
          value: _categoryId,
          isExpanded: true,
          hint: Text(ar ? 'اختر القسم' : 'Select category'),
          items: _cats.map((c) => DropdownMenuItem<int>(
            value: c['id'] as int,
            child: Text('${(c['name'] as Map?)?[ar ? 'ar' : 'en'] ?? ''}',
              overflow: TextOverflow.ellipsis))).toList(),
          onChanged: (v) => setState(() => _categoryId = v)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _lbl(ar ? 'التكلفة' : 'Cost'),
            TextField(controller: _cost,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(suffixText: 'KD')),
          ])),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _lbl(ar ? 'سعر البيع' : 'Sale price'),
            TextField(controller: _price,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(suffixText: 'KD')),
          ])),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _lbl('SKU'),
            TextField(controller: _sku),
          ])),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _lbl(ar ? 'الباركود' : 'Barcode'),
            TextField(controller: _barcode, keyboardType: TextInputType.number),
          ])),
        ]),
        const SizedBox(height: 12),
        _lbl(ar ? 'الوزن (كجم)' : 'Weight (kg)'),
        TextField(controller: _weight,
          keyboardType: const TextInputType.numberWithOptions(decimal: true)),
        const SizedBox(height: 12),
        _lbl(ar ? 'الوصف' : 'Description'),
        TextField(controller: _desc, minLines: 3, maxLines: 6,
          decoration: InputDecoration(hintText: ar ? 'وصف المنتج للعميل' : 'Description for the customer')),
        if (!isNew) Padding(padding: const EdgeInsets.only(top: 8),
          child: Text(ar ? 'ملاحظة: التعديلات تُرسل لمراجعة الأدمن قبل ظهورها.'
            : 'Note: edits are sent for admin review before going live.',
            style: UT.small)),
        if (_err != null) Padding(padding: const EdgeInsets.only(top: 10),
          child: Container(padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: UC.dangerBg, borderRadius: BorderRadius.circular(8)),
            child: Text(_err!, style: const TextStyle(color: UC.dangerDk, fontWeight: FontWeight.w700)))),
        const SizedBox(height: 18),
        SizedBox(width: double.infinity, child: ElevatedButton.icon(
          onPressed: _busy ? null : _save,
          icon: _busy
            ? const SizedBox(width: 16, height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: UC.brown))
            : const Icon(Icons.save, size: 18),
          label: Text(isNew
            ? (ar ? 'إرسال للمراجعة' : 'Submit for review')
            : (ar ? 'حفظ' : 'Save'),
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)))),
        const SizedBox(height: 24),
      ]),
    );
  }

  Widget _lbl(String t) => Padding(padding: const EdgeInsets.only(bottom: 6),
    child: Text(t.toUpperCase(), style: const TextStyle(fontSize: 10.5,
      fontWeight: FontWeight.w800, color: UC.muted, letterSpacing: .4)));
}
