// Sign-in for carrier portal users (managers + drivers).
import 'dart:async';

import 'package:flutter/material.dart';

import '../api.dart';
import '../fcm_service.dart';
import '../main.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _busy = false;
  bool _hide = true;

  Future<void> _go() async {
    final ar = CarrierApi.instance.lang == 'ar';
    if (_email.text.trim().isEmpty || _pass.text.isEmpty) {
      _snack(ar ? 'أدخل البريد وكلمة المرور' : 'Enter email and password');
      return;
    }
    setState(() => _busy = true);
    try {
      await CarrierApi.instance.login(_email.text.trim(), _pass.text);
      unawaited(FcmService.instance.register());
      if (!mounted) return;
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => const HomeScreen()));
    } on ApiException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack(ar ? 'تعذّر الاتصال — حاول مرة أخرى'
                : 'Connection failed — try again');
    }
    if (mounted) setState(() => _busy = false);
  }

  void _snack(String m) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final ar = CarrierApi.instance.lang == 'ar';
    return Scaffold(
      backgroundColor: kDark,
      body: SafeArea(child: Center(child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          Align(
            alignment: AlignmentDirectional.topEnd,
            child: TextButton(
              onPressed: () async {
                await CarrierApi.instance.setLang(ar ? 'en' : 'ar');
                DeliveryApp.of(context)?.rebuild();
              },
              child: Text(ar ? 'English' : 'العربية',
                  style: const TextStyle(color: kOrangeLight,
                      fontWeight: FontWeight.w800)),
            ),
          ),
          const Text('🚚', style: TextStyle(fontSize: 58)),
          const SizedBox(height: 6),
          Text(ar ? 'يلو للتوصيل' : 'Uellow Delivery',
              style: const TextStyle(color: kOrangeLight, fontSize: 26,
                  fontWeight: FontWeight.w900)),
          Text(ar ? 'لوحة شركات التوصيل والسائقين'
                  : 'Carrier companies & drivers console',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white60,
                  fontSize: 12.5)),
          const SizedBox(height: 26),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(children: [
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: ar ? 'البريد الإلكتروني' : 'Email',
                  isDense: true,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _pass, obscureText: _hide,
                decoration: InputDecoration(
                  labelText: ar ? 'كلمة المرور' : 'Password',
                  isDense: true,
                  suffixIcon: IconButton(
                    icon: Icon(_hide
                        ? Icons.visibility_off : Icons.visibility,
                        size: 18),
                    onPressed: () => setState(() => _hide = !_hide),
                  ),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(width: double.infinity, child: ElevatedButton(
                onPressed: _busy ? null : _go,
                style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                child: _busy
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white))
                    : Text(ar ? 'تسجيل الدخول' : 'Sign in'),
              )),
            ]),
          ),
          const SizedBox(height: 14),
          Text(ar ? 'احصل على حسابك من إدارة يلو أو من مدير شركتك'
                  : 'Accounts are issued by Uellow or your company manager',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white38, fontSize: 11)),
        ]),
      ))),
    );
  }
}
