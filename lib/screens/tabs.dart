// Cash & remittances / Stats / Drivers tabs (manager-heavy).
import 'package:flutter/material.dart';

import '../api.dart';
import '../main.dart';

// ════════════════ CASH TAB ════════════════

class CashTab extends StatefulWidget {
  const CashTab({super.key, required this.onChanged});
  final VoidCallback onChanged;
  @override
  State<CashTab> createState() => _CashTabState();
}

class _CashTabState extends State<CashTab> {
  Map<String, dynamic>? _data;
  final Set<int> _selected = {};

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final d = await CarrierApi.instance.cash();
      if (mounted) setState(() { _data = d; _selected.clear(); });
    } catch (_) {
      if (mounted) setState(() => _data = const {});
    }
  }

  Future<void> _remit() async {
    final ar = CarrierApi.instance.lang == 'ar';
    if (_selected.isEmpty) return;
    final refCtrl = TextEditingController();
    final ok = await showModalBottomSheet<bool>(
      context: context, isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius:
          BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(18, 16, 18,
            18 + MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(ar ? '📨 إنشاء تسوية (${_selected.length} طلب)'
                  : '📨 Create remittance (${_selected.length})',
              style: const TextStyle(fontWeight: FontWeight.w900,
                  fontSize: 15)),
          const SizedBox(height: 10),
          TextField(
            controller: refCtrl,
            decoration: InputDecoration(
                labelText: ar ? 'مرجع التحويل (اختياري)'
                              : 'Transfer reference (optional)',
                border: const OutlineInputBorder()),
          ),
          const SizedBox(height: 14),
          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 13)),
            child: Text(ar ? 'تأكيد التسوية' : 'Confirm'),
          )),
        ]),
      ),
    );
    if (ok != true) return;
    try {
      final res = await CarrierApi.instance
          .remit(_selected.toList(), ref: refCtrl.text.trim());
      _load(); widget.onChanged();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(ar
                ? '✓ أُنشئت التسوية ${res['name']}'
                : '✓ Remittance ${res['name']} created')));
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ar = CarrierApi.instance.lang == 'ar';
    final d = _data;
    if (d == null) {
      return const Center(child: CircularProgressIndicator(color: kDark));
    }
    final cashReady = List<Map<String, dynamic>>.from(
        (d['cash_ready'] as List?) ?? const []);
    final onlineReady = List<Map<String, dynamic>>.from(
        (d['online_ready'] as List?) ?? const []);
    final rems = List<Map<String, dynamic>>.from(
        (d['remittances'] as List?) ?? const []);
    double selectedTotal = 0;
    for (final o in [...cashReady, ...onlineReady]) {
      if (_selected.contains((o['id'] as num).toInt()) &&
          (o['payment'] ?? '') == 'cash') {
        selectedTotal += ((o['amount'] as num?) ?? 0).toDouble();
      }
    }
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: _selected.isEmpty ? null
          : FloatingActionButton.extended(
              backgroundColor: kOrange, foregroundColor: Colors.white,
              onPressed: _remit,
              icon: const Icon(Icons.send),
              label: Text(ar
                  ? 'تسوية ${_selected.length} (${selectedTotal.toStringAsFixed(3)})'
                  : 'Remit ${_selected.length} (${selectedTotal.toStringAsFixed(3)})',
                  style: const TextStyle(fontWeight: FontWeight.w900)),
            ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 90),
            children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF8B6508), kGold]),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(children: [
              const Text('💵', style: TextStyle(fontSize: 28)),
              const SizedBox(width: 10),
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('${((d['cash_total'] as num?) ?? 0).toStringAsFixed(3)} ${ar ? 'د.ك' : 'KD'}',
                    style: const TextStyle(color: Colors.white,
                        fontSize: 19, fontWeight: FontWeight.w900)),
                Text(ar
                    ? 'كاش محصَّل بانتظار التسوية (${cashReady.length} طلب)'
                    : 'Collected COD awaiting remittance (${cashReady.length})',
                    style: const TextStyle(color: Colors.white70,
                        fontSize: 11)),
              ])),
            ]),
          ),
          const SizedBox(height: 12),
          if (cashReady.isNotEmpty) ...[
            Text(ar ? '💵 كاش جاهز للتسوية' : '💵 COD ready',
                style: const TextStyle(fontWeight: FontWeight.w900,
                    fontSize: 13)),
            const SizedBox(height: 6),
            for (final o in cashReady) _orderRow(o, ar, cash: true),
          ],
          if (onlineReady.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(ar ? '✅ أونلاين مُسلّمة (للتقرير)'
                    : '✅ Delivered online orders',
                style: const TextStyle(fontWeight: FontWeight.w900,
                    fontSize: 13)),
            const SizedBox(height: 6),
            for (final o in onlineReady) _orderRow(o, ar, cash: false),
          ],
          if (cashReady.isEmpty && onlineReady.isEmpty)
            Padding(padding: const EdgeInsets.all(30),
                child: Center(child: Text(
                    ar ? 'لا توجد طلبات جاهزة للتسوية الآن'
                       : 'Nothing ready to remit',
                    style: const TextStyle(color: Colors.grey)))),
          const SizedBox(height: 14),
          Text(ar ? '🧾 التسويات السابقة' : '🧾 Past remittances',
              style: const TextStyle(fontWeight: FontWeight.w900,
                  fontSize: 13)),
          const SizedBox(height: 6),
          if (rems.isEmpty)
            Padding(padding: const EdgeInsets.all(16),
                child: Center(child: Text(ar ? 'لا توجد تسويات بعد'
                                             : 'No remittances yet',
                    style: const TextStyle(color: Colors.grey)))),
          for (final r in rems) Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(color: Colors.white,
                borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              Text((r['name'] ?? '').toString(),
                  style: const TextStyle(fontWeight: FontWeight.w800,
                      fontSize: 12)),
              const SizedBox(width: 8),
              Text('${r['orders']} ${ar ? 'طلب' : 'orders'}',
                  style: const TextStyle(fontSize: 11,
                      color: Colors.grey)),
              const Spacer(),
              Text('${((r['total'] as num?) ?? 0).toStringAsFixed(3)}',
                  style: const TextStyle(fontWeight: FontWeight.w900,
                      fontSize: 12.5, color: kDark)),
              const SizedBox(width: 8),
              Text((r['state'] ?? '') == 'confirmed' ||
                      (r['state'] ?? '') == 'done'
                  ? '✅' : '⏳', style: const TextStyle(fontSize: 13)),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _orderRow(Map<String, dynamic> o, bool ar, {required bool cash}) {
    final id = (o['id'] as num).toInt();
    final on = _selected.contains(id);
    final customer =
        (o['customer'] as Map?)?.cast<String, dynamic>() ?? const {};
    return GestureDetector(
      onTap: () => setState(() => on
          ? _selected.remove(id) : _selected.add(id)),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: on ? kOrange : Colors.transparent, width: 1.6),
        ),
        child: Row(children: [
          Icon(on ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 20, color: on ? kOrange : Colors.grey),
          const SizedBox(width: 8),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text((o['name'] ?? '').toString(),
                style: const TextStyle(fontWeight: FontWeight.w800,
                    fontSize: 12)),
            Text((customer['name'] ?? '').toString(),
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10.5,
                    color: Colors.grey)),
          ])),
          Text(cash
              ? '${((o['amount'] as num?) ?? 0).toStringAsFixed(3)}'
              : (ar ? 'أونلاين' : 'online'),
              style: TextStyle(fontWeight: FontWeight.w900,
                  fontSize: 12.5,
                  color: cash ? const Color(0xFF8B6508) : kGreen)),
        ]),
      ),
    );
  }
}

