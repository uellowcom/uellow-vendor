import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/api.dart';
import '../theme/theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  List<Map<String, dynamic>> _langs = const [];
  String _lang = VendorApi.instance.lang;
  bool _push = true;
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try { _langs = await VendorApi.instance.languages(); } catch (_) {}
    final p = await SharedPreferences.getInstance();
    _push = p.getBool('vendor_push_v1') ?? true;
    if (mounted) setState(() => _loading = false);
  }

  void _pickLang() {
    final ar = VendorApi.instance.lang == 'ar';
    showModalBottomSheet(context: context, isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (sheet) => SafeArea(child: Container(
        constraints: const BoxConstraints(maxHeight: 480),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
            child: Text(ar ? 'اختر اللغة' : 'Select language', style: UT.h2)),
          const Divider(height: 1),
          Expanded(child: ListView(children: [
            for (final l in _langs.isNotEmpty ? _langs : [
              {'code':'en_US','name':'English','flag':'🇺🇸'},
              {'code':'ar_001','name':'العربية','flag':'🇰🇼'},
            ])
              ListTile(
                leading: Text((l['flag'] ?? '🌐').toString(),
                  style: const TextStyle(fontSize: 22)),
                title: Text((l['name'] ?? '').toString(),
                  style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text((l['code'] ?? '').toString(), style: UT.small),
                trailing: ((l['code'] ?? '').toString().toLowerCase().startsWith(_lang))
                  ? const Icon(Icons.check_circle, color: UC.success) : null,
                onTap: () {
                  final code = (l['code'] ?? '').toString();
                  Navigator.pop(sheet);
                  VendorApi.instance.setLang(code);
                  setState(() => _lang = VendorApi.instance.lang);
                }),
          ])),
        ]))));
  }

  @override
  Widget build(BuildContext context) {
    final ar = VendorApi.instance.lang == 'ar';
    if (_loading) return const Scaffold(body: Center(child: USpinner()));
    final currentLang = _langs.firstWhere(
      (l) => (l['code'] ?? '').toString().toLowerCase().startsWith(_lang),
      orElse: () => {'name': _lang.toUpperCase(), 'flag': '🌐'});
    return Scaffold(
      appBar: AppBar(title: Text(ar ? 'الإعدادات' : 'Settings')),
      body: ListView(children: [
        _section(ar ? 'التفضيلات' : 'PREFERENCES'),
        _row(Icons.language, ar ? 'اللغة' : 'Language',
          trailing: Text('${currentLang['flag'] ?? '🌐'}  ${currentLang['name'] ?? ''}',
            style: const TextStyle(fontWeight: FontWeight.w700)),
          onTap: _pickLang),
        _toggleRow(Icons.notifications_outlined, ar ? 'الإشعارات' : 'Push notifications',
          _push, (v) async {
            setState(() => _push = v);
            (await SharedPreferences.getInstance()).setBool('vendor_push_v1', v);
          }),
        _section(ar ? 'الحساب' : 'ACCOUNT'),
        _row(Icons.store, ar ? 'بيانات المتجر' : 'Store profile',
          onTap: () => Navigator.pushNamed(context, '/profile')),
        _section(ar ? 'حول' : 'ABOUT'),
        _row(Icons.info_outline, ar ? 'الإصدار' : 'Version',
          trailing: const Text('v1.0.0', style: TextStyle(color: UC.muted))),
      ]),
    );
  }
  Widget _section(String t) => Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
    child: Text(t, style: const TextStyle(fontSize: 10.5, color: UC.muted,
      fontWeight: FontWeight.w800, letterSpacing: .4)));
  Widget _row(IconData ic, String label, {Widget? trailing, VoidCallback? onTap}) {
    return Container(color: Colors.white, child: InkWell(onTap: onTap,
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Container(width: 30, height: 30, alignment: Alignment.center,
            decoration: BoxDecoration(color: UC.yellowFaint,
              borderRadius: BorderRadius.circular(9)),
            child: Icon(ic, color: UC.brown, size: 16)),
          const SizedBox(width: 11),
          Expanded(child: Text(label,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
          if (trailing != null) trailing,
          if (onTap != null) const Padding(padding: EdgeInsets.only(left: 4),
            child: Icon(Icons.chevron_right, color: UC.muted, size: 18)),
        ]))));
  }
  Widget _toggleRow(IconData ic, String label, bool v, ValueChanged<bool> onCh) =>
    _row(ic, label, trailing: Switch(value: v, onChanged: onCh, activeColor: UC.yellow));
}
