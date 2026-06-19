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

  // Grouping of color keys into themed sections for a clearer layout.
  static const _groups = [
    {
      'icon': 0, // brand
      'title': ['Brand identity', 'هوية العلامة'],
      'subtitle': ['Your main store color and titles', 'لون متجرك الرئيسي والعناوين'],
      'keys': ['brand_color', 'section_title_color', 'header_text_color'],
    },
    {
      'icon': 1, // flash
      'title': ['Flash deals', 'عروض الفلاش'],
      'subtitle': ['Colors for flash sale banners', 'ألوان لافتات عروض الفلاش'],
      'keys': ['flash_bg_color', 'flash_accent_color'],
    },
    {
      'icon': 2, // pricing
      'title': ['Pricing & badges', 'الأسعار والشارات'],
      'subtitle': ['How prices and discounts look', 'مظهر الأسعار والخصومات'],
      'keys': ['price_color', 'badge_color'],
    },
  ];

  @override
  void initState() {
    super.initState();
    for (final k in _keys.keys) {
      _fields[k] = TextEditingController();
    }
    _load();
  }

  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
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

  // ---- helpers ----------------------------------------------------------

  Color? _parse(String? raw) {
    final v = (raw ?? '').trim();
    if (v.startsWith('#') && (v.length == 7 || v.length == 4)) {
      try {
        if (v.length == 4) {
          final r = v[1], g = v[2], b = v[3];
          return Color(int.parse('FF$r$r$g$g$b$b', radix: 16));
        }
        return Color(int.parse('FF${v.substring(1)}', radix: 16));
      } catch (_) {}
    }
    return null;
  }

  Color _on(Color c) =>
      c.computeLuminance() > 0.55 ? UC.ink : Colors.white;

  IconData _groupIcon(int i) => switch (i) {
        0 => Icons.storefront_rounded,
        1 => Icons.flash_on_rounded,
        _ => Icons.sell_rounded,
      };

  int _filledCount() =>
      _keys.keys.where((k) => _parse(_fields[k]!.text) != null).length;

  // ---- build ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final ar = VendorApi.instance.lang == 'ar';
    return Directionality(
      textDirection: ar ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(title: Text(ar ? 'تصميم المتجر' : 'Store style')),
        body: _loading
            ? const USpinner()
            : _denied
                ? _deniedView(ar)
                : _body(ar),
        bottomNavigationBar: (_loading || _denied) ? null : _saveBar(ar),
      ),
    );
  }

  Widget _deniedView(bool ar) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                  color: UC.warnBg, shape: BoxShape.circle),
              child: const Icon(Icons.lock_outline_rounded,
                  color: UC.warn, size: 30),
            ),
            const SizedBox(height: 16),
            Text(
                ar
                    ? 'تعديل تصميم المتجر غير متاح لحسابك.'
                    : 'Editing store style is disabled for your account.',
                textAlign: TextAlign.center,
                style: UT.body),
          ]),
        ),
      );

  Widget _body(bool ar) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        if (_error != null) ...[
          _errorBanner(),
          const SizedBox(height: 14),
        ],
        _previewCard(ar),
        const SizedBox(height: 18),
        for (final g in _groups) ...[
          _sectionCard(ar, g),
          const SizedBox(height: 14),
        ],
        const SizedBox(height: 4),
        Center(
          child: Text(
              ar
                  ? 'استخدم صيغة Hex مثل ‎#F5C320'
                  : 'Use hex format e.g. #F5C320',
              style: UT.small),
        ),
      ],
    );
  }

  Widget _errorBanner() => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: UC.dangerBg, borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          const Icon(Icons.error_outline_rounded,
              color: UC.dangerDk, size: 18),
          const SizedBox(width: 8),
          Expanded(
              child: Text(_error!,
                  style: const TextStyle(
                      color: UC.dangerDk, fontSize: 12, height: 1.3))),
        ]),
      );

  /// Live summary / preview card built from the entered colors.
  Widget _previewCard(bool ar) {
    final brand = _parse(_fields['brand_color']!.text) ?? UC.yellow;
    final flashBg = _parse(_fields['flash_bg_color']!.text) ?? UC.brown;
    final flashAccent =
        _parse(_fields['flash_accent_color']!.text) ?? UC.yellow;
    final price = _parse(_fields['price_color']!.text) ?? UC.brown;
    final badge = _parse(_fields['badge_color']!.text) ?? UC.danger;
    final headerText = _parse(_fields['header_text_color']!.text) ?? UC.ink;
    final filled = _filledCount();

    return Container(
      decoration: BoxDecoration(
        color: UC.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: UC.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // mock store header
        Container(
          color: brand,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(children: [
            Icon(Icons.storefront_rounded, color: headerText, size: 18),
            const SizedBox(width: 8),
            Text(ar ? 'متجري' : 'My Store',
                style: TextStyle(
                    color: headerText,
                    fontWeight: FontWeight.w900,
                    fontSize: 14)),
            const Spacer(),
            Icon(Icons.search_rounded, color: headerText, size: 18),
          ]),
        ),
        // mock flash strip
        Container(
          color: flashBg,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(children: [
            Icon(Icons.flash_on_rounded, color: flashAccent, size: 16),
            const SizedBox(width: 6),
            Text(ar ? 'عروض الفلاش' : 'Flash deals',
                style: TextStyle(
                    color: flashAccent,
                    fontWeight: FontWeight.w900,
                    fontSize: 12)),
          ]),
        ),
        // mock product row
        Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                  color: UC.bg, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.image_rounded,
                  color: UC.muted, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ar ? 'منتج تجريبي' : 'Sample product',
                        style: UT.h3),
                    const SizedBox(height: 4),
                    Row(children: [
                      Text(ar ? '٤.٩٠٠ د.ك' : '4.900 KD',
                          style: TextStyle(
                              color: price,
                              fontWeight: FontWeight.w900,
                              fontSize: 14)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                            color: badge,
                            borderRadius: BorderRadius.circular(6)),
                        child: Text('-30%',
                            style: TextStyle(
                                color: _on(badge),
                                fontWeight: FontWeight.w900,
                                fontSize: 10)),
                      ),
                    ]),
                  ]),
            ),
          ]),
        ),
        // footer status
        Container(
          color: UC.bg,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(children: [
            const Icon(Icons.visibility_rounded,
                color: UC.muted, size: 14),
            const SizedBox(width: 6),
            Text(ar ? 'معاينة مباشرة' : 'Live preview', style: UT.tiny),
            const Spacer(),
            UPill(
              text: ar
                  ? '$filled من ${_keys.length} لون'
                  : '$filled of ${_keys.length} set',
              bg: filled == _keys.length ? UC.successBg : UC.yellowFaint,
              fg: filled == _keys.length ? UC.successDk : UC.brownSoft,
              icon: Icons.palette_rounded,
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _sectionCard(bool ar, Map<String, Object> g) {
    final iconIdx = g['icon'] as int;
    final title = (g['title'] as List)[ar ? 1 : 0] as String;
    final subtitle = (g['subtitle'] as List)[ar ? 1 : 0] as String;
    final keys = (g['keys'] as List).cast<String>();
    return Container(
      decoration: BoxDecoration(
        color: UC.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: UC.border),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                color: UC.yellowFaint, borderRadius: BorderRadius.circular(10)),
            child: Icon(_groupIcon(iconIdx), color: UC.brown, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: UT.h2),
                  const SizedBox(height: 2),
                  Text(subtitle, style: UT.small),
                ]),
          ),
        ]),
        const SizedBox(height: 8),
        const Divider(height: 18, color: UC.border),
        for (int i = 0; i < keys.length; i++) ...[
          _colorField(keys[i], ar ? _keys[keys[i]]![1] : _keys[keys[i]]![0]),
          if (i != keys.length - 1) const SizedBox(height: 14),
        ],
      ]),
    );
  }

  Widget _colorField(String key, String label) {
    final c = _fields[key]!;
    final swatch = _parse(c.text);
    return Row(children: [
      Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
            color: swatch ?? UC.bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: UC.border)),
        child: swatch == null
            ? const Icon(Icons.colorize_rounded, color: UC.muted, size: 17)
            : null,
      ),
      const SizedBox(width: 12),
      Expanded(
        child: TextField(
          controller: c,
          onChanged: (_) => setState(() {}),
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: label,
            hintText: '#RRGGBB',
            isDense: true,
            suffixIcon: c.text.trim().isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 17),
                    color: UC.muted,
                    splashRadius: 18,
                    onPressed: () {
                      c.clear();
                      setState(() {});
                    },
                  ),
          ),
        ),
      ),
    ]);
  }

  /// Polished action bar: primary filled Save + secondary tonal Reset.
  Widget _saveBar(bool ar) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        color: UC.card,
        border: Border(top: BorderSide(color: UC.border)),
      ),
      child: Row(children: [
        OutlinedButton.icon(
          onPressed: _saving ? null : _load,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: Text(ar ? 'استرجاع' : 'Reset'),
          style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 50),
              padding: const EdgeInsets.symmetric(horizontal: 18)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.white))
                : const Icon(Icons.save_rounded, size: 19),
            label: Text(_saving
                ? (ar ? 'جارٍ الحفظ...' : 'Saving...')
                : (ar ? 'حفظ التغييرات' : 'Save changes')),
            style: FilledButton.styleFrom(
              backgroundColor: UC.brown,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
              textStyle: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  fontFamily: 'Tajawal'),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ]),
    );
  }
}
