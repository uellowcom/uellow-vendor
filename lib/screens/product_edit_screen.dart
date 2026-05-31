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
  final _name = TextEditingController();
  final _price = TextEditingController();
  final _sku = TextEditingController();
  final _desc = TextEditingController();
  Uint8List? _image;
  bool _busy = false, _loading = true;
  ProductDetail? _existing;
  String? _err;

  @override
  void initState() {
    super.initState();
    if (widget.productId != null) _load();
    else _loading = false;
  }

  Future<void> _load() async {
    try {
      _existing = await VendorApi.instance.productDetail(widget.productId!);
      _name.text = _existing!.name.t(VendorApi.instance.lang);
      _price.text = _existing!.listPrice.amount.toStringAsFixed(_existing!.listPrice.digits);
      _sku.text = _existing!.sku;
      _desc.text = _existing!.descriptionSale;
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _name.dispose(); _price.dispose(); _sku.dispose(); _desc.dispose();
    super.dispose();
  }

  Future<void> _pickImg(ImageSource src) async {
    final p = await ImagePicker().pickImage(source: src, maxWidth: 1280, imageQuality: 85);
    if (p == null) return;
    final b = await File(p.path).readAsBytes();
    setState(() => _image = b);
  }

  void _photoSheet() {
    final ar = VendorApi.instance.lang == 'ar';
    showModalBottomSheet(context: context, builder: (sheet) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: const Icon(Icons.camera_alt_outlined),
          title: Text(ar ? 'التقط صورة' : 'Take photo'),
          onTap: () { Navigator.pop(sheet); _pickImg(ImageSource.camera); }),
        ListTile(leading: const Icon(Icons.photo_library_outlined),
          title: Text(ar ? 'من المعرض' : 'From gallery'),
          onTap: () { Navigator.pop(sheet); _pickImg(ImageSource.gallery); }),
      ])));
  }

  Future<void> _save() async {
    final ar = VendorApi.instance.lang == 'ar';
    if (_name.text.trim().isEmpty) {
      setState(() => _err = ar ? 'الاسم مطلوب' : 'Name required');
      return;
    }
    final price = double.tryParse(_price.text.trim()) ?? 0;
    setState(() { _busy = true; _err = null; });
    try {
      if (widget.productId == null) {
        await VendorApi.instance.productCreate(
          name: _name.text.trim(),
          price: price,
          description: _desc.text.trim(),
          sku: _sku.text.trim(),
          image: _image);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ar ? 'تم إرسال المنتج للمراجعة' : 'Product sent for review')));
        Navigator.pop(context, true);
      } else {
        final body = <String, dynamic>{
          'name': _name.text.trim(),
          'list_price': price,
          'default_code': _sku.text.trim(),
          'description_sale': _desc.text.trim(),
          if (_image != null) 'image_base64': base64Encode(_image!),
        };
        await VendorApi.instance.productUpdate(widget.productId!, body);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ar ? 'تم حفظ التعديلات' : 'Saved')));
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
        // Image
        Center(child: GestureDetector(onTap: _photoSheet,
          child: Container(width: 130, height: 130,
            decoration: BoxDecoration(color: UC.yellowFaint,
              border: Border.all(color: UC.yellow, width: 2,
                style: BorderStyle.solid),
              borderRadius: BorderRadius.circular(16)),
            child: _image != null
              ? ClipRRect(borderRadius: BorderRadius.circular(14),
                  child: Image.memory(_image!, fit: BoxFit.cover))
              : (_existing?.imageUrl != null
                  ? ClipRRect(borderRadius: BorderRadius.circular(14),
                      child: Image.network('${VendorApi.instance.baseUrl}${_existing!.imageUrl!}',
                        fit: BoxFit.cover))
                  : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.add_a_photo, size: 36, color: UC.brown),
                      const SizedBox(height: 4),
                      Text(ar ? 'صورة المنتج' : 'Product photo',
                        style: const TextStyle(color: UC.brown,
                          fontWeight: FontWeight.w800, fontSize: 11.5)),
                    ])),
          ))),
        const SizedBox(height: 18),
        _lbl(ar ? 'اسم المنتج' : 'Product name'),
        TextField(controller: _name,
          decoration: InputDecoration(hintText: ar ? 'مثل: ساعة ذكية' : 'e.g. Smart Watch')),
        const SizedBox(height: 12),
        _lbl(ar ? 'السعر' : 'Price'),
        TextField(controller: _price,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(suffixText: 'KD')),
        const SizedBox(height: 12),
        _lbl(ar ? 'رمز SKU' : 'SKU'),
        TextField(controller: _sku,
          decoration: InputDecoration(hintText: ar ? 'كود داخلي اختياري' : 'Internal code (optional)')),
        const SizedBox(height: 12),
        _lbl(ar ? 'الوصف' : 'Description'),
        TextField(controller: _desc, minLines: 3, maxLines: 6,
          decoration: InputDecoration(hintText: ar ? 'وصف المنتج للعميل' : 'Description for the customer')),
        if (_err != null) Padding(padding: const EdgeInsets.only(top: 10),
          child: Container(padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: UC.dangerBg,
              borderRadius: BorderRadius.circular(8)),
            child: Text(_err!, style: const TextStyle(
              color: UC.dangerDk, fontWeight: FontWeight.w700)))),
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
      ]),
    );
  }

  Widget _lbl(String t) => Padding(padding: const EdgeInsets.only(bottom: 6),
    child: Text(t.toUpperCase(), style: const TextStyle(fontSize: 10.5,
      fontWeight: FontWeight.w800, color: UC.muted, letterSpacing: .4)));
}
