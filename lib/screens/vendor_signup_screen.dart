import 'package:flutter/material.dart';
import '../api/api.dart';
import '../theme/theme.dart';

/// Public "Request a vendor account" form, opened from the login screen.
/// Submits to /api/vendor/v1/auth/apply (creates a CRM lead for the team).
class VendorSignupScreen extends StatefulWidget {
  const VendorSignupScreen({super.key});
  @override
  State<VendorSignupScreen> createState() => _VendorSignupScreenState();
}

class _VendorSignupScreenState extends State<VendorSignupScreen> {
  final _store = TextEditingController();
  final _owner = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _city = TextEditingController();
  final _category = TextEditingController();
  final _message = TextEditingController();
  bool _busy = false, _done = false;
  String? _err;

  @override
  void dispose() {
    for (final c in [_store, _owner, _phone, _email, _city, _category, _message]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _ar => VendorApi.instance.lang == 'ar';

  Future<void> _submit() async {
    if (_store.text.trim().isEmpty || _phone.text.trim().isEmpty) {
      setState(() => _err = _ar
          ? 'اسم المتجر ورقم الهاتف مطلوبان'
          : 'Store name and phone are required');
      return;
    }
    setState(() { _busy = true; _err = null; });
    try {
      await VendorApi.instance.applyVendor({
        'store_name': _store.text.trim(),
        'owner_name': _owner.text.trim(),
        'phone': _phone.text.trim(),
        'email': _email.text.trim(),
        'city': _city.text.trim(),
        'category': _category.text.trim(),
        'message': _message.text.trim(),
      });
      if (!mounted) return;
      setState(() { _busy = false; _done = true; });
    } on VendorApiException catch (e) {
      setState(() { _busy = false; _err = e.message; });
    } catch (e) {
      setState(() { _busy = false; _err = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ar = _ar;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: UC.yellow,
        foregroundColor: UC.brown,
        elevation: 0,
        title: Text(ar ? 'طلب حساب تاجر' : 'Request vendor account',
            style: const TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: _done ? _success(ar) : _form(ar),
    );
  }

  Widget _success(bool ar) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 88, height: 88,
          decoration: const BoxDecoration(color: UC.yellow, shape: BoxShape.circle),
          child: const Icon(Icons.check_rounded, size: 50, color: UC.brown)),
        const SizedBox(height: 20),
        Text(ar ? 'تم استلام طلبك!' : 'Request received!',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: UC.brown)),
        const SizedBox(height: 10),
        Text(
          ar
            ? 'سيتواصل معك فريق Uellow قريباً لتفعيل حساب التاجر.'
            : 'The Uellow team will contact you soon to activate your vendor account.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: UC.brownSoft, fontSize: 14)),
        const SizedBox(height: 24),
        SizedBox(width: double.infinity, child: ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: UC.brown, foregroundColor: UC.yellowSoft,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          child: Text(ar ? 'العودة لتسجيل الدخول' : 'Back to sign in',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)))),
      ]),
    ));

  Widget _field(TextEditingController c, String label, {bool required = false,
      TextInputType? kt, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c, keyboardType: kt, maxLines: maxLines,
        decoration: InputDecoration(
          labelText: required ? '$label *' : label,
          filled: true, fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: UC.border))),
      ),
    );
  }

  Widget _form(bool ar) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(
        ar
          ? 'املأ النموذج وسيتواصل معك فريق Uellow لتفعيل متجرك.'
          : 'Fill the form and the Uellow team will reach out to activate your store.',
        style: const TextStyle(color: UC.brownSoft, fontSize: 13)),
      const SizedBox(height: 18),
      _field(_store, ar ? 'اسم المتجر' : 'Store name', required: true),
      _field(_owner, ar ? 'اسم المالك' : 'Owner name'),
      _field(_phone, ar ? 'رقم الهاتف' : 'Phone', required: true, kt: TextInputType.phone),
      _field(_email, ar ? 'البريد الإلكتروني' : 'Email', kt: TextInputType.emailAddress),
      _field(_city, ar ? 'المدينة' : 'City'),
      _field(_category, ar ? 'نوع المنتجات / القسم' : 'Products / category'),
      _field(_message, ar ? 'رسالة (اختياري)' : 'Message (optional)', maxLines: 3),
      if (_err != null) Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: UC.dangerBg, borderRadius: BorderRadius.circular(8)),
          child: Text(_err!, style: const TextStyle(color: UC.dangerDk, fontWeight: FontWeight.w700)))),
      SizedBox(width: double.infinity, child: ElevatedButton(
        onPressed: _busy ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: UC.brown, foregroundColor: UC.yellowSoft,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
        child: _busy
          ? const SizedBox(width: 18, height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: UC.yellowSoft))
          : Text(ar ? 'إرسال الطلب' : 'Submit request',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)))),
    ]),
  );
}
