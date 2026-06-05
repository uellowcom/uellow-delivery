// Slim Uellow API client for the Delivery app — auth + carrier endpoints.
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiException implements Exception {
  ApiException(this.code, this.message);
  final String code;
  final String message;
  @override
  String toString() => message;
}

class CarrierApi {
  CarrierApi._();
  static final CarrierApi instance = CarrierApi._();

  static const baseUrl = String.fromEnvironment('UELLOW_API_BASE',
      defaultValue: 'https://www.uellow.com');

  String lang = 'ar';
  String? _token;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('carrier_token');
    lang = prefs.getString('carrier_lang') ?? 'ar';
  }

  bool get signedIn => _token != null && _token!.isNotEmpty;

  Future<void> setLang(String l) async {
    lang = l;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('carrier_lang', l);
  }

  Future<void> _saveToken(String? t) async {
    _token = t;
    final prefs = await SharedPreferences.getInstance();
    if (t == null) {
      await prefs.remove('carrier_token');
    } else {
      await prefs.setString('carrier_token', t);
    }
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'X-Lang': lang,
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  Future<Map<String, dynamic>> _req(String method, String path,
      {Map<String, dynamic>? query, Object? body}) async {
    var uri = Uri.parse('$baseUrl$path');
    if (query != null) {
      uri = uri.replace(
          queryParameters: query.map((k, v) => MapEntry(k, '$v')));
    }
    late http.Response r;
    if (method == 'GET') {
      r = await http.get(uri, headers: _headers)
          .timeout(const Duration(seconds: 30));
    } else {
      r = await http.post(uri, headers: _headers,
              body: body == null ? null : jsonEncode(body))
          .timeout(const Duration(seconds: 30));
    }
    final j = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
    if (j['success'] != true) {
      throw ApiException((j['code'] ?? 'ERROR').toString(),
          (j['error'] ?? 'Request failed').toString());
    }
    return j;
  }

  Future<Map<String, dynamic>> _get(String p,
          {Map<String, dynamic>? query}) => _req('GET', p, query: query);
  Future<Map<String, dynamic>> _post(String p, {Object? body}) =>
      _req('POST', p, body: body);

  // auth
  Future<void> login(String email, String password) async {
    final res = await _post('/api/mobile/v2/auth/login', body: {
      'email': email, 'password': password,
      'device_name': 'Delivery app',
    });
    await _saveToken((res['data']?['token'] ?? '').toString());
  }

  Future<void> logout() async {
    try { await _post('/api/mobile/v2/auth/logout'); } catch (_) {}
    await _saveToken(null);
  }

  // carrier
  Future<Map<String, dynamic>> me() async =>
      ((await _get('/api/mobile/v2/carrier/me'))['data'] as Map)
          .cast<String, dynamic>();

  Future<List<Map<String, dynamic>>> orders(
      {String status = '', String q = '', int page = 1}) async {
    final res = await _get('/api/mobile/v2/carrier/orders', query: {
      if (status.isNotEmpty) 'status': status,
      if (q.isNotEmpty) 'q': q,
      'page': page, 'per_page': 25,
    });
    return List<Map<String, dynamic>>.from(
        (res['data']?['orders'] as List?) ?? const []);
  }

  Future<Map<String, dynamic>> orderDetail(int id) async =>
      ((await _get('/api/mobile/v2/carrier/orders/$id'))['data'] as Map)
          .cast<String, dynamic>();

  Future<Map<String, dynamic>> action(int id, String act,
      {Map<String, dynamic>? body}) async {
    final res = await _post('/api/mobile/v2/carrier/orders/$id/$act',
        body: body ?? const {});
    return (res['data'] as Map).cast<String, dynamic>();
  }

  Future<List<Map<String, dynamic>>> drivers() async {
    final res = await _get('/api/mobile/v2/carrier/drivers');
    return List<Map<String, dynamic>>.from(
        (res['data']?['drivers'] as List?) ?? const []);
  }

  Future<void> createDriver({
    required String name, required String phone,
    String vehicle = '', String email = '', String password = '',
  }) async {
    await _post('/api/mobile/v2/carrier/drivers', body: {
      'name': name, 'phone': phone, 'vehicle': vehicle,
      'email': email, 'password': password,
    });
  }

  Future<Map<String, dynamic>> cash() async =>
      ((await _get('/api/mobile/v2/carrier/cash'))['data'] as Map)
          .cast<String, dynamic>();

  Future<Map<String, dynamic>> remit(List<int> orderIds,
      {String ref = ''}) async {
    final res = await _post('/api/mobile/v2/carrier/cash/remit',
        body: {'order_ids': orderIds, 'carrier_ref': ref});
    return (res['data'] as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> stats() async =>
      ((await _get('/api/mobile/v2/carrier/stats'))['data'] as Map)
          .cast<String, dynamic>();
}