// ════════════════ STATS TAB ════════════════

class StatsTab extends StatefulWidget {
  const StatsTab({super.key, required this.me});
  final Map<String, dynamic> me;
  @override
  State<StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<StatsTab> {
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    CarrierApi.instance.stats().then((d) {
      if (mounted) setState(() => _data = d);
    }).catchError((_) {
      if (mounted) setState(() => _data = const {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final ar = CarrierApi.instance.lang == 'ar';
    final d = _data;
    final stats = (widget.me['stats'] as Map?)?.cast<String, dynamic>()
        ?? const {};
    if (d == null) {
      return const Center(child: CircularProgressIndicator(color: kDark));
    }
    final days = List<Map<String, dynamic>>.from(
        (d['days'] as List?) ?? const []);
    final breakdown = (d['breakdown'] as Map?)?.cast<String, dynamic>()
        ?? const {};
    final top = List<Map<String, dynamic>>.from(
        (d['top_drivers'] as List?) ?? const []);
    final maxV = days.fold<int>(1, (m, x) {
      final v = ((x['delivered'] as num?) ?? 0).toInt();
      return v > m ? v : m;
    });
    return ListView(padding: const EdgeInsets.all(14), children: [
      Row(children: [
        _big(ar ? 'تسليمات الشهر' : 'Month',
            '${stats['month_delivered'] ?? 0}', kDark),
        const SizedBox(width: 8),
        _big(ar ? 'نسبة النجاح' : 'Success',
            '${stats['success_rate'] ?? 100}%', kGreen),
        const SizedBox(width: 8),
        _big(ar ? 'كاش اليوم' : 'COD today',
            '${((stats['cod_today_kd'] as num?) ?? 0).toStringAsFixed(1)}',
            const Color(0xFF8B6508)),
      ]),
      const SizedBox(height: 14),
      // 14-day bar chart (pure widgets — no chart package needed)
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white,
            borderRadius: BorderRadius.circular(14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Text(ar ? '📈 التسليمات — آخر 14 يوماً'
                  : '📈 Deliveries — last 14 days',
              style: const TextStyle(fontWeight: FontWeight.w900,
                  fontSize: 13)),
          const SizedBox(height: 12),
          SizedBox(height: 120, child: Row(
              crossAxisAlignment: CrossAxisAlignment.end, children: [
            for (final x in days) Expanded(child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.5),
              child: Column(mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                if (((x['delivered'] as num?) ?? 0) > 0)
                  Text('${x['delivered']}', style: const TextStyle(
                      fontSize: 8, fontWeight: FontWeight.w800,
                      color: kDark)),
                const SizedBox(height: 2),
                Container(
                  height: 4 + 90 *
                      (((x['delivered'] as num?) ?? 0).toInt() / maxV),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [kOrange, kOrangeLight]),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 3),
                Text((x['date'] ?? '').toString().substring(8),
                    style: const TextStyle(fontSize: 7.5,
                        color: Colors.grey)),
              ]),
            )),
          ])),
        ]),
      ),
      const SizedBox(height: 12),
      // status breakdown
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white,
            borderRadius: BorderRadius.circular(14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Text(ar ? '📊 الطلبات حسب الحالة' : '📊 Orders by status',
              style: const TextStyle(fontWeight: FontWeight.w900,
                  fontSize: 13)),
          const SizedBox(height: 8),
          for (final e in [
            ('pending', ar ? 'جديدة' : 'New', Colors.grey),
            ('arrived_sorting', ar ? 'في الفرز' : 'Sorting',
                const Color(0xFF6B3FA0)),
            ('out_for_delivery', ar ? 'في الطريق' : 'On road', kOrange),
            ('delivered', ar ? 'مُسلّمة' : 'Delivered', kGreen),
            ('failed', ar ? 'فاشلة' : 'Failed', kRed),
            ('failed_returned', ar ? 'مرتجعة' : 'Returned',
                const Color(0xFF8E44AD)),
          ]) Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(children: [
              Container(width: 10, height: 10,
                  decoration: BoxDecoration(color: e.$3,
                      borderRadius: BorderRadius.circular(3))),
              const SizedBox(width: 8),
              Expanded(child: Text(e.$2,
                  style: const TextStyle(fontSize: 12,
                      fontWeight: FontWeight.w600))),
              Text('${breakdown[e.$1] ?? 0}',
                  style: const TextStyle(fontSize: 12.5,
                      fontWeight: FontWeight.w900)),
            ]),
          ),
        ]),
      ),
      if (top.isNotEmpty) ...[
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white,
              borderRadius: BorderRadius.circular(14)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text(ar ? '🏆 أفضل السائقين هذا الشهر'
                    : '🏆 Top drivers this month',
                style: const TextStyle(fontWeight: FontWeight.w900,
                    fontSize: 13)),
            const SizedBox(height: 8),
            for (var i = 0; i < top.length; i++) Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                SizedBox(width: 24, child: Text(
                    ['🥇', '🥈', '🥉'].elementAtOrNull(i) ?? '${i + 1}.',
                    style: const TextStyle(fontSize: 13))),
                Expanded(child: Text((top[i]['name'] ?? '').toString(),
                    style: const TextStyle(fontSize: 12,
                        fontWeight: FontWeight.w700))),
                Text('${top[i]['delivered']} ${ar ? 'تسليم' : 'deliveries'}',
                    style: const TextStyle(fontSize: 11.5,
                        fontWeight: FontWeight.w800, color: kGreen)),
              ]),
            ),
          ]),
        ),
      ],
    ]);
  }

  Widget _big(String label, String value, Color color) =>
      Expanded(child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
        decoration: BoxDecoration(color: Colors.white,
            borderRadius: BorderRadius.circular(12)),
        child: Column(children: [
          FittedBox(child: Text(value, style: TextStyle(fontSize: 17,
              fontWeight: FontWeight.w900, color: color))),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 10,
              color: Colors.grey, fontWeight: FontWeight.w700)),
        ]),
      ));
}

