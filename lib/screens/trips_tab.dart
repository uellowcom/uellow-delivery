// ════════════════ TRIPS — receive incoming orders at the sorting centre ═══
// The carrier sees trips Uellow dispatched, opens one, and receives each
// package either by tapping "Receive" or by scanning its barcode (turns
// green). "Receive all" can take in everything pending or only the scanned
// ones; Uellow is notified on the backend.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../api.dart';
import '../main.dart';

class TripsTab extends StatefulWidget {
  const TripsTab({super.key, this.onChanged});
  final VoidCallback? onChanged;
  @override
  State<TripsTab> createState() => _TripsTabState();
}

class _TripsTabState extends State<TripsTab> {
  List<Map<String, dynamic>>? _trips;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final v = await CarrierApi.instance.trips();
      if (mounted) setState(() => _trips = v);
    } catch (_) {
      if (mounted) setState(() => _trips = const []);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ar = CarrierApi.instance.lang == 'ar';
    final trips = _trips;
    if (trips == null) {
      return const Center(child: CircularProgressIndicator(color: kDark));
    }
    return Column(children: [
      Container(
        width: double.infinity,
        color: kDark,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(ar ? 'الرحلات الواردة من يلو' : 'Incoming trips from Uellow',
              style: const TextStyle(color: Colors.white,
                  fontWeight: FontWeight.w900, fontSize: 15)),
          const SizedBox(height: 2),
          Text(ar ? 'استلم الطلبات في مركز الفرز — يدوياً أو بمسح الباركود'
                  : 'Receive packages at the sorting centre — tap or scan',
              style: const TextStyle(color: Colors.white60, fontSize: 11)),
        ]),
      ),
      Expanded(child: trips.isEmpty
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('📭', style: TextStyle(fontSize: 46)),
              const SizedBox(height: 8),
              Text(ar ? 'لا توجد رحلات واردة حالياً' : 'No incoming trips',
                  style: const TextStyle(color: Colors.grey)),
            ]))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 20),
                itemCount: trips.length,
                itemBuilder: (_, i) => _TripCard(
                    trip: trips[i], onOpen: () => _open(trips[i])),
              ))),
    ]);
  }

  Future<void> _open(Map<String, dynamic> t) async {
    final changed = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => TripReceiveScreen(
          tripId: (t['id'] as num).toInt(),
          tripName: (t['name'] ?? '').toString()),
    ));
    if (changed == true) { _load(); widget.onChanged?.call(); }
  }
}

class _TripCard extends StatelessWidget {
  const _TripCard({required this.trip, required this.onOpen});
  final Map<String, dynamic> trip;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) {
    final ar = CarrierApi.instance.lang == 'ar';
    final total = (trip['total'] as num?)?.toInt() ?? 0;
    final pending = (trip['pending'] as num?)?.toInt() ?? 0;
    final received = total - pending;
    final pct = total == 0 ? 0.0 : received / total;
    final done = pending == 0;
    return GestureDetector(
      onTap: onOpen,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [BoxShadow(color: Color(0x11000000),
                blurRadius: 6, offset: Offset(0, 2))]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.inventory_2_outlined, size: 18, color: kDark),
            const SizedBox(width: 6),
            Text((trip['name'] ?? '').toString(),
                style: const TextStyle(fontWeight: FontWeight.w900,
                    fontSize: 14, color: kDark)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: done ? const Color(0xFFE6F7EF)
                            : const Color(0xFFFFF1E8),
                borderRadius: BorderRadius.circular(999)),
              child: Text(
                  done ? (ar ? 'مكتمل الاستلام' : 'All received')
                       : (ar ? '$pending بانتظار الاستلام' : '$pending to receive'),
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900,
                      color: done ? kGreen : kOrange)),
            ),
          ]),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: pct, minHeight: 7,
              backgroundColor: const Color(0xFFEDEDED),
              color: done ? kGreen : kOrange),
          ),
          const SizedBox(height: 6),
          Row(children: [
            Text('$received / $total ${ar ? "مستلم" : "received"}',
                style: const TextStyle(fontSize: 11, color: Colors.grey,
                    fontWeight: FontWeight.w700)),
            const Spacer(),
            if ((trip['date'] ?? '').toString().isNotEmpty)
              Text((trip['date']).toString().split('T').first,
                  style: const TextStyle(fontSize: 10.5, color: Colors.grey)),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
          ]),
        ]),
      ),
    );
  }
}

