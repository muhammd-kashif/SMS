import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  ApiException(this.message, {this.status = 0});

  final String message;
  final int status;

  @override
  String toString() => message;
}

String get apiRoot {
  if (kIsWeb) return 'http://127.0.0.1:8000/api';
  // The phone uses this computer's Wi-Fi address, so the API stays up when the USB cable moves.
  if (Platform.isAndroid) return 'http://192.168.2.110:8000/api';
  return 'http://127.0.0.1:8000/api';
}

class CollegeApi {
  String? token;

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (token != null && token!.isNotEmpty) 'Authorization': 'Bearer $token',
      };

  Future<dynamic> get(String path) => _send('GET', path);

  Future<dynamic> post(String path, [Map<String, dynamic>? body]) => _send('POST', path, body);

  Future<dynamic> put(String path, [Map<String, dynamic>? body]) => _send('PUT', path, body);

  Future<dynamic> _send(String method, String path, [Map<String, dynamic>? body]) async {
    final uri = Uri.parse('$apiRoot$path');
    late http.Response response;
    try {
      response = await http
          .Request(method, uri)
          .let((request) {
            request.headers.addAll(_headers);
            if (body != null) request.body = jsonEncode(body);
            return request.send();
          })
          .then(http.Response.fromStream)
          .timeout(const Duration(seconds: 25));
    } catch (error) {
      throw ApiException('Cannot reach the college API at $apiRoot. Start the Laravel server on port 8000.');
    }
    final decoded = response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body);
    if (response.statusCode >= 400) {
      final message = decoded is Map ? (decoded['message'] ?? _firstError(decoded) ?? 'Request failed.') : 'Request failed.';
      throw ApiException(message.toString(), status: response.statusCode);
    }
    return decoded;
  }

  String? _firstError(Map decoded) {
    final errors = decoded['errors'];
    if (errors is Map && errors.isNotEmpty) {
      final first = errors.values.first;
      if (first is List && first.isNotEmpty) return first.first.toString();
    }
    return null;
  }

  List<Map<String, dynamic>> asRows(dynamic data) {
    final list = data is List
        ? data
        : data is Map && data['data'] is List
            ? data['data'] as List
            : data is Map && data['students'] is List
                ? data['students'] as List
                : const [];
    return [
      for (final row in list)
        if (row is Map) Map<String, dynamic>.from(row),
    ];
  }

  Future<Map<String, dynamic>> branding() async => Map<String, dynamic>.from(await get('/branding') as Map);

  Future<Map<String, dynamic>> login(String email, String password) async {
    final data = await post('/login', {'email': email, 'password': password});
    return Map<String, dynamic>.from(data as Map);
  }

  Future<void> logout() async {
    try {
      await post('/logout');
    } catch (_) {}
  }

  Future<Map<String, dynamic>> dashboard() async => Map<String, dynamic>.from(await get('/dashboard') as Map);

  Future<List<Map<String, dynamic>>> students() async => asRows(await get('/students?all=1'));

  Future<Map<String, dynamic>> student(int id) async => Map<String, dynamic>.from(await get('/students/$id') as Map);

  Future<Map<String, dynamic>> createStudent(Map<String, dynamic> body) async => Map<String, dynamic>.from(await post('/students', body) as Map);

  Future<List<Map<String, dynamic>>> teachers() async => asRows(await get('/teachers?all=1'));

  Future<Map<String, dynamic>> structure() async => Map<String, dynamic>.from(await get('/structure') as Map);

  Future<List<Map<String, dynamic>>> fees() async => asRows(await get('/fees?all=1'));

  Future<List<Map<String, dynamic>>> payments() async => asRows(await get('/payments?all=1'));

  Future<List<Map<String, dynamic>>> defaulters() async => asRows(await get('/fees/defaulters'));

  Future<Map<String, dynamic>> pay(int feeItemId, num amount, String method) async {
    return Map<String, dynamic>.from(await post('/payments', {
      'fee_item_id': feeItemId,
      'amount': amount,
      'method': method,
    }) as Map);
  }

  Future<List<Map<String, dynamic>>> exams() async => asRows(await get('/exams?all=1'));

  Future<List<Map<String, dynamic>>> results(int examId) async => asRows(await get('/results?exam_id=$examId'));

  Future<List<Map<String, dynamic>>> leaves() async => asRows(await get('/leaves?all=1'));

  Future<List<Map<String, dynamic>>> timetable() async => asRows(await get('/timetable'));

  Future<List<Map<String, dynamic>>> homework() async => asRows(await get('/homework'));

  Future<List<Map<String, dynamic>>> assignments() async => asRows(await get('/assignments'));

  Future<List<Map<String, dynamic>>> announcements() async => asRows(await get('/announcements?all=1'));

  Future<List<Map<String, dynamic>>> notifications() async => asRows(await get('/notifications?all=1'));

  Future<List<Map<String, dynamic>>> attendance() async => asRows(await get('/attendance?person_type=student&all=1'));

  Future<Map<String, dynamic>> portal() async => Map<String, dynamic>.from(await get('/portal') as Map);

  Future<Map<String, dynamic>> settings() async => Map<String, dynamic>.from(await get('/settings') as Map);

  Future<Map<String, dynamic>> saveSettings(Map<String, dynamic> body) async => Map<String, dynamic>.from(await post('/settings', body) as Map);

  Future<List<Map<String, dynamic>>> reports(String type) async {
    final data = await get('/reports?type=$type');
    if (data is Map && data['rows'] is List) return asRows(data['rows']);
    return asRows(data);
  }

  Future<void> reviewLeave(int id, String status) async {
    await post('/leaves/$id/review', {'status': status});
  }

  Future<Map<String, dynamic>> applyLeave({
    required int studentId,
    required String type,
    required String start,
    required String end,
    required String reason,
  }) async {
    final data = await post('/leaves', {
      'student_id': studentId,
      'leave_type': type,
      'start_date': start,
      'end_date': end,
      'reason': reason,
    });
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> postAnnouncement(String title, String body, String audience) async {
    final data = await post('/announcements', {
      'title': title,
      'body': body,
      'audience': audience,
      'published': true,
    });
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> faceHealth() async => Map<String, dynamic>.from(await get('/face/health') as Map);

  Future<Map<String, dynamic>> faceRegister({
    required String personType,
    required int personId,
    required List<String> images,
  }) async {
    final data = await post('/face/register', {
      'person_type': personType,
      'person_id': personId,
      'images': images,
    });
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> faceScan(String image) async {
    try {
      final data = await post('/face/scan', {'image': image});
      return Map<String, dynamic>.from(data as Map);
    } on ApiException catch (error) {
      return {'failed': true, 'verified': false, 'message': error.message};
    }
  }

  Future<void> updateLocale(String locale) async {
    await put('/me', {'locale': locale});
  }
}

extension<T> on T {
  R let<R>(R Function(T value) block) => block(this);
}
