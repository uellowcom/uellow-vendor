import 'package:flutter/material.dart';
import '../api/api.dart';
import '../theme/theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _go());
  }
  Future<void> _go() async {
    final api = VendorApi.instance;
    if (api.token.isEmpty) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }
    if (api.adminOnly) {
      Navigator.pushReplacementNamed(context, '/admin');
      return;
    }
    if (api.vendor == null) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }
    try {
      await api.me();
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home');
    } catch (_) {
      await api.logout();
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/login');
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UC.yellow,
      body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 110, height: 110, alignment: Alignment.center,
          decoration: BoxDecoration(color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [BoxShadow(color: Color(0x33000000),
                  blurRadius: 16, offset: Offset(0, 8))]),
          child: ClipRRect(borderRadius: BorderRadius.circular(20),
            child: Image.asset('assets/images/logo.png', width: 78, height: 78)),
        ),
        const SizedBox(height: 18),
        const Text('Uellow Vendor',
            style: TextStyle(color: UC.brown, fontSize: 22, fontWeight: FontWeight.w900)),
        const SizedBox(height: 22),
        const USpinner(size: 22),
      ])),
    );
  }
}
