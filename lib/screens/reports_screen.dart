import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../api/api.dart';
import '../theme/theme.dart';

/// Reports center — download/share Excel (.xlsx) exports.
Future<void> downloadAndShare(BuildContext context, String apiPath, String filename) async {
  final ar = VendorApi.instance.lang == 'ar';
  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(SnackBar(content: Text(ar ? 'جارٍ التصدير...' : 'Exporting...')));
  try {
    final bytes = await VendorApi.instance.exportBytes(apiPath);
    final f = File('${Directory.systemTemp.path}/$filename');
    await f.writeAsBytes(bytes);
    await Share.shareXFiles([XFile(f.path)], subject: filename);
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('$e')));
  }
}

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final ar = VendorApi.instance.lang == 'ar';
    final items = <List<String>>[
      ['/api/vendor/v1/export/orders.xlsx', 'orders.xlsx',
        ar ? 'تقرير الطلبات' : 'Orders report'],
      ['/api/vendor/v1/export/products.xlsx', 'products.xlsx',
        ar ? 'تقرير المنتجات والمخزون' : 'Products & stock'],
      ['/api/vendor/v1/export/returns.xlsx', 'returns.xlsx',
        ar ? 'تقرير الاسترجاع' : 'Returns report'],
    ];
    return Scaffold(
      appBar: AppBar(title: Text(ar ? 'التقارير' : 'Reports')),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        Text(ar ? 'تصدير Excel' : 'Excel exports', style: UT.h2),
        const SizedBox(height: 8),
        for (final it in items) Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: UC.border)),
          child: ListTile(
            leading: const CircleAvatar(backgroundColor: UC.yellowFaint,
              child: Icon(Icons.table_view, color: UC.brown, size: 20)),
            title: Text(it[2], style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text(it[1], style: UT.small),
            trailing: const Icon(Icons.download, color: UC.brown),
            onTap: () => downloadAndShare(context, it[0], it[1]),
          )),
      ]),
    );
  }
}
