// Carrier home — role-aware tabs: orders / cash / stats / drivers / me.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api.dart';
import '../main.dart';
import 'login_screen.dart';
import 'tabs.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? _me;
  bool _error = false;
  int _tab = 0;

  bool get _isManager => (_me?['role'] ?? '') == 'manager';

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final me = await CarrierApi.instance.me();
      if (mounted) setState(() { _me = me; _error = false; });
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  Future<void> _logout() async {
    await CarrierApi.instance.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final ar = CarrierApi.instance.lang == 'ar';
    final company = (_me?['company'] as Map?)?.cast<String, dynamic>();
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          const Text('🚚 ', style: TextStyle(fontSize: 18)),
          Expanded(child: Text(
              (company?['name'] ?? (ar ? 'يلو للتوصيل' : 'Uellow Delivery'))
                  .toString(),
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w900,
                  fontSize: 15))),
        ]),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          IconButton(
            onPressed: () async {
              await CarrierApi.instance.setLang(ar ? 'en' : 'ar');
              DeliveryApp.of(context)?.rebuild();
            },
            icon: const Icon(Icons.translate),
          ),
          IconButton(onPressed: _logout, icon: const Icon(Icons.logout)),
        ],
      ),
      body: _body(ar),
      bottomNavigationBar: _me == null || (_me?['role'] ?? '') == 'none'
          ? null
          : NavigationBar(
              selectedIndex: _tab,
              height: 64,
              backgroundColor: Colors.white,
              indicatorColor: kOrange.withValues(alpha: 0.15),
              onDestinationSelected: (i) => setState(() => _tab = i),
              destinations: [
                NavigationDestination(
                    icon: const Icon(Icons.local_shipping_outlined),
                    selectedIcon:
                        const Icon(Icons.local_shipping, color: kOrange),
                    label: ar ? 'الطلبات' : 'Orders'),
                if (_isManager) NavigationDestination(
                    icon: const Icon(Icons.payments_outlined),
                    selectedIcon:
                        const Icon(Icons.payments, color: kOrange),
                    label: ar ? 'التحصيل' : 'Cash'),
                NavigationDestination(
                    icon: const Icon(Icons.insights_outlined),
                    selectedIcon:
                        const Icon(Icons.insights, color: kOrange),
                    label: ar ? 'الإحصائيات' : 'Stats'),
                if (_isManager) NavigationDestination(
                    icon: const Icon(Icons.groups_outlined),
                    selectedIcon: const Icon(Icons.groups, color: kOrange),
                    label: ar ? 'السائقون' : 'Drivers'),
              ],
            ),
    );
  }

  Widget _body(bool ar) {
    if (_error) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.cloud_off_outlined, size: 56, color: Colors.grey),
        const SizedBox(height: 12),
        ElevatedButton(onPressed: _load,
            child: Text(ar ? 'إعادة المحاولة' : 'Retry')),
      ]));
    }
    final me = _me;
    if (me == null) {
      return const Center(child: CircularProgressIndicator(color: kDark));
    }
    if ((me['role'] ?? 'none') == 'none') {
      return Center(child: Padding(
        padding: const EdgeInsets.all(36),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('🔒', style: TextStyle(fontSize: 52)),
          const SizedBox(height: 12),
          Text(ar ? 'هذا الحساب ليس حساب شركة توصيل'
                  : 'This account is not a carrier account',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(ar ? 'اطلب من إدارة يلو ربط حسابك بشركة التوصيل'
                  : 'Ask Uellow to link your account to a carrier company',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 12.5)),
        ]),
      ));
    }
    // map nav index → tab widget (cash/drivers only for managers)
    final tabs = <Widget>[
      OrdersTab(me: me, isManager: _isManager, onChanged: _load),
      if (_isManager) CashTab(onChanged: _load),
      StatsTab(me: me),
      if (_isManager) const DriversTab(),
    ];
    return tabs[_tab.clamp(0, tabs.length - 1)];
  }
}

// ════════════════ ORDERS TAB ════════════════

