import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../api/api.dart';
import '../theme/theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final TextEditingController _nameEn, _nameAr, _taglineEn, _taglineAr;
  late final TextEditingController _phone, _email, _business, _commreg, _iban, _bank;
  Uint8List? _logo, _banner;
  bool _busy = false;
  String? _msg;

  @override
  void initState() {
    super.initState();
    final v = VendorApi.instance.vendor;
    _nameEn = TextEditingController(text: v?.storeName.en ?? '');
    _nameAr = TextEditingController(text: v?.storeName.ar ?? '');
    _taglineEn = TextEditingController(text: v?.tagline.en ?? '');
    _taglineAr = TextEditingController(text: v?.tagline.ar ?? '');
    _phone = TextEditingController(text: v?.contactPhone ?? '');
    _email = TextEditingController(text: v?.contactEmail ?? '');
    _business = TextEditingController(text: v?.businessName ?? '');
    _commreg = TextEditingController(text: '');
    _iban = TextEditingController(text: v?.bankIban ?? '');
    _bank = TextEditingController(text: v?.bankName ?? '');
  }

  @override
  void dispose() {
    for (final c in [_nameEn, _nameAr, _taglineEn, _taglineAr, _phone, _email,
        _business, _commreg, _iban, _bank]) { c.dispose(); }
    super.dispose();
  }

  Future<void> _pick(bool isLogo) async {
    final p = await ImagePicker().pickImage(source: ImageSource.gallery,
        maxWidth: isLogo ? 800 : 1600, imageQuality: 85);
    if (p == null) return;
    final b = await File(p.path).readAsBytes();
    setState(() { if (isLogo) _logo = b; else _banner = b; });
  }

  Future<void> _save() async {
    final ar = VendorApi.instance.lang == 'ar';
    setState(() { _busy = true; _msg = null; });
    try {
      await VendorApi.instance.updateProfile({
        'store_name_en': _nameEn.text.trim(),
        'store_name_ar': _nameAr.text.trim(),
        'store_tagline_en': _taglineEn.text.trim(),
        'store_tagline_ar': _taglineAr.text.trim(),
        'contact_phone': _phone.text.trim(),
        'contact_email': _email.text.trim(),
        'business_name': _business.text.trim(),
        'commercial_reg': _commreg.text.trim(),
        'bank_iban': _iban.text.trim(),
        'bank_name': _bank.text.trim(),
        if (_logo != null) 'logo_base64': base64Encode(_logo!),
        if (_banner != null) 'banner_base64': base64Encode(_banner!),
      });
      if (!mounted) return;
      setState(() => _msg = ar ? 'تم الحفظ' : 'Saved');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_msg!)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _msg = e.toString());
    } finally { if (mounted) setState(() => _busy = false); }
  }

  @override
  Widget build(BuildContext context) {
    final ar = VendorApi.instance.lang == 'ar';
    return Scaffold(
      appBar: AppBar(title: Text(ar ? 'ملف التاجر' : 'Vendor profile')),
      body: ListView(padding: const EdgeInsets.all(14), children: [
        _marketsCard(ar),
        _lbl(ar ? 'الشعار' : 'Logo'),
        GestureDetector(onTap: () => _pick(true),
          child: Container(width: 90, height: 90,
            decoration: BoxDecoration(color: UC.yellowFaint,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: UC.yellow, width: 2)),
            child: _logo != null
              ? ClipRRect(borderRadius: BorderRadius.circular(14),
                  child: Image.memory(_logo!, fit: BoxFit.cover))
              : (VendorApi.instance.vendor?.logoUrl != null
                  ? ClipRRect(borderRadius: BorderRadius.circular(14),
                      child: Image.network('${VendorApi.instance.baseUrl}${VendorApi.instance.vendor!.logoUrl!}',
                        fit: BoxFit.cover))
                  : const Icon(Icons.add_a_photo, color: UC.brown, size: 28)))),
        const SizedBox(height: 14),
        _lbl(ar ? 'البانر' : 'Banner'),
        GestureDetector(onTap: () => _pick(false),
          child: Container(height: 80, width: double.infinity,
            decoration: BoxDecoration(color: UC.yellowFaint,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: UC.yellow, width: 1.5)),
            child: _banner != null
              ? ClipRRect(borderRadius: BorderRadius.circular(10),
                  child: Image.memory(_banner!, fit: BoxFit.cover))
              : (VendorApi.instance.vendor?.bannerUrl != null
                  ? ClipRRect(borderRadius: BorderRadius.circular(10),
                      child: Image.network('${VendorApi.instance.baseUrl}${VendorApi.instance.vendor!.bannerUrl!}',
                        fit: BoxFit.cover))
                  : const Icon(Icons.add_photo_alternate, color: UC.brown)))),
        const SizedBox(height: 18),
        _lbl(ar ? 'اسم المتجر (EN)' : 'Store name (EN)'),
        TextField(controller: _nameEn),
        const SizedBox(height: 10),
        _lbl(ar ? 'اسم المتجر (AR)' : 'Store name (AR)'),
        TextField(controller: _nameAr),
        const SizedBox(height: 10),
        _lbl(ar ? 'الشعار التعريفي (EN)' : 'Tagline (EN)'),
        TextField(controller: _taglineEn),
        const SizedBox(height: 10),
        _lbl(ar ? 'الشعار التعريفي (AR)' : 'Tagline (AR)'),
        TextField(controller: _taglineAr),
        const SizedBox(height: 18),
        _lbl(ar ? 'بيانات التواصل' : 'Contact'),
        TextField(controller: _phone, decoration: InputDecoration(labelText: ar ? 'الهاتف' : 'Phone')),
        const SizedBox(height: 8),
        TextField(controller: _email, decoration: InputDecoration(labelText: ar ? 'البريد' : 'Email')),
        const SizedBox(height: 18),
        _lbl(ar ? 'البيانات التجارية' : 'Business info'),
        TextField(controller: _business, decoration: InputDecoration(labelText: ar ? 'الاسم القانوني' : 'Legal name')),
        const SizedBox(height: 8),
        TextField(controller: _commreg, decoration: InputDecoration(labelText: ar ? 'السجل التجاري' : 'Commercial reg.')),
        const SizedBox(height: 18),
        _lbl(ar ? 'بيانات البنك' : 'Bank details'),
        TextField(controller: _bank, decoration: InputDecoration(labelText: ar ? 'البنك' : 'Bank')),
        const SizedBox(height: 8),
        TextField(controller: _iban, decoration: const InputDecoration(labelText: 'IBAN')),
        if (_msg != null) Padding(padding: const EdgeInsets.only(top: 10),
          child: Text(_msg!, style: const TextStyle(fontWeight: FontWeight.w700))),
        const SizedBox(height: 22),
        SizedBox(width: double.infinity, child: ElevatedButton.icon(
          onPressed: _busy ? null : _save,
          icon: _busy ? const SizedBox(width: 16, height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: UC.brown))
            : const Icon(Icons.save, size: 18),
          label: Text(ar ? 'حفظ التغييرات' : 'Save changes',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)))),
      ]),
    );
  }

  Widget _lbl(String t) => Padding(padding: const EdgeInsets.only(bottom: 6),
    child: Text(t.toUpperCase(), style: const TextStyle(fontSize: 10.5,
      fontWeight: FontWeight.w800, color: UC.muted, letterSpacing: .4)));

  Widget _marketsCard(bool ar) {
    final v = VendorApi.instance.vendor;
    if (v == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [UC.brown, UC.brownSoft],
          begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.public, color: UC.yellow, size: 18),
          const SizedBox(width: 8),
          Text(ar ? 'نطاق البيع' : 'Sales scope',
            style: const TextStyle(color: UC.yellowSoft, fontSize: 12, fontWeight: FontWeight.w900)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _kv(ar ? 'الدولة' : 'Country',
            v.countryName.isNotEmpty ? v.countryName : (v.country.isNotEmpty ? v.country : '—'))),
          Expanded(child: _kv(ar ? 'العملة' : 'Currency', '${v.currency} (${v.currencySymbol})')),
        ]),
        const SizedBox(height: 10),
        Text((ar ? 'الأسواق المتاحة' : 'Available markets').toUpperCase(),
          style: const TextStyle(color: Color(0xCCFFE066), fontSize: 9.5, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        if (v.markets.isEmpty)
          Text(ar ? 'كل الأسواق' : 'All markets',
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))
        else
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final m in v.markets) Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(color: const Color(0x22FFFFFF),
                borderRadius: BorderRadius.circular(999)),
              child: Text(m, style: const TextStyle(color: Colors.white,
                fontSize: 10.5, fontWeight: FontWeight.w800))),
          ]),
        if (v.exclusiveMarkets) Padding(padding: const EdgeInsets.only(top: 8),
          child: Text(ar ? '🔒 منتجاتك حصرية لهذه الأسواق فقط'
            : '🔒 Your products are exclusive to these markets',
            style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 10.5))),
      ]),
    );
  }

  Widget _kv(String k, String val) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(k.toUpperCase(), style: const TextStyle(color: Color(0xCCFFE066),
      fontSize: 9.5, fontWeight: FontWeight.w800)),
    const SizedBox(height: 2),
    Text(val, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900)),
  ]);
}