// ════════════════ DRIVERS TAB ════════════════

class DriversTab extends StatefulWidget {
  const DriversTab({super.key});
  @override
  State<DriversTab> createState() => _DriversTabState();
}

class _DriversTabState extends State<DriversTab> {
  List<Map<String, dynamic>>? _items;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final v = await CarrierApi.instance.drivers();
      if (mounted) setState(() => _items = v);
    } catch (_) {
      if (mounted) setState(() => _items = const []);
    }
  }

  Future<void> _addDriver() async {
    final ar = CarrierApi.instance.lang == 'ar';
    final name = TextEditingController();
    final phone = TextEditingController();
    final vehicle = TextEditingController();
    final email = TextEditingController();
    final pass = TextEditingController();
    final ok = await showModalBottomSheet<bool>(
      context: context, isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius:
          BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(18, 16, 18,
            18 + MediaQuery.of(ctx).viewInsets.bottom),
        child: SingleChildScrollView(child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(ar ? '🛵 إضافة سائق' : '🛵 Add driver',
              style: const TextStyle(fontWeight: FontWeight.w900,
                  fontSize: 15)),
          const SizedBox(height: 10),
          for (final f in [
            (name, ar ? 'الاسم *' : 'Name *'),
            (phone, ar ? 'الهاتف *' : 'Phone *'),
            (vehicle, ar ? 'المركبة' : 'Vehicle'),
          ]) Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TextField(controller: f.$1,
                decoration: InputDecoration(labelText: f.$2,
                    isDense: true,
                    border: const OutlineInputBorder())),
          ),
          Text(ar ? 'حساب دخول للتطبيق (اختياري):'
                  : 'App login (optional):',
              style: const TextStyle(fontSize: 11.5,
                  fontWeight: FontWeight.w800, color: Colors.grey)),
          const SizedBox(height: 6),
          for (final f in [
            (email, ar ? 'البريد الإلكتروني' : 'Email'),
            (pass, ar ? 'كلمة المرور' : 'Password'),
          ]) Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TextField(controller: f.$1,
                decoration: InputDecoration(labelText: f.$2,
                    isDense: true,
                    border: const OutlineInputBorder())),
          ),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 13)),
            child: Text(ar ? 'إضافة السائق' : 'Add driver'),
          )),
        ])),
      ),
    );
    if (ok != true) return;
    final ar2 = CarrierApi.instance.lang == 'ar';
    if (name.text.trim().isEmpty || phone.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
          ar2 ? 'الاسم والهاتف مطلوبان' : 'Name and phone required')));
      return;
    }
    try {
      await CarrierApi.instance.createDriver(
        name: name.text.trim(), phone: phone.text.trim(),
        vehicle: vehicle.text.trim(),
        email: email.text.trim(), password: pass.text,
      );
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
            ar2 ? '✓ أُضيف السائق' : '✓ Driver added')));
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ar = CarrierApi.instance.lang == 'ar';
    final items = _items;
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: kOrange, foregroundColor: Colors.white,
        onPressed: _addDriver,
        icon: const Icon(Icons.add),
        label: Text(ar ? 'سائق جديد' : 'New driver',
            style: const TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: items == null
          ? const Center(child: CircularProgressIndicator(color: kDark))
          : items.isEmpty
              ? Center(child: Text(
                  ar ? 'لا يوجد سائقون — أضف أول سائق'
                     : 'No drivers yet — add the first one',
                  style: const TextStyle(color: Colors.grey)))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 90),
                    itemCount: items.length,
                    itemBuilder: (_, i) {
                      final d = items[i];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.white,
                            borderRadius: BorderRadius.circular(14)),
                        child: Row(children: [
                          Container(
                            width: 44, height: 44,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: kDark.withValues(alpha: 0.06),
                              shape: BoxShape.circle,
                            ),
                            child: const Text('🛵',
                                style: TextStyle(fontSize: 20)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                            Row(children: [
                              Text((d['name'] ?? '').toString(),
                                  style: const TextStyle(fontSize: 13,
                                      fontWeight: FontWeight.w900)),
                              if (d['has_login'] == true) const Padding(
                                padding: EdgeInsetsDirectional.only(
                                    start: 5),
                                child: Icon(Icons.smartphone, size: 13,
                                    color: kGreen),
                              ),
                            ]),
                            Text('${d['phone'] ?? ''}'
                                 '${(d['vehicle'] ?? '').toString().isNotEmpty ? ' · ${d['vehicle']}' : ''}',
                                style: const TextStyle(fontSize: 11,
                                    color: Colors.grey)),
                          ])),
                          Column(crossAxisAlignment:
                              CrossAxisAlignment.end, children: [
                            Text('${d['today_delivered'] ?? 0} ${ar ? 'اليوم' : 'today'}',
                                style: const TextStyle(fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    color: kGreen)),
                            Text('${d['active_orders'] ?? 0} ${ar ? 'نشط' : 'active'}',
                                style: const TextStyle(fontSize: 10,
                                    color: kOrange,
                                    fontWeight: FontWeight.w800)),
                            Text('${d['total_delivered'] ?? 0} ${ar ? 'إجمالي' : 'total'}',
                                style: const TextStyle(fontSize: 9.5,
                                    color: Colors.grey)),
                          ]),
                        ]),
                      );
                    },
                  )),
    );
  }
}
