import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:surprise_studio/core/network/api_client.dart';
import 'package:surprise_studio/core/network/api_exception.dart';
import 'package:surprise_studio/core/storage/token_store.dart';

class Sent {
  Sent(this.method, this.path, this.headers, this.body);
  final String method;
  final String path;
  final Map<String, dynamic> headers;
  final String body;
}

typedef Handler = FutureOr<(int, Object?)> Function(Sent request);

/// Plays the server: records every request and answers with whatever the handler returns.
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.handler);
  final Handler handler;
  final List<Sent> sent = [];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    final bytes = <int>[];
    if (requestStream != null) {
      await for (final chunk in requestStream) {
        bytes.addAll(chunk);
      }
    }
    final req = Sent(options.method, options.uri.toString(), Map.of(options.headers), utf8.decode(bytes, allowMalformed: true));
    sent.add(req);
    final (status, body) = await handler(req);
    return ResponseBody.fromString(body == null ? '' : jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}

  int count(String method, String pathPart) => sent.where((s) => s.method == method && s.path.contains(pathPart)).length;
}

Map<String, Object?> ok(Object? data) => {'success': true, 'data': data};
Map<String, Object?> err(String code, [String message = 'm']) => {'success': false, 'error': {'code': code, 'message': message}};

const tokens = Tokens(accessToken: 'access-1', refreshToken: 'refresh-1');

(ApiClient, FakeAdapter, MemoryTokenStore, List<int>) build(Handler handler, {Tokens? initial = tokens}) {
  final adapter = FakeAdapter(handler);
  final store = MemoryTokenStore();
  if (initial != null) store.write(initial);
  final expired = <int>[];
  final dio = Dio()..httpClientAdapter = adapter;
  final uploadDio = Dio()..httpClientAdapter = adapter;
  final client = ApiClient(baseUrl: 'https://api.test/api/v1', tokens: store, dio: dio, uploadDio: uploadDio, onSessionExpired: () => expired.add(1));
  return (client, adapter, store, expired);
}

