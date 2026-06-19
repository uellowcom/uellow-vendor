import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
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
    // Reflect live edits into the header preview.
    _nameEn.addListener(_refresh);
    _nameAr.addListener(_refresh);
    _taglineEn.addListener(_refresh);
    _taglineAr.addListener(_refresh);
  }

  void _refresh() { if (mounted) setState(() {}); }

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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: UC.successDk,
        behavior: SnackBarBehavior.floating,
        content: Row(children: [
          const Icon(Icons.check_circle, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text(_msg!, style: const TextStyle(fontWeight: FontWeight.w800)),
        ]),
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _msg = e.toString());
    } finally { if (mounted) setState(() => _busy = false); }
  }

  @override
  Widget build(BuildContext context) {
    final ar = VendorApi.instance.lang == 'ar';
    return Scaffold(
      backgroundColor: UC.bg,
      appBar: AppBar(title: Text(ar ? 'ملف التاجر' : 'Vendor profile')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 110),
        children: [
          _header(ar),
          const SizedBox(height: 16),
          _marketsCard(ar),
          const SizedBox(height: 14),
          _identityCard(ar),
          const SizedBox(height: 14),
          _contactCard(ar),
          const SizedBox(height: 14),
          _businessCard(ar),
          const SizedBox(height: 14),
          _bankCard(ar),
          if (_msg != null && _msg != (ar ? 'تم الحفظ' : 'Saved'))
            Padding(padding: const EdgeInsets.only(top: 14),
              child: _banner_msg(_msg!)),
        ],
      ),
      bottomSheet: _saveBar(ar),
    );
  }

  // ---------------------------------------------------------------- header
  Widget _header(bool ar) {
    final v = VendorApi.instance.vendor;
    final base = VendorApi.instance.baseUrl;
    final name = ar
        ? (_nameAr.text.trim().isNotEmpty ? _nameAr.text.trim() : _nameEn.text.trim())
        : (_nameEn.text.trim().isNotEmpty ? _nameEn.text.trim() : _nameAr.text.trim());
    final tag = ar
        ? (_taglineAr.text.trim().isNotEmpty ? _taglineAr.text.trim() : _taglineEn.text.trim())
        : (_taglineEn.text.trim().isNotEmpty ? _taglineEn.text.trim() : _taglineAr.text.trim());

    Widget bannerLayer() {
      if (_banner != null) {
        return Image.memory(_banner!, fit: BoxFit.cover, width: double.infinity);
      }
      if (v?.bannerUrl != null) {
        return CachedNetworkImage(
          imageUrl: '$base${v!.bannerUrl!}',
          fit: BoxFit.cover, width: double.infinity,
          placeholder: (_, __) => Container(color: UC.brownSoft),
          errorWidget: (_, __, ___) => const SizedBox.shrink(),
        );
      }
      return const SizedBox.shrink();
    }

    Widget logoLayer() {
      if (_logo != null) {
        return Image.memory(_logo!, fit: BoxFit.cover, width: 92, height: 92);
      }
      if (v?.logoUrl != null) {
        return CachedNetworkImage(
          imageUrl: '$base${v!.logoUrl!}',
          fit: BoxFit.cover, width: 92, height: 92,
          placeholder: (_, __) => Container(color: UC.yellowFaint),
          errorWidget: (_, __, ___) =>
              const Icon(Icons.storefront, color: UC.brown, size: 34),
        );
      }
      return const Icon(Icons.add_a_photo, color: UC.brown, size: 28);
    }

    return Container(
      decoration: BoxDecoration(
        color: UC.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: UC.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .05),
          blurRadius: 12, offset: const Offset(0, 4))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Banner band with edit affordance.
        SizedBox(
          height: 132,
          child: Stack(fit: StackFit.expand, children: [
            Container(decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [UC.brown, UC.brownSoft],
                begin: Alignment.topLeft, end: Alignment.bottomRight))),
            bannerLayer(),
            Container(decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.transparent, Colors.black.withValues(alpha: .35)],
                begin: Alignment.topCenter, end: Alignment.bottomCenter))),
            Positioned(top: 10, right: 10,
              child: _editChip(ar ? 'تغيير البانر' : 'Edit banner',
                Icons.image_outlined, () => _pick(false))),
          ]),
        ),
        // Logo + name row overlapping the banner.
        Transform.translate(
          offset: const Offset(0, -34),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              GestureDetector(
                onTap: () => _pick(true),
                child: Stack(children: [
                  Container(
                    width: 92, height: 92,
                    decoration: BoxDecoration(
                      color: UC.yellowFaint,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white, width: 4),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .12),
                        blurRadius: 8, offset: const Offset(0, 3))],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Center(child: logoLayer()),
                  ),
                  Positioned(
                    bottom: 2, right: 2,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(color: UC.yellow, shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2)),
                      child: const Icon(Icons.edit, size: 12, color: UC.brown),
                    ),
                  ),
                ]),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(name.isNotEmpty ? name : (ar ? 'اسم متجرك' : 'Your store'),
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: UT.h2),
                    if (tag.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(tag, maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: UT.small),
                    ],
                  ]),
                ),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 2),
      ]),
    );
  }

  Widget _editChip(String t, IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .42),
        borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: Colors.white),
        const SizedBox(width: 5),
        Text(t, style: const TextStyle(color: Colors.white,
          fontSize: 11, fontWeight: FontWeight.w800)),
      ]),
    ),
  );

  // ----------------------------------------------------------------- cards
  Widget _section({required String title, required IconData icon,
      required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: UC.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: UC.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(color: UC.yellowFaint,
              borderRadius: BorderRadius.circular(9)),
            child: Icon(icon, size: 16, color: UC.brown),
          ),
          const SizedBox(width: 10),
          Text(title, style: UT.h3),
        ]),
        const SizedBox(height: 14),
        ...children,
      ]),
    );
  }

  Widget _identityCard(bool ar) => _section(
    title: ar ? 'هوية المتجر' : 'Store identity',
    icon: Icons.storefront_outlined,
    children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: _field(_nameEn, ar ? 'اسم المتجر (EN)' : 'Store name (EN)',
          Icons.badge_outlined)),
        const SizedBox(width: 10),
        Expanded(child: _field(_nameAr, ar ? 'اسم المتجر (AR)' : 'Store name (AR)',
          Icons.badge_outlined)),
      ]),
      const SizedBox(height: 12),
      _field(_taglineEn, ar ? 'الشعار التعريفي (EN)' : 'Tagline (EN)',
        Icons.notes_outlined),
      const SizedBox(height: 12),
      _field(_taglineAr, ar ? 'الشعار التعريفي (AR)' : 'Tagline (AR)',
        Icons.notes_outlined),
    ],
  );

  Widget _contactCard(bool ar) => _section(
    title: ar ? 'بيانات التواصل' : 'Contact',
    icon: Icons.contact_phone_outlined,
    children: [
      _field(_phone, ar ? 'الهاتف' : 'Phone', Icons.phone_outlined,
        keyboard: TextInputType.phone),
      const SizedBox(height: 12),
      _field(_email, ar ? 'البريد' : 'Email', Icons.mail_outline,
        keyboard: TextInputType.emailAddress),
    ],
  );

  Widget _businessCard(bool ar) => _section(
    title: ar ? 'البيانات التجارية' : 'Business info',
    icon: Icons.business_center_outlined,
    children: [
      _field(_business, ar ? 'الاسم القانوني' : 'Legal name',
        Icons.account_balance_outlined),
      const SizedBox(height: 12),
      _field(_commreg, ar ? 'السجل التجاري' : 'Commercial reg.',
        Icons.assignment_outlined),
    ],
  );

  Widget _bankCard(bool ar) => _section(
    title: ar ? 'بيانات البنك' : 'Bank details',
    icon: Icons.account_balance_wallet_outlined,
    children: [
      _field(_bank, ar ? 'البنك' : 'Bank', Icons.account_balance_outlined),
      const SizedBox(height: 12),
      _field(_iban, 'IBAN', Icons.numbers_outlined),
    ],
  );

  Widget _field(TextEditingController c, String label, IconData icon,
      {TextInputType? keyboard}) {
    return TextField(
      controller: c,
      keyboardType: keyboard,
      style: UT.body.copyWith(fontWeight: FontWeight.w700, color: UC.ink),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: UC.muted, fontWeight: FontWeight.w700),
        prefixIcon: Icon(icon, size: 18, color: UC.muted),
        filled: true,
        fillColor: UC.bg,
      ),
    );
  }

  Widget _banner_msg(String t) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: UC.dangerBg,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: UC.danger.withValues(alpha: .35))),
    child: Row(children: [
      const Icon(Icons.error_outline, color: UC.dangerDk, size: 18),
      const SizedBox(width: 8),
      Expanded(child: Text(t, style: const TextStyle(color: UC.dangerDk,
        fontWeight: FontWeight.w700, fontSize: 12))),
    ]),
  );

  // ------------------------------------------------------------- save bar
  Widget _saveBar(bool ar) {
    return Container(
      padding: EdgeInsets.fromLTRB(14, 12, 14,
          12 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: UC.card,
        border: const Border(top: BorderSide(color: UC.border)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .06),
          blurRadius: 12, offset: const Offset(0, -3))],
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _busy ? null : _save,
          icon: _busy
            ? const SizedBox(width: 16, height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: UC.brown))
            : const Icon(Icons.save_outlined, size: 18),
          label: Text(ar ? 'حفظ التغييرات' : 'Save changes',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16)),
        ),
      ),
    );
  }

  // --------------------------------------------------------- markets card
  Widget _marketsCard(bool ar) {
    final v = VendorApi.instance.vendor;
    if (v == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [UC.brown, UC.brownSoft],
          begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: UC.brown.withValues(alpha: .25),
          blurRadius: 12, offset: const Offset(0, 4))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(9)),
            child: const Icon(Icons.public, color: UC.yellow, size: 16),
          ),
          const SizedBox(width: 10),
          Text(ar ? 'نطاق البيع' : 'Sales scope',
            style: const TextStyle(color: UC.yellowSoft, fontSize: 13,
              fontWeight: FontWeight.w900)),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _kv(ar ? 'الدولة' : 'Country',
            v.countryName.isNotEmpty ? v.countryName
              : (v.country.isNotEmpty ? v.country : '—'))),
          Container(width: 1, height: 32,
            color: Colors.white.withValues(alpha: .15),
            margin: const EdgeInsets.symmetric(horizontal: 12)),
          Expanded(child: _kv(ar ? 'العملة' : 'Currency',
            '${v.currency} (${v.currencySymbol})')),
        ]),
        const SizedBox(height: 14),
        Text((ar ? 'الأسواق المتاحة' : 'Available markets').toUpperCase(),
          style: const TextStyle(color: Color(0xCCFFE066), fontSize: 9.5,
            fontWeight: FontWeight.w800, letterSpacing: .4)),
        const SizedBox(height: 8),
        if (v.markets.isEmpty)
          Text(ar ? 'كل الأسواق' : 'All markets',
            style: const TextStyle(color: Colors.white, fontSize: 12,
              fontWeight: FontWeight.w700))
        else
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final m in v.markets) Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: const Color(0x22FFFFFF),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withValues(alpha: .12))),
              child: Text(m, style: const TextStyle(color: Colors.white,
                fontSize: 10.5, fontWeight: FontWeight.w800))),
          ]),
        if (v.exclusiveMarkets) Padding(padding: const EdgeInsets.only(top: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(color: Colors.black.withValues(alpha: .18),
              borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              const Icon(Icons.lock_outline, color: Color(0xCCFFFFFF), size: 13),
              const SizedBox(width: 6),
              Expanded(child: Text(ar
                ? 'منتجاتك حصرية لهذه الأسواق فقط'
                : 'Your products are exclusive to these markets',
                style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 10.5,
                  fontWeight: FontWeight.w600))),
            ]),
          )),
      ]),
    );
  }

  Widget _kv(String k, String val) => Column(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(k.toUpperCase(), style: const TextStyle(color: Color(0xCCFFE066),
      fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: .4)),
    const SizedBox(height: 3),
    Text(val, style: const TextStyle(color: Colors.white, fontSize: 14,
      fontWeight: FontWeight.w900)),
  ]);
}