// ════════════════ TRIP RECEIVE SCREEN ════════════════
class TripReceiveScreen extends StatefulWidget {
  const TripReceiveScreen({super.key, required this.tripId, required this.tripName});
  final int tripId;
  final String tripName;
  @override
  State<TripReceiveScreen> createState() => _TripReceiveScreenState();
}

class _TripReceiveScreenState extends State<TripReceiveScreen> {
  List<Map<String, dynamic>>? _orders;
  Map<String, dynamic>? _trip;
  final Set<int> _scanned = {};   // locally marked-received (tap or scan)
  bool _busy = false;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final res = await CarrierApi.instance.tripDetail(widget.tripId);
      final orders = List<Map<String, dynamic>>.from(
          (res['orders'] as List?) ?? const []);
      if (mounted) setState(() {
        _orders = orders;
        _trip = (res['trip'] as Map?)?.cast<String, dynamic>();
      });
    } catch (_) {
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _assignPickup() async {
    final ar = CarrierApi.instance.lang == 'ar';
    List<Map<String, dynamic>> drivers = [];
    try { drivers = await CarrierApi.instance.drivers(); } catch (_) {}
    if (!mounted) return;
    final picked = await showModalBottomSheet<int>(
      context: context, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius:
          BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min,
          children: [
        Padding(padding: const EdgeInsets.all(14),
            child: Text(ar ? 'اختر مندوب الاستلام من مخزن يلو'
                          : 'Pick the courier to collect from Uellow',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15))),
        if (drivers.isEmpty) Padding(padding: const EdgeInsets.all(20),
            child: Text(ar ? 'لا يوجد سائقون' : 'No drivers')),
        for (final d in drivers.take(15)) ListTile(
          leading: const Icon(Icons.sports_motorsports_outlined, color: kDark),
          title: Text((d['name'] ?? '').toString(),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          subtitle: Text((d['phone'] ?? '').toString(),
              style: const TextStyle(fontSize: 11)),
          onTap: () => Navigator.pop(ctx, (d['id'] as num).toInt()),
        ),
      ])),
    );
    if (picked == null) return;
    setState(() => _busy = true);
    try {
      await CarrierApi.instance.tripAssignPickup(widget.tripId, picked);
      await _load();
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            backgroundColor: kGreen,
            content: Text(ar ? '✓ تم تعيين المندوب وإشعاره'
                            : '✓ Courier assigned & notified')));
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message)));
      }
    }
  }

  Widget _pickupBanner(bool ar) {
    final t = _trip;
    if (t == null) return const SizedBox.shrink();
    final state = (t['pickup_state'] ?? 'unassigned').toString();
    final pd = (t['pickup_driver'] as Map?)?.cast<String, dynamic>();
    final label = {
      'unassigned': ar ? 'لم يُعيَّن مندوب استلام بعد' : 'No pickup courier yet',
      'assigned':   ar ? 'مندوب الاستلام مُعيَّن — بانتظار الجمع' : 'Pickup courier assigned',
      'collecting': ar ? 'جاري الجمع من مخزن يلو' : 'Collecting from Uellow',
      'collected':  ar ? 'تم الجمع من مخزن يلو' : 'Collected from Uellow',
    }[state] ?? state;
    final done = state == 'collected';
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: done ? const Color(0xFFE9F8EF) : const Color(0xFFF3EDFA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: done
            ? kGreen.withValues(alpha: 0.4)
            : const Color(0xFF6B3FA0).withValues(alpha: 0.25)),
      ),
      child: Row(children: [
        Icon(done ? Icons.check_circle : Icons.local_shipping_outlined,
            color: done ? kGreen : const Color(0xFF6B3FA0), size: 22),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w900,
              fontSize: 12.5)),
          if (pd != null) Text('${ar ? "المندوب" : "Courier"}: ${pd['name']}',
              style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ])),
        if (state == 'unassigned' || state == 'assigned')
          TextButton(
            onPressed: _busy ? null : _assignPickup,
            child: Text(state == 'unassigned'
                ? (ar ? 'تعيين مندوب' : 'Assign')
                : (ar ? 'تغيير' : 'Change'),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800))),
      ]),
    );
  }

  bool _alreadyReceived(Map<String, dynamic> o) => o['received'] == true;
  bool _done(Map<String, dynamic> o) =>
      _alreadyReceived(o) || _scanned.contains((o['id'] as num).toInt());

  List<Map<String, dynamic>> get _pending =>
      (_orders ?? const []).where((o) => !_alreadyReceived(o)).toList();

  Future<void> _scan() async {
    final pending = _pending;
    final result = await Navigator.of(context).push<Set<int>>(MaterialPageRoute(
      builder: (_) => TripScanScreen(orders: pending, initialScanned: _scanned),
    ));
    if (result != null) setState(() { _scanned.addAll(result); });
  }

  Future<void> _receiveAll() async {
    final ar = CarrierApi.instance.lang == 'ar';
    final pendingIds = _pending.map((o) => (o['id'] as num).toInt()).toSet();
    if (pendingIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ar ? 'لا يوجد ما يُستلم' : 'Nothing to receive')));
      return;
    }
    final scannedPending = pendingIds.intersection(_scanned);
    final notScanned = pendingIds.difference(_scanned);

    if (notScanned.isEmpty) {
      await _submit(orderIds: scannedPending.toList(), receiveMissing: false);
      return;
    }
    // some packages were never scanned/received → ask
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ar ? 'استلام الطلبات' : 'Receive orders'),
        content: Text(ar
            ? 'يوجد ${notScanned.length} طلب لم يتم مسحه/استلامه.\n'
              'هل تريد استلام الكل، أم استلام المُمسوح فقط (${scannedPending.length})؟'
            : '${notScanned.length} order(s) were not scanned.\n'
              'Receive everything, or only the scanned ones (${scannedPending.length})?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, 'cancel'),
              child: Text(ar ? 'إلغاء' : 'Cancel')),
          if (scannedPending.isNotEmpty)
            TextButton(onPressed: () => Navigator.pop(ctx, 'scanned'),
                child: Text(ar ? 'المُمسوح فقط' : 'Scanned only')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, 'all'),
              style: ElevatedButton.styleFrom(backgroundColor: kOrange),
              child: Text(ar ? 'استلام الكل' : 'Receive all')),
        ],
      ),
    );
    if (choice == null || choice == 'cancel') return;
    if (choice == 'all') {
      await _submit(orderIds: pendingIds.toList(), receiveMissing: true);
    } else {
      await _submit(orderIds: scannedPending.toList(), receiveMissing: false);
    }
  }

  Future<void> _submit({required List<int> orderIds, required bool receiveMissing}) async {
    final ar = CarrierApi.instance.lang == 'ar';
    setState(() => _busy = true);
    try {
      final res = await CarrierApi.instance.tripReceive(widget.tripId,
          orderIds: orderIds, receiveMissing: receiveMissing);
      final n = (res['received'] as num?)?.toInt() ?? orderIds.length;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: kGreen,
          content: Text(ar ? '✓ تم استلام $n طلب — وتم إشعار يلو'
                            : '✓ Received $n order(s) — Uellow notified')));
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ar = CarrierApi.instance.lang == 'ar';
    final orders = _orders;
    final total = orders?.length ?? 0;
    final doneCount = (orders ?? const []).where(_done).length;
    return Directionality(
      textDirection: ar ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text('${ar ? "استلام" : "Receive"} · ${widget.tripName}',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
        ),
        body: orders == null
            ? const Center(child: CircularProgressIndicator(color: kDark))
            : Column(children: [
                // progress header
                Container(
                  color: kDark,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Row(children: [
                      Text('$doneCount / $total',
                          style: const TextStyle(color: Colors.white,
                              fontSize: 22, fontWeight: FontWeight.w900)),
                      const SizedBox(width: 6),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text(ar ? 'مُستلم' : 'received',
                            style: const TextStyle(color: Colors.white54,
                                fontSize: 12)),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: total == 0 ? 0 : doneCount / total,
                        minHeight: 8,
                        backgroundColor: Colors.white24, color: kGold),
                    ),
                  ]),
                ),
                // pickup-courier banner (assign / status)
                _pickupBanner(ar),
                // scan button
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                  child: SizedBox(width: double.infinity, height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _busy ? null : _scan,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kOrange, foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14))),
                      icon: const Icon(Icons.qr_code_scanner, size: 22),
                      label: Text(ar ? 'مسح باركود الطلبات' : 'Scan order barcodes',
                          style: const TextStyle(fontWeight: FontWeight.w900,
                              fontSize: 15)))),
                ),
                Expanded(child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 20),
                  itemCount: orders.length,
                  itemBuilder: (_, i) => _orderRow(orders[i], ar),
                )),
                // receive-all bar
                SafeArea(top: false, child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
                  child: SizedBox(width: double.infinity, height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _busy ? null : _receiveAll,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kGreen, foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15))),
                      icon: _busy
                          ? const SizedBox(width: 18, height: 18, child:
                              CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.done_all, size: 22),
                      label: Text(ar ? 'استلام الكل / المُمسوح' : 'Receive all / scanned',
                          style: const TextStyle(fontWeight: FontWeight.w900,
                              fontSize: 15)))),
                )),
              ]),
      ),
    );
  }

  Widget _orderRow(Map<String, dynamic> o, bool ar) {
    final id = (o['id'] as num).toInt();
    final done = _done(o);
    final already = _alreadyReceived(o);
    final customer = (o['customer'] as Map?)?.cast<String, dynamic>() ?? const {};
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: done ? const Color(0xFFE9F8EF) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: done ? kGreen.withValues(alpha: 0.5) : const Color(0xFFECECEC),
            width: 1.3),
      ),
      child: Row(children: [
        Icon(done ? Icons.check_circle : Icons.radio_button_unchecked,
            color: done ? kGreen : const Color(0xFFB8B8B8), size: 24),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Row(children: [
            Text((o['name'] ?? '').toString(),
                style: const TextStyle(fontWeight: FontWeight.w900,
                    fontSize: 13, color: kDark)),
            if ((o['code'] ?? '').toString().isNotEmpty &&
                (o['code']).toString() != (o['name']).toString())
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 6),
                child: Text((o['code']).toString(),
                    style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ),
          ]),
          Text('${customer['name'] ?? ''} · ${customer['phone'] ?? ''}',
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5, color: Colors.grey)),
        ])),
        if (already)
          Text(ar ? 'مُستلم' : 'Received',
              style: const TextStyle(color: kGreen, fontWeight: FontWeight.w800,
                  fontSize: 11))
        else if (done)
          TextButton(
            onPressed: () => setState(() => _scanned.remove(id)),
            child: Text(ar ? 'تراجع' : 'Undo',
                style: const TextStyle(fontSize: 11.5)))
        else
          ElevatedButton(
            onPressed: () => setState(() => _scanned.add(id)),
            style: ElevatedButton.styleFrom(
              backgroundColor: kDark, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              minimumSize: const Size(0, 0),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9))),
            child: Text(ar ? 'استلام' : 'Receive',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800))),
      ]),
    );
  }
}

