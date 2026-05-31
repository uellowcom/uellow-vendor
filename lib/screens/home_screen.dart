import 'package:flutter/material.dart';
import '../api/api.dart';
import '../theme/theme.dart';
import 'dashboard_tab.dart';
import 'orders_tab.dart';
import 'products_tab.dart';
import 'finance_tab.dart';
import 'me_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  late final List<Widget> _pages;
  @override
  void initState() {
    super.initState();
    _pages = const [DashboardTab(), OrdersTab(), ProductsTab(), FinanceTab(), MeTab()];
  }
  @override
  Widget build(BuildContext context) {
    final ar = VendorApi.instance.lang == 'ar';
    return Scaffold(
      body: IndexedStack(index: _tab, children: _pages),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(color: Colors.white,
          border: Border(top: BorderSide(color: UC.border)),
          boxShadow: [BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, -2))]),
        child: SafeArea(top: false, child: SizedBox(height: 64,
          child: Row(children: [
            _btn(0, Icons.dashboard_outlined, ar ? 'الرئيسية' : 'Home'),
            _btn(1, Icons.inventory_2_outlined, ar ? 'الطلبات' : 'Orders'),
            _btn(2, Icons.shopping_bag_outlined, ar ? 'المنتجات' : 'Products'),
            _btn(3, Icons.account_balance_wallet_outlined, ar ? 'المالية' : 'Finance'),
            _btn(4, Icons.storefront_outlined, ar ? 'متجري' : 'Me'),
          ]))),
      ),
    );
  }
  Widget _btn(int idx, IconData icon, String label) {
    final on = _tab == idx;
    return Expanded(child: InkWell(onTap: () => setState(() => _tab = idx),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: on ? UC.brown : UC.muted, size: 22),
        const SizedBox(height: 3),
        Text(label, style: TextStyle(color: on ? UC.brown : UC.muted,
          fontSize: 10, fontWeight: FontWeight.w800)),
      ])));
  }
}
