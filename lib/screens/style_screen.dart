import 'package:flutter/material.dart';
import '../api/api.dart';
import '../theme/theme.dart';

/// Store style — edit the storefront colors (mirrors /my/vendor/style).
class StyleScreen extends StatefulWidget {
  const StyleScreen({super.key});
  @override
  State<StyleScreen> createState() => _StyleScreenState();
}

class _StyleScreenState extends State<StyleScreen> {
  bool _loading = true, _saving = false, _denied = false;
  String? _error;
  final _fields = <String, TextEditingController>{};
  static const _keys = {
    'brand_color': ['Brand color', 'لون العلامة'],
    'flash_bg_color': ['Flash background', 'خلفية الفلاش'],
    'flash_accent_color': ['Flash accent', 'لون مميز للفلاش'],
    'section_title_color': ['Section titles', 'عناوين الأقسام'],
    'price_color': ['Price color', 'لون السعر'],
    'badge_color': ['Discount badge', 'شارة الخصم'],
    'header_text_color': ['Header text', 'نص الترويسة'],
  };

  @override
  void initState() {
    super.initState();
    for (final k in _keys.keys) {
      _fields[k] = TextEditingController();
    }
    _load();
  }

  Future<void> _load() async {
    try {
      final caps = await VendorApi.instance.capabilities();
      _denied = (caps['capabilities']?['edit_store'] == false);
      final d = await VendorApi.instance.styleGet();
      for (final k in _keys.keys) {
        _fields[k]!.text = (d[k] ?? '').toString();
      }
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await VendorApi.instance.styleSave(
          {for (final k in _keys.keys) k: _fields[k]!.text.trim()});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(VendorApi.instance.lang == 'ar' ? 'تم الحفظ' : 'Saved')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final ar = VendorApi.instance.lang == 'ar';
    return Scaffold(
      appBar: AppBar(title: Text(ar ? 'تصميم المتجر' : 'Store style')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _denied
              ? Center(child: Padding(padding: const EdgeInsets.all(24),
                  child: Text(ar
                      ? 'تعديل تصميم المتجر غير متاح لحسابك.'
                      : 'Editing store style is disabled for your account.',
                      textAlign: TextAlign.center, style: UT.body)))
              : ListView(padding: const EdgeInsets.all(16), children: [
                  if (_error != null)
                    Text(_error!, style: const TextStyle(color: UC.dangerDk)),
                  Text(ar ? 'ألوان واجهة متجرك (Hex مثل #F5C320)' : 'Your storefront colors (hex e.g. #F5C320)',
                      style: UT.small),
                  const SizedBox(height: 12),
                  for (final e in _keys.entries) _colorField(e.key, ar ? e.value[1] : e.value[0]),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                        backgroundColor: UC.brown,
                        minimumSize: const Size(double.infinity, 50)),
                    child: Text(_saving ? '...' : (ar ? 'حفظ' : 'Save'),
                        style: const TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ]),
    );
  }

  Widget _colorField(String key, String label) {
    final c = _fields[key]!;
    Color? swatch;
    final v = c.text.trim();
    if (v.startsWith('#') && (v.length == 7 || v.length == 4)) {
      try { swatch = Color(int.parse('FF${v.substring(1)}', radix: 16)); } catch (_) {}
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        Container(width: 34, height: 34,
            decoration: BoxDecoration(color: swatch ?? UC.bg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: UC.border))),
        const SizedBox(width: 10),
        Expanded(child: TextField(
          controller: c,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(labelText: label, hintText: '#RRGGBB',
              border: const OutlineInputBorder(), isDense: true),
        )),
      ]),
    );
  }
}