class OrdersTab extends StatefulWidget {
  const OrdersTab({super.key, required this.me, required this.isManager,
      required this.onChanged});
  final Map<String, dynamic> me;
  final bool isManager;
  final VoidCallback onChanged;
  @override
  State<OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<OrdersTab> {
  List<Map<String, dynamic>>? _items;
  String _status = 'active';
  final _q = TextEditingController();

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final v = await CarrierApi.instance
          .orders(status: _status, q: _q.text.trim());
      if (mounted) setState(() => _items = v);
    } catch (_) {
      if (mounted) setState(() => _items = const []);
    }
  }

  void _setStatus(String s) {
    if (s == _status) return;
    setState(() { _status = s; _items = null; });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final ar = CarrierApi.instance.lang == 'ar';
    final counts = (widget.me['status_counts'] as Map?)
        ?.cast<String, dynamic>() ?? const {};
    final stats = (widget.me['stats'] as Map?)?.cast<String, dynamic>()
        ?? const {};
    final tabs = <(String, String, int)>[
      ('active', ar ? 'نشطة' : 'Active',
          (stats['active_orders'] as num?)?.toInt() ?? 0),
      ('pending', ar ? 'جديدة' : 'New',
          (counts['pending'] as num?)?.toInt() ?? 0),
      ('out_for_delivery', ar ? 'في الطريق' : 'On road',
          (counts['out_for_delivery'] as num?)?.toInt() ?? 0),
      ('delivered', ar ? 'مُسلّمة' : 'Delivered',
          (counts['delivered'] as num?)?.toInt() ?? 0),
      ('failed', ar ? 'فاشلة' : 'Failed',
          ((counts['failed'] as num?)?.toInt() ?? 0) +
              ((counts['failed_returned'] as num?)?.toInt() ?? 0)),
    ];
    final items = _items;
    return Column(children: [
      // hero stats strip
      Container(
        color: kDark,
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
        child: Row(children: [
          _hero(ar ? 'اليوم' : 'Today',
              '${stats['today_delivered'] ?? 0}', kOrangeLight),
          _hero(ar ? 'الأسبوع' : 'Week',
              '${stats['week_delivered'] ?? 0}', Colors.white),
          _hero(ar ? 'نسبة النجاح' : 'Success',
              '${stats['success_rate'] ?? 100}%', const Color(0xFF7BE495)),
          _hero(ar ? 'كاش معلق' : 'COD due',
              '${((stats['cod_pending_kd'] as num?) ?? 0).toStringAsFixed(1)}',
              kGold),
        ]),
      ),
      // search
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
        child: TextField(
          controller: _q,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _load(),
          decoration: InputDecoration(
            hintText: ar ? 'ابحث: رقم الطلب / هاتف / اسم العميل…'
                         : 'Search: order # / phone / customer…',
            prefixIcon: const Icon(Icons.search, size: 18),
            isDense: true, filled: true, fillColor: Colors.white,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
          ),
        ),
      ),
      // status chips
      SizedBox(height: 38, child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        children: [
          for (final t in tabs) Padding(
            padding: const EdgeInsetsDirectional.only(end: 6),
            child: ChoiceChip(
              label: Text('${t.$2}${t.$3 > 0 ? ' (${t.$3})' : ''}',
                  style: TextStyle(fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: _status == t.$1 ? Colors.white : kDark)),
              selected: _status == t.$1,
              selectedColor: kDark,
              backgroundColor: Colors.white,
              showCheckmark: false,
              onSelected: (_) => _setStatus(t.$1),
            ),
          ),
        ],
      )),
      Expanded(child: items == null
          ? const Center(child: CircularProgressIndicator(color: kDark))
          : items.isEmpty
              ? Center(child: Text(
                  ar ? 'لا توجد طلبات في هذه الحالة'
                     : 'No orders in this state',
                  style: const TextStyle(color: Colors.grey)))
              : RefreshIndicator(
                  onRefresh: () async { await _load(); widget.onChanged(); },
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 20),
                    itemCount: items.length,
                    itemBuilder: (_, i) => OrderCard(
                        o: items[i], isManager: widget.isManager,
                        onChanged: () { _load(); widget.onChanged(); }),
                  ))),
    ]);
  }

  Widget _hero(String label, String value, Color color) =>
      Expanded(child: Column(children: [
        Text(value, style: TextStyle(color: color, fontSize: 17,
            fontWeight: FontWeight.w900)),
        Text(label, style: const TextStyle(color: Colors.white54,
            fontSize: 10)),
      ]));
}

