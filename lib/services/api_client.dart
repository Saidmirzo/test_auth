import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:test_auth/config/api_config.dart';
import 'package:test_auth/services/alice_inspector.dart';
import 'package:test_auth/services/token_storage.dart';

class SessionExpiredException implements Exception {
  const SessionExpiredException();
}

class ApiClient {
  ApiClient._() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: const {'Content-Type': 'application/json'},
      ),
    );
    _refreshDio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: const {'Content-Type': 'application/json'},
      ),
    );
    _dio.interceptors.add(_AuthInterceptor(this));
    final inspector = AliceInspector.dioInterceptor();
    if (inspector != null) {
      _dio.interceptors.add(inspector);
      _refreshDio.interceptors.add(AliceInspector.dioInterceptor()!);
    }
  }

  static final ApiClient instance = ApiClient._();

  late final Dio _dio;
  late final Dio _refreshDio;
  final TokenStorage tokens = TokenStorage();
  VoidCallback? onSessionExpired;
  bool _handlingExpiry = false;

  Dio get dio => _dio;

  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    bool skipAuthRefresh = false,
  }) {
    return _dio.post<T>(
      path,
      data: data,
      options: Options(extra: {'skipAuthRefresh': skipAuthRefresh}),
    );
  }

  Future<Response<T>> get<T>(String path) => _dio.get<T>(path);

  Future<void> notifySessionExpired() async {
    await tokens.clear();
    if (_handlingExpiry) return;
    _handlingExpiry = true;
    try {
      onSessionExpired?.call();
    } finally {
      _handlingExpiry = false;
    }
  }
}

class _AuthInterceptor extends QueuedInterceptor {
  _AuthInterceptor(this._client);

  final ApiClient _client;
  bool _refreshing = false;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final access = await _client.tokens.readAccess();
    if (access != null && access.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $access';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final request = err.requestOptions;
    final skip = request.extra['skipAuthRefresh'] == true;
    final retried = request.extra['_retried'] == true;
    final isRefreshCall = request.path.contains(ApiPaths.tokenRefresh);
    if (err.response?.statusCode != 401 || skip || isRefreshCall || retried) {
      handler.next(err);
      return;
    }

    try {
      await _refreshTokens();
      final access = await _client.tokens.readAccess();
      if (access != null) {
        request.headers['Authorization'] = 'Bearer $access';
      }
      request.extra['_retried'] = true;
      final retry = await _client.dio.fetch(request);
      handler.resolve(retry);
    } on SessionExpiredException {
      await _client.notifySessionExpired();
      handler.next(err);
    } catch (_) {
      await _client.notifySessionExpired();
      handler.next(err);
    }
  }

  Future<void> _refreshTokens() async {
    if (_refreshing) {
      return;
    }
    _refreshing = true;
    try {
      final refresh = await _client.tokens.readRefresh();
      if (refresh == null || refresh.isEmpty) {
        throw const SessionExpiredException();
      }
      final response = await _client._refreshDio.post(
        ApiPaths.tokenRefresh,
        data: {'refresh': refresh},
      );
      final data = response.data;
      if (data is! Map || data['access'] == null || data['refresh'] == null) {
        throw const SessionExpiredException();
      }
      await _client.tokens.saveTokens(
        access: data['access'] as String,
        refresh: data['refresh'] as String,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw const SessionExpiredException();
      }
      rethrow;
    } finally {
      _refreshing = false;
    }
  }
}
