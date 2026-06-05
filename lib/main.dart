// =============================================================================
// Uellow Delivery — carrier companies & drivers companion app (v1.0.0).
// Managers: company orders, drivers, cash & remittances, stats.
// Drivers: their queue + deliver/fail flow with proof photo + GPS.
// =============================================================================
import 'package:flutter/material.dart';

import 'api.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

// Distinct identity: deep indigo + signal orange
const kDark = Color(0xFF15203A);
const kAccent2 = Color(0xFF24345C);
const kOrange = Color(0xFFFF7A30);
const kOrangeLight = Color(0xFFFFA46B);
const kGold = Color(0xFFF5C320);
const kBg = Color(0xFFF2F4F8);
const kGreen = Color(0xFF1F8A40);
const kRed = Color(0xFFC0392B);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await CarrierApi.instance.init();
  runApp(const DeliveryApp());
}

class DeliveryApp extends StatefulWidget {
  const DeliveryApp({super.key});
  static _DeliveryAppState? of(BuildContext c) =>
      c.findAncestorStateOfType<_DeliveryAppState>();
  @override
  State<DeliveryApp> createState() => _DeliveryAppState();
}

class _DeliveryAppState extends State<DeliveryApp> {
  void rebuild() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final ar = CarrierApi.instance.lang == 'ar';
    return MaterialApp(
      title: 'Uellow Delivery',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Tajawal',
        scaffoldBackgroundColor: kBg,
        colorScheme: ColorScheme.fromSeed(
            seedColor: kOrange, primary: kDark, secondary: kOrange),
        appBarTheme: const AppBarTheme(
          backgroundColor: kDark, foregroundColor: Colors.white,
          elevation: 0, centerTitle: false,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: kOrange, foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(
                fontFamily: 'Tajawal', fontWeight: FontWeight.w900),
          ),
        ),
      ),
      builder: (c, child) => Directionality(
        textDirection: ar ? TextDirection.rtl : TextDirection.ltr,
        child: child ?? const SizedBox.shrink(),
      ),
      home: CarrierApi.instance.signedIn
          ? const HomeScreen() : const LoginScreen(),
    );
  }
}