// ════════════════ ORDER CARD + ACTIONS ════════════════

class OrderCard extends StatelessWidget {
  const OrderCard({super.key, required this.o, required this.isManager,
      required this.onChanged});
  final Map<String, dynamic> o;
  final bool isManager;
  final VoidCallback onChanged;

  (Color, Color) _statusColors(String s) => switch (s) {
        'delivered' => (const Color(0xFFE6F7EF), kGreen),
        'failed' || 'failed_returned' =>
            (const Color(0xFFFDE8E8), kRed),
        'out_for_delivery' => (const Color(0xFFFFF1E8), kOrange),
        'assigned' => (const Color(0xFFEDF3FA), const Color(0xFF1D5FA6)),
        'arrived_sorting' =>
            (const Color(0xFFF3EDFA), const Color(0xFF6B3FA0)),
        _ => (const Color(0xFFF0F0F0), Colors.grey),
      };

  @override
  Widget build(BuildContext context) {
    final ar = CarrierApi.instance.lang == 'ar';
    final status = (o['status'] ?? 'pending').toString();
    final (chipBg, chipFg) = _statusColors(status);
    final label = (((o['status_label'] as Map?)?[ar ? 'ar' : 'en'])
        ?? status).toString();
    final cash = (o['payment'] ?? '') == 'cash';
    final customer = (o['customer'] as Map?)?.cast<String, dynamic>()
        ?? const {};
    return GestureDetector(
      onTap: () => _openDetail(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [BoxShadow(color: Color(0x11000000),
                blurRadius: 6, offset: Offset(0, 2))]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Row(children: [
            Text((o['name'] ?? '').toString(),
                style: const TextStyle(fontWeight: FontWeight.w900,
                    fontSize: 13.5, color: kDark)),
            if ((o['ref'] ?? '').toString().isNotEmpty)
              Text('  ·  ${o['ref']}', style: const TextStyle(
                  fontSize: 10.5, color: Colors.grey)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: chipBg,
                  borderRadius: BorderRadius.circular(999)),
              child: Text(label, style: TextStyle(fontSize: 10,
                  fontWeight: FontWeight.w900, color: chipFg)),
            ),
          ]),
          const SizedBox(height: 7),
          Row(children: [
            const Icon(Icons.person_outline, size: 14,
                color: Colors.grey),
            const SizedBox(width: 4),
            Expanded(child: Text(
                '${customer['name'] ?? ''} · ${customer['phone'] ?? ''}',
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12,
                    fontWeight: FontWeight.w600))),
          ]),
          if ((o['address'] ?? '').toString().isNotEmpty) Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Row(children: [
              const Icon(Icons.place_outlined, size: 14,
                  color: Colors.grey),
              const SizedBox(width: 4),
              Expanded(child: Text((o['address']).toString(),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11,
                      color: Colors.grey))),
            ]),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: cash ? const Color(0xFFFFF6DC)
                            : const Color(0xFFE9F4EE),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(
                  cash
                      ? '💵 ${(o['amount'] as num?)?.toStringAsFixed(3)} ${ar ? 'كاش' : 'COD'}'
                      : '✅ ${ar ? 'مدفوع أونلاين' : 'Paid online'}',
                  style: TextStyle(fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: cash
                          ? const Color(0xFF8B6508) : kGreen)),
            ),
            const SizedBox(width: 6),
            if (o['driver'] != null) Flexible(child: Text(
                '🛵 ${(o['driver'] as Map)['name']}',
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11,
                    color: Colors.grey, fontWeight: FontWeight.w700))),
            const Spacer(),
            Text('${o['items_count'] ?? 0} ${ar ? 'منتج' : 'items'}',
                style: const TextStyle(fontSize: 10.5,
                    color: Colors.grey)),
          ]),
        ]),
      ),
    );
  }

  void _openDetail(BuildContext context) {
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius:
          BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => OrderSheet(
          orderId: (o['id'] as num).toInt(),
          isManager: isManager, onChanged: onChanged),
    );
  }
}

// ── full order sheet with actions ──

