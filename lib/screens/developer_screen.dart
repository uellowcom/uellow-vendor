import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../api/api.dart';
import '../theme/theme.dart';

/// Developer / Open API — manage API keys and webhooks for ERP/store integrations.
class DeveloperScreen extends StatefulWidget {
  const DeveloperScreen({super.key});
  @override
  State<DeveloperScreen> createState() => _DeveloperScreenState();
}

class _DeveloperScreenState extends State<DeveloperScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _meta = {};
  List<Map<String, dynamic>> _keys = [];
  List<Map<String, dynamic>> _hooks = [];

  bool get _ar => VendorApi.instance.lang == 'ar';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final m = await VendorApi.instance.devMeta();
      final k = await VendorApi.instance.apiKeys();
      final h = await VendorApi.instance.webhooks();
      if (!mounted) return;
      setState(() {
        _meta = m;
        _keys = k;
        _hooks = h;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _events =>
      ((_meta['events'] as List?) ?? const []).cast<Map>().map((e) => e.cast<String, dynamic>()).toList();

  // ── API key actions ───────────────────────────────────
  Future<void> _createKey() async {
    String name = 'API key';
    String scope = 'read';
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(_ar ? 'مفتاح API جديد' : 'New API key'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              decoration: InputDecoration(labelText: _ar ? 'الاسم' : 'Label'),
              onChanged: (v) => name = v,
            ),
            const SizedBox(height: 12),
            Row(children: [
              Text(_ar ? 'الصلاحية:' : 'Scope:', style: UT.body),
              const SizedBox(width: 10),
              DropdownButton<String>(
                value: scope,
                items: [
                  DropdownMenuItem(value: 'read', child: Text(_ar ? 'قراءة فقط' : 'Read only')),
                  DropdownMenuItem(value: 'write', child: Text(_ar ? 'قراءة وكتابة' : 'Read & write')),
                ],
                onChanged: (v) => setS(() => scope = v ?? 'read'),
              ),
            ]),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(_ar ? 'إلغاء' : 'Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(_ar ? 'إنشاء' : 'Create')),
          ],
        ),
      ),
    );
    if (go != true) return;
    try {
      final res = await VendorApi.instance.apiKeyCreate(name, scope);
      if (!mounted) return;
      await _showSecret(_ar ? 'مفتاح API' : 'API key', res['key'] as String,
          _ar ? 'انسخه الآن — لن يظهر مرة أخرى.' : 'Copy it now — it will not be shown again.');
      _load();
    } catch (e) {
      _snack('$e');
    }
  }

  Future<void> _revokeKey(int id) async {
    final ok = await _confirm(_ar ? 'إلغاء هذا المفتاح؟' : 'Revoke this key?');
    if (ok != true) return;
    try {
      await VendorApi.instance.apiKeyRevoke(id);
      _load();
    } catch (e) {
      _snack('$e');
    }
  }

  // ── Webhook actions ───────────────────────────────────
  Future<void> _createHook() async {
    String name = 'Webhook';
    String url = '';
    final selected = <String>{'new_order'};
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(_ar ? 'Webhook جديد' : 'New webhook'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              TextField(
                decoration: InputDecoration(labelText: _ar ? 'الاسم' : 'Label'),
                onChanged: (v) => name = v,
              ),
              const SizedBox(height: 8),
              TextField(
                decoration: const InputDecoration(labelText: 'https://...'),
                keyboardType: TextInputType.url,
                onChanged: (v) => url = v,
              ),
              const SizedBox(height: 12),
              Text(_ar ? 'الأحداث:' : 'Events:', style: UT.tiny),
              for (final e in _events)
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: selected.contains(e['code']),
                  title: Text(_ar ? (e['ar'] ?? e['en']) : e['en'], style: UT.body),
                  onChanged: (v) => setS(() {
                    if (v == true) {
                      selected.add(e['code'] as String);
                    } else {
                      selected.remove(e['code']);
                    }
                  }),
                ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(_ar ? 'إلغاء' : 'Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(_ar ? 'إضافة' : 'Add')),
          ],
        ),
      ),
    );
    if (go != true) return;
    if (url.trim().isEmpty) return;
    try {
      final res = await VendorApi.instance.webhookCreate(name, url.trim(), selected.toList());
      if (!mounted) return;
      await _showSecret(_ar ? 'سر التوقيع' : 'Signing secret', res['secret'] as String,
          _ar ? 'استخدمه للتحقق من توقيع X-Uellow-Signature.' : 'Use it to verify the X-Uellow-Signature header.');
      _load();
    } catch (e) {
      _snack('$e');
    }
  }

  Future<void> _testHook(int id) async {
    try {
      final res = await VendorApi.instance.webhookTest(id);
      final ok = res['delivered'] == true;
      _snack(ok
          ? (_ar ? 'تم التسليم ✓' : 'Delivered ✓')
          : (_ar ? 'فشل التسليم: ${res['last_status']}' : 'Delivery failed: ${res['last_status']}'));
      _load();
    } catch (e) {
      _snack('$e');
    }
  }

  Future<void> _deleteHook(int id) async {
    final ok = await _confirm(_ar ? 'حذف هذا الـ Webhook؟' : 'Delete this webhook?');
    if (ok != true) return;
    try {
      await VendorApi.instance.webhookDelete(id);
      _load();
    } catch (e) {
      _snack('$e');
    }
  }

  // ── helpers ───────────────────────────────────────────
  void _snack(String m) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<bool?> _confirm(String msg) => showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          content: Text(msg),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(_ar ? 'لا' : 'No')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(_ar ? 'نعم' : 'Yes')),
          ],
        ),
      );

  Future<void> _showSecret(String title, String secret, String hint) => showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            SelectableText(secret,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: UC.brown)),
            const SizedBox(height: 8),
            Text(hint, style: UT.small),
          ]),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: secret));
                _snack(_ar ? 'تم النسخ' : 'Copied');
              },
              child: Text(_ar ? 'نسخ' : 'Copy'),
            ),
            ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_ar ? 'المطورون / API' : 'Developer / API')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error!, textAlign: TextAlign.center, style: UT.body),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(padding: const EdgeInsets.all(12), children: [
                    if (_meta['base_url'] != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: UC.yellowFaint,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: UC.border),
                        ),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(_ar ? 'رابط الـ API' : 'API base URL', style: UT.tiny),
                          const SizedBox(height: 2),
                          SelectableText('${_meta['base_url']}',
                              style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: UC.brown)),
                          const SizedBox(height: 6),
                          Text(_ar ? 'المصادقة: ترويسة  X-API-Key' : 'Auth: header  X-API-Key', style: UT.small),
                        ]),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: UC.card,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: UC.border),
                        ),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(_ar ? 'تغذية الكتالوج (Google / Meta)' : 'Catalog feed (Google / Meta)', style: UT.tiny),
                          const SizedBox(height: 4),
                          SelectableText('${_meta['base_url']}/feed.xml?key=YOUR_API_KEY',
                              style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: UC.brown)),
                          SelectableText('${_meta['base_url']}/feed.csv?key=YOUR_API_KEY',
                              style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: UC.brown)),
                          const SizedBox(height: 4),
                          Text(_ar ? 'استبدل YOUR_API_KEY بمفتاحك بالأسفل.' : 'Replace YOUR_API_KEY with a key below.', style: UT.small),
                        ]),
                      ),
                      const SizedBox(height: 14),
                    ],
                    // ── API keys ──
                    _sectionHeader(_ar ? 'مفاتيح API' : 'API keys', Icons.vpn_key_outlined, _createKey),
                    if (_keys.isEmpty)
                      Padding(padding: const EdgeInsets.all(8), child: Text(_ar ? 'لا توجد مفاتيح بعد.' : 'No keys yet.', style: UT.small)),
                    for (final k in _keys)
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: UC.border)),
                        child: ListTile(
                          title: Text('${k['name']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                          subtitle: Text('${k['prefix']}…  ·  ${k['scope']}', style: UT.small),
                          trailing: (k['active'] == true)
                              ? TextButton(onPressed: () => _revokeKey(k['id'] as int),
                                  child: Text(_ar ? 'إلغاء' : 'Revoke', style: const TextStyle(color: UC.dangerDk)))
                              : Text(_ar ? 'ملغى' : 'revoked', style: UT.tiny),
                        ),
                      ),
                    const SizedBox(height: 16),
                    // ── Webhooks ──
                    _sectionHeader('Webhooks', Icons.webhook_outlined, _createHook),
                    if (_hooks.isEmpty)
                      Padding(padding: const EdgeInsets.all(8), child: Text(_ar ? 'لا توجد Webhooks بعد.' : 'No webhooks yet.', style: UT.small)),
                    for (final h in _hooks)
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: UC.border)),
                        child: ListTile(
                          title: Text('${h['name']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                          subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('${h['url']}', style: UT.small, maxLines: 1, overflow: TextOverflow.ellipsis),
                            Text((h['events'] as List).join(', '), style: UT.tiny),
                            if ('${h['last_status'] ?? ''}'.isNotEmpty)
                              Text('${_ar ? 'آخر حالة: ' : 'last: '}${h['last_status']}', style: UT.tiny),
                          ]),
                          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                            IconButton(icon: const Icon(Icons.send, size: 18, color: UC.brown), onPressed: () => _testHook(h['id'] as int)),
                            IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: UC.dangerDk), onPressed: () => _deleteHook(h['id'] as int)),
                          ]),
                        ),
                      ),
                  ]),
                ),
    );
  }

  Widget _sectionHeader(String title, IconData icon, VoidCallback onAdd) => Padding(
        padding: const EdgeInsets.only(bottom: 4, top: 2),
        child: Row(children: [
          Icon(icon, color: UC.brown, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(title, style: UT.h2)),
          TextButton.icon(onPressed: onAdd, icon: const Icon(Icons.add, size: 18), label: Text(_ar ? 'إضافة' : 'Add')),
        ]),
      );
}