// ════════════════ BARCODE SCANNER ════════════════
class TripScanScreen extends StatefulWidget {
  const TripScanScreen({super.key, required this.orders, required this.initialScanned});
  final List<Map<String, dynamic>> orders;   // pending orders {id, code, name}
  final Set<int> initialScanned;
  @override
  State<TripScanScreen> createState() => _TripScanScreenState();
}

class _TripScanScreenState extends State<TripScanScreen> {
  final MobileScannerController _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal, facing: CameraFacing.back);
  late final Set<int> _scanned = {...widget.initialScanned};
  String _msg = '';
  Color _msgColor = Colors.white;
  String _lastRaw = '';

  int? _match(String raw) {
    final r = raw.trim().toLowerCase();
    if (r.isEmpty) return null;
    for (final o in widget.orders) {
      final id = (o['id'] as num).toInt();
      final code = (o['code'] ?? '').toString().trim().toLowerCase();
      final name = (o['name'] ?? '').toString().trim().toLowerCase();
      if (r == code || r == name || r == '$id'
          || (code.isNotEmpty && code == r) || (name.isNotEmpty && r == name)) {
        return id;
      }
    }
    return null;
  }

  void _onDetect(BarcodeCapture cap) {
    final ar = CarrierApi.instance.lang == 'ar';
    for (final b in cap.barcodes) {
      final raw = (b.rawValue ?? '').trim();
      if (raw.isEmpty || raw == _lastRaw) continue;
      _lastRaw = raw;
      final id = _match(raw);
      if (id == null) {
        _flash(ar ? '✗ باركود غير معروف' : '✗ Unknown barcode', kRed);
      } else if (_scanned.contains(id)) {
        _flash(ar ? '• مُسجّل بالفعل' : '• Already scanned', kGold);
      } else {
        _scanned.add(id);
        HapticFeedback.mediumImpact();
        final o = widget.orders.firstWhere((x) => (x['id'] as num).toInt() == id);
        _flash('✓ ${o['name']}', kGreen);
      }
    }
  }

  void _flash(String msg, Color color) {
    if (!mounted) return;
    setState(() { _msg = msg; _msgColor = color; });
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final ar = CarrierApi.instance.lang == 'ar';
    final total = widget.orders.length;
    final got = widget.orders
        .where((o) => _scanned.contains((o['id'] as num).toInt())).length;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        MobileScanner(controller: _controller, onDetect: _onDetect),
        // scan frame
        Center(child: Container(
          width: 250, height: 250,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white, width: 3),
            borderRadius: BorderRadius.circular(18)),
        )),
        // top bar
        SafeArea(child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            IconButton(
              onPressed: () => Navigator.pop(context, _scanned),
              icon: const Icon(Icons.arrow_back, color: Colors.white)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: kDark.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(999)),
              child: Text(ar ? 'مُمسوح: $got / $total' : 'Scanned: $got / $total',
                  style: const TextStyle(color: Colors.white,
                      fontWeight: FontWeight.w900, fontSize: 13)),
            ),
            const Spacer(),
            IconButton(
              onPressed: () => _controller.toggleTorch(),
              icon: const Icon(Icons.flash_on, color: Colors.white)),
          ]),
        )),
        // feedback + done
        Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (_msg.isNotEmpty) Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(color: _msgColor,
                    borderRadius: BorderRadius.circular(12)),
                child: Text(_msg, style: const TextStyle(color: Colors.white,
                    fontWeight: FontWeight.w900, fontSize: 14)),
              ),
              SizedBox(width: double.infinity, height: 52,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context, _scanned),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white, foregroundColor: kDark,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15))),
                  icon: const Icon(Icons.check, size: 20),
                  label: Text(ar ? 'تم — رجوع للقائمة' : 'Done — back to list',
                      style: const TextStyle(fontWeight: FontWeight.w900,
                          fontSize: 15)))),
            ]),
          )),
        ),
      ]),
    );
  }
}
