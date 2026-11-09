// Named parameters cannot be private, so the token store is assigned in the initializer list.
// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:dio/dio.dart';

import '../storage/token_store.dart';
import 'api_exception.dart';

const _kAuth = 'auth';
const _kRetried = 'retried';

/// Talks to the Surprise Studio API: unwraps the `{ success, data | error }` envelope, attaches the
/// access token, and transparently refreshes it when it expires.
class ApiClient {
  ApiClient({
    required String baseUrl,
    required TokenStore tokens,
    this.onSessionExpired,
    Dio? dio,
    Dio? uploadDio,
  })  : _tokens = tokens,
        _dio = dio ?? Dio(),
        _uploadDio = uploadDio ?? Dio() {
    _dio.options
      ..baseUrl = baseUrl
      ..connectTimeout = const Duration(seconds: 15)
      ..receiveTimeout = const Duration(seconds: 30)
      ..validateStatus = (_) => true; // we map every status ourselves
    _dio.interceptors.add(InterceptorsWrapper(onRequest: _attachToken, onResponse: _maybeRefresh));
    // Photo bytes go to storage, not the API, and carry no credentials of ours.
    _uploadDio.options
      ..connectTimeout = const Duration(seconds: 20)
      ..sendTimeout = const Duration(minutes: 2)
      ..receiveTimeout = const Duration(seconds: 30)
      ..validateStatus = (_) => true;
  }

  final TokenStore _tokens;
  final Dio _dio;
  final Dio _uploadDio;

  /// Called when the refresh token is rejected: the session is over and the user must log in again.
  final void Function()? onSessionExpired;

  Future<void>? _refreshing;

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) => _send('GET', path, query: query);
  Future<dynamic> post(String path, {Object? body, bool auth = true}) => _send('POST', path, body: body, auth: auth);
  Future<dynamic> patch(String path, {Object? body}) => _send('PATCH', path, body: body);
  Future<dynamic> delete(String path, {Object? body}) => _send('DELETE', path, body: body);

  /// PUTs raw bytes to a presigned URL. Sends only the headers the URL was signed with.
  Future<void> putToStorage(String url, List<int> bytes, Map<String, String> headers) async {
    final Response<dynamic> res;
    try {
      res = await _uploadDio.put<dynamic>(
        url,
        data: Stream.fromIterable([bytes]),
        options: Options(headers: {...headers, Headers.contentLengthHeader: bytes.length}),
      );
    } on DioException catch (e) {
      throw _fromDio(e);
    }
    if ((res.statusCode ?? 0) >= 300) {
      throw ApiException(code: 'UPLOAD_FAILED', message: 'The photo could not be uploaded', status: res.statusCode);
    }
  }

  Future<dynamic> _send(String method, String path, {Object? body, Map<String, dynamic>? query, bool auth = true}) async {
    final Response<dynamic> res;
    try {
      res = await _dio.request<dynamic>(
        path,
        data: body,
        queryParameters: query,
        options: Options(method: method, extra: {_kAuth: auth}),
      );
    } on DioException catch (e) {
      throw _fromDio(e);
    }
    return _unwrap(res);
  }

  dynamic _unwrap(Response<dynamic> res) {
    final status = res.statusCode ?? 0;
    final data = res.data;
    if (status >= 200 && status < 300) {
      return data is Map<String, dynamic> ? data['data'] : null;
    }
    if (data is Map<String, dynamic> && data['error'] is Map<String, dynamic>) {
      final e = data['error'] as Map<String, dynamic>;
      throw ApiException(code: '${e['code'] ?? 'ERROR'}', message: '${e['message'] ?? 'Request failed'}', status: status);
    }
    throw ApiException(code: 'HTTP_$status', message: 'Request failed ($status)', status: status);
  }

  ApiException _fromDio(DioException e) => switch (e.type) {
        DioExceptionType.connectionError ||
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout =>
          const ApiException.network(),
        _ => ApiException(code: 'CLIENT_ERROR', message: e.message ?? 'Request failed'),
      };

  Future<void> _attachToken(RequestOptions options, RequestInterceptorHandler handler) async {
    if (options.extra[_kAuth] != false) {
      final tokens = await _tokens.read();
      if (tokens != null) options.headers['Authorization'] = 'Bearer ${tokens.accessToken}';
    }
    handler.next(options);
  }

  /// A 401 on an authenticated call means the access token expired: refresh once, then replay.
  Future<void> _maybeRefresh(Response<dynamic> res, ResponseInterceptorHandler handler) async {
    final options = res.requestOptions;
    final retryable = res.statusCode == 401 && options.extra[_kAuth] != false && options.extra[_kRetried] != true;
    if (!retryable || await _tokens.read() == null) return handler.next(res);

    try {
      await _refreshOnce();
    } on ApiException catch (e) {
      // Network trouble is not a reason to log the user out; surface it and keep the session.
      return handler.reject(DioException(requestOptions: options, type: DioExceptionType.connectionError, error: e));
    }
    if (await _tokens.read() == null) return handler.next(res); // session ended while refreshing

    options.extra[_kRetried] = true;
    try {
      handler.next(await _dio.fetch<dynamic>(options..headers.remove('Authorization')));
    } on DioException catch (e) {
      handler.reject(e);
    }
  }

  /// Many requests can 401 at once when a token expires; they must share ONE refresh, because the
  /// server rotates refresh tokens and treats reuse of a spent one as theft (it revokes everything).
  Future<void> _refreshOnce() => _refreshing ??= _refresh().whenComplete(() => _refreshing = null);

  Future<void> _refresh() async {
    final current = await _tokens.read();
    if (current == null) return;
    try {
      final data = await post('/auth/refresh', body: {'refreshToken': current.refreshToken}, auth: false) as Map<String, dynamic>;
      await _tokens.write(Tokens(accessToken: data['accessToken'] as String, refreshToken: data['refreshToken'] as String));
    } on ApiException catch (e) {
      if (e.isNetwork || (e.status != null && e.status! >= 500)) rethrow;
      await _tokens.clear();
      onSessionExpired?.call();
    }
  }
}