void main() {
  group('envelope', () {
    test('returns the data of a successful response', () async {
      final (client, _, _, _) = build((_) => (200, ok({'id': 7})));
      expect(await client.get('/x'), {'id': 7});
    });

    test('accepts 201 and an empty data', () async {
      final (client, _, _, _) = build((_) => (201, ok(null)));
      expect(await client.post('/x'), isNull);
    });

    test('turns an error envelope into an ApiException with the stable code', () async {
      final (client, _, _, _) = build((_) => (400, err('PHOTOS_REQUIRED', 'Add a photo')));
      await expectLater(
        client.post('/x'),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'PHOTOS_REQUIRED').having((e) => e.status, 'status', 400).having((e) => e.message, 'message', 'Add a photo')),
      );
    });

    test('copes with a non-envelope failure such as a proxy error page', () async {
      final (client, _, _, _) = build((_) => (502, null));
      await expectLater(client.get('/x'), throwsA(isA<ApiException>().having((e) => e.code, 'code', 'HTTP_502')));
    });

    test('reports an unreachable server as a network error', () async {
      final adapter = FakeAdapter((_) => (200, ok(null)));
      final dio = Dio()..httpClientAdapter = _Throwing();
      final client = ApiClient(baseUrl: 'https://api.test', tokens: MemoryTokenStore(), dio: dio, uploadDio: Dio()..httpClientAdapter = adapter);
      await expectLater(client.get('/x'), throwsA(isA<ApiException>().having((e) => e.isNetwork, 'isNetwork', true)));
    });
  });

  group('credentials', () {
    test('sends the access token on authenticated calls', () async {
      final (client, adapter, _, _) = build((_) => (200, ok(null)));
      await client.get('/x');
      expect(adapter.sent.single.headers['Authorization'], 'Bearer access-1');
    });

    test('sends nothing when signed out, and never on auth:false calls', () async {
      final (client, adapter, _, _) = build((_) => (200, ok(null)));
      await client.post('/auth/login', body: {}, auth: false);
      expect(adapter.sent.single.headers.containsKey('Authorization'), isFalse);

      final (anon, anonAdapter, _, _) = build((_) => (200, ok(null)), initial: null);
      await anon.get('/x');
      expect(anonAdapter.sent.single.headers.containsKey('Authorization'), isFalse);
    });
  });

  group('token refresh', () {
    /// First call with the old token is rejected; the refresh works; the replay with the new token succeeds.
    Handler expiringToken({int refreshStatus = 200}) => (req) {
          if (req.path.endsWith('/auth/refresh')) {
            return refreshStatus == 200
                ? (200, ok({'accessToken': 'access-2', 'refreshToken': 'refresh-2'}))
                : (refreshStatus, err('INVALID_REFRESH_TOKEN'));
          }
          return req.headers['Authorization'] == 'Bearer access-2' ? (200, ok({'ok': true})) : (401, err('INVALID_TOKEN'));
        };

    test('refreshes once on a 401 and replays the request with the new token', () async {
      final (client, adapter, store, _) = build(expiringToken());
      expect(await client.get('/surprises'), {'ok': true});
      expect(adapter.count('POST', '/auth/refresh'), 1);
      expect(adapter.sent.where((s) => s.path.endsWith('/surprises')).length, 2);
      final saved = await store.read();
      expect((saved!.accessToken, saved.refreshToken), ('access-2', 'refresh-2'));
    });

    test('sends the refresh token in the body and no bearer header', () async {
      final (client, adapter, _, _) = build(expiringToken());
      await client.get('/surprises');
      final refresh = adapter.sent.firstWhere((s) => s.path.endsWith('/auth/refresh'));
      expect(jsonDecode(refresh.body), {'refreshToken': 'refresh-1'});
      expect(refresh.headers.containsKey('Authorization'), isFalse);
    });

    test('simultaneous 401s share ONE refresh (the server revokes everything on refresh-token reuse)', () async {
      final (client, adapter, _, _) = build(expiringToken());
      final results = await Future.wait([client.get('/a'), client.get('/b'), client.get('/c'), client.get('/d')]);
      expect(results, everyElement({'ok': true}));
      expect(adapter.count('POST', '/auth/refresh'), 1);
    });

    test('a rejected refresh token ends the session: tokens cleared, callback fired, original error surfaces', () async {
      final (client, _, store, expired) = build(expiringToken(refreshStatus: 401));
      await expectLater(client.get('/surprises'), throwsA(isA<ApiException>().having((e) => e.status, 'status', 401)));
      expect(await store.read(), isNull);
      expect(expired, hasLength(1));
    });

    test('a network failure during refresh does NOT log the user out', () async {
      final adapter = FakeAdapter((req) => (401, err('INVALID_TOKEN')));
      var failRefresh = false;
      final dio = Dio()..httpClientAdapter = _Flaky(adapter, (o) => failRefresh && o.path.endsWith('/auth/refresh'));
      final store = MemoryTokenStore()..write(tokens);
      final expired = <int>[];
      final client = ApiClient(baseUrl: 'https://api.test/api/v1', tokens: store, dio: dio, uploadDio: Dio()..httpClientAdapter = adapter, onSessionExpired: () => expired.add(1));
      failRefresh = true;
      await expectLater(client.get('/surprises'), throwsA(isA<ApiException>().having((e) => e.isNetwork, 'isNetwork', true)));
      expect(await store.read(), isNotNull);
      expect(expired, isEmpty);
    });

    test('a server error during refresh does not log the user out either', () async {
      final (client, _, store, expired) = build(expiringToken(refreshStatus: 503));
      await expectLater(client.get('/surprises'), throwsA(isA<ApiException>()));
      expect(await store.read(), isNotNull);
      expect(expired, isEmpty);
    });

    test('does not loop: if the replay is still 401 it gives up after one refresh', () async {
      final (client, adapter, _, _) = build((req) => req.path.endsWith('/auth/refresh') ? (200, ok({'accessToken': 'access-2', 'refreshToken': 'refresh-2'})) : (401, err('INVALID_TOKEN')));
      await expectLater(client.get('/surprises'), throwsA(isA<ApiException>().having((e) => e.status, 'status', 401)));
      expect(adapter.count('POST', '/auth/refresh'), 1);
      expect(adapter.sent.where((s) => s.path.endsWith('/surprises')).length, 2);
    });

    test('a 401 from a login attempt is NOT retried or refreshed', () async {
      final (client, adapter, _, _) = build((_) => (401, err('INVALID_CREDENTIALS')));
      await expectLater(client.post('/auth/login', body: {}, auth: false), throwsA(isA<ApiException>().having((e) => e.code, 'code', 'INVALID_CREDENTIALS')));
      expect(adapter.sent, hasLength(1));
    });

    test('non-auth errors such as 403 or 400 are never refreshed', () async {
      final (client, adapter, _, _) = build((_) => (403, err('FORBIDDEN')));
      await expectLater(client.get('/x'), throwsA(isA<ApiException>()));
      expect(adapter.count('POST', '/auth/refresh'), 0);
    });
  });

  group('putToStorage', () {
    test('sends the bytes with only the signed headers: never our bearer token', () async {
      final (client, adapter, _, _) = build((_) => (200, null));
      await client.putToStorage('https://storage.test/bucket/uploads/abc?X-Amz-Signature=sig', [1, 2, 3, 4], {'Content-Type': 'image/jpeg'});
      final put = adapter.sent.single;
      expect(put.method, 'PUT');
      expect(put.headers.containsKey('Authorization'), isFalse);
      expect(put.headers['Content-Type'], 'image/jpeg');
      expect(put.headers['content-length'] ?? put.headers['Content-Length'], 4);
      expect(put.path, contains('X-Amz-Signature=sig'));
    });

    test('a rejected upload (for example a size mismatch) is an UPLOAD_FAILED error', () async {
      final (client, _, _, _) = build((_) => (403, null));
      await expectLater(client.putToStorage('https://storage.test/x', [1], {}), throwsA(isA<ApiException>().having((e) => e.code, 'code', 'UPLOAD_FAILED')));
    });
  });
}

class _Throwing implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) =>
      throw DioException(requestOptions: options, type: DioExceptionType.connectionError, error: 'offline');
  @override
  void close({bool force = false}) {}
}

/// Delegates to [inner] but throws a connection error for requests matching [shouldFail].
class _Flaky implements HttpClientAdapter {
  _Flaky(this.inner, this.shouldFail);
  final HttpClientAdapter inner;
  final bool Function(RequestOptions) shouldFail;
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) {
    if (shouldFail(options)) throw DioException(requestOptions: options, type: DioExceptionType.connectionError, error: 'offline');
    return inner.fetch(options, requestStream, cancelFuture);
  }

  @override
  void close({bool force = false}) => inner.close(force: force);
}