class OrderSheet extends StatefulWidget {
  const OrderSheet({super.key, required this.orderId,
      required this.isManager, required this.onChanged});
  final int orderId;
  final bool isManager;
  final VoidCallback onChanged;
  @override
  State<OrderSheet> createState() => _OrderSheetState();
}

class _OrderSheetState extends State<OrderSheet> {
  Map<String, dynamic>? _o;
  bool _busy = false;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final o = await CarrierApi.instance.orderDetail(widget.orderId);
      if (mounted) setState(() => _o = o);
    } catch (_) {
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _act(String act, {Map<String, dynamic>? body}) async {
    setState(() => _busy = true);
    try {
      final o = await CarrierApi.instance
          .action(widget.orderId, act, body: body);
      if (mounted) setState(() { _o = o; _busy = false; });
      widget.onChanged();
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _deliver() async {
    final ar = CarrierApi.instance.lang == 'ar';
    String? proofB64;
    // proof photo (optional but encouraged)
    try {
      final shot = await ImagePicker().pickImage(
          source: ImageSource.camera, maxWidth: 1100, imageQuality: 72);
      if (shot != null) {
        proofB64 = base64Encode(await File(shot.path).readAsBytes());
      }
    } catch (_) {}
    // GPS stamp (best-effort)
    double? lat, lng;
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm != LocationPermission.denied &&
          perm != LocationPermission.deniedForever) {
        final pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.medium))
            .timeout(const Duration(seconds: 8));
        lat = pos.latitude; lng = pos.longitude;
      }
    } catch (_) {}
    await _act('deliver', body: {
      if (proofB64 != null) 'proof_image': proofB64,
      if (lat != null) 'lat': lat, if (lng != null) 'lng': lng,
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ar ? '✅ تم تأكيد التسليم' : '✅ Delivery confirmed')));
    }
  }

  Future<void> _fail() async {
    final ar = CarrierApi.instance.lang == 'ar';
    final reasons = ar
        ? ['العميل لا يرد', 'العنوان غير صحيح', 'العميل رفض الاستلام',
           'العميل طلب التأجيل', 'أخرى']
        : ['No answer', 'Wrong address', 'Customer refused',
           'Customer postponed', 'Other'];
    final reason = await showModalBottomSheet<String>(
      context: context, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius:
          BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(child: Column(
          mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.all(14),
          child: Text(ar ? 'سبب فشل التسليم' : 'Failure reason',
              style: const TextStyle(fontWeight: FontWeight.w900,
                  fontSize: 15)),
        ),
        for (final r in reasons) ListTile(
          title: Text(r, style: const TextStyle(fontSize: 13)),
          leading: const Icon(Icons.error_outline, color: kRed, size: 18),
          onTap: () => Navigator.pop(ctx, r),
        ),
      ])),
    );
    if (reason == null) return;
    await _act('fail', body: {'reason': reason});
  }

  Future<void> _assignDriver() async {
    final ar = CarrierApi.instance.lang == 'ar';
    List<Map<String, dynamic>> drivers = [];
    try { drivers = await CarrierApi.instance.drivers(); } catch (_) {}
    if (!mounted) return;
    final picked = await showModalBottomSheet<int>(
      context: context, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius:
          BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(child: Column(
          mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.all(14),
          child: Text(ar ? 'اختر السائق' : 'Pick a driver',
              style: const TextStyle(fontWeight: FontWeight.w900,
                  fontSize: 15)),
        ),
        if (drivers.isEmpty) Padding(
            padding: const EdgeInsets.all(20),
            child: Text(ar ? 'لا يوجد سائقون — أضفهم من تبويب السائقين'
                           : 'No drivers — add them from the Drivers tab')),
        for (final d in drivers.take(12)) ListTile(
          leading: const Icon(Icons.sports_motorsports_outlined,
              color: kDark),
          title: Text((d['name'] ?? '').toString(),
              style: const TextStyle(fontSize: 13,
                  fontWeight: FontWeight.w700)),
          subtitle: Text(
              '${d['phone'] ?? ''} · ${ar ? 'نشط الآن' : 'active'}: ${d['active_orders'] ?? 0}',
              style: const TextStyle(fontSize: 11)),
          onTap: () => Navigator.pop(ctx, (d['id'] as num).toInt()),
        ),
      ])),
    );
    if (picked == null) return;
    await _act('assign', body: {'driver_id': picked});
  }

  @override
  Widget build(BuildContext context) {
    final ar = CarrierApi.instance.lang == 'ar';
    final o = _o;
    if (o == null) {
      return const SizedBox(height: 280,
          child: Center(child: CircularProgressIndicator(color: kDark)));
    }
    final status = (o['status'] ?? '').toString();
    final customer = (o['customer'] as Map?)?.cast<String, dynamic>()
        ?? const {};
    final items = List<Map<String, dynamic>>.from(
        (o['items'] as List?) ?? const []);
    final fees = (o['fees'] as Map?)?.cast<String, dynamic>();
    final cash = (o['payment'] ?? '') == 'cash';
    final phone = (customer['phone'] ?? '').toString();
    final mapUrl = (o['map_url'] ?? '').toString();
    return DraggableScrollableSheet(
      expand: false, initialChildSize: 0.85, maxChildSize: 0.95,
      builder: (_, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 30),
        children: [
          Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: const Color(0xFFE3E3E3),
                  borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 12),
          Row(children: [
            Text((o['name'] ?? '').toString(),
                style: const TextStyle(fontWeight: FontWeight.w900,
                    fontSize: 17, color: kDark)),
            const Spacer(),
            Text((((o['status_label'] as Map?)?[ar ? 'ar' : 'en'])
                ?? '').toString(),
                style: const TextStyle(fontWeight: FontWeight.w800,
                    fontSize: 12, color: kOrange)),
          ]),
          const SizedBox(height: 12),
          // quick actions: call / whatsapp / navigate
          Row(children: [
            _quick(Icons.call, ar ? 'اتصال' : 'Call', kGreen,
                phone.isEmpty ? null
                    : () => launchUrl(Uri.parse('tel:$phone'))),
            const SizedBox(width: 8),
            _quick(Icons.chat, 'WhatsApp', const Color(0xFF25D366),
                phone.isEmpty ? null : () => launchUrl(
                    Uri.parse('https://wa.me/${phone.replaceAll(RegExp(r'[^0-9]'), '')}'),
                    mode: LaunchMode.externalApplication)),
            const SizedBox(width: 8),
            _quick(Icons.navigation, ar ? 'الخريطة' : 'Navigate',
                const Color(0xFF1D5FA6),
                mapUrl.isEmpty ? null : () => launchUrl(Uri.parse(mapUrl),
                    mode: LaunchMode.externalApplication)),
          ]),
          const SizedBox(height: 14),
          _box(children: [
            _row(ar ? 'العميل' : 'Customer',
                '${customer['name'] ?? ''}'),
            _row(ar ? 'الهاتف' : 'Phone', phone),
            _row(ar ? 'العنوان' : 'Address',
                (o['address'] ?? '—').toString()),
            _row(ar ? 'الدفع' : 'Payment', cash
                ? '💵 ${ar ? "كاش عند التسليم" : "Cash on delivery"} — ${(o['amount'] as num?)?.toStringAsFixed(3)} ${ar ? "د.ك" : "KD"}'
                : '✅ ${ar ? "مدفوع أونلاين" : "Paid online"}'),
            if (o['driver'] != null)
              _row(ar ? 'السائق' : 'Driver',
                  '${(o['driver'] as Map)['name']}'),
            if ((o['note'] ?? '').toString().isNotEmpty)
              _row(ar ? 'ملاحظات' : 'Notes', (o['note']).toString()),
          ]),
          const SizedBox(height: 10),
          // items
          _box(children: [
            Text(ar ? '📦 المنتجات (${items.length})'
                    : '📦 Items (${items.length})',
                style: const TextStyle(fontWeight: FontWeight.w900,
                    fontSize: 12.5)),
            const SizedBox(height: 6),
            for (final it in items) Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                Expanded(child: Text((it['name'] ?? '').toString(),
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12))),
                Text('×${(it['qty'] as num?)?.toInt() ?? 1}',
                    style: const TextStyle(fontSize: 12,
                        fontWeight: FontWeight.w800)),
              ]),
            ),
          ]),
          if (widget.isManager && fees != null) ...[
            const SizedBox(height: 10),
            _box(children: [
              Text(ar ? '💰 رسومك على هذا الطلب'
                      : '💰 Your fees on this order',
                  style: const TextStyle(fontWeight: FontWeight.w900,
                      fontSize: 12.5)),
              const SizedBox(height: 6),
              _row(ar ? 'رسوم التوصيل' : 'Delivery fee',
                  '${fees['delivery']}'),
              _row(ar ? 'عمولة الكاش' : 'Cash commission',
                  '${fees['cash_commission']}'),
              _row(ar ? 'الصافي' : 'Net', '${fees['net']}'),
            ]),
          ],
          const SizedBox(height: 16),
          // status actions
          if (_busy)
            const Center(child: CircularProgressIndicator(color: kDark))
          else ..._actions(status, ar),
        ],
      ),
    );
  }

  List<Widget> _actions(String status, bool ar) {
    final out = <Widget>[];
    void add(String label, Color color, VoidCallback onTap,
        {IconData icon = Icons.check}) {
      out.add(Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: SizedBox(width: double.infinity, child: ElevatedButton.icon(
          onPressed: onTap,
          icon: Icon(icon, size: 17),
          style: ElevatedButton.styleFrom(backgroundColor: color,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 13)),
          label: Text(label, style: const TextStyle(fontSize: 13.5)),
        )),
      ));
    }
    final m = widget.isManager;
    switch (status) {
      case 'pending':
        if (m) {
          add(ar ? '📥 استلام في مركز الفرز' : '📥 Receive at sorting',
              const Color(0xFF6B3FA0), () => _act('receive'));
          add(ar ? '🚫 لم يُستلم — مرتجع' : '🚫 Not received — return',
              kRed, () => _act('not-received'),
              icon: Icons.block);
        }
      case 'arrived_sorting':
      case 'assigned':
        if (m) {
          add(ar ? '🛵 إسناد لسائق' : '🛵 Assign driver',
              const Color(0xFF1D5FA6), _assignDriver,
              icon: Icons.sports_motorsports);
        }
        add(ar ? '🚚 خرج للتوصيل' : '🚚 Out for delivery',
            kOrange, () => _act('start'), icon: Icons.local_shipping);
      case 'out_for_delivery':
        add(ar ? '✅ تأكيد التسليم (صورة إثبات + GPS)'
               : '✅ Confirm delivery (proof + GPS)',
            kGreen, _deliver, icon: Icons.camera_alt);
        add(ar ? '❌ فشل التسليم' : '❌ Failed', kRed, _fail,
            icon: Icons.error_outline);
        if (m) {
          add(ar ? '↩️ إلغاء الإسناد' : '↩️ Unassign', Colors.grey,
              () => _act('unassign'), icon: Icons.undo);
        }
      case 'failed':
        if (m) {
          add(ar ? '↩️ تم إرجاعه إلى يلو' : '↩️ Returned to Uellow',
              const Color(0xFF6B3FA0), () => _act('return'),
              icon: Icons.keyboard_return);
        }
        add(ar ? '🚚 محاولة توصيل جديدة' : '🚚 Retry delivery',
            kOrange, () => _act('start'), icon: Icons.refresh);
    }
    return out;
  }

  Widget _quick(IconData icon, String label, Color color,
          VoidCallback? onTap) =>
      Expanded(child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: onTap == null
                ? const Color(0xFFF0F0F0)
                : color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: onTap == null
                ? const Color(0xFFE3E3E3)
                : color.withValues(alpha: 0.35)),
          ),
          child: Column(children: [
            Icon(icon, size: 19,
                color: onTap == null ? Colors.grey : color),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 10,
                fontWeight: FontWeight.w800,
                color: onTap == null ? Colors.grey : color)),
          ]),
        ),
      ));

  Widget _box({required List<Widget> children}) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: const Color(0xFFF7F8FA),
            borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: children),
      );

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 92, child: Text(k, style: const TextStyle(
              fontSize: 11.5, color: Colors.grey,
              fontWeight: FontWeight.w700))),
          Expanded(child: Text(v, style: const TextStyle(fontSize: 12,
              fontWeight: FontWeight.w600))),
        ]),
      );
}
